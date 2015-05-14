require 'timeout'
require_relative 'events'


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

        # Attempts to obtain the named lock +lock_name+. If the lock is already
        # held by another process, this method blocks until one of the following
        # occurs:
        # - the lock is released by the process that currently holds it
        # - the lock expires, by reaching it's timeout period
        # - the +lock_wait_timeout+ period is reached.
        #
        # Lock management is managed via the event publishing system; subscribers
        # to the 'lock?' event indicate whether a lock is available by their
        # response to the event. A value of false indicates the lock is
        # currently held; a response of true indicates the lock has been granted.
        #
        # @param lock_name [String] The name of the lock that is needed.
        # @param lock_timeout [Fixnum] The maximum number of seconds that this
        #   process can hold the requested lock before it times out (allowing
        #   any other processes waiting on the lock to proceed). This value
        #   should be set high enough that the lock does not timeout while
        #   processing that relies on the lock is not still running.
        # @param lock_wait_timeout [Fixnum] The maximum time this process is
        #   prepared to wait for the lock to become available. If not specified,
        #   the wait will timeout after the same amount of time as +lock_timeout+.
        # @raise Timeout::Error If the lock is not obtained within
        #   +lock_wait_timeout+ seconds.
        def lock(lock_name, lock_timeout, lock_wait_timeout = nil)
            unless lock_timeout && lock_timeout.is_a?(Fixnum) && lock_timeout > 0
                raise ArgumentError, "Invalid lock_timeout; must be > 0"
            end
            unless lock_wait_timeout.nil? || (lock_wait_timeout.is_a?(Fixnum) && lock_wait_timeout >= 0)
                raise ArgumentError, "Invalid lock_wait_timeout; must be nil or >= 0"
            end
            unless Batch::Events.has_subscribers?(self, 'lock?')
                if self.respond_to?(:log)
                    log.warn "No lock manager available; proceeding without locking"
                end
                return
            end
            lock_wait_timeout ||= lock_timeout
            lock_expire_time = nil
            wait_expire_time = Time.now + lock_wait_timeout
            if lock_wait_timeout > 0
                # Loop waiting for lock if not available
                begin
                    Timeout.timeout(lock_wait_timeout) do
                        i = 0
                        loop do
                            lock_holder = {}
                            lock_expire_time = Batch::Events.publish(self, 'lock?', lock_name,
                                                                     lock_timeout, lock_holder)
                            break if lock_expire_time
                            if i == 0
                                Batch::Events.publish(self, 'lock_held', lock_name,
                                                      lock_holder[:lock_holder],
                                                      lock_holder[:lock_expires_at])
                                Batch::Events.publish(self, 'lock_wait', lock_name, wait_expire_time)
                            end
                            sleep 1
                            i += 1
                        end
                        Batch::Events.publish(self, 'locked', lock_name, lock_expire_time)
                    end
                rescue Timeout::Error
                    Batch::Events.publish(self, 'lock_wait_timeout', lock_name, wait_expire_time)
                    raise Timeout::Error, "Timed out waiting for lock '#{lock_name}' to become available"
                end
            else
                # No waiting for lock to become free
                lock_holder = {}
                if lock_expire_time = Batch::Events.publish(self, 'lock?', lock_name, lock_timeout, lock_holder)
                    Batch::Events.publish(self, 'locked', lock_name, lock_expire_time)
                else
                    Batch::Events.publish(self, 'lock_held', lock_name,
                                          lock_holder[:lock_holder], lock_holder[:lock_expires_at])
                    Batch::Events.publish(self, 'lock_wait_timeout', lock_name, wait_expire_time)
                    raise Timeout::Error, "Lock '#{lock_name}' is already in use"
                end
            end
        end


        # Release a lock held by this object.
        #
        # @param lock_name [String] The name of the lock to be released.
        def unlock(lock_name)
            unless Batch::Events.has_subscribers?(self, 'unlock?')
                return
            end
            if Batch::Events.publish(self, 'unlock?', lock_name)
                Batch::Events.publish(self, 'unlocked', lock_name)
            end
        end


        # Obtains the requested +lock_name+, then yields to the supplied block.
        # Ensures the lock is released when the block ends or raises an error.
        #
        # @param lock_name [String] The name of the lock to obtain.
        # @param lock_timeout [Fixnum] The maximum number of seconds that this
        #   process can hold the requested lock before it times out (allowing
        #   any other processes waiting on the lock to proceed). This value
        #   should be set high enough that the lock does not timeout while
        #   processing that relies on the lock is not still running.
        # @param lock_wait_timeout [Fixnum] The maximum time this process is
        #   prepared to wait for the lock to become available. If not specified,
        #   the wait will timeout after the same amount of time as +lock_timeout+.
        # @raise Timeout::Error If the lock is not obtained within
        #   +lock_wait_timeout+ seconds.
        def with_lock(lock_name, lock_timeout, lock_wait_timeout = nil)
            self.lock(lock_name, lock_timeout, lock_wait_timeout)
            begin
                yield
            ensure
                self.unlock(lock_name)
            end
        end

    end

end
