require 'arg_parser'
require 'color-console'
require 'readline'
require 'csv'
require_relative 'loggable'


class BatchKit

    class Shell

        # Define a DSL for registering commands and shortcuts that can be run
        # from a shell. Commands must be BatchKit::Job instances that can be
        # executed via a call to #run_once. Shortcuts are snippets of Ruby code
        # that can take a command-line and return an alternate command line.
        # Shortcuts are intended to be used to simplify common usage patterns
        # of utilities, by filling in some of the boiler-plate.
        module Commands

            class Command

                attr_reader :name, :description, :arguments

                def initialize(name, class_name, desc, args, &blk)
                    @name = name
                    @description = desc
                    @class = class_name
                    @arguments = args
                    @processor = blk
                end


                def get
                    Object.const_get(@class)
                end


                def run(args)
                    if @processor
                        @processor.call(self.get, args)
                    else
                        self.get.run_once(args, false)
                    end
                end

            end
            

            module ClassMethods

                include BatchKit::Loggable


                def history(file_name)
                    @history_path = File.join(Dir.home, file_name)
                end


                def registered_commands
                    @registered_commands ||= {}
                end


                def desc(desc)
                    @desc = desc
                end


                def arguments(args)
                    @arguments = args
                end


                # Register a new command, invoked using +name+.
                def command(name, cls, &blk)
                    registered_commands[name] = Command.new(name, cls, @desc, @arguments, &blk)
                    @desc = nil
                    @arguments = nil
                end


                # Invoke a new shell instance supporting the defined commands
                # and shortcuts.
                def run
                    BatchKit::Shell.new(registered_commands, @history_path).execute
                end

            end


            def self.included(base)
                base.extend(ClassMethods)
            end

        end


        include BatchKit::Loggable


        def initialize(commands, history_path)
            @commands = commands
            @history_path = history_path
        end


        def execute
            if ARGV.size > 0
                run_command(ARGV)
            else
                load_history
                prompt = '> '
                puts "Starting interactive shell... enter 'exit' to quit"
                while true do
                    begin
                        input = Readline.readline(prompt, true).strip
                        args = CSV.parse_line(input, col_sep: ' ')
                        next if args.nil? || args.size == 0
                        if args.first =~ /^(exit|quit)$/i
                            break
                        end
                        Readline::HISTORY.push(input) if input != Readline::HISTORY[-1]
                        if input =~ /^!\s*(.+)/
                            out = `#{$1}`
                            puts out
                        else
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
            when /^help$/i
                if args[1] && cmd_info = @commands[args[1].intern]
                    display_help(cmd_info)
                else
                    puts 'Available commands:'
                    @commands.keys.sort.each do |key|
                        puts "  #{key.to_s.ljust(25)} #{@commands[key].description}"
                    end
                end
            else
                cmd = args.shift.intern
                if cmd_info = @commands[cmd]
                    if cmd_info.arguments && args.size == 0
                        display_usage(cmd_info)
                    else
                        process_command(cmd, cmd_info, args)
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


        def process_command(cmd, cmd_info, args)
            begin
                cmd_info.run(args)
            rescue SystemExit => e
                puts "#{cmd} exited with status code #{e.status}"
            rescue Exception => ex
                log_exception ex
            end
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
                    history = history.slice[-100..-1] if history.size > 100
                    history.each{ |line| f.puts line }
                end
            end
        end

    end

end

