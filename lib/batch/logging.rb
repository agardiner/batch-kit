require 'fileutils'


class Batch

    module Logging

        # Log levels available
        LEVELS = [:error, :warning, :info, :config, :detail, :trace, :debug]

        # Supported logging frameworks
        FRAMEWORKS = [
            :null,
            :stdout,
            :log4r,
            :java_util_logging
        ]

        # Method aliasing needed to provide log methods corresponding to levels
        FRAMEWORK_INIT = {
            null: lambda{
                require_relative 'logging/null_logger'
            },
            stdout: lambda{
                require_relative 'logging/stdout_logger'
            },
            java_util_logging: lambda{
                require_relative 'logging/java_util_logger'
            },
            log4r: lambda{
                require_relative 'logging/log4r_logger'
            }
        }

    end


    # Used for setting the log framework to use, and retrieving a logger
    # from the current framework.
    class LogManager

        class << self

            def configure(options = {})
                self.log_framework = options[:log_framework] if options[:log_framework]
                if options.fetch(:color, true)
                    case self.log_framework
                    when :log4r
                        require 'color_console/log4r_logger'
                        Console.replace_console_logger(logger: 'batch')
                    when :java_util_logging
                        require 'color_console/java_util_logger'
                        Console.replace_console_logger
                    else
                        require 'color_console'
                    end
                end
                self.level = options[:log_level] if options[:log_level]
                self.log_file = options[:log_file] if options[:log_file]
            end


            # Returns a symbol identifying which logging framework is being used.
            def log_framework
                unless @log_framework
                    if RUBY_PLATFORM == 'java'
                        LogManager.log_framework = :java_util_logging
                    else
                        log4r = require 'log4r' rescue nil
                        if log4r.nil?
                            LogManager.log_framework = :stdout
                        else
                            LogManager.log_framework = :log4r
                        end
                    end
                end
                @log_framework
            end


            # Sets the logging framework
            def log_framework=(framework)
                unless Logging::FRAMEWORKS.include?(framework)
                    raise ArgumentError, "Unknown logging framework #{framework.inspect}"
                end
                if @log_framework
                    lvl = self.level
                end
                @log_framework = framework
                if init_proc = Logging::FRAMEWORK_INIT[@log_framework]
                    init_proc.call
                end
                self.level = lvl if lvl
                logger.trace "Log framework is #{@log_framework}"
            end


            # Returns the current root log level
            def level
                logger.level
            end


            # Sets the log level
            def level=(level)
                case log_framework
                when :log4r
                    lvl = Log4r::LNAMES.index(level.to_s.upcase)
                    Log4r::Logger.each_logger{ |l| l.level = lvl }
                else
                    logger.level = level
                end
            end


            # Sets the log file to which messages should be logged
            def log_file=(log_path)
                FileUtils.mkdir_p(File.dirname(log_path)) if log_path
                case log_framework
                when :java_util_logging
                    fh = Java::JavaUtilLogging::FileHandler.new(log_path, true)
                    if defined?(Console::JavaUtilLogger)
                        fmt = Console::JavaUtilLogger::RubyFormatter.new('[%1$tF %1$tT] %4$-6s  %5$s%n')
                    else
                        fmt = Java::JavaUtilLogging::SimpleFormatter.new
                    end
                    fh.setFormatter(fmt)
                    logger.addHandler(fh)
                when :log4r
                    if outputter = Log4r::Outputter['file']
                        outputter.close
                        logger.remove 'file'
                    end
                    if log_path
                        formatter = Log4r::PatternFormatter.new(pattern: '[%d] %-6l %x %M\r')
                        outputter = Log4r::FileOutputter.new('file', filename: log_path,
                                                             trunc: false, formatter: formatter)
                        logger.add 'file'
                    end
                when :stdout
                    logger.log_file = log_path
                end
            end


            # Returns a logger with a given name, which must be under the 'batch'
            # namespace. If name is omitted, the logger is named 'batch'. If a
            # name is specified that is not under 'batch', then it is prepended
            # with 'batch'.
            #
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
            def logger(name = nil)
                case name
                when NilClass, ''
                    name = 'batch'
                when /^batch/
                when String
                    name = "batch.#{name}"
                end
                case log_framework
                when :stdout
                    Batch::Logging::StdOutLogger.logger(name)
                when :java_util_logging
                    Java::JavaUtilLogging::Logger.getLogger(name)
                when :log4r
                    log4r_name = name.gsub('.', '::')
                    Batch::Logging::Log4rFacade.new(Log4r::Logger[log4r_name] ||
                                                    Log4r::Logger.new(log4r_name))
                else Batch::Logging::NullLogger.instance
                end
            end

        end


        if defined?(Batch::Events)
            Batch::Events.subscribe(Job::Definition, 'post-configure') do |src, cfg|
                LogManager.configure(cfg)
            end
        end

    end

end

