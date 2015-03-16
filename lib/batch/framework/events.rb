class Batch

    # Manages batch event notifications and subscriptions
    class Events

        # Records subscription details
        class Subscription

            attr_reader :source, :callback


            def initialize(source, callback)
                @source = source
                @callback = callback
            end


            def ===(obj)
                @source.nil? || (@source === obj) ||
                    (obj.respond_to?(:job) && @source === obj.job)
            end

        end



        class << self

            # @param source [Object] The source of the event
            # @param event [String] The name of the event
            # @return [Boolean] whether there are any subscribers for the specified
            #   event.
            def has_subscribers?(source, event)
                subscribers.has_key?(event) && subscribers[event].size > 0 &&
                    subscribers[event].find{ |sub| sub === source }
            end


            # Setup a subscription for a particular event. When a matching event
            # occurs, the supplied block will be called with the published
            # arguments.
            #
            # @param source [Object] The type of source object from which to
            #   listen for events.
            # @param event [String] The name of the event to subscribe to.
            # @param callback [Proc] A block to be invoked when the event occurs.
            def subscribe(source, event, &callback)
                subscribers[event] << Subscription.new(source, callback)
            end


            # Remove a subscriber
            #
            # @param source [Object] The object that is the source of the event
            #   from which to unsubscribe.
            # @param event [String] The name of the event to unsubscribe from.
            def unsubscribe(source, event)
                subscribers[event].delete_if{ |sub| sub === source }
            end


            # Publishes an event to all registered subscribers.
            #
            # @param source [Object] The source from which the event has been
            #   generated.
            # @param event [String] The name of the event that has occurred.
            # @param payload [*Object] Arguments passed with the event.
            def publish(source, event, *payload)
                res = true
                subscribers.has_key?(event) && subscribers[event].each do |sub|
                    if sub === source
                        begin
                            r = sub.callback.call(source, *payload)
                            res &&= r
                        rescue Exception => ex
                            STDERR.puts "Exception in listener during #{event} on #{source}: #{ex}"
                        end
                    end
                end
                res
            end


            private

            def subscribers
                @subscribers ||= Hash.new{ |h, k| h[k] = [] }
            end

        end

    end

end
