class Batch

    module Logging

        # Log levels available
        LEVELS = [:error, :warning, :info, :config, :detail, :trace, :debug]

        # Supported logging frameworks
        FRAMEWORKS = [
            :null,
            :stdout,
            :log4r,
            :java_util_logging,
            :logger
        ]

        # Method aliasing needed to provide log methods corresponding to levels
        FRAMEWORK_INIT = {
            :java_util_logging => lambda{
                require 'java'

                Java::JavaUtilLogging::Logger.alias_method :error, :fatal
                Java::JavaUtilLogging::Logger.alias_method :detail, :fine
                Java::JavaUtilLogging::Logger.alias_method :trace, :finer
                Java::JavaUtilLogging::Logger.alias_method :debug, :finest
            },
            :log4r => lambda{
                require 'log4r'
                require 'log4r/configurator'

                Log4r::Configurator.custom_levels Logging::LEVELS.reverse.map{ |l| l.to_s.upcase }
            },
            :logger => lambda{
                require 'logger'

                Logger.alias_method :warning, :warn
                Logger.alias_method :config, :info
                Logger.alias_method :detail, :info
                Logger.alias_method :trace, :debug
            }
        }


        # Used for setting the log framework to use, and retrieving a logger
        # from the current framework.
        class LogManager

            class << self

                attr_reader :log_framework


                def log_framework=(framework)
                    unless FRAMEWORKS.include?(framework)
                        raise ArgumentError, "Unknown logging framework #{framework.inspect}"
                    end
                    @log_framework = framework
                    if init_proc = FRAMEWORK_INIT[@log_framework]
                        init_proc.call
                    end
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
                    logger = @loggers[name]
                    unless logger
                        logger = case @log_framework
                        when :stdout
                            StdOutLogger.new(name)
                        when :java_util_logging
                            Java::JavaUtilLogging::Logger.getLogger(name)
                        when :log4r
                            Log4r::Logger[name] || Log4r::Logger.new(name)
                        when :logger
                            Logger.new(name)
                        else NullLogger.instance
                        end
                        @loggers[name] = logger
                    end
                    logger
                end

            end

        end

        # Default is to log to STDOUT
        LogManager.log_framework = :stdout

    end

end


require_relative 'logging/null_logger'
require_relative 'logging/stdout_logger'

