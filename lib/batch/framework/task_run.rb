class Batch

    module Task

        # Captures details of an execution of a task.
        class Run < Runnable

            # @return [Job::Run] The job run that this task is running under.
            attr_reader :job_run
            # @return [Fixnum] An integer identifier that uniquely identifies
            #    this task run.
            attr_accessor :task_run_id

            # Make Task::Defintion properties accessible off this Task::Run.
            add_delegated_properties(*Task::Definition.properties)


            # Create a new task run.
            #
            # @param task_def [Task::Definition] The Task::Definition to which this
            #   run relates.
            # @param job_object [Object] The job object instance from which the
            #   task is being executed.
            # @param job_run [Job::Run] The job run to which this task run belongs.
            # @param run_args [Array<Object>] An array of the argument values
            #   passed to the task method.
            def initialize(task_def, job_object, job_run, *run_args)
                raise ArgumentError, "task_def not a Task::Definition" unless task_def.is_a?(Task::Definition)
                raise ArgumentError, "job_run not a Job::Run" unless job_run.is_a?(Job::Run)
                @job_run = job_run
                @job_run << self
                super(task_def, job_object, run_args)
            end


            # @return [Boolean] True if this task run should be persisted in any
            #   persistence layer.
            def persist?
                !definition.job.do_not_track
            end


            # @return [String] A short representation of this Task::Run.
            def to_s
                "<Batch::Task::Run label='#{label}'>"
            end

        end

    end

end

