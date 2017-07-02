require 'batch/arguments'
require 'batch/configurable'
require 'batch/loggable'


# Default log level is :detail
Batch::LogManager.configure(log_level: :detail)


class Batch

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
                job = self.new
                job.parse_arguments(args)
                unless self.job.method_name
                    raise "No job entry method has been defined; use job :<method_name> or job do ... end in your class"
                end
                job.send(self.job.method_name)
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

    end


    Batch::Events.subscribe(Runnable, 'execute') do |run, obj, *args|
        Console.title = case run
                        when Job::Run then run.label
                        when Task::Run then "#{run.job_run.label} : #{run.label}"
                        end
    end

    Batch::Events.subscribe(Task::Run, 'post-execute') do |run, obj, *args|
        Console.title = run.job_run.label
    end


    # Add unhandled exception logging
    Batch::Events.subscribe(Runnable, 'failure') do |run, obj, ex|
        unless (oid = ex.object_id) == @last_id
            @last_id = oid
            # Strip out framework methods from backtrace
            ex.backtrace.reject!{ |f| f =~ /batch.lib.batch.framework/ }
            obj.log.error ex
        end
    end

end

