require 'java'


class Java::JavaUtilLogging::Logger

    # @return The path to any log file used with this logger
    attr_reader :log_file

    alias_method :error, :severe
    alias_method :warn, :warning
    alias_method :detail, :fine
    alias_method :trace, :finer
    alias_method :debug, :finest


    def level
        case self.getLevel()
        when Java::JavaUtilLogging::Level::SEVERE
            :error
        when Java::JavaUtilLogging::Level::WARNING
            :warning
        when Java::JavaUtilLogging::Level::INFO
            :info
        when Java::JavaUtilLogging::Level::CONFIG
            :config
        when Java::JavaUtilLogging::Level::FINE
            :detail
        when Java::JavaUtilLogging::Level::FINER
            :trace
        when Java::JavaUtilLogging::Level::FINEST
            :debug
        end
    end


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


    # Adds a FileHandler to capture output from this logger to a log file.
    def log_file=(log_path)
        self.getHandlers().each{ |h| self.removeHandler(h) if h.is_a?(Java::JavaUtilLogging::FileHandler) }
        @log_file = log_path
        if log_path
            FileUtils.mkdir_p(File.dirname(log_path))
            fh = Java::JavaUtilLogging::FileHandler.new(log_path, true)
            if defined?(Console::JavaUtilLogger)
                fmt = Console::JavaUtilLogger::RubyFormatter.new('[%1$tF %1$tT] %4$-6s  %5$s%n')
            else
                fmt = Java::JavaUtilLogging::SimpleFormatter.new
            end
            fh.setFormatter(fmt)
            self.addHandler(fh)
        end
    end

end

