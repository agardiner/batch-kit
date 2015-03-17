require 'java'


class Java::JavaUtilLogging::Logger

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

end

