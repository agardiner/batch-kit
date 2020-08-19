require 'etc'


class BatchKit

    class Job

        # Captures details of an execution of a job.
        class Run < Runnable

            # @!attribute :run_by [String] The name of the user that ran this job
            #   instance.
            # @!attribute :cmd_line [String] The command-line used to invoke the job.
            # @!attribute :job_args [ArgParser::Arguments] A structure holding the
            #   parsed job arguments.
            #
            # @!attribute :job_run_id [Fixnum] An integer identifier that uniquely
            #   identifies this job run.
            # @!attribute :pid [Fixnum] A process identifier (PID) for the process
            #   that is running the job.
            # @!attribute :start_time [Time] Time at which the job started
            #   executing.
            # @!attribute :end_time [Time] Time at which the job ended execution.
            # @!attribute :task_runs [Array<TaskRun>] An array containing details of
            #   the tasks that were executed by this job.
            # @!attribute :exit_code [Fixnum] An exit status code for the job, where
            #   0 signifies success, and non-zero failure. A value of -1 indicates
            #   the job was aborted (killed).
            # @!attribute :exception [Exception] Any uncaught exception that
            #   occurred during job execution (and which was not caught by a task
            #   run).
            PROPERTIES = [
                :run_by, :pid, :job_run_id,
                :cmd_line, :job_args, :task_runs
            ]
            # Define accessors for each property
            PROPERTIES.each do |attr|
                attr_accessor attr
            end

            # Make Job::Definition properties accessible off this Job::Run.
            add_delegated_properties(*Job::Definition.properties)


            # Instantiate a new JobRun representing a run of a job.
            #
            # @param job_def [Job::Definition] The Job::Definition to which this
            #   run relates.
            # @param job_object [Object] The job object instance from which the
            #   job is being executed.
            # @param run_args [Array<Object>] An array of the argument values
            #   passed to the job method.
            def initialize(job_def, job_object, *run_args)
                raise ArgumentError unless job_def.is_a?(Job::Definition)
                @run_by = Etc.getlogin || '(unknown)'
                @cmd_line = "#{$0} #{ARGV.map{ |s| s =~ / |^\*$/ ? %Q{"#{s}"} : s }.join(' ')}".strip
                @pid = ::Process.pid
                @task_runs = []
                @job_args = job_object.arguments if job_object.respond_to?(:arguments)
                super(job_def, job_object, run_args)
            end


            # Adds a Task::Run to this Job::Run.
            def <<(task_run)
                unless task_run.is_a?(Task::Run)
                    raise ArgumentError, "Only Task::Run objects can be added to this Job::Run"
                end
                @task_runs << task_run
            end


            # Called as the process is executing.
            #
            # @param process_obj [Object] Object that is executing the batch
            #   process.
            # @param args [*Object] Any arguments passed to the method that is
            #   executing the process.
            # @yield at the point when the process should execute.
            def around_execute(process_obj, *args)
              if process_obj.job_run && process_obj.job_run.status == :executing
                    raise "There is already a job run active (#{process_obj.job_run}) for #{process_obj}"
                end
                process_obj.instance_variable_set(:@__job_run__, self)
                super
            end


            # Called after the process executes and completes successfully.
            #
            # @param process_obj [Object] Object that is executing the batch
            #   process.
            # @param result [Object] The return value of the process.
            def success(process_obj, result)
                super
                process_obj.on_success if process_obj.respond_to?(:on_success)
            end


            # Called after the process executes and fails.
            #
            # @param process_obj [Object] Object that is executing the batch
            #   process.
            # @param exception [Exception] The exception that caused the job to
            #   fail.
            def failure(process_obj, exception)
                super
                process_obj.on_failure(exception) if process_obj.respond_to?(:on_failure)
            end


            # Called if a batch process is aborted.
            #
            # @param process_obj [Object] Object that is executing the batch
            #   process.
            def abort(process_obj)
                super
                process_obj.on_abort if process_obj.respond_to?(:on_abort)
            end


            # @return [Boolean] True if the job run should be recorded via any
            #   persistence layer.
            def persist?
                !definition.do_not_track
            end


            # @return [String] a short representation of this job run.
            def to_s
                "<BatchKit::Job::Run label='#{label}'>"
            end

        end

    end

end

