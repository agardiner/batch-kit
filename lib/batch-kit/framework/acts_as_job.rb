class BatchKit

    # When included into a class, marks the class as a BatchKit job.
    # The including class has the following class methods added, which act as a
    # DSL for specifying the job properties and behaviour:
    # - {ClassMethods#desc desc} A method for setting a description for a
    #   subsequent job or task
    # - {ClassMethods#job job} Defines a job entry method
    # - {ClassMethods#task task} Defines a task method
    # - {ClassMethods#job_definition job_definition} Returns the Job::Definition
    #   object for the including class
    # - {ClassMethods#on_success on_success} defines a callback to be called if
    #   the job completes successfully.
    # - {ClassMethods#on_failure on_failure} defines a callback to be called if
    #   the job encounters an unhandled exception.
    # - {ClassMethods#on_completion} defines a callback to be called when the
    #   job completes.
    #
    # Instances of the including class also get the following instance methods:
    # - {#job} Returns the Job::Definition for the class
    # - {#job_run} Returns the Job::Run associated with this object instance.
    module ActsAsJob

        # Define methods to be added to the class that includes this module.
        module ClassMethods

            # @return The Job::Definition object used to hold attributes of this
            #   job.
            def job_definition
                @__job__
            end
            alias_method :definition, :job_definition


            # Captures a description for the following task or job definition.
            #
            # @param desc [String] The description to associate with the next
            #   task or job that is defined.
            def desc(desc)
                @__desc__ = desc
            end


            # Defines the method that is used to run this job.
            # This may be an existing method, in which case the name of the
            # method must be passed as the first argument.
            # Alternatively, a block may be supplied, which will be used to
            # create the job method.
            #
            # @param job_method [Symbol] The name of an existing method that is
            #   to be the job entry point.
            # @param job_opts [Hash] Options that affect the job definition.
            # @option job_opts [Symbol] :method_name The name to be assigned to
            #   the job method created from the supplied block. Default is
            #   :execute.
            # @option job_opts [String] :description A description for the job.
            def job(job_method = nil, job_opts = @__desc__, &body)
                # If called as an accessor, just return the @__job__
                if  job_method || job_opts || body
                    unless job_method.is_a?(Symbol)
                        job_opts = job_method
                        job_method = (job_opts && job_opts.is_a?(Hash) &&
                            job_opts[:method_name]) || :execute
                    end

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

                    # Define job method if a body block was supplied
                    define_method(job_method, &body) if body

                    opts = job_opts.clone
                    opts[:description] = job_desc unless opts[:description]
                    opts[:method_name] = job_method
                    # The @__job__ instance variable is crated when this module is included
                    @__job__.set_from_options(opts)
                end
                @__job__
            end


            # Defines the method that is used to run a task.
            # This may be an existing method, in which case the name of the
            # method must be passed as the first argument.
            # Alternatively, a block may be supplied, which will be used to
            # create the task method.
            #
            # @param task_method [Symbol] The name for the method that is to be
            #  this task. May be the name of an existing method (in which case
            #  no block should be supplied), or the name to give to the method
            #  that will be created from the supplied block.
            # @param task_opts [Hash] A hash containing options for the task
            #  being defined.
            # @option task_opts [Symbol] :method_name The name for the method
            #  if no symbol was provided as the first argument.
            # @option job_opts [String] :description A description for the task.
            def task(task_method, task_opts = @__desc__, &body)
                unless task_method.is_a?(Symbol)
                    task_opts = task_method
                    task_method = task_opts && task_opts[:method_name]
                end
                raise ArgumentError, "No method name specified for task" unless task_method

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

                # Define task method if a body block was supplied
                define_method(task_method, &body) if body

                opts = task_opts.clone
                opts[:description] = task_desc unless opts[:description]

                # Create a new TaskDefinition class for the task
                task_defn = Task::Definition.new(self, task_method)
                task_defn.set_from_options(opts)
                task_defn
            end


            # Defines a handler to be invoked if the job encounters an unhandled
            # exception.
            def on_failure(mthd = nil, &blk)
                Events.subscribe(self, 'job_run.failure'){ |obj, jr, ex| obj.send(mthd, ex) } if mthd
                Events.subscribe(self, 'job_run.failure'){ |obj, jr, ex| obj.instance_exec(ex, &blk) } if blk
            end


            # Defines a handler to be invoked if the job ends successfully.
            def on_success(mthd = nil, &blk)
                Events.subscribe(self, 'job_run.success'){ |obj, jr| obj.send(mthd) } if mthd
                Events.subscribe(self, 'job_run.success'){ |obj, jr| obj.instance_exec(&blk) } if blk
            end


            # Defines a handler to be invoked on completion of the job, whether
            # the job completes successfully or fails. The handler may be specified
            # as either a method name and/or via a block. Multiple calls to this
            # method can be made to register multiple callbacks if desired.
            #
            # @param mthd [Symbol] The name of an existing method on the including
            #   class. This method will be called with the Job::Run object that
            #   represents the completing job run.
            # 
            def on_completion(mthd = nil, &blk)
                Events.subscribe(self, 'job_run.post-execute'){ |obj, jr, ok| obj.send(mthd) } if mthd
                Events.subscribe(self, 'job_run.post-execute'){ |obj, jr, ok| obj.instance_exec(&blk) } if blk
            end

        end


        # Hook used to extend the including class with class methods defined in
        # the ActsAsJob::ClassMethods module.
        #
        # Creates a Job::Definition object to hold details of the job, and stores
        # it away in a @__job__ class instance variable.
        def self.included(base)
            caller.find{ |f| !(f =~ /batch-kit.framework/) } =~ /^((?:[a-zA-Z]:)?[^:]+)/
            job_file = File.realpath($1)
            job_defn = Job::Definition.new(base, job_file)
            base.instance_variable_set :@__job__, job_defn
            base.extend(ClassMethods)
            Events.publish(base, 'acts_as_job.included', job_defn)
        end


        # @return [Job::Definition] The JobDefinition for this job instance.
        def job
            self.class.job_definition
        end


        # @return [Job::Run] The JobRun for this job instance.
        def job_run
            @__job_run__
        end

    end

end

