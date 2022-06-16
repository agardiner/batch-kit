require 'arg_parser'
require 'color-console'
require 'readline'
require 'csv'
require_relative 'loggable'


class BatchKit

    class Shell

        class Command

            attr_reader :name, :description, :arguments

            def initialize(name, class_or_name, desc, args)
                @name = name
                @description = desc
                @class_or_name = class_or_name
                @arguments = args
            end


            def get
                if @class.is_a?(String) || @class_or_name.is_a?(Symbol)
                    Object.const_get(@class_or_name)
                else
                    @class_or_name
                end
            end

        end


        # Define a DSL for registering commands and shortcuts that can be run
        # from a shell. Commands must be BatchKit::Job instances that can be
        # executed via a call to #run_once. Shortcuts are snippets of Ruby code
        # that can take a command-line and return an alternate command line.
        # Shortcuts are intended to be used to simplify common usage patterns
        # of utilities, by filling in some of the boiler-plate.
        module DSL

            module ClassMethods

                include BatchKit::Loggable


                def history(file_name=nil)
                    if file_name
                        @history_path = File.join(Dir.home, file_name)
                    else
                        @history_path
                    end
                end


                def registered_commands
                    @registered_commands ||= {}
                end


                def import_commands(mod)
                    include mod
                    registered_commands.merge!(mod.registered_commands)
                end


                def desc(desc)
                    @desc = desc
                end


                def arguments(args)
                    @arguments = args
                end


                # Register a new command, invoked using +name+.
                def command(name, cls=nil, &blk)
                    registered_commands[name] = Command.new(name, cls, @desc, @arguments)
                    @desc = nil
                    @arguments = nil
                    if blk
                        define_method(name, &blk)
                    else
                        define_method(name) do |cls, args|
                            cls.run_once(args, false)
                        end
                    end
                end


                # Invoke a new shell instance supporting the defined commands
                # and shortcuts.
                def run
                    self.new.execute
                end

            end


            def self.included(base)
                base.extend(ClassMethods)
            end

        end


        include BatchKit::Shell::DSL
        include BatchKit::Loggable


        def initialize
            @commands = self.class.registered_commands
            @history_path = self.class.history
        end


        def execute
            if ARGV.size > 0
                argv = ARGV.clone
                cmd = argv.shift.intern
                if cmd_info = @commands[cmd]
                    if cmd_info.arguments && argv.size < cmd_info.arguments.size
                        display_usage(cmd_info)
                        exit 99
                    else
                        run_command(ARGV)
                    end
                else
                    STDERR.puts "ERROR: Unknown command '#{cmd}'"
                    exit 99
                end
            else
                load_history
                prompt = '> '
                puts "Starting interactive shell... enter 'exit' to quit"
                while true do
                    begin
                        input = Readline.readline(prompt, true).strip
                        break if args.first =~ /^(exit|quit)$/i
                        Readline::HISTORY.push(input) if Readline::HISTORY.size == 0 || input != Readline::HISTORY[-1]
                        if input =~ /^!\s*(.+)/
                            out = `#{$1}`
                            puts out
                        else
                            args = CSV.parse_line(input, col_sep: ' ')
                            next if args.nil? || args.size == 0
                            run_command(args)
                        end
                    rescue => ex
                        log.error ex
                    end
                end
                save_history
            end
        end


        def run_command(args)
            case args.first
            whe /^history$/i
                puts Readline::HISTORY.to_a.inspect
            when /^help$/i
                if args[1] && cmd_info = @commands[args[1].intern]
                    display_help(cmd_info)
                else
                    puts 'Available commands:'
                    @commands.keys.sort.each do |key|
                        puts "  #{key.to_s.ljust(25)} #{@commands[key].description}"
                    end
                end
            when /^irb$/
                require 'irb'
                IRB.start
            else
                cmd = args.shift.intern
                if cmd_info = @commands[cmd]
                    if cmd_info.arguments && args.size < cmd_info.arguments.size
                        display_usage(cmd_info)
                    else
                        begin
                            if clazz = cmd_info.get
                                send(cmd, clazz, args)
                            else
                                send(cmd, args)
                            end
                        rescue SystemExit => e
                            puts "#{cmd} exited with status code #{e.status}"
                        end
                    end
                else
                    puts "ERROR: Unknown command '#{cmd}'"
                end
            end
        end


        def display_help(cmd_info)
            puts "#{cmd_info.name}: #{cmd_info.description}"
            puts
            display_usage(cmd_info)
        end


        def display_usage(cmd_info)
            puts "Usage: #{cmd_info.name} #{cmd_info.arguments.join(' ')}"
        end


        def load_history
            if @history_path && File.exists?(@history_path)
                IO.foreach(@history_path){ |line| Readline::HISTORY.push(line.chomp) }
            end
            Readline.completion_proc = lambda{ |s|
                line = Readline.line_buffer.split(' ')
                if line.length == 1
                    @commands.keys.grep(/#{Regexp.escape(s)}/)
                end
            }
        end


        def save_history
            if @history_path
                File.open(@history_path, 'w') do |f|
                    history = Readline::HISTORY.to_a
                    history = history.slice(-100..-1) if history.size > 100
                    history.each{ |line| f.puts line }
                end
            end
        end

    end

end

