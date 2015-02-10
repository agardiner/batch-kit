require 'arg_parser'
require 'color-console'


class Batch

    # Defines a module for adding argument parsing to a job via the arg-parser
    # gem, and displaying help via the color-console gem.
    module Arguments

        include ArgParser::DSL


        # Adds an arguments accessor that returns the results from parsing the
        # command-line.
        attr_reader :arguments


        # Parse command-line arguments
        def parse_arguments(args = ARGV)
            args_def.title ||= self.job.name.titleize
            args_def.purpose ||= self.job.description
            arg_parser = ArgParser::Parser.new(args_def)
            @arguments = arg_parser.parse(args)
            if @arguments == false
                if arg_parser.show_help?
                    args_def.show_help(nil, Console.width || 80).each do |line|
                        Console.puts line, :cyan
                    end
                    exit
                else
                    arg_parser.errors.each{ |error| Console.puts error, :red }
                    args_def.show_usage(nil, Console.width || 80).each do |line|
                        Console.puts line, :yellow
                    end
                    exit(99)
                end
            end
            @arguments
        end


        # Add class methods when module is included
        def self.included(base)
            base.extend(ClassMethods)
        end

    end

end
