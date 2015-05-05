require_relative 'events'
require_relative 'database/schema'


class Batch

    class Database


        def initialize(options = {})
            @schema = Schema.new(options)
        end


        def connect(*args)
            @schema.connect(*args)

            # We can only include the models once we have connected
            require_relative 'database/models'

            # Check if the database schema is up-to-date
            MD5.check_schema(@schema)

            # Perform housekeeping tasks
            perform_housekeeping
        end


        # Purges detail records that are older than the retention threshhold
        def perform_housekeeping
            # Only do housekeeping once per day
            #return if @conn.batch_job_run.where{job_start_time > Date.today}.count > 0

            @schema.log.info "Performing batch database housekeeping"

            # Abort jobs in Executing state that have not logged for 6+ hours
            @schema.connection.transaction do
                cutoff = Time.now - 6 * 60 *60
                exec_jobs = JobRun.where(job_status: 'EXECUTING').map(:job_run)
                curr_jobs = JobRunLog.select_group(:job_run).
                    where(job_run: exec_jobs).having{max(log_time) > cutoff}.map(:job_run)
                abort_jobs = JobRun.where(job_run: exec_jobs - curr_jobs).all
                if abort_jobs.size > 0
                    abort_tasks = TaskRun.where(job_run: abort_jobs.map(&:id), task_status: 'EXECUTING')
                    abort_tasks.each(&:timeout)
                    abort_jobs.each(&:timeout)
                end
            end
        end

    end

end
