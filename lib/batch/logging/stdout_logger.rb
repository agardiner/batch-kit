class Batch

    module Logging

        class StdOutLogger

            # @return [String] The name of this logger
            attr_reader :name
            # @return [Symbol] The current level at which logging is set
            attr_accessor :level
            # @return [String] The log file path, if any
            attr_reader :log_file

            # Width at which to split lines
            attr_accessor :width
            # Amount by which to indent lines
            attr_accessor :indent


            def initialize(name, level = :detail)
                @name = name
                @level = level
                @indent = 8
                @width = Console.width if use_console?
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
                lvl = level.to_s.upcase
                msg = args.join(' ')
                spacer = LEVELS.index(level) >= LEVELS.index(:config) ? '  ' : ''
                fmt_msg = "%-6s  %s%s" % [lvl, spacer, msg]
                if use_console?
                    color = case level
                    when :error then :red
                    when :warning then :yellow
                    when :info then :white
                    when :config then :cyan
                    when :detail then :light_gray
                    else :dark_gray
                    end

                    indent = @indent || 0
                    indent += 2 if indent > 0 && [:config, :detail, :trace, :debug].include?(level)

                    msg = @width ? Console.wrap_text(msg, @width - indent) : [msg]
                    msg = msg.each_with_index.map do |line, i|
                        "%-6s  %s%s" % [[lvl][i], spacer, line]
                    end.join("\n")
                    Console.puts msg, color
                else
                    STDOUT.puts fmt_msg
                end
                if @log_file
                    @log_file.puts Time.now.strftime('[%F %T] ') + fmt_msg
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
