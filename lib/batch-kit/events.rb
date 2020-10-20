class BatchKit

    # Manages BatchKit event notifications and subscriptions, which provide a
    # useful means of decoupling different components of the BatchKit library.
    #
    # The problem we are looking to solve here is that we want our BatchKit jobs,
    # tasks etc to be able to notify interested parties when something happens
    # (e.g. a task starts, a job fails, etc) without these event sources needing
    # to know all the interested parties to notify. We therefore introduce an
    # intermediary, which is the Events system.
    #
    # Interested parties register their interest in specific events or event
    # classes by subscribing to the events of interest. Framework classes then
    # notify the Event system when an event occurs, and the event system routes
    # these notifications on to all registered subscribers.
    #
    # One of the problems we need to solve for is how subscribers can define the
    # scope of their interest. Is it all events of a particular type, regardless
    # of source? Or are we only interested in events from a specific source (e.g
    # job or task)?
    class Events

        # Records subscription details
        class Subscription

            attr_reader :source, :event, :callback, :raise_on_error


            def initialize(source, event, options, callback)
                @source = source
                @event = event
                @raise_on_error = options.fetch(:raise_on_error, true)
                @callback = callback
            end


            def ===(obj)
                @source.nil? ||             # Nil source means match any obj
                    (@source == obj) ||     # Source is obj
                    (@source === obj) ||    # obj is an instance of source class
                    (@source.instance_of?(Module) && obj.instance_of?(Class) &&
                     obj.include?(@source))   # Source is a module included by obj
            end

        end


        # Represents special tokens that an event handler can use to signal the
        # event source to alter standard behaviour.
        # As an event may have many handlers, and most won't care what they
        # return, we need a way to filter out the significant return values from
        # the rest. A Token when combined with any non-token will always return
        # the token. If no token is returned, the non-token values are and-ed
        # to form the return value from the event publication.
        class Token

            attr_reader :value, :result
            attr_accessor :reason
            

            def initialize(value, result=value, reason=nil)
                @value = value
                @result = result
                @reason = reason
            end


            def combine(oth)
                if oth.is_a?(Token) && @value.nil
                    oth
                else
                    self
                end
            end


            def ==(oth)
                oth.is_a?(Token) && oth.value == @value
            end


            def result
                @value ? self : @result
            end


            # Token used to signal an action should be cancelled
            CANCEL = Token.new(:cancel)
            # Token used to signal a Runnable should not be run
            SKIP_RUN = Token.new(:skip_run)
            # Token used to indicate a failure event should suppress the exception
            SUPPRESS_EXCEPTION = Token.new(:suppress_exception)

        end



        class << self


            attr_reader :log


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
            # @param options [Hash] An options hash defining optional settings
            #   for the subscription.
            # @option options [Fixnum] :position The position within the list to
            #   insert the subscriber. Default is to add to the end of the list.
            # @param callback [Proc] A block to be invoked when the event occurs.
            def subscribe(source, event, options = {}, &callback)
                @log.trace "Adding subscriber for #{source} event '#{event}'" if @log
                position = options.fetch(:position, -1)
                if event.is_a?(Array)
                    event.each{ |e| subscribers[e].insert(position, Subscription.new(source, e, options, callback)) }
                else
                    subscribers[event].insert(position, Subscription.new(source, event, options, callback))
                end
            end


            # Remove a subscriber
            #
            # @param source [Object] The object that is the source of the event
            #   from which to unsubscribe.
            # @param event [String] The name of the event to unsubscribe from.
            def unsubscribe(source, event)
                @log.trace "Removing subscriber(s) for #{source} event '#{event}'" if @log
                subscribers[event].delete_if{ |sub| sub === source }
            end


            # Publishes an event to all registered subscribers.
            #
            # @param source [Object] The source from which the event has been
            #   generated.
            # @param event [String] The name of the event that has occurred.
            # @param payload [*Object] Arguments passed with the event.
            def publish(source, event, *payload)
                @log.trace "Publishing event '#{event}' for #{source}" if @log
                res = Token.new(nil, true)
                count = 0
                if subscribers.has_key?(event)
                    subscribers[event].each do |sub|
                        if sub === source
                            begin
                                r = sub.callback.call(source, *payload)
                                count += 1
                                res = res.combine(r)
                            rescue StandardError => ex
                                if source.is_a?(Loggable)
                                    source.log.error "Unhandled exception in '#{event}' listener for #{source}"
                                    source.log_exception(ex)
                                elsif source.respond_to?(:log)
                                    source.log.error "Unhandled exception in '#{event}' listener for #{source}"
                                    source.log.error ex
                                end
                                if sub.raise_on_error
                                    raise
                                else
                                    STDERR.puts "Exception in '#{event}' event listener for #{source}: #{ex}\n" +
                                        "  at: #{ex.backtrace[0...10].join("\n")}"
                                end
                            end
                        end
                    end
                    @log.debug "Notified #{count} listeners of '#{event}'" if @log
                end
                res.result
            end


            # Enable/disable event debugging
            def debug=(dbg)
                @log = dbg ? LogManager.logger('batch-kit.events') : nil
            end


            # Dumps a list of events and their subscribers to the logger
            def dump_subscribers(show_event = nil, log = @log)
                if log
                    subscribers.each do |event, subs|
                        if show_event.nil? || show_event == event
                            log.info "Subscribers for event '#{event}':"
                            subs.each{ |sub| log.detail sub.inspect }
                        end
                    end
                end
            end


            private

            def subscribers
                @subscribers ||= Hash.new{ |h, k| h[k] = [] }
            end

        end

    end

end
