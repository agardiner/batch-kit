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

            module ClassMethods

                include BatchKit::Loggable


                def registered_commands
                    @registered_commands ||= {}
                end


                def registered_shortcuts
                    @registered_shortcuts ||= {}
                end
                

                # Set the base path to which command relative paths will be
                # appended. Can be called multiple times; command paths are
                # evaluated relative to this base path at the time they are
                # defined.
                def base_path(base_path)
                    @base_path = base_path
                end


                # Register a new command, invoked using +name+.
                def command(name, path, cls)
                    registered_commands[name] = {path: File.join(@base_path, path), class: cls}
                    log.detail "Registered command #{name}"
                end


                # Register a new shortcut snipper, invoked using +name+.
                def shortcut(name, &blk)
                    raise ArgumentError, "A block must be supplied" unless block_given?
                    registered_shortcuts[name] = blk
                    log.detail "Registerd shortcut #{name}"
                end


                # Invoke a new shell instance supporting the defined commands
                # and shortcuts.
                def run
                    BatchKit::Shell.new(registered_commands, registered_shortcuts).execute
                end

            end


            def self.included(base)
                base.extend(ClassMethods)
            end

        end


        include BatchKit::Loggable


        def initialize(commands, shortcuts)
            @commands = commands
            @shortcuts = shortcuts
        end


        def execute
            puts "Starting interactive shell... enter 'exit' to quit"
            prompt = '> '
            while true do
                args = Readline.readline(prompt, true).strip
                case args
                when /^(exit|quit)/i
                    break
                when /^help(?:\s+(\w+))?$/
                    if $1 && cmd_info = @commands[$1.intern]
                        process_command($1, cmd_info, '--help')
                    else
                        puts "Available commands: #{(@commands.keys + @shortcuts.keys).join(', ')}"
                    end
                when /^!\s*(.+)/
                    out = `#{$1}`
                    puts out
                else
                    args = CSV.parse_line(args, col_sep: ' ')
                    next if args.size == 0
                    cmd = args.shift.intern
                    if blk = @shortcuts[cmd]
                        cmd, args = process_shortcut(cmd, args, blk)
                    end
                    next unless cmd
                    if cmd_info = @commands[cmd]
                        process_command(cmd, cmd_info, args)
                    else
                        puts "ERROR: Unknown command '#{cmd}'"
                    end
                end
            end
        end


        def process_command(cmd, cmd_info, args)
            begin
                require cmd_info[:path]
                cls = Object.const_get(cmd_info[:class])
                cls.run_once(args, false)
            rescue SystemExit => e
                puts "#{cmd} exited with status code #{e.status}"
            rescue Exception => ex
                log.error ex
            end
        end


        def process_shortcut(cmd, args, blk)
            begin
                args = blk.call(args)
                cmd = args.shift.intern
                [cmd, args]
            rescue Exception => ex
                puts "#{cmd} failed: #{ex}"
            end
        end

    end

end

