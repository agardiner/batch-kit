require 'digest'


class BatchKit

    class Database

        Sequel::Model.plugin :dirty

        # Records an MD5 hash of String objects, which are used to detect when
        # items such as jobs have changed. This in turn is used to increment a
        # version number on objects.
        class MD5 < Sequel::Model(:batchkit_md5)

            dataset = self.dataset.sequence(:seq_batchkit_md5_id)


            # Locate the MD5 record for the object named +obj_name+ whose type
            # is +obj_type+.
            def self.for(obj_name, obj_type, digest)
                self.where(Sequel.function(:upper, :object_name) => obj_name.upcase,
                           Sequel.function(:upper, :object_type) => obj_type.upcase,
                           :md5_digest => digest).first
            end


            # Checks that the BatchKit database tables have been deployed and match
            # the table definitions in schema.rb.
            def self.check_schema(schema)
                schema_file = IO.read("#{File.dirname(__FILE__)}/schema.rb")
                ok, md5 = self.check('SCHEMA', 'schema.rb', schema_file)
                unless ok
                    # TODO: Find a better way to update schema for table changes;
                    #       This method throws away all history
                    #schema.drop_tables
                    Console.puts "Schema definition has changed!"
                    schema.create_tables
                    md5.save
                end
            end


            # Checks to see if the recorded MD5 digest of +string+ matches the MD5
            # digest of +string+ as calculated by Digest::MD5.
            #
            # @return [Boolean, String] Returns two values in an array: a boolean
            #   indicating whether the digest value is the same, and the actual
            #   calculated value for the MD5 digest of +string+.
            def self.check(obj_type, obj_name, string)
                digest = Digest::MD5.hexdigest(string)
                # Attempt to retrieve the MD5 for the schema; could fail if not deployed
                md5 = self.for(obj_name, obj_type, digest) rescue nil
                if md5
                    [md5.md5_id, md5]
                else
                    [nil, self.new(obj_type, obj_name, string, digest)]
                end
            end


            # Create a new MD5 hash of an object
            def initialize(obj_type, obj_name, string, digest = nil)
                obj_ver = self.class.where(Sequel.function(:upper, :object_name) => obj_name.upcase,
                                           Sequel.function(:upper, :object_type) => obj_type.upcase).
                                     max(:object_version) || 0
                super(object_type: obj_type, object_name: obj_name,
                      object_version: obj_ver + 1,
                      md5_digest: digest || Digest::MD5.hexdigest(string),
                      md5_created_at: model.dataset.current_datetime)
            end

        end



        # Records details of job definitions
        class Job < Sequel::Model(:batchkit_job)

            dataset = self.dataset.sequence(:seq_batchkit_job_id)

            many_to_one :md5, class: MD5, key: :job_file_md5_id
            one_to_many :job_runs

            plugin :timestamps, create: :job_created_at, update: :job_modified_at,
                update_on_create: true


            # Ensures that the job described by +job_def+ has been registered in
            # the batch database.
            def self.register(job_def)
                job = self.where(job_class: job_def.job_class.name,
                                 job_host: job_def.computer).first
                job_file = IO.read(job_def.file)
                self.dataset.db.transaction do
                    ok, md5 = MD5.check('JOB', "//#{job_def.computer}/#{job_def.file}", job_file)
                    md5.save unless ok
                    if job
                        # Existing job
                        unless ok == job.job_file_md5_id
                            job.update(job_name: job_def.name, job_method: job_def.method_name,
                                       job_desc: job_def.description, job_file: job_def.file,
                                       job_version: md5.object_version, md5: md5)
                        end
                    else
                        # New job
                        job = self.new(job_def, md5).save
                    end
                end
                job_def.job_id = job.job_id
                job_def.job_version = job.job_version
                job
            end


            # Purge jobs with no runs
            def self.purge_old_jobs
                self.dataset.db.transaction do
                    purge_jobs = Job.association_left_join(:job_run).
                        where(Sequel.qualify(:job_run, :job_id) => nil).
                        select(Sequel.qualify(Job.table_name, :job_id)).map(:job_id)
                    if purge_jobs.count > 0
                        log = LogManager.logger('batch-kit.database')
                        log.detail "Purging #{purge_jobs.count} old jobs"
                        purge_jobs.each_slice(1000).each do |purge_ids|
                            JobRunFailure.where(job_id: purge_ids).delete
                            Task.where(job_id: purge_ids).delete
                            self.where(job_id: purge_ids).delete
                        end
                    end
                end
            end


            def log
                @log ||= LogManager.logger('batch-kit.database')
            end


            def initialize(job_def, md5)
                log.detail "Registering job '#{job_def.name}' on #{job_def.computer} in batch database"
                super(job_name: job_def.name, job_class: job_def.job_class.name,
                      job_method: job_def.method_name, job_desc: job_def.description,
                      job_host: job_def.computer, job_file: job_def.file,
                      job_version: md5.object_version, md5: md5,
                      job_run_count: 0, job_success_count: 0, job_fail_count: 0,
                      job_abort_count: 0, job_min_success_duration_ms: 0,
                      job_max_success_duration_ms: 0, job_mean_success_duration_ms: 0,
                      job_m2_success_duration_ms: 0)
            end


            # Record the start of a job run
            #
            # @param job_run [JobRun] The JobRun instance that has commenced.
            def job_start(job_run)
                self.job_last_run_at = job_run.start_time
                self.job_run_count += 1
                self.save
            end


            # Record the successful completion of the JobRun.
            #
            # @param job_run [JobRun] The JobRun instance that has completed.
            def job_success(job_run)
                self.job_success_count += 1
                n = self.job_success_count
                ms = job_run.elapsed * 1000
                delta = ms - self.job_mean_success_duration_ms
                self.job_min_success_duration_ms = self.job_min_success_duration_ms == 0 ?
                    ms : [self.job_min_success_duration_ms, ms].min
                self.job_max_success_duration_ms = self.job_max_success_duration_ms == 0 ?
                    ms : [self.job_max_success_duration_ms, ms].max
                mean = self.job_mean_success_duration_ms += delta / n
                self.job_m2_success_duration_ms += delta * (ms - mean)
                self.save
            end


            # Record the failure of a JobRun.
            #
            # @param job_run [JobRun] The JobRun instance that has failed.
            def job_failure(job_run)
                self.job_fail_count += 1
                self.save
            end


            # Record that a JobRun has been aborted.
            #
            # @param job_run [JobRun] The JobRun instance that has aborted.
            def job_abort(job_run)
                self.job_abort_count += 1
                self.save
            end


            # Record that a JobRun has timed out. This happens when the database
            # finds an instance in the table that has been running for a long
            # period without any activity.
            #
            # @param job_run [JobRun] The JobRun instance that has aborted.
            def job_timeout(job_run)
                self.job_abort_count += 1
                self.save
            end


            Events.subscribe(nil, 'job_run.pre-execute') do |job_obj, job_run, *args|
                Job.register(job_run.definition) if job_run.persist?
                true
            end
            Events.subscribe(nil, 'job_run.execute') do |job_obj, job_run, *args|
                Job[job_run.job_id].job_start(job_run) if job_run.persist?
            end
            Events.subscribe(nil, 'job_run.success') do |job_obj, job_run, result|
                Job[job_run.job_id].job_success(job_run) if job_run.persist?
            end
            Events.subscribe(nil, 'job_run.failure') do |job_obj, job_run, ex|
                Job[job_run.job_id].job_failure(job_run) if job_run.persist?
            end
            Events.subscribe(nil, 'job_run.abort') do |job_obj, job_run|
                Job[job_run.job_id].job_abort(job_run) if job_run.persist?
            end

        end



        # Records details of Task definitions
        class Task < Sequel::Model(:batchkit_task)

            dataset = self.dataset.sequence(:seq_batchkit_task_id)

            many_to_one :job
            one_to_many :task_runs

            plugin :timestamps, create: :task_created_at, update: :task_modified_at,
                update_on_create: true


            def self.register(job_def)
                Task.where(job_id: job_def.job_id).update(task_current_flag: false)
                job_def.tasks.each do |task_key, task_def|
                    task = self.where(job_id: job_def.job_id,
                                      task_method: task_def.method_name.to_s).first
                    if task
                        task.update(task_name: task_def.name, task_class: task_def.task_class.name,
                                    task_desc: task_def.description, task_current_flag: 'Y')
                    else
                        task = Task.new(task_def).save
                    end
                    task_def.task_id = task.task_id
                end
            end


            def initialize(task_def)
                super(job_id: task_def.job.job_id, job_version: task_def.job.job_version,
                      task_name: task_def.name, task_class: task_def.task_class.name,
                      task_method: task_def.method_name.to_s, task_desc: task_def.description,
                      task_run_count: 0, task_success_count: 0, task_fail_count: 0,
                      task_abort_count: 0, task_min_success_duration_ms: 0,
                      task_max_success_duration_ms: 0, task_mean_success_duration_ms: 0,
                      task_m2_success_duration_ms: 0)
            end


            def task_start(task_run)
                self.task_last_run_at = task_run.start_time
                self.task_run_count += 1
                self.save
            end


            def task_success(task_run)
                self.task_success_count += 1
                n = self.task_success_count
                ms = task_run.elapsed * 1000
                delta = ms - self.task_mean_success_duration_ms
                self.task_min_success_duration_ms = self.task_min_success_duration_ms == 0 ?
                    ms : [self.task_min_success_duration_ms, ms].min
                self.task_max_success_duration_ms = self.task_max_success_duration_ms == 0 ?
                    ms : [self.task_max_success_duration_ms, ms].max
                mean = self.task_mean_success_duration_ms += delta / n
                self.task_m2_success_duration_ms += delta * (ms - mean)
                self.save
            end


            def task_failure(task_run)
                self.task_fail_count += 1
                self.save
            end


            def task_abort(task_run)
                self.task_abort_count += 1
                self.save
            end


            def task_timeout(task_run)
                self.task_abort_count += 1
                self.save
            end


            Events.subscribe(nil, 'job_run.pre-execute') do |job_obj, job_run, *args|
                Task.register(job_run.definition) if job_run.persist?
            end

            Events.subscribe(nil, 'task_run.execute') do |job_obj, task_run, *args|
                Task[task_run.task_id].task_start(task_run) if task_run.persist?
            end
            Events.subscribe(nil, 'task_run.success') do |job_obj, task_run, result|
                Task[task_run.task_id].task_success(task_run) if task_run.persist?
            end
            Events.subscribe(nil, 'task_run.failure') do |job_obj, task_run, ex|
                Task[task_run.task_id].task_failure(task_run) if task_run.persist?
            end
            Events.subscribe(nil, 'task_run.abort') do |job_obj, task_run|
                Task[task_run.task_id].task_abort(task_run) if task_run.persist?
            end

        end



        # Records details of job runs
        class JobRun < Sequel::Model(:batchkit_job_run)

            dataset = self.dataset.sequence(:seq_batchkit_job_run_id)

            many_to_one :job
            one_to_many :child_job_runs, class: self, key: :parent_job_run_id
            one_to_many :task_runs
            one_to_many :task_run_logs
            one_to_many :task_run_args
            one_to_many :locks

            dataset_module do

                # Job runs where the job was launched directly, not as a sub-job
                def root_runs
                    where(parent_job_run_id: nil)
                end

                def between(start_time, end_time)
                    where("JOB_START_TIME >= TIMESTAMP '#{start_time.strftime('%Y-%m-%d %H:%M:%S'
                         } AND JOB_START_TIME <= TIMESTAMP '#{end_time.strftime('%Y-%m-%d %H:%M:%S')}")
                end

            end


            def self.abort_zombie_job_runs
                # Abort jobs in Executing state that have not logged for 6+ hours
                self.dataset.db.transaction do
                    cutoff = Time.now - 6 * 60 * 60
                    exec_jobs = self.where(job_status: 'EXECUTING').map(:job_run_id)
                    curr_jobs = JobRunLog.select_group(:job_run_id).
                        where(job_run_id: exec_jobs).
                        having{max(log_time) > Sequel.lit('(SYSDATE - 0.25)')}.
                        map(:job_run_id).map(&:to_i)
                    abort_jobs = self.where(job_run_id: exec_jobs - curr_jobs).all
                    if abort_jobs.count > 0
                        log = LogManager.logger('batch-kit.database')
                        log.detail "Cleaning up #{abort_jobs.count} zombie jobs"
                        abort_tasks = TaskRun.where(job_run_id: abort_jobs.map(&:job_run_id), task_status: 'EXECUTING')
                        abort_tasks.each(&:timeout)
                        abort_jobs.each(&:timeout)
                    end
                end
            end


            # Purge old task and job runs
            def self.purge_old_runs(retention_days)
                self.dataset.db.transaction do
                    purge_date = Date.today - retention_days
                    purge_job_runs = self.where{job_start_time < purge_date}.map(:job_run)
                    if purge_job_runs.count > 0
                        log = LogManager.logger('batch-kit.database')
                        log.detail "Purging job and task run records for #{purge_job_runs.count} job runs"
                        purge_job_runs.each_slice(1000).each do |purge_ids|
                            self.where(parent_job_run_id: purge_ids).update(parent_job_run_id: nil)
                            JobRunArg.where(job_run_id: purge_ids).delete
                            TaskRun.where(job_run_id: purge_ids).delete
                            JobRun.where(job_run_id: purge_ids).delete
                        end
                    end
                end
            end


            def initialize(job_run)
                parent_jr = case job_run.parent
                            when BatchKit::Job::Run then job_run.parent.job_run_id
                            when BatchKit::Task::Run then job_run.parent.job_run.job_run_id
                            end
                super(parent_job_run_id: parent_jr,
                      job_id: job_run.job_id, job_instance: job_run.instance,
                      job_version: job_run.job_version, job_run_by: job_run.run_by,
                      job_cmd_line: job_run.cmd_line, job_start_time: job_run.start_time,
                      job_status: job_run.status.to_s.upcase, job_pid: job_run.pid)
            end


            def job_start(job_run)
                self.save
                job_run.job_run_id = self.job_run_id
            end


            def job_end(job_run)
                self.job_end_time = job_run.end_time
                self.job_status = job_run.status.to_s.upcase
                self.job_pid = nil
                self.job_exit_code = job_run.exit_code
                self.save
            end


            def timeout
                self.job_end_time = Time.now
                self.job_status = 'TIMEOUT'
                self.job_pid = nil
                self.job_exit_code = -1
                self.save

                Job[self.job_id].job_timeout(self)
            end


            Events.subscribe(nil, 'job_run.pre-execute') do |job_obj, job_run, *args|
                if !job_run.definition.no_checkpoints && job_run.checkpoint_window
                    last_completed = JobRun.where(job_id: job_run.job_id,
                                                  job_instance: job_run.instance,
                                                  job_status: 'COMPLETED').max(:job_end_time)
                    if last_completed && (Time.now - last_completed) <= job_run.checkpoint_window
                        Events::Token.new(:skip_run, nil, 'a run has already completed successfully within the checkpoint window')
                    end
                end
            end
            Events.subscribe(nil, 'job_run.execute', position: 0) do |job_obj, job_run, *args|
                JobRun.new(job_run).job_start(job_run) if job_run.persist?
            end
            Events.subscribe(nil, 'job_run.post-execute') do |job_obj, job_run, ok|
                JobRun[job_run.job_run_id].job_end(job_run) if job_run.persist?
            end

        end



        # Captures the value of all defined command-line arguments to the job
        class JobRunArg < Sequel::Model(:batchkit_job_run_arg)

            unrestrict_primary_key

            many_to_one :job_run


            def self.from(job_run)
                job_run.job_args && job_run.job_args.each_pair do |name, val|
                    v = case val
                        when String, Numeric, TrueClass, FalseClass then val
                        else val.inspect
                        end
                    JobRunArg.new(job_run, name, v.to_s[0...255]).save
                end
            end


            def initialize(job_run, name, val)
                super(job_run_id: job_run.job_run_id, job_arg_name: name, job_arg_value: val)
            end


            Events.subscribe(nil, 'job_run.execute') do |job_obj, job_run, *args|
                JobRunArg.from(job_run) if job_run.persist?
            end

        end



        # Captures details of a job run exception
        class JobRunFailure < Sequel::Model(:batchkit_job_run_failure)

            many_to_one :job
            many_to_one :job_run


            def initialize(job_run, ex)
                super(job_run_id: job_run.job_run_id, job_id: job_run.definition.job_id,
                      job_version: job_run.definition.job_version, job_failed_at: Time.now,
                      exception_message: ex.message && ex.message.size > 0 ?
                            ex.message[0...500] : 'No exception message',
                      exception_backtrace: ex.backtrace.join("\n")[0...4000])
            end


            Events.subscribe(nil, 'job_run.failure') do |job_obj, job_run, ex|
                JobRunFailure.new(job_run, ex).save if job_run.persist?
            end

        end



        # Capture details of a task run
        class TaskRun < Sequel::Model(:batchkit_task_run)

            dataset = self.dataset.sequence(:seq_batchkit_task_run_id)

            many_to_one :task
            many_to_one :job_run
            one_to_many :child_task_runs, class: self, key: :parent_task_run_id


            def initialize(task_run)
                super(parent_task_run_id: task_run.parent.is_a?(BatchKit::Task::Run) ? task_run.parent.task_run_id : nil,
                      task_id: task_run.task_id, job_run_id: task_run.job_run.job_run_id,
                      task_instance: task_run.instance, task_start_time: task_run.start_time,
                      task_status: task_run.status.to_s.upcase)
            end


            def task_start(task_run)
                self.save
                task_run.task_run_id = self.task_run_id
            end


            def task_end(task_run)
                self.task_end_time = task_run.end_time
                self.task_status = task_run.status.to_s.upcase
                self.task_exit_code = task_run.exit_code
                self.save
            end


            def timeout
                self.task_end_time = Time.now
                self.task_status = 'TIMEOUT'
                self.task_exit_code = -1
                self.save

                Task[task_id].task_timeout(self)
            end


            Events.subscribe(nil, 'task_run.pre-execute') do |job_obj, task_run, *args|
                if !task_run.job_run.definition.no_checkpoints && task_run.checkpoint_window
                    last_completed = TaskRun.join(JobRun, :job_run_id => :job_run_id).
                        where(task_id: task_run.task_id,
                              job_instance: task_run.job_run.instance,
                              task_instance: task_run.instance,
                              task_status: 'COMPLETED').
                        max(:task_end_time)
                    if last_completed && (Time.now - last_completed) <= task_run.checkpoint_window
                        Events::Token.new(:skip_run, nil, 'a run has already completed successfully within the checkpoint window')
                    end
                end
            end
            Events.subscribe(nil, 'task_run.execute', position: 0) do |job_obj, task_run, *args|
                TaskRun.new(task_run).task_start(task_run) if task_run.persist?
            end
            Events.subscribe(nil, 'task_run.post-execute') do |job_obj, task_run, ok|
                TaskRun[task_run.task_run_id].task_end(task_run) if task_run.persist?
            end

        end



        # Model for a single log message
        class JobRunLog < Sequel::Model(:batchkit_job_run_log)

            unrestrict_primary_key

            many_to_one :job_run


            def self.install_log_handler(job_run, logger)
                case LogManager.log_framework
                when :java_util_logging
                    require_relative 'java_util_log_handler'
                    handler = JavaUtilLogHandler.new(job_run)
                    logger.addHandler(handler)
                when :log4r
                    require_relative 'log4r_outputter'
                    outputter = Log4ROutputter.new(job_run)
                    logger.add(outputter)
                end
            end


            # Purge log records for old job runs
            def self.purge_old_logs(retention_days)
                self.dataset.db.transaction do
                    purge_date = Date.today - retention_days
                    purge_job_runs = JobRun.where(job_purged_flag: false).
                        where{job_start_time < purge_date}.map(:job_run_id)
                    if purge_job_runs.count > 0
                        log = LogManager.logger('batch-kit.database')
                        log.detail "Purging log records for #{purge_job_runs.count} job runs"
                        purge_job_runs.each_slice(1000).each do |purge_ids|
                            JobRunLog.where(job_run_id: purge_ids).delete
                            JobRun.where(job_run_id: purge_ids).update(job_purged_flag: true)
                        end
                    end
                end
            end


            Events.subscribe(nil, 'job_run.execute') do |job_obj, job_run, *args|
                if job_run.persist? && (logger = job_obj.respond_to?(:log) && job_obj.log)
                    JobRunLog.install_log_handler(job_run, logger)
                end
            end
        end



        # Model for a lock
        class Lock < Sequel::Model(:batchkit_lock)

            unrestrict_primary_key

            many_to_one :job_run


            def self.lock?(runnable, lock_name, lock_timeout, lock_holder = nil)
                job_run = runnable.is_a?(BatchKit::Job::Run) ? runnable : runnable.job_run
                lock_expires_at = nil
                attempts = 0
                begin
                    attempts += 1
                    self.dataset.db.transaction do
                        lock_rec = self.where(lock_name: lock_name).first
                        if lock_rec
                            lock_expires_at = nil   # Ensure lock_expires_at not set from failed insert
                            lock_job = JobRun.join(Job, :job_id => :job_id).where(job_run_id: lock_rec.job_run_id).first
                            holder = "job '#{lock_job[:job_name]}' (job run #{lock_rec.job_run_id})"
                            if lock_rec.lock_expires_at < Time.now
                                Events.publish(job_run, 'lock.expire', lock_name, lock_rec.job_run_id)
                                Events.publish(job_run, 'lock.takeover', lock_name, holder)
                                self.where(lock_name: lock_name).delete
                                lock_rec = nil
                            else
                                if lock_holder
                                    lock_holder[:lock_expires_at] = lock_rec.lock_expires_at.getlocal
                                    lock_holder[:lock_holder] = holder
                                end
                            end
                        else
                            lock_expires_at = Time.now + lock_timeout
                            if job_run.persist?
                                self.new(lock_name: lock_name, job_run_id: job_run.job_run_id,
                                         lock_created_at: Time.now,
                                         lock_expires_at: lock_expires_at).save
                            end
                        end
                    end
                rescue
                    if attempts < 3
                        sleep(rand())
                        retry
                    end
                    raise
                end
                lock_expires_at
            end


            def self.unlock?(runnable, lock_name)
                job_run = runnable.is_a?(BatchKit::Job::Run) ? runnable : runnable.job_run
                unlocked = false
                if job_run.persist?
                    self.where(lock_name: lock_name,
                               job_run_id: job_run.job_run_id).delete
                    unlocked = true
                end
                unlocked
            end


            # Purge locks that expired 6+ hours ago
            def self.purge_expired_locks
                self.dataset.db.transaction do
                    purge_date = Time.now - 6 * 60 * 60
                    self.where{lock_expires_at < purge_date}.delete
                end
            end


            Events.subscribe(Runnable, 'lock?') do |job_run, lock_name, lock_timeout, lock_holder|
                Lock.lock?(job_run, lock_name, lock_timeout, lock_holder)
            end
            Events.subscribe(Runnable, 'unlock?') do |job_run, lock_name|
                Lock.unlock?(job_run, lock_name)
            end

        end


        class Alert < Sequel::Model(:batchkit_alert)

            many_to_one :job_run

            dataset_module do

                def between(start_time, end_time)
                    where("ALERT_CREATED_AT >= TIMESTAMP '#{start_time.strftime('%Y-%m-%d %H:%M:%S')
                          }' AND ALERT_CREATED_AT <= TIMESTAMP '#{end_time.strftime('%Y-%m-%d %H:%M%S')}'")
                end

            end


            def self.info(job_run_id, alert_type, message)
                self.new(job_run_id: job_run_id, alert_level: 'INFO',
                         alert_tye: alert_type, alert_message: message,
                         alert_created_at: Time.now).save
            end


            def self.warn(job_run_id, alert_type, message)
                self.new(job_run_id: job_run_id, alert_level: 'WARN',
                         alert_tye: alert_type, alert_message: message,
                         alert_created_at: Time.now).save
            end

            Events.subscribe(nil, 'job_run.alert') do |job_run, alert_lvl, alert_type, alert_msg|
                Alert.new(job_run_id: job_run.job_run_id, alert_level: alert_lvl,
                         alert_tye: alert_type, alert_message: alert_msg,
                         alert_created_at: Time.now).save
            end
            Events.subscribe(nil, 'job_run.timeout') do |job_run|
                Alert.warn(job_run.job_run_id, 'Job Run Timeout',
                           "Job '#{job_run.name}' timed out and has been aborted")
            end
            Events.subscribe(Runnable, 'lock.expire') do |job_run, lock_name, holder_job_run_id|
                Alert.warn(holder_job_run_id, 'Job Run Timeout',
                           "Lock '#{lock_name}' expired before it was released")
            end
            Events.subscribe(Runnable, 'lock.takeover') do |job_run, lock_name, old_holder|
                Alert.warn(job_run.job_run_id, 'Lock Takeover',
                           "Lock #{lock_name} has expired and been taken over from #{old_holder}")
            end

        end

    end

end
