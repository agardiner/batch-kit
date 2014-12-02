class Batch

    # Captures details of an execution of a task.
    module Task

        class Run < Runnable

            # @!attribute :job_run [Job::Run] The job run that this task is
            #   running under.
            # @!attribute :task_run_id [Fixnum] An integer identifier that uniquely
            #   identifies this task run.
            PROPERTIES = [
                :job_run, :task_run_id
            ]
            # Create accessors for each property
            PROPERTIES.each do |prop|
                attr_accessor prop
            end

            # Make Task::Defintion properties accessible off this Task::Run.
            add_delegated_properties(*Task::Definition.properties)


            # Create a new task run.
            def initialize(task_def, job_run, *run_args)
                raise ArgumentError, "task_def not a Task::Definition" unless task_def.is_a?(Task::Definition)
                raise ArgumentError, "job_run not a Job::Run" unless job_run.is_a?(Job::Run)
                instance = nil
                if task_def.instance_expr
                    instance = task_def.instance_expr.gsub(/(?:\$|%)\{(?:([0-9])|([\.\w]+))\}/) do
                        val = case
                        when $1 then run_args[$1.to_i]
                        when $2 then job_run.job_object.instance_eval($2)
                        end
                        val.is_a?(Array) ? val.join(', ') : val
                    end
                    instance = instance.length > 0 ? instance : nil
                end
                super(task_def, instance)
                @job_run = job_run
                @job_run << self
            end


            # Called before the task executes; if false is returned, task execution
            # will be cancelled.
            def before_execute
                #@task_start_time = Time.now
                #@task_end_time = nil
                #@status = :executing
                #@exit_code = 0
                #Batch.publish('before_execute.task', self)
                run = @job_run.job_object.respond_to?(:before_task) ?
                    @job_run.job_object.before_task(self) : true
                @status = :skipped unless run
                run
            end


            def to_s
                "<Batch::Task::Run label='#{label}'>"
            end

        end

    end

end

