require_relative 'events'
require 'set'
require 'jruby/synchronized' if RUBY_ENGINE == 'jruby'


class Batch

    # Defines a manager for resource types, such as database connections etc.
    # Resource types are registered with this class, which then adds acquisition
    # methods to the ResourceHelper module. These acquisition methods add the
    # acquired objects to a collection managed by the objects of the class that
    # includes the ResourceHelper, and modify the returned resource objects so
    # that they automatically de-register themselves if they are disposed of
    # explicitly.
    class ResourceManager

        class << self

            include JRuby::Synchronized if RUBY_ENGINE == 'jruby'


            # Returns an unbound method object that represents the method that
            # should be called to dispose of +rsrc+.
            def disposal_method(rsrc)
                disp_mthd = resource_types[rsrc.class] || resource_types.find{ |rt, _| rt === rsrc }.last rescue nil
                disp_mthd or raise ArgumentError, "No registered resource class matches '#{rsrc.class}'"
            end


            # Register a resource type for automated resource management
            def register(rsrc_cls, acq_mthd, options = {}, &body)
                if resource_types.has_key?(rsrc_cls)
                    raise ArgumentError, "Resource class #{rsrc_cls} is already registered"
                end
                close_mthd_name = options.fetch(:disposal_method, :close)
                resource_types[rsrc_cls] = rsrc_cls.instance_method(close_mthd_name)
                ResourceHelper.class_eval do
                    define_method acq_mthd do |*args|
                        if Batch::Events.publish(rsrc_cls, 'resource.pre_acquire', *args)
                            result = nil
                            begin
                                result = body.call(*args)
                                unless rsrc_cls === result
                                    raise ArgumentError, "Returned object is of type #{result.class.name}, not #{rsrc_cls}"
                                end
                                # Override close method on this acquired instance to call dispose
                                result.define_singleton_method(close_mthd_name) do
                                    dispose_resource(self)
                                end
                                add_resource(result)
                                Batch::Events.publish(rsrc_cls, 'resource.acquired', result)
                                result
                            rescue Exception => ex
                                Batch::Events.publish(rsrc_cls, 'resource.acquisition_failed', ex)
                                raise
                            end
                        end
                    end
                end
                Batch::Events.publish(self, 'resource.registered', rsrc_cls, acq_mthd)
            end


            private


            def resource_types
                @resource_types ||= {}
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

        # Register a resource for later clean-up
        def add_resource(rsrc)
            # Ensure we know how to dispose of this resource
            Batch::ResourceManager.disposal_method(rsrc)
            (@__resources__ ||= Set.new) << rsrc
        end


        # Dispose of a resource.
        #
        # This method will be called automatically whenever a resource is closed
        # manually (via a call to the resources normal disposal method, e.g.
        # #close), or when #cleanup_resources is used to tidy-up all managed
        # resources.
        def dispose_resource(rsrc)
            rsrc_cls = rsrc.class
            disp_mthd = Batch::ResourceManager.disposal_method(rsrc)
            @__resources__.delete(rsrc)
            begin
                disp_mthd.bind(rsrc).call
                Batch::Events.publish(rsrc_cls, 'resource.disposed', rsrc)
            rescue Exception => ex
                Batch::Events.publish(rsrc_cls, 'resource.disposal_failed', ex)
                raise
            end
        end


        # Dispose of all resources managed by this object.
        def cleanup_resources
            if @__resources__
                @__resources__.clone.each do |rsrc|
                    dispose_resource(rsrc)
                end
                @__resources__ = nil
            end
        end


        # Add automatic disposal of resources on completion of job if included
        # into a job.
        def self.included(cls)
            if defined?(Batch::ActsAsJob) && cls.include?(Batch::ActsAsJob)
                Batch::Events.subscribe(Batch::Job::Run, 'after_execute') do
                    cleanup_resources
                end
            end
        end

    end

end

