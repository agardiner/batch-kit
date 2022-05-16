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
                if !@shell && args.include?('--shell')
                    args.delete_if{ |arg| arg == '--shell' }
                    shell(args)
                else
                    run_once(args)
                end
            end
        end


        # Class method for marking this job class as one that should not provide
        # an interactive shell.
        def self.no_shell
            @shell = false
        end


        # Class method for marking this job class as one that should not be tracked
        # in the database.
        def self.do_not_track
            self.job_definition.do_not_track = true
        end


        # Instantiates and executes a job, using the supplied arguments +args+.
        #
        # @param args [Array<String>, Hash<String, String>] an array containing
        #   the command-line to be processed by the job, or a hash of argument
        #   keys and values.
        def self.run_once(args, show_usage_on_error = true)
            if args.delete('--do-not-track')
                self.job_definition.do_not_track = true
            end
            if args.delete('--no-checkpoints')
                self.job_definition.no_checkpoints = true
            end
            job = self.new
            job.parse_arguments(args, show_usage_on_error)
            unless self.job.method_name
                raise "No job entry method has been defined; use job :<method_name> or job do ... end in your class"
            end
            job.send(self.job.method_name)
        end


        # Starts an interactive shell for this job. Each command line entered is
        # passed to a new instance of the job for execution.
        def self.shell(std_args = nil, prompt = '> ')
            require 'readline'
            require 'csv'
            puts "Starting interactive shell... enter 'exit' to quit"
            while true do
                args = Readline.readline(prompt, true).strip
                case args
                when /^(exit|quit)/i then break
                when /^set\s*(.*)?/i then
                    std_args = $1 && CSV.parse_line($1, col_sep: ' ')
                else
                    once_args = CSV.parse_line(args, col_sep: ' ')
                    if once_args.nil?
                        once_args = std_args
                    elsif std_args
                        once_args = std_args + once_args
                    end
                    begin
                        run_once(once_args, false) if once_args
                    rescue Exception
                    end
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


        # Run another job as a child of this one.
        #
        # @param job_cls [BatchKit::Job] The class representing the job to run
        #   as a child job.
        # @param args [Array|Hash] An array of command-line tokens, or a hash of
        #   argument keys and values.
        def run_job(job_cls, args)
            if block_given?
                job = job_cls.new
                job.parse_arguments(args, false)
                yield job, job.arguments
            else
                job_cls.run_once(args, false)
            end
        end


        # Set console title to show current job/task on Windows only
        # On Linux the title is persistent, whereas on Windows it is
        # reset when the process ends
        if Gem.win_platform?
            Events.subscribe(self, 'job_run.execute') do |obj, run, *args|
                Console.title = run.label
            end
            Events.subscribe(self, 'task_run.execute') do |obj, run, *args|
                Console.title = "#{run.job_run.label} : #{run.label}"
            end
            Events.subscribe(self, 'task_run.post-execute') do |obj, run, *args|
                Console.title = run.job_run.label
            end
        end


        # Add unhandled exception logging
        Events.subscribe(self, ['sequence_run.failure',
                                'job_run.failure',
                                'task_run.failure']) do |obj, run, ex|
            obj.log_exception(ex)
        end

    end

end

