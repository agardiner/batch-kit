class Batch

    module Logging

        class StdOutLogger


            # @return [String] The name of this logger
            attr_reader :name
            # @return [Symbol] The current level at which logging is set
            attr_accessor :level


            def initialize(name, level = :config)
                @name = name
                @level = level
            end


            LEVELS.each do |level|
                define_method level do |*args|
                    log_msg(level, *args)
                end
            end


            def log_msg(level, *args)
                return if LEVELS.index(level) > LEVELS.index(@level)
                msg = "%-6s  %s" % [level.to_s.upcase, args.join(' ')]
                if use_console?
                    color = case level
                    when :error then :red
                    when :warning then :yellow
                    when :info then :white
                    when :config then :cyan
                    when :detail then :light_gray
                    else :dark_gray
                    end
                    Console.puts msg, color
                else
                    STDOUT.puts msg
                end
            end


            def use_console?
                if @use_console.nil?
                    @use_console = defined?(::Console)
                end
                @use_console
            end

        end

    end

end
