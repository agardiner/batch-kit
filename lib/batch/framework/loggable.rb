require 'batch/logging'


class Batch

    # Adds logging behaviour to a batch process, causing its lifecycle to be
    # logged.
    module Loggable

        def register(runnable)
            Batch::Events.subscribe(runnable, 'execute'){ |run, proc_obj, *args| log_execute(run, proc_obj, *args) }
            Batch::Events.subscribe(runnable, 'post-execute'){ |run, proc_obj, ok| log_post_execute(run, proc_obj, ok) }
        end
        module_function :register


        def log_execute(run, proc_obj, *args)
            msg = case run
            when Job::Run then "Job '#{run.label}' started on #{run.computer} by #{run.run_by}"
            else "#{run.class.name.split('::')[-2]} '#{run.label}' started"
            end
            @logger ||= Batch::LogManager.logger('batch.run')
            @logger.info msg
        end
        module_function :log_execute


        def log_post_execute(run, proc_obj, ok)
            msg = "#{run.class.name.split('::')[-2]} '#{run.label}' completed #{
                    ok ? 'successfully' : 'with errors'} in #{run.elapsed} seconds"
            @logger ||= Batch::LogManager.logger('batch.run')
            @logger.info msg
        end
        module_function :log_post_execute

        register(Batch::Job::Run)
        register(Batch::Task::Run)
    end

end
