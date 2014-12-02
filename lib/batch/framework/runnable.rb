require 'forwardable'


class Batch

    # Captures details of a single execution of a runnable batch process, e.g. a
    # Task or Job.
    class Runnable

        # Runnables delegate to their definitions for properties that are common
        # across all runs.
        extend Forwardable

        # The definition object for this runnable
        attr_reader :definition
        # The instance qualifier for this runnable, if it has an instance
        # qualifier.
        attr_reader :instance
        # Current status of this process.
        # One of the following states:
        #   :initialized
        #   :skipped
        #   :executing
        #   :completed
        #   :failed
        #   :aborted
        attr_reader :status
        # Time at which processing began (or nil)
        attr_reader :start_time
        # Time at which processing completed (or nil)
        attr_reader :end_time
        # Exit code of the process
        attr_reader :exit_code
        # Exception thrown that caused process to fail
        attr_accessor :exception


        # Add delegates for each specified property in +props+.
        def self.add_delegated_properties(*props)
            def_delegators :@definition, *props
        end


        # Sets the state of the runnable to :initialized.
        def initialize(definition, instance)
            @definition = definition
            @instance = instance
            @status = :initialized
        end


        # @return a label consisting of the task name and any instance qualifier.
        def label
            @instance ?
                "#{@definition.name} [#{@instance}]" : @definition.name
        end


        # Returns the elapsed time in seconds
        def elapsed
            @start_time ? (@end_time || Time.now) - @start_time : 0
        end


        # Called before the process executes; if false is returned, execution
        # will be cancelled.
        def before_execute
            @exit_code = 0
            @exception = nil
            #Batch.publish('before_execute.task', self)
            #run = @job_run.job_object.respond_to?(:before_task) ?
            #    @job_run.job_object.before_task(self) : true
            #@status = :skipped unless run
            #run
        end


        def around_execute
            @start_time = Time.now
            @status = :executing
            begin
                yield
            ensure
                @end_time = Time.now
            end
        end


        # Called after the process executes; if +success+ is true, process is
        # considered a success. If processing fails, an exception may be supplied
        # indicating the reason for failure.
        def after_execute(success, ex = nil)
            if success
                @status = :completed
                @exit_code = 0 unless @exit_code
                #@job_run.job_object.task_success(self) if @job_run.job_object.respond_to?(:task_success)
                #Batch.publish('on_success.task', self)
            else
                @status = :failed
                @exit_code = 1 unless @exit_code
                @exception = ex
                #@job_run.job_object.task_failure(self) if @job_run.job_object.respond_to?(:task_failure)
                #Batch.publish('on_failure.task', self)
            end
            #@job_run.job_object.after_task(self, success) if @job_run.job_object.respond_to?(:after_task)
            #Batch.publish('after_execute.task', self, success)
        end

    end

end

