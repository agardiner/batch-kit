require 'mail'
require_relative '../core_ext/file_utils'
require_relative 'html'
require_relative 'date_time'


class BatchKit

    module Helpers

        # Defines a number of methods to help with generating email messages in
        # both plain-text and HTML formats.
        module Email

            include Html

            # Creates a new Mail message object that can be used to create and
            # send an email.
            #
            # @param cfg [BatchKit::Config] A config object containing details of
            #   an SMTP gateway for delivering the message. Defaults to the
            #   config object defined by including BatchKit#Configurable.
            def create_email(cfg = nil)
                cfg = config if cfg.nil? && self.respond_to?(:config)
                Mail.defaults do
                    delivery_method :smtp, cfg.smtp
                end

                Mail.new(to: mail_list(cfg.smtp[:to]),
                         cc: mail_list(cfg.smtp[:cc]),
                         from: cfg.smtp[:email_from] || "#{self.job.job_class.name}@#{self.job.computer}",
                         reply_to: mail_list(cfg.smtp[:reply_to]))
            end


            # Mail likes its recipient lists as a comma-separated list in a
            # String. To make this easier to use, this helper method converts
            # an array of values into sucn a string.
            def mail_list(recips)
                recips.is_a?(Array) ? recips.join(', ') : recips
            end


            # Creates an HTML formatted email, with a default set of styles.
            #
            # @param cfg [BatchKit::Config] A config object containing details of
            #   an SMTP gateway for delivering the message. Defaults to the
            #   config object defined by including BatchKit#Configurable.
            # @param body_text [String] An optional string containing text to
            #   add to the email body.
            # @yield [Array<String>] an Array of strings to which body content
            #   can be added.
            def create_html_email(cfg = config, body_text = nil, &blk)
                if cfg.is_a?(String) || cfg.is_a?(Array)
                    body_text = cfg
                    cfg = nil
                end
                msg = create_email(cfg)
                body = create_html_document(body_text, &blk)
                msg.html_part = Mail::Part.new do |part|
                  part.content_type('text/html; charset=UTF-8')
                  part.body(body.join("\n"))
                end
                msg
            end


            # Adds details of tasks run and their duration to an email.
            #
            # @param body [Array<String>] An array containing the lines of the
            #   message body. Job execution details will be added as an HTML
            #   table to this.
            def add_job_details_to_email(body)
                has_instances = self.job_run.task_runs.find{ |tr| tr.instance }
                body << "<br>"
                body << "<div class='separator'></div>"
                body << "<p>"
                body << "<p>Job execution details:</p>"
                create_html_table(body, self.job_run.task_runs,
                                  {name: :name, label: 'Task'},
                                  {name: :instance, show: has_instances},
                                  {name: :start_time, label: 'Start Time'},
                                  {name: :end_time, label: 'End Time'},
                                  {label: 'Duration', class: 'right',
                                   value: lambda{ |tr| DateTime.display_duration(tr.elapsed) }})
                body.slice!(-2..-1)
                body << "<tr><th>#{self.job.name}</th>"
                body << "<th>#{self.job_run.instance}</th>" if has_instances
                body << "<th class='right'>#{self.job_run.start_time.strftime("%H:%M:%S")}</th>"
                body << "<th class='right'></th>"
                body << "<th class='right'>#{DateTime.display_duration(self.job_run.elapsed)}</th></tr>"
                body << "</tbody>"
                body << "</table>"
                body << "<br>"
            end


            # Creates an email message containing details of the exception that
            # caused this job to fail.
            def create_failure_email(cfg = config)
                msg = create_email(cfg)
                to = cfg[:failure_email_to]
                to = to.join(', ') if to.is_a?(Array)
                cc = cfg[:failure_email_cc]
                cc = cc.join(', ') if cc.is_a?(Array)
                msg.to = to
                msg.cc = cc
                msg.subject = "#{self.job.name} job on #{self.job.computer} Failed!"

                # Add details of the failed job and task runs
                body = []
                self.job.runs.each do |jr|
                    ex = nil
                    jr.task_runs.select{ |tr| tr.exception != nil }.each do |tr|
                        ex = tr.exception
                        body << "Job '#{jr.label}' has failed in task '#{tr.label}'."
                        body << "\n#{ex.class.name}: #{ex.message}"
                        body << "\nBacktrace:"
                        body += ex.backtrace
                        body << "\n"
                    end
                    if ex != jr.exception
                        body << "Job '#{jr.label}' has failed."
                        body << "\n#{jr.exception.class.name}: #{jr.exception.message}"
                        body << "\nBacktrace:"
                        body += jr.exception.backtrace
                        body << "\n"
                    end
                end

                # Add job log file as attachment (if it exists)
                if self.respond_to?(:log) && self.log.log_file
                    body << "See the attached log for details.\n"
                    msg.add_file(self.log.log_file)
                end
                msg.body = body.join("\n")
                msg
            end


            # Sends a failure email message in response to a job failure.
            #
            # @param recipients [String|Array] The recipient(s) to receive the
            #   email. If no recipients are specified, the configured recipients
            #   will receive the failure email.
            def send_failure_email(cfg = config, recipients = nil)
                case cfg
                when Exception
                    # Called directly from #on_failure
                    cfg = config
                when Hash
                else
                    recipients = cfg
                    cfg = config
                end
                msg = create_failure_email(cfg)
                if recipients
                    # Override default recipients
                    msg.to = recipients
                    msg.cc = nil
                end
                msg.deliver!
                log.detail "Failure email sent to #{recipient_count(msg)} recipients"
            end


            # Given a message, returns the number of recipients currently set.
            #
            # @param msg [Mail] A Mail message object.
            def recipient_count(msg)
                count = 0
                count += msg.to.size if msg.to
                count += msg.cc.size if msg.cc
                count
            end


            # Saves the content of a message to a file.
            #
            # @param msg [Mail] The message whose content is to be saved.
            # @param path [String] The path to the file to be created.
            # @param options [Hash] An options hash; see FileUtils.archive for
            #   details of supported option settings.
            def save_msg_to_file(msg, path, options = {})
                FileUtils.archive(path, options)
                file = File.open(path, "w")
                in_html = false
                msg.html_part.to_s.each_line do |line|
                    line.chomp!
                    in_html ||= (line =~ /^<html/i)
                    if in_html
                        file.puts line
                        file.puts "<title>#{msg.subject}</title>" if line =~ /<head>/
                    end
                end
                file.close
                log.detail "Saved email body to #{path}"
            end

        end

    end

end
