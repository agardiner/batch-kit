require 'java'


class Batch

    module Logging

        class JavaLogFacade

            LEVEL_MAP = {
                :error => Java::JavaUtilLogging::Level::SEVERE,
                :warning => Java::JavaUtilLogging::Level::WARNING,
                :info => Java::JavaUtilLogging::Level::INFO,
                :config => Java::JavaUtilLogging::Level::CONFIG,
                :detail => Java::JavaUtilLogging::Level::FINE,
                :trace => Java::JavaUtilLogging::Level::FINER,
                :debug => Java::JavaUtilLogging::Level::FINEST
            }

            # @return The path to any log file used with this logger
            attr_reader :log_file


            def initialize(logger)
                @java_logger = logger
            end


            def level
                LEVEL_MAP.invert[@java_logger.getLevel()]
            end


            def level=(level)
                @java_logger.setLevel(LEVEL_MAP[level])
            end


            # Adds a FileHandler to capture output from this logger to a log file.
            def log_file=(log_path)
                @java_logger.getHandlers().each do |h|
                    @java_logger.removeHandler(h) if h.is_a?(Java::JavaUtilLogging::FileHandler)
                end
                @log_file = log_path
                if log_path
                    FileUtils.mkdir_p(File.dirname(log_path))
                    fh = Java::JavaUtilLogging::FileHandler.new(log_path, true)
                    if defined?(Console::JavaUtilLogger)
                        fmt = Console::JavaUtilLogger::RubyFormatter.new('[%1$tF %1$tT] %4$-6s  %5$s', -1)
                        fmt.level_labels[Java::JavaUtilLogging::Level::FINE] = 'DETAIL'
                        fmt.level_labels[Java::JavaUtilLogging::Level::FINER] = 'TRACE'
                    else
                        fmt = Java::JavaUtilLogging::SimpleFormatter.new
                    end
                    fh.setFormatter(fmt)
                    self.addHandler(fh)
                end
            end


            Batch::Logging::LEVELS.each do |lvl|
                java_mthd = LEVEL_MAP[lvl].getName().downcase.intern
                class_eval <<-EOD
                    def #{lvl}(msg)
                        @java_logger.#{java_mthd}(msg.to_s)
                    end
                EOD
            end

            alias_method :warn, :warning


            def method_missing(mthd, *args)
                @java_logger.send(mthd, *args)
            end

        end

    end

end

