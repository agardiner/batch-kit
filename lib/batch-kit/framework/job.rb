require_relative '../arguments'
require_relative '../configurable'
require_relative '../loggable'


# Default log level is :detail
BatchKit::LogManager.configure(log_level: :detail)


class BatchKit

    class Job

        include Arguments
        include Configurable
        include Loggable


        # Include ActsAsJob into any inheriting class
        def self.inherited(sub_class)
            sub_class.class_eval do
                include ActsAsJob
            end
        end


        # A class variable for controlling whether jobs run; defaults to true.
        # Provides a means for orchestration programs to prevent the running
        # of jobs on require when jobs need to be runnable as standalone progs.
        @@enabled = true
        def self.enabled=(val)
            @@enabled = val
        end


        # A method that instantiates an instance of this job, parses
        # arguments from the command-line, and then executes the job.
        def self.run(args = ARGV)
            if @@enabled
                if args.length == 0 && self.args_def.keys.length > 0
                    shell
                else
                    run_once(args)
                end
            end
        end


        # Instantiates and executes a job, using the supplied arguments +args+.
        #
        # @param args [Array<String>] an array containin§g the command-line to
        #   be processed by the job.
        def self.run_once(args, show_usage_on_error = true)
            job = self.new
            job.parse_arguments(args, show_usage_on_error)
            unless self.job.method_name
                raise "No job entry method has been defined; use job :<method_name> or job do ... end in your class"
            end
            job.send(self.job.method_name)
        end


        # Starts an interactive shell for this job. Each command line entered is
        # passed to a new instance of the job for execution.
        def self.shell(prompt = '> ')
            require 'readline'
            require 'csv'
            puts "Starting interactive shell... enter 'exit' to quit"
            while true do
                args = Readline.readline(prompt, true)
                break if args == 'exit' || args == 'quit'
                begin
                    run_once(CSV.parse_line(args, col_sep: ' '), false)
                rescue Exception
                end
            end
        end


        # Convenience method for using a lock within a job method
        #
        # @param lock_name [String] The name of the lock to obtain during
        #   execution of the block.
        # @param lock_timeout [Fixnum] The maximum time (in seconds) until the
        #   lock should expire.
        # @param wait_timeout [Fixnum] An optional time (in seconds) to wait for
        #   the lock to become available if it is already in use.
        def with_lock(lock_name, lock_timeout, wait_timeout = nil, &blk)
            self.job_run.with_lock(lock_name, lock_timeout, wait_timeout, &blk)
        end


        Events.subscribe(self, 'job_run.execute') do |obj, run, *args|
            Console.title = run.label
        end

        Events.subscribe(self, 'task_run.execute') do |obj, run, *args|
            Console.title = "#{run.job_run.label} : #{run.label}"
        end

        Events.subscribe(self, 'task_run.post-execute') do |obj, run, *args|
            Console.title = run.job_run.label
        end


        # Add unhandled exception logging
        Events.subscribe(self, ['sequence_run.failure',
                                       'job_run.failure',
                                       'task_run.failure']) do |obj, run, ex|
            unless (oid = ex.object_id) == @last_id
                @last_id = oid
                # Strip out framework methods from backtrace
                ex.backtrace.reject!{ |f| f =~ /lib.batch.framework/ }
                obj.log.error "#{ex} at #{ex.backtrace.first}"
            end
        end

    end

end

