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
                on_failure{ |ex| log.error ex.message }
            end
        end


        # A method that instantiates an instance of this job, parses
        # arguments from the command-line, and then executes the job.
        def self.run
            job = self.new
            job.parse_arguments
            job.send(self.job.method_name)
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

end

