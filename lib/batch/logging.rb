class Batch

    module Logging

        # Log levels available
        LEVELS = [:error, :warning, :info, :config, :detail, :trace, :debug]

        # Supported logging frameworks
        FRAMEWORKS = [:null, :stdout, :log4r, :java_util_logging]


        class LogManager

            class << self

                attr_reader :log_framework


                def log_framework=(framework)
                    unless FRAMEWORKS.include?(framework)
                        raise ArgumentError, "Unknown logging framework #{framework.inspect}"
                    end
                    @log_framework = framework
                    @loggers = {}
                end


                # @return [Logger] a logger object that can be used for generating
                #   log messages. The type of logger returned will depend on the
                #   log framework being used, but the logger is guaranteed to
                #   implement the following log methods:
                #   - error
                #   - warning
                #   - info
                #   - config
                #   - detail
                #   - trace
                #   - debug
                def logger(name)
                    puts @loggers
                    logger = @loggers[name]
                    unless logger
                        logger = case @log_framework
                        when :stdout
                            StdOutLogger.new(name)
                        when :java_util_logging
                            Java::JavaUtilLogging::Logger.getLogger(name)
                        when :log4r
                            Log4r::Logger[name] || Log4r::Logger.new(name)
                        else NullLogger.instance
                        end
                        @loggers[name] = logger
                    end
                    logger
                end

            end

        end

        LogManager.log_framework = :stdout

    end

end


require_relative 'logging/null_logger'
require_relative 'logging/stdout_logger'
