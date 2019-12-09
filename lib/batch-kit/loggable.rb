require_relative 'logging'


class BatchKit

    # Adds logging behaviour to a batch-kit process, causing its lifecycle to be
    # logged.
    module Loggable

        # Returns a logger instance named after the class
        def log
            @log ||= LogManager.logger(self.class.name)
        end


        if defined?(BatchKit::Events)

            # Subscribe to batch-kit lifecycle events that should be logged
            Events.subscribe(Configurable, 'config.post-load') do |job_cls, cfg|
                if cfg.has_key?(:log_level) || cfg.has_key?(:log_file)
                    log = LogManager.logger(job_cls.name)
                    if cfg[:log_level]
                        log.level = cfg[:log_level]
                        log.config "Log level set to #{cfg[:log_level].upcase}"
                    end
                    if cfg.has_key?(:log_file)
                        log.config "Logging output to: #{cfg[:log_file]}" if cfg[:log_file]
                        FileUtils.mkdir_p(File.dirname(cfg[:log_file]))
                        LogManager.logger.log_file = cfg[:log_file]
                    end
                end
            end
            Events.subscribe(Loggable, 'sequence_run.execute') do |job_obj, run, *args|
                job_obj.log.info "Sequence '#{run.label}' started"
            end
            Events.subscribe(Loggable, 'job_run.execute') do |job_obj, run, *args|
                id = run.job_run_id ? " as job run #{run.job_run_id}" : ''
                job_obj.log.info "Job '#{run.label}' started on #{run.computer} by #{run.run_by}#{id}"
            end
            Events.subscribe(Loggable, 'task_run.execute') do |job_obj, run, *args|
                id = run.task_run_id ? " as task run #{run.task_run_id}" : ''
                job_obj.log.info "Task '#{run.label}' started#{id}"
            end
            %w{sequence_run job_run task_run}.each do |runnable|
                Events.subscribe(Loggable, "#{runnable}.post-execute") do |job_obj, run, ok|
                    job_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' completed #{
                        ok ? 'successfully' : 'with errors'} in #{'%.3f' % run.elapsed} seconds"
                end
            end

            Events.subscribe(Lockable, 'lock_wait') do |job_run, lock_name|
                if (job_obj = job_run.object).is_a?(Loggable)
                    job_obj.log.detail "Waiting for lock '#{lock_name}' to become avaialable"
                end
            end
            Events.subscribe(Lockable, 'lock_held') do |job_run, lock_name, lock_holder, lock_expire_time|
                if (job_obj = job_run.object).is_a?(Loggable)
                    job_obj.log.warn "Lock '#{lock_name}' is currently held by #{lock_holder}; expires at #{
                        lock_expire_time.strftime('%H:%M:%S')}"
                end
            end
            Events.subscribe(Lockable, 'locked') do |job_run, lock_name, lock_expire_time|
                if (job_obj = job_run.object).is_a?(Loggable)
                    job_obj.log.detail "Obtained lock '#{lock_name}'; expires at #{
                        lock_expire_time.strftime('%H:%M:%S')}"
                end
            end
            Events.subscribe(Lockable, 'unlocked') do |job_run, lock_name|
                if (job_obj = job_run.object).is_a?(Loggable)
                    job_obj.log.detail "Released lock '#{lock_name}'"
                end
            end

        end

    end

end
