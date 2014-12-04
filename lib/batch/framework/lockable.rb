class Batch

    # Defines lockable behaviour, which can be added to any batch process.
    # This behavior allows a process to define a named lock that it needs
    # exclusively during execution.
    # When the process is about to be executed, it will first attempt to obtain
    # the named lock. If it is successful, execution will proceed as normal, and
    # on completion of processing (whether succesful or otherwise), the lock
    # will be released.
    # If the lock is already held by another process, the requesting process
    # will block and wait for the lock to become available. The process will
    # only wait as long as lock_wait_timeout; if the lock has not become
    # availabe in that time period, a LockTimeout exception will be thrown,
    # and processing will not take place.
    module Lockable

        def around_execute(run)
            #LockManager.lock(run, lock, lock_timeout, lock_wait_timeout)
            begin
                super
            ensure
                #LockManager.unlock(run, lock)
            end
        end


        def self.included(cls)
            # Add lock properties
            # Alias method chain around_execute
        end

    end

end
