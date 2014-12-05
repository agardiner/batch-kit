class Batch

    module Logging

        # Implements a NULL logger, i.e. a logger that throws away log messages.
        # This logger should be used when no logging is desired.
        class NullLogger


            def self.instance
                @instance ||= self.new
            end


            LEVELS.each do |level|
                define_method level do |*args|
                    log_msg(level, *args)
                end
            end


            def log_msg(level, msg)
            end

        end

    end

end
