class Batch

    class Sequence

        include Arguments
        include Configurable
        include Loggable


        # Include ActsAsSequence into any inheriting class
        def self.inherited(sub_class)
            sub_class.class_eval do
                include ActsAsSequence
            end
        end


        # A class variable for controlling whether sequences run; defaults to true.
        # Provides a means for orchestration programs to prevent the running
        # of sequences on require when sequences need to be runnable as standalone progs.
        @@enabled = true
        def self.enabled=(val)
            @@enabled = val
        end


        def self.load_job(job_name)
            Job.enabled = false
            require job_name
            Job.enabled = true
        end


        # Import arguments defined on a Job into this sequence
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


        # A method that instantiates an instance of this job, parses
        # arguments from the command-line, and then executes the job.
        def self.run
            if @@enabled
                sequence = self.new
                sequence.parse_arguments
                unless self.sequence.method_name
                    raise "No sequence entry method has been defined; use sequence :<method_name> or sequence do ... end in your class"
                end
                sequence.send(self.sequence.method_name)
            end
        end


        def run(job_cls, args)
            job = job_cls.new
            keys, vals = [], []
            job_cls.args_def.args.each do |arg|
                keys << arg.key
                if args.has_key?(arg.key)
                    vals << args[arg.key]
                elsif self.args_def.has_key?(arg.key)
                    vals << self.arguments.send(arg.key)
                else
                    vals << nil
                end
            end
            job_args = Struct.new(*keys)
            job_arg_vals = job_args.new(*vals)
            job.instance_variable_set(:@arguments, job_arg_vals)
            if block_given?
                yield job, job_arg_vals
            else
                unless job_cls.job.method_name
                    raise "No job entry method has been defined; use job :<method_name> or job do ... end in your class"
                end
                job.send(job_cls.job.method_name)
            end
        end

    end

end
