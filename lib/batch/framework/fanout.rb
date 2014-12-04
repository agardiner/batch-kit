class Batch

    # Handles notifying all subscribed listeners when an event occurs.
    class Fanout


        # Create a new subscriber list.
        def initialize
            @subscribers = Hash.new{ |h, k| h[k] = [] }
        end


        # @return [Boolean] whether there are any subscribers for the specified
        #   event.
        def has_subscribers?(event)
            @subscribers.has_key?(event) && @subscribers[event].size > 0
        end


        # Setup a subscription for a particular event. When a matching event
        # occurs, the supplied block will be called with the published arguments.
        #
        # @param event [String] The name of the event to subscribe to.
        # @param callback [Proc] A block to be invoked when the event occurs.
        def subscribe(event, &callback)
            @subscribers[event] << callback
        end


        # Publishes an event to all registered subscribers.
        #
        # @param event [String] The name of the event that has occurred.
        # @param payload [*Object] Arguments passed with the event.
        def publish(event, *payload)
            res = true
            @subscribers.has_key?(event) && @subscribers[event].each do |l|
                begin
                    r = l.call(*payload)
                    res &&= r
                rescue Exception => ex
                    STDERR.puts "Exception in listener during #{event}: #{ex}"
                end
            end
            res
        end

    end

end
