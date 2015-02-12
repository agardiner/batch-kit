require_relative 'database/schema'


class Batch

    class Database


        def initialize(options = {})
            @schema = Schema.new(options)

            Job::Run.subscribe('pre-execute') do |job_run, job_obj, *args|
                job_load(job_run.definition)
                job_start(job_run)
            end
        end


        def connect(*args)
            @schema.connect(*args)
            @schema.create_tables unless @schema.deployed?

            require_relative 'database/models'

            MD5.check_schema(@schema)
        end


        def job_load(job_def)
            return if job_def.do_not_track
            Job.register(job_def)
        end


        def job_start(job_run)
            true
        end


        def task_start(task_run)
            true
        end


        def task_end(task_run)
        end


        def job_end(job_run)
        end


    end

end
