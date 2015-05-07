require 'batch/arguments'
require 'batch/configurable'
require 'batch/loggable'
require 'batch/lockable'


# Default log level is :detail
Batch::LogManager.configure(log_level: :detail)


class Batch

    class Job

        include Arguments
        include Configurable
        include Loggable
        include Lockable


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

    end

end

