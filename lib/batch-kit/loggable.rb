require_relative 'logging'


class BatchKit

    # Adds logging behaviour to a batch-kit process, causing its lifecycle to be
    # logged.
    module Loggable

        # Returns a logger instance named after the class
        def log
            @log ||= LogManager.logger(self.class.name)
        end


        def log_exception(ex)
            @@last_oid ||= nil
            unless (oid = ex.object_id) == @@last_oid
                @@last_oid = oid
                # Strip out framework methods from backtrace
                locs = ex.backtrace.reject{ |f| f =~ /lib.batch-kit.framework|RubyMethod/ }
                max_mthd = 0
                locs.map! do |line|
                    case line
                    when /([^(]+)\(Native Method/
                        mthd, file, line = $1, '(Native Method)', nil
                    when /(.+?):(\d+)(?::in `(.+)')/
                        mthd, file, line = $3, $1, $2
                    when /([^(]+)\((.+?):(\d+)\)/
                        mthd, file, line = $1, $2, $3
                    else
                        mthd, file, line = line, '???', nil
                    end
                    max_mthd = mthd.to_s.length if mthd.to_s.length > max_mthd
                    [mthd, file, line]
                end
                locs.map!{ |mthd, file, line| line ?
                    "%#{max_mthd}s at %s:%i" % [mthd, file, line] :
                    "%#{max_mthd}s at %s" % [mthd, file]
                }
                log.error "#{ex.class.name}: #{ex.message}\n|  #{locs.join("\n|  ")}"
            end
        end


        if defined?(BatchKit::Events)

            # Subscribe to batch-kit lifecycle events that should be logged
            Events.subscribe(Runnable, 'job_run.initialized') do |run|
                if run.object.respond_to(:config) && run.object.respond_to(:log)
                    cfg = run.object.config
                    log = run.object.log
                    if cfg[:log_level]
                        log.level = cfg[:log_level]
                        log.config "Log level set to #{cfg[:log_level].upcase}"
                    end
                    if run.parent.nil? && cfg[:log_dir]
                        cfg.log_file = "#{cfg[:log_dir]}/#{File.nameonly(run.definition.file)}#{
                            run.instance ? '_' + run.instance.gsub(/[:\/\\ ]/, '_').gsub(/__+/, '_') : ''}.log"
                        FileUtils.archive(cfg.log_file)
                        log.config "Logging output to: #{cfg.log_file}"
                        FileUtils.mkdir_p(File.dirname(cfg.log_file))
                        # Set log file at root logger level
                        LogManager.logger.log_file = cfg.log_file
                    end
                end
            end
            Events.subscribe(Loggable, 'job_run.execute') do |job_obj, run, *args|
                id = run.job_run_id ? " as job run #{run.job_run_id}" : ''
                job_obj.log.info "Job '#{run.label}' started on #{run.computer} by #{run.run_by}#{id}"
            end
            Events.subscribe(Loggable, 'task_run.execute') do |job_obj, run, *args|
                id = run.task_run_id ? " as task run #{run.task_run_id}" : ''
                job_obj.log.info "Task '#{run.label}' started#{id}"
            end
            %w{job_run task_run}.each do |runnable|
                Events.subscribe(Loggable, "#{runnable}.post-execute") do |job_obj, run, ok|
                    case
                    when ok && run.exit_code == 0 then 'successfully'
                    when ok then "with exit code #{run.exit_code}"
                    else "with errors (exit code #{run.exit_code})"
                    end
                    job_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' completed #{
                        status} in #{'%.3f' % run.elapsed} seconds"
                end
                Events.subscribe(Loggable, "#{runnable}.skipped") do |job_obj, run, reason|
                    if reason
                        job_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' skipped; #{reason}"
                    else
                        job_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' skipped"
                    end
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
