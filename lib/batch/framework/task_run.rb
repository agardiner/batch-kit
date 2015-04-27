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
            def initialize(task_def, job_object, job_run, *run_args)
                raise ArgumentError, "task_def not a Task::Definition" unless task_def.is_a?(Task::Definition)
                raise ArgumentError, "job_run not a Job::Run" unless job_run.is_a?(Job::Run)
                instance = eval_instance_expr(task_def.instance_expr, job_object, run_args)
                @job_run = job_run
                @job_run << self
                super(task_def, instance)
            end


            def persist?
                !definition.job.do_not_track
            end


            def to_s
                "<Batch::Task::Run label='#{label}'>"
            end

        end

    end

end

