require 'set'
require_relative 'events'


class BatchKit

    # Defines a manager for resource types, such as database connections etc.
    # Resource types are registered with this class, which then adds acquisition
    # methods to the ResourceHelper module. These acquisition methods add the
    # acquired objects to a collection managed by the objects of the class that
    # includes the ResourceHelper, and modify the returned resource objects so
    # that they automatically de-register themselves if they are disposed of
    # explicitly.
    class ResourceManager

        class << self


            # All active resources acquired via any ResourceHelper object.
            def resources
                @resources ||= Set.new
            end


            # Returns an unbound method object that represents the method that
            # should be called to dispose of +rsrc+.
            def disposal_method(rsrc)
                disp_mthd = resource_types[rsrc.class] || resource_types.find{ |rt, _| rt === rsrc }.last rescue nil
                disp_mthd or raise ArgumentError, "No registered resource class matches '#{rsrc.class}'"
            end


            # Register a resource type for automated resource management.
            #
            # @param rsrc_cls [Class] The class of resource to be managed. This
            #   must be the type of the object that will be returned when an
            #   instance of this resource is acquired.
            # @param helper_mthd [Symbol] The name of the resource acquisition
            #   helper method that should be added to the ResourceHelper module.
            # @param options [Hash] An options class.
            # @option options [Symbol] :acquisition_method For cases where an
            #   existing method can be called directly on the +rsrc_cls+ to
            #   obtain a resource (rather than passing in a block containing
            #   resource acquisition steps), the name of that method. Defaults
            #   to :open.
            # @option options [Symbol] :disposal_method The name of the method
            #   to be called on the resource to dispose of it. Defaults to
            #   :close.
            def register(rsrc_cls, helper_mthd, options = {}, &body)
                if ResourceHelper.method_defined?(helper_mthd)
                    raise ArgumentError, "Resource acquisition method #{helper_mthd} is already registered"
                end
                unless body
                    open_mthd = options.fetch(:acquisition_method, :open)
                    body = lambda{ |*args| rsrc_cls.send(open_mthd, *args) }
                end
                disp_mthd = options.fetch(:disposal_method, :close)

                if rsrc_cls.method_defined?(disp_mthd)
                    if (m = resource_types[rsrc_cls]) && m.name != disp_mthd
                        raise ArgumentError, "Resource class #{rsrc_cls} has already been registered" +
                            " with a different disposal method (##{m.name})"
                    else
                        resource_types[rsrc_cls] = rsrc_cls.instance_method(disp_mthd)
                    end
                else
                    raise ArgumentError, "No method named '#{disp_mthd}' is defined on #{rsrc_cls}"
                end

                # Define a __dispose_resource__ method on the resource class
                rsrc_cls.class_eval{ define_method(:__dispose_resource__) { self.send(disp_mthd) } }

                # Define the helper method on the ResourceHelper module. This is
                # necessary (as opposed to just calling the block from the
                # acquisition methd) in order to ensure that self etc are set
                # correctly
                ResourceHelper.class_eval{ define_method(helper_mthd, &body) }

                # Now wrap an aspect around the method to handle the tracking of
                # resources acquired, and event notifications
                add_aspect(rsrc_cls, helper_mthd, disp_mthd)
                Events.publish(self, 'resource.registered', rsrc_cls, helper_mthd)
            end


            # Disposes of all remaining active resources
            def cleanup_all_resources
                if @resources && @resources.size > 0
                    @resources.clone.reverse_each do |rsrc|
                        rsrc.__dispose_resource__
                    end
                    @resources = nil
                end
            end


            # Ensure that all acquired resources are disposed of at exit
            at_exit{ ResourceManager.cleanup_all_resources }


            private


            def resource_types
                @resource_types ||= {}
            end


            # Define the helper method to acquire a resource, publish events about
            # the resource lifecycle, and track the usage of the resource to
            # ensure we know about unreleased resources and can clean then up at
            # the appropriate time when the owning object is done with them.
            def add_aspect(rsrc_cls, helper_mthd, disp_mthd)
                mthd = ResourceHelper.instance_method(helper_mthd)
                ResourceHelper.class_eval do
                    define_method helper_mthd do |*args|
                        rsrc_helper = self
                        if Events.publish(rsrc_helper, 'resource.pre_acquire', rsrc_cls, *args)
                            rsrc = nil
                            begin
                                rsrc = mthd.bind(self).call(*args)
                                unless rsrc_cls === rsrc
                                    raise ArgumentError, "Returned resource is of type #{
                                        rsrc.class.name}, not #{rsrc_cls}"
                                end
                                # Override disposal method on this acquired instance
                                # to call #dispose_resource instead
                                rsrc.define_singleton_method(disp_mthd) do
                                    disposition = Events.publish(rsrc_helper, 'resource.pre-disposal', self)
                                    unless Events::Token::CANCEL == disposition
                                        begin
                                            ResourceManager.disposal_method(self).bind(self).call
                                            Events.publish(rsrc_helper, 'resource.disposed', self)
                                        rescue Exception => ex
                                            Events.publish(rsrc_helper, 'resource.disposal-failed', self, ex)
                                            raise
                                        end
                                    end
                                end
                                Events.publish(rsrc_helper, 'resource.acquired', rsrc)
                                rsrc
                            rescue Exception => ex
                                Events.publish(rsrc_helper, 'resource.acquisition_failed', rsrc_cls, ex)
                                raise
                            end
                        end
                    end
                end
            end

            Events.subscribe(nil, 'resource.acquired') do |_, rsrc|
                ResourceManager.resources << rsrc
            end
            Events.subscribe(nil, 'resource.disposed') do |_, rsrc|
                ResourceManager.resources.delete(rsrc)
            end
            
        end

    end



    # A module that can be included in a class to provide resource acquisition
    # with automated resource cleanup.
    #
    # Resources acquired via this module are tracked, and can be disposed of
    # when no longer needed via a call to the #cleanup_resources method.
    #
    # The benefits of including and using ResourceHelper module:
    # - Resource acquisition can be setup to use a common configuration process,
    #   such as obtaining connection details from a shared configuration file.
    # - All resources obtained by an object can be freed when the object is
    #   done with them by calling the #cleanup_resources.
    module ResourceHelper

        # Returns the open resources acquired via this object.
        def resources
            @__resources__ ||= Set.new
        end
        

        # Dispose of all resources managed by this object.
        def cleanup_resources
            if @__resources__
                @__resources__.clone.reverse_each do |rsrc|
                    rsrc.__dispose_resource__
                end
                @__resources__ = nil
            end
        end


        # Add automatic disposal of resources on completion of job if included
        # into a job.
        def self.included(cls)
            Events.subscribe(cls, 'resource.acquired') do |rsrc_helper, rsrc|
                rsrc_helper.resources << rsrc
            end
            Events.subscribe(cls, 'resource.disposed') do |rsrc_helper, rsrc|
                rsrc_helper.resources.delete(rsrc)
            end
            if (defined?(BatchKit::Job) && BatchKit::Job == cls) ||
                (defined?(BatchKit::ActsAsJob) && cls.include?(BatchKit::ActsAsJob))
                Events.subscribe(cls, 'job_run.post-execute') do |job_obj, run, ok|
                    job_obj.cleanup_resources
                end
            end
        end

    end

end

