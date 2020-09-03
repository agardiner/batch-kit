require 'arg_parser'
require 'color-console'


class BatchKit

    # Defines a module for adding argument parsing to a job via the arg-parser
    # gem, and displaying help via the color-console gem.
    module Arguments

        include ArgParser::DSL


        module JobClassMethods

            # Import arguments defined on a Job into this class
            def self.import_args(source, options={})
                unless source.is_a?(ArgParser::Definition)
                    source = source.args_def
                end
                exclude = [options[:except]].flatten
                source.args.each do |arg|
                    unless exclude.include?(arg.key)
                        arg = arg.clone
                        if self.args_def.short_keys.include?(arg.short_key)
                            arg.instance_variable_set :@short_key, nil
                        end
                        self.args_def << arg
                    end
                end
            end

        end


        # Adds an arguments accessor that returns the results from parsing the
        # command-line.
        attr_reader :arguments


        # Parse command-line arguments
        def parse_arguments(args = ARGV, show_usage_on_error = true)
            args_def = self.class.args_def
            if defined?(BatchKit::Job) && self.is_a?(BatchKit::Job)
                args_def.title ||= self.job.name.titleize
                args_def.purpose ||= self.job.description
            end
            arg_parser = ArgParser::Parser.new(args_def)
            @arguments = arg_parser.parse(args)
            if @arguments == false
                if arg_parser.show_help?
                    arg_parser.definition.show_help(nil, Console.width || 80).each do |line|
                        Console.puts line, :cyan
                    end
                    exit
                else
                    arg_parser.errors.each{ |error| Console.puts error, :red }
                    if show_usage_on_error
                        arg_parser.definition.show_usage(nil, Console.width || 80).each do |line|
                            Console.puts line, :yellow
                        end
                    end
                    exit(99)
                end
            end
            @args_def = arg_parser.definition
            @arguments
        end


        # Add class methods when module is included
        def self.included(base)
            base.extend(ClassMethods)
            base.extend(JobClassMethods)
        end

    end

end
