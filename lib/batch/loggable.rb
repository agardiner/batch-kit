require 'batch/logging'


class Batch

    # Adds logging behaviour to a batch process, causing its lifecycle to be
    # logged.
    module Loggable

        # Returns a logger instance named after the class
        def log
            @log ||= LogManager.logger(self.class.name)
        end


        Batch::Events.subscribe(Runnable, 'execute') do |run, job_obj, *args|
            if job_obj.is_a?(Loggable)
                case run
                when Job::Run
                    job_obj.log.info "Job '#{run.label}' started on #{run.computer} by #{run.run_by}"
                else
                    job_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' started"
                end
            end
        end
        Batch::Events.subscribe(Runnable, 'post-execute') do |run, job_obj, ok|
            if job_obj.is_a?(Loggable)
                job_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' completed #{
                    ok ? 'successfully' : 'with errors'} in #{run.elapsed} seconds"
            end
        end

        Batch::Events.subscribe(Runnable, 'lock_wait') do |job_obj|
            if job_obj.is_a?(Loggable)
                job_obj.log.detail "Waiting for lock '#{lock_name}' to become avaialable"
            end
        end
        Batch::Events.subscribe(Runnable, 'lock_wait_timeout') do |job_obj, lock_name|
            if job_obj.is_a?(Loggable)
                job_obj.log.error "Timed out waiting for lock '#{lock_name}' to become available"
            end
        end
        Batch::Events.subscribe(Runnable, 'locked') do |job_obj, lock_name, lock_expire_time|
            if job_obj.is_a?(Loggable)
                job_obj.log.detail "Obtained lock '#{lock_name}'; expires at #{
                    lock_expire_time.strftime('%H:%M:%S')}"
            end
        end
        Batch::Events.subscribe(Runnable, 'unlocked') do |job_obj, lock_name|
            if job_obj.is_a?(Loggable)
                job_obj.log.detail "Released lock '#{lock_name}'"
            end
        end

    end

end
