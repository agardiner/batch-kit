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

            # Perform housekeeping tasks if this the first job run of the day
            if JobRun.where{job_start_time > Date.today}.count == 0
                perform_housekeeping
            end
        end


        # Purges detail records that are older than the retention threshhold.
        def perform_housekeeping
            log.info "Performing batch database housekeeping"
            JobRun.abort_zombie_jobs
            Lock.purge_expired_locks
            JobRunLog.purge_old_logs(@options.fetch(:log_retention_days, 60))
            JobRun.purge_old_runs(@options.fetch(:job_run_retention_days, 365))
            Job.purge_old_jobs
        end

    end

end
