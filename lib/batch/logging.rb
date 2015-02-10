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

                Java::JavaUtilLogging::Logger.class_eval do
                    alias_method :error, :severe
                    alias_method :detail, :fine
                    alias_method :trace, :finer
                    alias_method :debug, :finest

                    def level=(level)
                        case level
                        when :error
                            self.setLevel(Java::JavaUtilLogging::Level::SEVERE)
                        when :warning
                            self.setLevel(Java::JavaUtilLogging::Level::WARNING)
                        when :info
                            self.setLevel(Java::JavaUtilLogging::Level::INFO)
                        when :config
                            self.setLevel(Java::JavaUtilLogging::Level::CONFIG)
                        when :detail
                            self.setLevel(Java::JavaUtilLogging::Level::FINE)
                        when :trace
                            self.setLevel(Java::JavaUtilLogging::Level::FINER)
                        when :debug
                            self.setLevel(Java::JavaUtilLogging::Level::FINEST)
                        end
                    end
                end
            },
            :log4r => lambda{
                require 'log4r'
                require 'log4r/configurator'

                Log4r::Configurator.custom_levels Logging::LEVELS.reverse.map{ |l| l.to_s.upcase }
            },
            :logger => lambda{
                require 'logger'

                Logger.class_eval do
                    alias_method :warning, :warn
                    alias_method :config, :info
                    alias_method :detail, :info
                    alias_method :trace, :debug
                end
            }
        }

    end


    # Used for setting the log framework to use, and retrieving a logger
    # from the current framework.
    class LogManager

        class << self

            attr_reader :log_framework


            def log_framework=(framework)
                unless Logging::FRAMEWORKS.include?(framework)
                    raise ArgumentError, "Unknown logging framework #{framework.inspect}"
                end
                @log_framework = framework
                if init_proc = Logging::FRAMEWORK_INIT[@log_framework]
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
                        Batch::Logging::StdOutLogger.new(name)
                    when :java_util_logging
                        Java::JavaUtilLogging::Logger.getLogger(name)
                    when :log4r
                        Log4r::Logger[name] || Log4r::Logger.new(name)
                    when :logger
                        Logger.new(name)
                    else Batch::Logging::NullLogger.instance
                    end
                    @loggers[name] = logger
                end
                logger
            end

        end

    end

    # Default is to log to STDOUT
    if RUBY_PLATFORM == 'java'
        LogManager.log_framework = :java_util_logging
    else
        LogManager.log_framework = :stdout
    end

end


require_relative 'logging/null_logger'
require_relative 'logging/stdout_logger'

