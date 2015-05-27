require 'mail'
require 'batch/core_ext/integer'
require 'batch/core_ext/string'


class Batch

    module Helpers

        # Defines a number of methods to help with generating email messages in
        # both plain-text and HTML formats.
        module Email

            # Creates a new Mail message object that can be used to create and
            # send an email.
            #
            # @param cfg [Batch::Config] A config object containing details of
            #   an SMTP gateway for delivering the message. Defaults to the
            #   config object defined by including Batch#Configurable.
            def create_email(cfg = nil)
                cfg = config if cfg.nil? && self.respond_to?(:config)
                Mail.defaults do
                    delivery_method :smtp, cfg.smtp
                end

                Mail.new(to: mail_list(cfg[:to]),
                         cc: mail_list(cfg[:cc]),
                         from: cfg[:email_from] || "#{self.job.job_class.name}@#{self.job.computer}",
                         reply_to: mail_list(cfg[:reply_to]))
            end


            # Mail likes its recipient lists as a comma-separated list in a
            # String. To make this easier to use, this helper method converts
            # an array of values into sucn a string.
            def mail_list(recips)
                recips.is_a?(Array) ? recips.join(', ') : recips
            end


            # Creates an HTML formatted email, with a default set of styles.
            def create_html_email(cfg = config, body_text = nil)
                if cfg.is_a?(String) || cfg.is_a?(Array)
                    body_text = cfg
                    cfg = nil
                end
                msg = create_email(cfg)

                hdr = <<-EOB.gsub(/\s{20}/, '')
                    <html>
                    <head>
                    <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=us-ascii">
                    <style>
                        @font-face {font-family: Calibri;}

                        h1      {font-family: Calibri; font-size: 16pt;}
                        h2      {font-family: Calibri; font-size: 14pt; margin: 1em 0em .2em;}
                        h3      {font-family: Calibri; font-size: 12pt; margin: 1em 0em .2em;}
                        body    {font-family: Calibri; font-size: 11pt;}
                        p       {margin: .2em 0em;}
                        table   {font-family: Calibri; font-size: 10pt;
                                 line-height: 12pt; border-collapse: collapse;}
                        th      {background-color: #00205B; color: white;
                                 font-size: 11pt; font-weight: bold; text-align: left;
                                 border: 1px solid #DDDDFF; padding: 1px 5px;}
                        td      {border: 1px solid #DDDDFF; padding: 1px 5px;}

                        .summary    {font-size: 13pt;}
                        .red        {background-color: white; color: #FF0000;}
                        .amber      {background-color: white; color: #FFA500;}
                        .green      {background-color: white; color: #33A000;}
                        .blue       {background-color: white; color: #0000A0;}
                        .bold       {font-weight: bold;}
                        .center     {text-align: center;}
                        .right      {text-align: right;}
                        .separator  {width: 200px; border-bottom: 1px gray solid;}
                    </style>
                    </head>
                    <body>
                EOB
                body = [hdr]
                body << body_text if body_text
                yield body if block_given?
                body << <<-EOB.gsub(/\s{20}/, '')
                    </body>
                    </html>
                EOB

                html_part = Mail::Part.new do |part|
                  part.content_type 'text/html; charset=UTF-8'
                  part.body body.join("\n")
                end

                msg.html_part = html_part
                msg
            end


            # Creates an HTML table from +data+.
            #
            # @param body [Array] The HTML body to which this table will be
            #   appended.
            # @param data [Array|Hash] The data to be added to the table.
            # @param cols [Array<Symbol|String|Hash>] An array of symbols,
            #   strings, or Hashes. String and symbols output as-is, while the
            #   hash can contain various options that control the display of
            #   the column and the content below it, as follows:
            #     - :name is the name of the property. It will be used to access
            #       data values if +data+ is a Hash, and will be used as the
            #       column header unless a :label property is passed.
            #     - :label is the label to use as the column header.
            #     - :class specifies a CSS class name to assign to each cell in
            #       the column.
            #     - :show is a boolean that determines whether the column is
            #       output or suppressed.
            #     - :prefix is any text that should appear before the content.
            #     - :suffix is any text that should appear after the content.
            def create_html_table(body, data, *cols)
                cols.map!{ |col| col.is_a?(Symbol) || col.is_a?(String) ? {name: col.intern} : col }
                body << "<table>"
                body << "<thead><tr>"
                add_table_cells(body,
                                cols.map{ |col| (col[:label] || col[:name]).to_s.titleize },
                                cols.map{ |col| {show: col.fetch(:show, true)} },
                                :th)
                body << "</tr></thead>"
                body << "<tbody>"
                data.each do |row|
                    body << "<tr>"
                    add_table_cells(body, row, cols)
                    body << "</tr>"
                end
                body << "</tbody>"
                body << "</table>"
            end


            # Adds a row of cells to a table.
            def add_table_cells(body, row, cols, cell_type = :td)
                cols.each_with_index do |col, i|
                    cls = col[:class]
                    show = col.fetch(:show, true)
                    prefix = col.fetch(:prefix, '')
                    suffix = col.fetch(:suffix, '')
                    next if !show
                    val = case
                    when col[:value]
                        col[:value].call(row)
                    when row.is_a?(Array)
                        row[i]
                    when row.is_a?(Hash)
                        row[col[:name]]
                    when row.respond_to?(col[:name])
                        row.send(col[:name])
                    else
                        row
                    end
                    case val
                    when Fixnum
                        val = val.with_commas
                        cls = 'right' unless cls
                    when Date, Time, DateTime
                        val = val.strftime('%H:%M:%S')
                        cls = 'right' unless cls
                    end
                    td = %Q{<#{cell_type}#{cls ? " class='#{cls}'" : ''}>#{prefix}#{val}#{suffix}</#{cell_type}>}
                    body << td
                end
            end


            # Adds details of tasks run and their duration to an email.
            def add_job_details_to_msg(body)
                has_instances = self.task_runs.find{ |tr| tr.task_instance }
                body << "<br>"
                body << "<div class='separator'></div>"
                body << "<p>"
                body << "<p>Job execution details:</p>"
                create_html_table(body, self.task_runs,
                                  {name: :task_name, label: 'Task'},
                                  {name: :task_instance, show: has_instances},
                                  {name: :task_start_time, label: 'Start Time'},
                                  {name: :task_end_time, label: 'End Time'},
                                  {label: 'Duration', class: 'right',
                                   value: lambda{ |tr| display_duration(tr.elapsed) }})
                body.slice!(-2..-1)
                body << "<tr><th>#{self.job_name}</th>"
                body << "<th>#{self.job_instance}</th>" if has_instances
                body << "<th class='right'>#{self.job_start_time.strftime("%H:%M:%S")}</th>"
                body << "<th class='right'></th>"
                body << "<th class='right'>#{display_duration(self.elapsed)}</th></tr>"
                body << "</tbody>"
                body << "</table>"
                body << "<br>"
            end


            # Creates an email message containing details of the exception that
            # caused a job to fail.
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
            #   email. If no recipients are specified, the con
            def send_failure_email(cfg = config, recipients = nil)
                unless cfg.is_a?(Hash)
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
            def save_msg_to_file(msg, path)
                # TODO: archive(path)
                file = File.open(path, "w")
                in_html = false
                msg.html_part.to_s.each_line do |line|
                    line.chomp!
                    in_html ||= (line == '<html>')
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
