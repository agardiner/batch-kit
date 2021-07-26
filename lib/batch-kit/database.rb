require_relative 'events'
require_relative 'database/schema'


class BatchKit

    # Implements functionality for persisting details of jobs run in a relational
    # database, via the Sequel database library.
    class Database


        # Instantiate a database back-end for persisting job and task runs.
        #
        # @param options [Hash] An options hash, passed on to the
        #   {BatchKit::Database::Schema#initialize Schema} instance.
        def initialize(options = {})
            @options = options
            @schema = Schema.new(options)
        end


        # @return the database connection
        def connection
            @schema.connection
        end


        # Log database messages under the batch-kit.database namespace.
        def log
            @log ||= BatchKit::LogManager.logger('batch-kit.database')
        end


        # Connect to a back-end database for persistence.
        #
        # @param args [Array<String>] Connection details to be passed to
        #  the {BatchKit::Database::Schema#connect} method.
        def connect(*args)
            @schema.connect(*args)

            # We can only include the models once we have connected
            require_relative 'database/models'

            # Check if the database schema is up-to-date
            MD5.check_schema(@schema)

            # Perform housekeeping tasks
            perform_housekeeping
        end


        # Purges detail records that are older than the retention threshhold.
        def perform_housekeeping
            # Only do housekeeping once per day
            return if JobRun.where{job_start_time > Date.today}.count > 0

            log.info "Performing batch database housekeeping"

            # Abort jobs in Executing state that have not logged for 6+ hours
            @schema.connection.transaction do
                cutoff = Time.now - 6 * 60 * 60
                exec_jobs = JobRun.where(job_status: 'EXECUTING').map(:job_run)
                curr_jobs = JobRunLog.select_group(:job_run).
                    where(job_run: exec_jobs).having{max(log_time) > cutoff}.map(:job_run)
                abort_jobs = JobRun.where(job_run: exec_jobs - curr_jobs).all
                if abort_jobs.count > 0
                    log.detail "Cleaning up #{abort_jobs.count} zombie jobs"
                    abort_tasks = TaskRun.where(job_run: abort_jobs.map(&:id), task_status: 'EXECUTING')
                    abort_tasks.each(&:timeout)
                    abort_jobs.each(&:timeout)
                end
            end

            # Purge locks that expired 6+ hours ago
            @schema.connection.transaction do
                purge_date = Time.now - 6 * 60 * 60
                Lock.where{lock_expires_at < purge_date}.delete
            end

            # Purge log records for old job runs
            @schema.connection.transaction do
                purge_date = Date.today - @options.fetch(:log_retention_days, 60)
                purge_job_runs = JobRun.where(job_purged_flag: false).
                    where{job_start_time < purge_date}.map(:job_run)
                if purge_job_runs.count > 0
                    log.detail "Purging log records for #{purge_job_runs.count} job runs"
                    purge_job_runs.each_slice(1000).each do |purge_ids|
                        JobRunLog.where(job_run: purge_ids).delete
                        JobRun.where(job_run: purge_ids).update(job_purged_flag: true)
                    end
                end
            end

            # Purge old task and job runs
            @schema.connection.transaction do
                purge_date = Date.today - @options.fetch(:job_run_retention_days, 365)
                purge_job_runs = JobRun.where{job_start_time < purge_date}.map(:job_run)
                if purge_job_runs.count > 0
                    log.detail "Purging job and task run records for #{purge_job_runs.count} job runs"
                    purge_job_runs.each_slice(1000).each do |purge_ids|
                        JobRun.where(parent_job_run: purge_ids).update(parent_job_run: nil)
                        JobRunArg.where(job_run: purge_ids).delete
                        TaskRun.where(job_run: purge_ids).delete
                        JobRun.where(job_run: purge_ids).delete
                    end
                end
            end

            # Purge jobs with no runs
            @schema.connection.transaction do
                purge_jobs = Job.left_join(JobRun, :job_id => :job_id).
                    where(Sequel.qualify(JobRun.table_name, :job_id) => nil).
                    select(Sequel.qualify(Job.table_name, :job_id)).map(:job_id)
                if purge_jobs.count > 0
                    log.detail "Purging #{purge_jobs.count} old jobs"
                    purge_jobs.each_slice(1000).each do |purge_ids|
                        JobRunFailure.where(job_id: purge_ids).delete
                        Task.where(job_id: purge_ids).delete
                        Job.where(job_id: purge_ids).delete
                    end
                end
            end
        end

    end

end
