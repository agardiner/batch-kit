class BatchKit

    module Task

        # Captures details about a task definition - the job that it belongs to, the
        # method name that performs the task work, etc.
        class Definition < Definable

            # @!attribute :task_name [String] The name of the task (defaults to the
            #    method name).
            # @!attribute :job [Job::Definition] The job that this task belongs to.
            # @!attribute :method_name [Symbol] The name of the method that
            #   performs the work for this task.
            # @!attribute :task_id [Fixnum] A unique id for this Task::Definition,
            #   assigned by the persistence layer.
            add_properties(
                # Properties defined by a task declaration
                :job, :method_name,
                # Properties defined by persistence layer
                :task_id
            )


            # Create a new Task::Definition object for the task defined in +job_class+
            # in +method_name+.
            def initialize(job_class, method_name, task_name = nil)
                raise ArgumentError, "job_class must be a Class" unless job_class.is_a?(Class)
                raise ArgumentError, "method_name must be a Symbol" unless method_name.is_a?(Symbol)
                job_defn = job_class.job
                raise ArgumentError, "job_class must have a Job::Definition" unless job_defn

                @name = task_name || method_name.to_s.gsub(/([^A-Z ])([A-Z])/, '\1 \2').
                    gsub(/_/, ' ').gsub('::', ':').gsub(/\b([a-z])/) { $1.upcase }
                @job = job_defn
                @task_class = job_class
                @method_name = nil
                self.method_name = method_name
                @job << self
                super()
            end


            # Define a task method - the method to be run to trigger the execution
            # of a task.
            #
            # @param mthd_name [Symbol] The name of a method on the task class
            #   that is executed to begin the task processing. Note: This method
            #   must already exist on the task class when this setter is called, so
            #   that it can be wrapped in an aspect with before/after processing.
            def method_name=(mthd_name)
                unless task_class.instance_methods.include?(mthd_name)
                    raise ArgumentError, "Task class #{task_class.name} does not define a ##{mthd_name} method"
                end
                if @method_name
                    raise "Task class #{task_class.name} already has a task method defined for ##{@method_name}"
                end
                @method_name = mthd_name

                # Add an aspect for executing task
                add_aspect(task_class, mthd_name)
            end


            # Create a new Task::Run object for a run of this task.
            #
            # @param job_obj [Object] The job object that is running this task.
            # @param args [Array<Object>] The arguments passed to the task method.
            def create_run(job_obj, *args)
                # Look up the task from the actual job_obj class, so that we get the right
                # task instance (in the case of sub-classing) to create the task run for
                task = job_obj.job.tasks[self.method_name]
                task_run = Task::Run.new(task, job_obj, job_obj.job_run, *args)
                @runs << task_run
                task_run
            end


            def to_s
                "<BatchKit::Task::Definition #{task_class.name}##{@method_name}>"
            end

        end

    end

end

