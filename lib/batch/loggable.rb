require 'batch/logging'


class Batch

    # Adds logging behaviour to a batch process, causing its lifecycle to be
    # logged.
    module Loggable

        # Returns a logger instance named after the class
        def log
            @log ||= LogManager.logger(self.class.name)
        end


        Batch::Events.subscribe(Batch::Runnable, 'execute') do |run, proc_obj, *args|
            if proc_obj.is_a?(Loggable)
                case run
                when Job::Run
                    proc_obj.log.info "Job '#{run.label}' started on #{run.computer} by #{run.run_by}"
                else
                    proc_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' started"
                end
            end
        end


        Batch::Events.subscribe(Batch::Runnable, 'post-execute') do |run, proc_obj, ok|
            if proc_obj.is_a?(Loggable)
                proc_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' completed #{
                        ok ? 'successfully' : 'with errors'} in #{run.elapsed} seconds"
            end
        end

    end

end
