require 'etc'


class Batch

    # Captures details of an execution of a job.
    module Job

        class Run < Runnable

            # @!attribute :job_object [Object] The object instance that executed the
            #   job logic.
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
            # @!attribute :request_id [Fixnum] An integer identifier that links this
            #   job run to a job run request (if job is run on-demand).
            # @!attribute :requestors [Array<String>] A list of the requestor(s) that
            #   requested for this job to be run. May be more than one if the request
            #   has been in a queue.
            # @!attribute :job_start_time [Time] Time at which the job started
            #   executing.
            # @!attribute :job_end_time [Time] Time at which the job ended execution.
            # @!attribute :task_runs [Array<TaskRun>] An array containing details of
            #   the tasks that were executed by this job.
            # @!attribute :exit_code [Fixnum] An exit status code for the job, where
            #   0 signifies success, and non-zero failure. A value of -1 indicates
            #   the job was aborted (killed).
            # @!attribute :exceptions [Exception] Any uncaught exception that
            #   occurred during job execution (and which was not caught by a task
            #   run).
            PROPERTIES = [
                :job_object, :run_by, :pid, :job_run_id,
                :cmd_line, :job_args,
                :request_id, :requestors, :task_runs
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
            # @param run_arg [] ???
            def initialize(job_def, job_object, *run_args)
                raise ArgumentError unless job_def.is_a?(Job::Definition)
                instance = nil
                if job_def.instance_expr
                    instance = job_def.instance_expr.gsub(/(?:\$|%)\{(?:([0-9])|([\.\w]+))\}/) do
                        val = case
                        when $1 then run_args[$1.to_i]
                        when $2 then job_object.instance_eval($2)
                        end
                        val.is_a?(Array) ? val.join(', ') : val
                    end
                    instance = instance.length > 0 ? instance : nil
                end
                super(job_def, instance)

                @job_object = job_object
                @run_by = Etc.getlogin
                @cmd_line = "#{$0} #{ARGV.map{ |s| s =~ / |^\*$/ ? %Q{"#{s}"} : s }.join(' ')}".strip
                @pid = ::Process.pid
                @task_runs = []
            end


            def <<(task_run)
                unless task_run.is_a?(Task::Run)
                    raise ArgumentError, "Only Task::Run objects can be added to this Job::Run" 
                end
                @task_runs << task_run
            end


            # Call-back to be called just prior to beginning execution of a job.
            def before_execute
                super
                trap 'INT' do
                    #job_object.on_abort(self) if job_object.respond_to?(:on_abort)
                    #Batch.publish('on_abort.job', self)
                    Thread.main.raise Interrupt
                end
            end


            def to_s
                "<Batch::Job::Run label='#{label}'>"
            end

        end

    end

end

