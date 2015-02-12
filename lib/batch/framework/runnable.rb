require 'forwardable'


class Batch

    # Captures details of a single execution of a runnable batch process, e.g. a
    # Task or Job.
    class Runnable

        # Runnables delegate to their definitions for properties that are common
        # across all runs.
        extend Forwardable

        class << self

            # @return [Fanout] A Fanout object used to maintain and notify
            #   subscribers to lifecycle events.
            def fanout
                @fanout ||= Fanout.new
            end


            # Subscribe to life-cycle events on this runnable class.
            def subscribe(event, &callback)
                fanout.subscribe(event, &callback)
            end


            # Add delegates for each specified property in +props+.
            def add_delegated_properties(*props)
                def_delegators :@definition, *props
            end

        end


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



        # Sets the state of the runnable to :initialized.
        def initialize(definition, instance)
            @definition = definition
            @instance = instance
            @status = :initialized
            publish('initialized', self)
        end


        # @return a label consisting of the name and any instance qualifier.
        def label
            lbl = @definition.name.gsub(/_/, ' ').gsub(/\b([a-z])/) { $1.upcase }
            @instance ? "#{lbl} [#{@instance}]" : lbl
        end


        # Returns the elapsed time in seconds
        def elapsed
            @start_time ? (@end_time || Time.now) - @start_time : 0
        end


        # A pre-execute pointcut for execution of a process. Return value
        # determines whether execution should proceed.
        #
        # @param process_obj [Object] Object that is executing the batch
        #   process.
        # @param args [*Object] Any arguments passed to the method that is
        #   executing the process.
        # @return [Boolean] True if the process should proceed, or false if it
        #   should be skipped.
        def pre_execute(process_obj, *args)
            if self.class.fanout.has_subscribers?('pre-execute')
                run = publish('pre-execute', self, process_obj, *args)
            else
                run = true
            end
            unless run
                @status = :skipped unless run
                publish('skipped', self, process_obj, *args)
            end
            run
        end


        # Called as the process is executing.
        #
        # @param process_obj [Object] Object that is executing the batch
        #   process.
        # @param args [*Object] Any arguments passed to the method that is
        #   executing the process.
        # @yield at the point when the process should execute.
        def around_execute(process_obj, *args)
            @start_time = Time.now
            @status = :executing
            publish('execute', self, process_obj, *args)
            begin
                yield
            ensure
                @end_time = Time.now
            end
        end


        # Called after the process executes and completes successfully.
        #
        # @param process_obj [Object] Object that is executing the batch
        #   process.
        # @param result [Object] If +success+ is true, the return value of the
        #   process. If +success+ is false, the exception that caused it to fail.
        def success(process_obj, result)
            @status = :completed
            @exit_code = 0 unless @exit_code
            publish('success', self, process_obj, result)
        end


        # Called after the process executes and fails.
        #
        # @param process_obj [Object] Object that is executing the batch
        #   process.
        # @param success [Boolean] True if the process completed without
        #   throwing an exception.
        # @param result_or_exception [Object|Exception] If +success+ is true,
        #   the return value of the process. If +success+ is false, the
        #   exception that caused it to fail.
        def failure(process_obj, exception)
            @status = :failed
            @exit_code = 1 unless @exit_code
            @exception = exception
            publish('failure', self, process_obj, exception)
        end


        # Called if a batch process is aborted.
        #
        # @param process_obj [Object] Object that is executing the batch
        #   process.
        def abort(process_obj)
            @status = :aborted
            publish('abort', self, process_obj)
        end


        # Called after the process executes.
        #
        # @param process_obj [Object] Object that is executing the batch
        #   process.
        # @param ok [Boolean] True if the process completed without throwing
        #   an exception.
        def post_execute(process_obj, success)
            publish('post-execute', self, process_obj, success)
        end


        private


        # Replaces placeholder expressions in an instance_expr to return an
        # instance value for a job, task, etc.
        #
        # @param instance_expr [String] The instance expression to be evaluated.
        # @param instance_obj [Object] The object against which Ruby expressions
        #   in the instance_expr will be evaluated.
        # @param run_args [Array<Object>] An array of arguments passed to the
        #   method used to execute the job, task, etc.
        # @return [String] An instance value to identify this instance of the
        #   run.
        def eval_instance_expr(instance_expr, instance_obj, run_args)
            if instance_expr
                # Replace references to run arguments (i.e. ${0} to ${9}) first...
                instance = instance_expr.gsub(/(?:\$|%)\{([0-9])\}/) do
                    val = run_args[$1.to_i]
                    val.is_a?(Array) ? val.join(', ') : val
                end
                # ... then evaluate any remaining expressions between ${} or %{}
                instance.gsub!(/(?:\$|%)\{([^\}]+)\}/) do
                    val = instance_obj.instance_eval($1)
                    val.is_a?(Array) ? val.join(', ') : val
                end
                instance = instance.length > 0 ? instance : nil
            end
        end


        # Publish a runnable life-cycle event to any listeners.
        #
        # @param event [String] The name of the event.
        # @param args [*Object] Any payload arguments to accompany the event.
        def publish(event, *args)
            self.class.fanout.publish(event, *args)
        end

    end

end

