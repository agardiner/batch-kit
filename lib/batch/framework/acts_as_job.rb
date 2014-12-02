class Batch

    # When included into a class, marks the class as a Batch job.
    # The including class has the following class methods added, which act as a
    # DSL for specifying the job properties and behaviour:
    # - #desc A method for setting a description for a subsequent job or task
    # - #job Defines a job entry method
    # - #task Defines a task method
    # - #job_definition Returns the Job::Definition object for the including
    #   class
    # Instances of the including class also get the following instance methods:
    # - #job Returns the Job::Definition for the class
    # - #job_run Returns the Job::Run associated with this object instance.
    module ActsAsJob

        # Define methods to be added to the class that includes this module.
        module ClassMethods

            # @return The Job::Definition object used to hold attributes of this
            #   job.
            def job_definition
                @__job__
            end


            # Captures a description for the following task or job definition
            def desc(desc)
                @__desc__ = desc
            end


            # Defines the method that is used to run this job.
            # This may be an existing method, in which case the name of the
            # method must be passed as the first argument.
            # Alternatively, a block may be supplied, which will be used to
            # create the job method.
            def job(job_method = nil, job_opts = @__desc__, &body)
                # If called as an accessor, just return the @__job__
                if  job_method || job_opts || body
                    unless job_method.is_a?(Symbol)
                        job_opts = job_method
                        job_method = job_opts.fetch(:method, :execute)
                    end

                    # Define job method if a body block was supplied
                    define_method(job_method, &body) if body

                    job_desc = nil
                    if job_opts.is_a?(Hash)
                        job_desc = @__desc__
                    elsif job_opts.is_a?(String)
                        job_desc = job_opts
                        job_opts = {}
                    elsif job_opts.nil?
                        job_opts = {}
                    end
                    @__desc__ = nil

                    opts = job_opts.clone
                    opts[:description] = job_desc unless opts[:description]
                    opts[:method_name] = job_method
                    @__job__.set_from_options(opts)
                end
                @__job__
            end


            # Defines the method that is used to run a task.
            # This may be an existing method, in which case the name of the
            # method must be passed as the first argument.
            # Alternatively, a block may be supplied, which will be used to
            # create the task method.
            def task(task_method, task_opts = @__desc__, &body)
                task_desc = nil
                if task_opts.is_a?(Hash)
                    task_desc = @__desc__
                elsif task_opts.is_a?(String)
                    task_desc = task_opts
                    task_opts = {}
                elsif task_opts.nil?
                    task_opts = {}
                end
                @__desc__ = nil

                opts = task_opts.clone
                opts[:description] = task_desc unless opts[:description]
                task_method = task_opts[:method_name] if task_opts[:method_name]

                # Create a new TaskDefinition class for the task
                task_defn = Task::Definition.new(self, task_method)
                task_defn.set_from_options(opts)
                task_defn
            end

        end


        # Hook used to extend the including class with class methods defined in
        # the Job ClassMethods module.
        #
        # Creates a JobDefinition object to hold details of the job, and stores
        # it away in a @__job_defn__ class instance variable.
        def self.included(base)
            base.extend(ClassMethods)
            caller.first =~ /^((?:[A-Z]:)?[^:]+)/
            job_file = File.realpath($1)
            job_defn = Job::Definition.new(base, job_file)
            base.instance_variable_set :@__job__, job_defn
        end


        # @return [JobDefinition] The JobDefinition for this job instance.
        def job
            self.class.job_definition
        end


        # @return [JobRun] The JobRun for this job instance.
        def job_run
            @__job_run__
        end

    end

end

