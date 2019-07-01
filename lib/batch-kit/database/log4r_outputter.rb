class BatchKit

    class Database

        # Outputs Log4r log events to the BATCH_JOB_RUN_LOG table.
        class Log4ROutputter < Log4r::Outputter


            # Create a new database outputter for a single job run
            #
            # @param job_run [JobRun] A JobRun object representing the job run
            #   that is to be logged.
            # @param opts [Hash] An options hash.
            # @option opts [Fixnum] :max_lines The maximium number of lines to
            #   log to the database. Default is 10,000.
            # @option opts [Fixnum] :max_errors The maximum number of errors to
            #   ignore before disabling further attempts to store log messages.
            def initialize(job_run, opts = {})
                super('db_output')
                @job_run_id = job_run.job_run_id
                @log_line = 0
                @errors = 0
                @max_lines = opts.fetch(:max_lines, 10_000)
                @max_errors = opts.fetch(:max_errors, 3)
            end


            # Formats a log event, and writes it to the BATCH_JOB_RUN_LOG table
            def format(event)
                if @errors < @max_errors && event.level >= Log4r::DETAIL
                    if @log_line < @max_lines || event.level >= Log4r::WARN
                        msg = event.data.to_s[0...1000].strip
                        return unless msg.length > 0
                        @log_line += 1
                        log_name = (event.fullname[-40..-1] || event.fullname).gsub('::', '.')
                        thread_id = Log4r::MDC.get(:thread_id)
                        level = Log4r::LNAMES[event.level]
                        begin
                            JobRunLog.new(job_run: @job_run_id, log_line: @log_line,
                                          log_time: Time.now, log_name: log_name,
                                          log_level: level, thread_id: thread_id && thread_id[0..8],
                                          log_message: msg).save
                        rescue
                            # Disable logging if an exception occurs
                            @errors += 1
                            raise
                        end
                    end
                end
            end

        end

    end

end

