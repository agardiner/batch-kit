require 'sequel'
require 'batch/logging'


class Batch

    class Database

        class Schema

            attr_accessor :table_prefix


            def initialize(options = {})
                @table_prefix = options.fetch(:table_prefix, 'BATCH_')
            end


            def connect(*args)
                @conn = Sequel.connect(*args)
                @conn.loggers << Batch::LogManager.logger('batch.schema')
            end


            # Drops all existing batch tables in the connected schema
            def drop_tables
                @conn.drop_table(name_for(:requestor))
                @conn.drop_table(name_for(:request))
                @conn.drop_table(name_for(:lock))
                @conn.drop_table(name_for(:task_run))
                @conn.drop_table(name_for(:task))
                @conn.drop_table(name_for(:job_run_failure))
                @conn.drop_table(name_for(:job_run_log))
                @conn.drop_table(name_for(:job_run_arg))
                @conn.drop_table(name_for(:job_run))
                @conn.drop_table(name_for(:job))
                @conn.drop_table(name_for(:md5))
            end



            def create_tables
                md5 = name_for(:md5)
                job = name_for(:job)
                task = name_for(:task)
                job_run = name_for(:job_run)
                request = name_for(:request)

                # MD5 table, used to hold hashes of objects to detect version changes
                @conn.create_table?(name_for(:md5)) do
                    primary_key :md5_id
                    String :object_type, size: 30, null: false
                    String :object_name, size: 255, null: false
                    String :md5_digest, size: 32, null: false
                    unique [:object_type, :object_name]
                end

                # Job table, holds details of job definitions
                @conn.create_table?(name_for(:job)) do
                    primary_key :job_id
                    String :job_name, size: 80, null: false
                    String :job_class, size: 80, null: false
                    String :job_method, size: 80, null: false
                    String :job_desc, size: 255, null: true
                    String :job_host, size: 50, null: false
                    String :job_file, size: 255, null: false
                    Fixnum :job_version, null: false
                    foreign_key :job_file_md5_id, md5, null: false
                    Fixnum :job_run_count, null: false
                    Fixnum :job_success_count, null: false
                    Fixnum :job_fail_count, null: false
                    Fixnum :job_abort_count, null: false
                    Bignum :job_min_success_duration_ms, null: false
                    Bignum :job_max_success_duration_ms, null: false
                    Bignum :job_mean_success_duration_ms, null: false
                    Bignum :job_m2_success_duration_ms, null: false
                    DateTime :job_created_at, null: false
                    DateTime :job_modified_at, null: false
                    DateTime :job_last_run_at, null: false
                    unique [:job_host, :job_name]
                end

                # Task table, holds details of task definitions
                @conn.create_table?(name_for(:task)) do
                    primary_key :task_id
                    foreign_key :job_id, job, null: false
                    Fixnum :job_version, null: false
                    String :task_name, size: 80, null: false
                    String :task_class, size: 80, null: false
                    String :task_method, size: 80, null: false
                    String :task_desc, size: 255, null: true
                    TrueClass :task_current_flag, null: false
                    Fixnum :task_run_count, null: false
                    Fixnum :task_success_count, null: false
                    Fixnum :task_fail_count, null: false
                    Fixnum :task_abort_count, null: false
                    Bignum :task_min_success_duration_ms, null: false
                    Bignum :task_max_success_duration_ms, null: false
                    Bignum :task_mean_success_duration_ms, null: false
                    Bignum :task_m2_success_duration_ms, null: false
                    DateTime :task_created_at, null: false
                    DateTime :task_modified_at, null: false
                    DateTime :task_last_run_at, null: false
                end

                # Job run table, holds details of a single execution of a job
                @conn.create_table?(name_for(:job_run)) do
                    primary_key :job_run
                    foreign_key :job_id, job, null: false
                    String :job_instance, size: 80, null: true
                    Fixnum :job_version, null: false
                    String :job_run_by, size: 50, null: false
                    String :job_cmd_line, size: 2000, null: true
                    DateTime :job_start_time, null: false
                    DateTime :job_end_time, null: false
                    String :job_status, size: 10, null: false
                    Fixnum :job_pid, null: true
                    Fixnum :job_exit_code, null: true
                    TrueClass :job_purged_flag, null: false, default: false
                end

                # Job run arguments table, holds details of the arguments used on a job
                @conn.create_table?(name_for(:job_run_arg)) do
                    foreign_key :job_run, job_run
                    String :job_arg_name, size: 50, null: false
                    String :job_arg_value, size: 255
                    primary_key [:job_run, :job_arg_name]
                end

                # Job run log table, holds log records for a job
                @conn.create_table?(name_for(:job_run_log)) do
                    foreign_key :job_run, job_run
                    Fixnum :log_line, null: false
                    DateTime :log_time, null: false
                    String :log_level, size: 8, null: false
                    String :log_message, size: 1000, null: false
                    primary_key [:job_run, :log_line]
                end

                # Job failure table, holds exception details for job failures
                @conn.create_table?(name_for(:job_run_failure)) do
                    # We don't use an FK here, because we want to be able to retain
                    # failure details longer than we retain job runs
                    Fixnum :job_run, null: false
                    foreign_key :job_id, job, null: false
                    Fixnum :job_version, null: false
                    DateTime :job_failed_at, null: false
                    String :exception_message, size: 500, null: false
                    String :exception_backtrace, size: 4000, null: false
                end

                # Task run table, holds details of a single execution of a task
                @conn.create_table?(name_for(:task_run)) do
                    primary_key :task_run
                    foreign_key :task_id, task, null: false
                    foreign_key :job_run, job_run, null: false
                    String :task_instance, size: 80, null: false
                    DateTime :task_start_time, null: false
                    DateTime :task_end_time, null: true
                    String :task_status, size: 10, null: false
                    Fixnum :task_exit_code, null: true
                end

                # Lock table, holds details of the current locks
                @conn.create_table?(name_for(:lock)) do
                    primary_key :lock_name, type: String, size: 50
                    foreign_key :job_run, job_run
                    DateTime :lock_created_at, null: false
                    DateTime :lock_expires_at, null: false
                end

                # Request table, holds details of job run requests
                @conn.create_table?(name_for(:request)) do
                    primary_key :request_id
                    String :request_label, size: 80, null: false
                    String :job_host, size: 30, null: false
                    String :job_file, size: 255, null: false
                    String :job_args, size: 2000, null: true
                    String :working_dir, size: 255, null: true
                    TrueClass :processed_flag, default: false, null: false
                    foreign_key :job_run, job_run, false: true
                    DateTime :request_created_at, null: false
                    DateTime :request_start_at, null: true
                    DateTime :request_launched_at, null: true
                end

                # Requestor table, holds details of job run requestors
                @conn.create_table?(name_for(:requestor)) do
                    foreign_key :request_id, request, null: false
                    DateTime :requested_at, null: false
                    String :requested_by, size: 80, null: false
                    String :email_address, size: 100, null: true
                end
            end


            def name_for(table)
                "#{@table_prefix}#{table}".intern
            end

        end

    end

end

