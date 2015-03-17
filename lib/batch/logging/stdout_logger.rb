class Batch

    module Logging

        class StdOutLogger

            # @return [String] The name of this logger
            attr_reader :name
            # @return [Symbol] The current level at which logging is set
            attr_accessor :level
            # @return [String] The log file path, if any
            attr_reader :log_file


            def initialize(name, level = :detail)
                @name = name
                @level = level
            end


            LEVELS.each do |level|
                define_method level do |*args|
                    log_msg(level, *args)
                end
            end


            def log_file=(log_path, options = {})
                @log_file.close if @log_file
                if log_path
                    append = options.fetch(:append, true)
                    @log_file = File.new(log_path, append ? 'a' : 'w')
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
                if @log_file
                    @log_file.puts Time.now.strftime('[%F %T] ') + msg
                end
            end


            def use_console?
                unless @use_console
                    @use_console = defined?(::Console)
                end
                @use_console
            end

        end

    end

end
