module Enumerable

    # Convenience function for spawning multiple threads to do a common task,
    # driven by the contents of this enumerable. Each entry in self will be
    # be yielded to a new thread, which will then call the supplied block with
    # the element.
    def concurrent_each(options = {}, &blk)
        if self.size < 2
            self.each(&blk)
        else
            abort_opt = options.fetch(:abort_on_exception, true)
            threads = []
            Thread.abort_on_exception = abort_opt
            self.each do |params|
                threads << Thread.new do
                    if abort_opt
                        # Raise exception on main thread
                        begin
                            yield params
                        rescue Exception => ex
                            Thread.main.raise ex
                        end
                    else
                        # Exceptions will be picked up below when main thread joins
                        yield params
                    end
                end
            end

            # Wait for all threads to complete
            ex = nil
            threads.each do |th|
                begin
                    th.join
                rescue Exception => t
                    ex = t unless ex
                end
            end
            raise ex if ex
        end
    end

end

