require 'batch/logging'


class Batch

    # Adds logging behaviour to a batch process, causing its lifecycle to be
    # logged.
    module Loggable

        # Returns a logger instance named after the class
        def log
            @log ||= LogManager.logger(self.class.name)
        end


        # Subscribe to batch lifecycle events that should be logged
        Batch::Events.subscribe(Configurable, 'post-configure') do |job_cls, cfg|
            if cfg.has_key?(:log_level) || cfg.has_key?(:log_file)
                log = LogManager.logger(job_cls.name)
                if cfg[:log_level]
                    log.level = cfg[:log_level]
                    log.config "Log level set to #{cfg[:log_level].upcase}"
                end
                if cfg.has_key?(:log_file)
                    log.config "Logging output to: #{cfg[:log_file]}" if cfg[:log_file]
                    log.log_file = cfg[:log_file]
                end
            end
        end
        Batch::Events.subscribe(Runnable, 'execute') do |run, job_obj, *args|
            if job_obj.is_a?(Loggable)
                case run
                when Job::Run
                    id = run.job_run_id ? " as job run #{run.job_run_id}" : ''
                    job_obj.log.info "Job '#{run.label}' started on #{run.computer} by #{run.run_by}#{id}"
                when Task::Run
                    id = run.task_run_id ? " as task run #{run.task_run_id}" : ''
                    job_obj.log.info "Task '#{run.label}' started#{id}"
                else
                    job_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' started"
                end
            end
        end
        Batch::Events.subscribe(Runnable, 'post-execute') do |run, job_obj, ok|
            if job_obj.is_a?(Loggable)
                job_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' completed #{
                    ok ? 'successfully' : 'with errors'} in #{'%.3f' % run.elapsed} seconds"
            end
        end

        Batch::Events.subscribe(Runnable, 'lock_wait') do |job_run, lock_name|
            if (job_obj = job_run.object).is_a?(Loggable)
                job_obj.log.detail "Waiting for lock '#{lock_name}' to become avaialable"
            end
        end
        Batch::Events.subscribe(Runnable, 'lock_held') do |job_run, lock_name, lock_holder, lock_expire_time|
            if (job_obj = job_run.object).is_a?(Loggable)
                job_obj.log.warn "Lock '#{lock_name}' is currently held by #{lock_holder}; expires at #{
                    lock_expire_time.strftime('%H:%M:%S')}"
            end
        end
        Batch::Events.subscribe(Runnable, 'locked') do |job_run, lock_name, lock_expire_time|
            if (job_obj = job_run.object).is_a?(Loggable)
                job_obj.log.detail "Obtained lock '#{lock_name}'; expires at #{
                    lock_expire_time.strftime('%H:%M:%S')}"
            end
        end
        Batch::Events.subscribe(Runnable, 'unlocked') do |job_run, lock_name|
            if (job_obj = job_run.object).is_a?(Loggable)
                job_obj.log.detail "Released lock '#{lock_name}'"
            end
        end

    end

end
