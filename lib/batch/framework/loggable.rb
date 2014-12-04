class Batch

    # Defines logging behaviour to a batch process, causing its lifecycle to be
    # logged.
    module Loggable

        def register(runnable)
            runnable.subscribe('execute') do |run, proc_obj, *args|
                STDOUT.puts "#{run.class.name} started"
            end
            runnable.subscribe('post-execute') do |run, proc_obj, *args|
                STDOUT.puts "#{run.class.name} completed"
            end
        end
        module_function :register

    end

end
