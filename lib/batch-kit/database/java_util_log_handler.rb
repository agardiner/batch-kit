class BatchKit

    class Database


        class JavaUtilLogHandler < Java::JavaUtilLogging::Handler

            # Create a new java.util.logging handler for recording log records
            # to the database.
            #
            # @param job_run [JobRun] A JobRun object representing the job run
            #   that is to be logged.
            # @param opts [Hash] An options hash.
            # @option opts [Fixnum] :max_lines The maximium number of lines to
            #   log to the database. Default is 10,000.
            # @option opts [Fixnum] :max_errors The maximum number of errors to
            #   ignore before disabling further attempts to store log messages.
            def initialize(job_run, opts = {})
                super()
                @job_run_id = job_run.job_run_id
                @log_line = 0
                @errors = 0
                @max_lines = opts.fetch(:max_lines, 10_000)
                @max_errors = opts.fetch(:max_errors, 3)
            end


            def close
                @job_run_id = nil
            end


            def flush
            end


            def publish(event)
                if @job_run_id && @errors < @max_errors &&
                    event.level.intValue >= Java::JavaUtilLogging::Level::FINE.intValue
                    if @log_line < @max_lines || event.level >= Java::JavaUtilLogging::Level::WARNING
                        msg = event.getMessage[0...1000].strip
                        return unless msg.length > 0
                        @log_line += 1
                        log_name = (event.getLoggerName[-40..-1] || event.getLoggerName)
                        level = event.level
                        begin
                            JobRunLog.new(job_run: @job_run_id, log_line: @log_line,
                                          thread_id: event.getThreadID,
                                          log_time: Time.at(event.getMillis / 1000.0), log_name: log_name,
                                          log_level: level, log_message: msg).save
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

