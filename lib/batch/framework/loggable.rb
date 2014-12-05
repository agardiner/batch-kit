require 'batch/logging'

class Batch

    # Adds logging behaviour to a batch process, causing its lifecycle to be
    # logged.
    module Loggable

        def register(runnable)
            @logger ||= Logging::LogManager.logger('batch.run')
            runnable.subscribe('execute'){ |run, proc_obj, *args| log_execute(run, proc_obj, *args) }
            runnable.subscribe('post-execute'){ |run, proc_obj, ok| log_post_execute(run, proc_obj, ok) }
        end
        module_function :register


        def log_execute(run, proc_obj, *args)
            msg = case run
            when Job::Run then "Job '#{run.label}' started on #{run.computer} by #{run.run_by}"
            when Task::Run then "Task '#{run.label}' started"
            else "#{run.class.name.split('::')[-2..-1].join(' ')} #{run.name}"
            end
            @logger.info msg
        end
        module_function :log_execute


        def log_post_execute(run, proc_obj, ok)
            msg = "#{run.class.name.split('::')[-2]} '#{run.label}' completed #{
                    ok ? 'successfully' : 'with errors'} in #{run.elapsed} seconds"
            @logger.info msg
        end
        module_function :log_post_execute

    end

end
