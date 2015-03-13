require 'batch/arguments'
require 'batch/config'
require_relative 'configurable'
require_relative 'loggable'


# Default log level is :detail
Batch::LogManager.configure(level: :detail)


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


        # A method that instantiates an instance of this job, parses
        # arguments from the command-line, and then executes the job.
        def self.run
            job = self.new
            job.parse_arguments
            job.send(self.job.method_name)
        end


        # Returns a logger instance named after the class
        def log
            @log ||= LogManager.logger(self.class.name)
        end

    end

end

