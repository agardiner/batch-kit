require 'batch/logging'


class Batch

    # Adds logging behaviour to a batch process, causing its lifecycle to be
    # logged.
    module Loggable

        # Returns a logger instance named after the class
        def log
            @log ||= LogManager.logger(self.class.name)
        end


        def log_execute(run, proc_obj, *args)
            case run
            when Job::Run
                proc_obj.log.info "Job '#{run.label}' started on #{run.computer} by #{run.run_by}"
            else
                proc_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' started"
            end
        end
        module_function :log_execute


        def log_post_execute(run, proc_obj, ok)
            proc_obj.log.info "#{run.class.name.split('::')[-2]} '#{run.label}' completed #{
                    ok ? 'successfully' : 'with errors'} in #{run.elapsed} seconds"
        end
        module_function :log_post_execute


        Batch::Events.subscribe(Batch::Runnable, 'execute'){ |*args| log_execute(*args) }
        Batch::Events.subscribe(Batch::Runnable, 'post-execute'){ |*args| log_post_execute(*args) }

    end

end
