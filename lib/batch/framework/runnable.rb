require 'forwardable'


class Batch

    # Captures details of a single execution of a runnable batch process, e.g. a
    # Task or Job.
    class Runnable

        # Runnables delegate to their definitions for properties that are common
        # across all runs.
        extend Forwardable

        # Add locking functionality for obtaining a lock during execution of a
        # Runnable
        include Lockable


        class << self

            # Add delegates for each specified property in +props+.
            def add_delegated_properties(*props)
                del_props = props.reject{ |prop| self.instance_methods.include?(prop) }
                def_delegators :@definition, *del_props
            end

        end


        # The definition object for this runnable
        attr_reader :definition
        # The object instance that is running this runnable
        attr_reader :object
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
        # Name of any exclusive lock needed by this run
        attr_reader :lock_name
        # Number of seconds before the lock times out
        attr_reader :lock_timeout
        # Number of seconds to wait for the lock to be released before giving up
        attr_reader :lock_wait_timeout



        # Sets the state of the runnable to :initialized.
        def initialize(definition, obj, run_args)
            @definition = definition
            @object = obj
            @instance = eval_property_expr(definition.instance, obj, run_args)
            @status = :initialized
            @lock_name = eval_property_expr(definition.lock_name, obj, run_args)
            @lock_timeout = case definition.lock_timeout
                when Fixnum then definition.lock_timeout
                when String then eval_property_expr(definition.lock_timeout, obj, run_args, :to_i)
            end
            @lock_wait_timeout = case definition.lock_wait_timeout
                when Fixnum then definition.lock_wait_timeout
                when String then eval_property_expr(definition.lock_wait_timeout, obj, run_args, :to_i)
            end
            Batch::Events.publish(self, 'initialized')
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
            if Batch::Events.has_subscribers?(self, 'pre-execute')
                run = Batch::Events.publish(self, 'pre-execute', process_obj, *args)
            else
                run = true
            end
            unless run
                @status = :skipped unless run
                Batch::Events.publish(self, 'skipped', process_obj, *args)
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
        def around_execute(process_obj, *args, &blk)
            @start_time = Time.now
            @status = :executing
            @exit_code = nil
            Batch::Events.publish(self, 'execute', process_obj, *args)
            begin
                if @lock_name
                    self.with_lock(@lock_name, @lock_timeout, @lock_wait_timeout, &blk)
                else
                    yield
                end
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
            Batch::Events.publish(self, 'success', process_obj, result)
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
            Batch::Events.publish(self, 'failure', process_obj, exception)
        end


        # Called if a batch process is aborted.
        #
        # @param process_obj [Object] Object that is executing the batch
        #   process.
        def abort(process_obj)
            @status = :aborted
            Batch::Events.publish(self, 'abort', process_obj)
        end


        # Called after the process executes.
        #
        # @param process_obj [Object] Object that is executing the batch
        #   process.
        # @param ok [Boolean] True if the process completed without throwing
        #   an exception.
        def post_execute(process_obj, success)
            Batch::Events.publish(self, 'post-execute', process_obj, success)
            @object = nil
        end


        private


        # Replaces placeholder expressions in a property expression to return a
        # property value for a job, task, etc. Property expressions may contain
        # both references to arguments passed to a method, as well as Ruby
        # expressions. Both are indicated by %{} or ${} delimiters surrounding
        # the expression to be evaluated and replaced.
        #
        # @param property_expr [String] The expression to be evaluated.
        # @param instance_obj [Object] The object against which Ruby expressions
        #   in the property_expr will be evaluated.
        # @param run_args [Array<Object>] An array of arguments passed to the
        #   method used to execute the job, task, etc.
        # @param conv_mthd [Symbol] The optional name of a method to call on the
        #   result String to convert it to another type (Fixnum, Symbol, etc)
        # @return [Object] The evaluated property value for this run.
        def eval_property_expr(property_expr, instance_obj, run_args, conv_mthd = nil)
            if property_expr
                raise ArgumentError, "property_expr must be a String" unless property_expr.is_a?(String)
                # Replace references to run arguments (i.e. ${0} to ${9}) first...
                property = property_expr.gsub(/(?:\$|%)\{([0-9])\}/) do
                    val = run_args[$1.to_i]
                    val.is_a?(Array) ? val.join(', ') : val
                end
                # ... then evaluate any remaining expressions between ${} or %{}
                property.gsub!(/(?:\$|%)\{([^\}]+)\}/) do
                    val = instance_obj.instance_eval($1)
                    val.is_a?(Array) ? val.join(', ') : val
                end
                property = property.length > 0 ?
                    (conv_mthd ? property.send(conv_mthd) : property) : nil
            end
        end

    end

end

