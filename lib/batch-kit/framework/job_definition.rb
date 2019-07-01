require 'socket'


class BatchKit

    class Job

        # Captures details about a job definition - the class of the job, the server
        # it runs on, the file it is defined in, etc.
        class Definition < Definable

            # @!attribute :job_class [Class] The class that defines the job.
            # @!attribute :method_name [Symbol] The method that is run to execute
            #   the job.
            # @!attribute :computer [String] The name of the machine on which the
            #   job was instantiated.
            # @!attribute :file [String] The name of the file containing the job
            #   code.
            # @!attribute :do_not_track [Boolean] By default, job executions may be
            #   recorded (if a persistence layer is available). This attribute can be
            #   used by jobs to indicate that runs of this job should not be recorded.
            # @!attribute :tasks [Hash<Task::Definition>] A hash of task method names to
            #   Task::Definition objects capturing details of each task that is defined
            #   for this Job::Definition.
            # @!attribute :job_id [Fixnum] A unique id for this Job::Definition, as
            #   assigned by the persistence layer.
            # @!attribute :job_version [Fixnum] A version number for the job.
            add_properties(
                # Properties from job/task declarations
                :job_class, :method_name, :computer, :file, :do_not_track, :tasks,
                # Properties provided by persistence layer
                :job_id, :job_version
            )


            # Create a new job Definition object for the job defined in +job_class+
            # in +job_file+.
            def initialize(job_class, job_file, job_name = nil)
                raise ArgumentError, "job_class must be a Class" unless job_class.is_a?(Class)
                @job_class = job_class
                @file = job_file
                @name = job_name || job_class.name.gsub(/([^A-Z ])([A-Z])/, '\1 \2').
                    gsub(/_/, ' ').gsub('::', ':').gsub(/\b([a-z])/) { $1.upcase }
                @computer = Socket.gethostname
                @method_name = nil
                @tasks = {}
                super()
            end


            # Define a job method - the method to be run to trigger the execution
            # of the job.
            #
            # @param mthd_name [Symbol] The name of a method on the job class
            #   that is executed to begin the job processing. Note: This method
            #   must already exist on the job class when this setter is called, so
            #   that it can be wrapped in an aspect with before/after processing.
            def method_name=(mthd_name)
                unless job_class.instance_methods.include?(mthd_name)
                    raise ArgumentError, "Job class #{job_class.name} does not define a ##{mthd_name} method"
                end
                if @method_name
                    raise "Job class #{job_class.name} already has a job method defined (##{@method_name})"
                end
                @method_name = mthd_name

                # Add an aspect for executing job
                add_aspect(job_class, mthd_name)
            end


            # Add a record of a run of the job, or details about a task that the job
            # performs.
            def <<(task)
                unless task.is_a?(Task::Definition)
                    raise ArgumentError, "Only a Task::Definition can be added to a Job::Definition"
                end
                key = task.method_name
                if @tasks.has_key?(key)
                    raise ArgumentError, "#{self} already has a task for ##{key}"
                end
                @tasks[key] = task
            end


            # Create a new Job::Run object for a run of thie job.
            #
            # @param job_obj [Object] The job object that is running this job.
            # @param args [Array<Object>] The arguments passed to the job method.
            def create_run(job_obj, *args)
                job_run = Job::Run.new(self, job_obj, *args)
                @runs << job_run
                job_run
            end


            def to_s
                "<BatchKit::Job::Definition #{@job_class.name}##{@method_name}>"
            end

        end

    end

end
