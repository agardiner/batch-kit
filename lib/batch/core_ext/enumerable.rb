require 'thread'


module Enumerable

    # Maps each item in the Enumerable, surrounding it with the +left+ and +right+
    # strings. If +right+ is not specified, it is set to the same string as +left+,
    # which in turn is defaulted to the double-quote character.
    def surround(left = '"', right = left)
        self.map{ |item| "#{left}#{item}#{right}" }
    end


    # Surrounds each item in the Enumerable with single quotes.
    def squote
        self.surround("'")
    end


    # Surrounds each item in the Enumerable with double quotes.
    def dquote
        self.surround('"')
    end


    # Convenience function for spawning multiple threads to do a common task,
    # driven by the contents of this enumerable. Each entry in self will be
    # be yielded to a new thread, which will then call the supplied block with
    # the element.
    def concurrent_each(options = {}, &blk)
        if self.count < 2
            self.each(&blk)
        else
            abort_opt = options.fetch(:abort_on_exception, true)
            Thread.abort_on_exception = abort_opt

            # Push items onto a queue from which work items can be removed by
            # threads in the pool
            queue = Queue.new
            self.each{ |it| queue << it }

            # Setup thread pool to iterate over work queue
            thread_count = options.fetch(:threads, [4, self.count].min)
            threads = []

            # Launch each worker thread, which loops extracting work items from
            # the queue until it is empty
            (0...thread_count).each do |i|
                threads << Thread.new do
                    begin
                        while work_item = queue.pop(true)
                            if abort_opt
                                # Raise exception on main thread
                                begin
                                    yield work_item
                                rescue Exception => ex
                                    Thread.main.raise ex
                                end
                            else
                                # Exceptions will be picked up below when main thread joins
                                yield work_item
                            end
                        end
                    rescue ThreadError
                        # Work queue is empty, so exit loop
                    end
                end
            end

            # Now wait for all threads in pool to complete
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

