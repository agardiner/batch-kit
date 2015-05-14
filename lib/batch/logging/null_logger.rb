class Batch

    module Logging

        # Implements a NULL logger, i.e. a logger that throws away log messages.
        # This logger should be used when no logging is desired.
        class NullLogger


            def self.instance
                @instance ||= self.new
            end


            def log_level=(level)
            end


            LEVELS.each do |level|
                define_method level do |*args|
                    log_msg(level, *args)
                end
            end

            alias_method :warn, :warning


            def log_msg(level, msg)
            end

        end

    end

end
