require 'batch/config'


class Batch

    # Adds a configure class method that can be used to load a configuration file
    # and make it available to the class and instances of it.
    module Configurable

        module ClassMethods

            def configure(*cfg_files)
                options = cfg_files.last.is_a?(Hash) ? cfg_files.pop.clone : {}
                config.decryption_key = options.delete(:decryption_key) if options[:decryption_key]
                config.merge!(options)
                cfg_files.each do |cfg_file|
                    config.load(cfg_file, options)
                end
                if defined?(Batch::Events)
                    Batch::Events.publish(self, 'post-configure', config)
                end
                config
            end


            def config
                @config ||= Batch::Config.new
            end

        end


        def self.included(base)
            base.extend(ClassMethods)
        end


        # Each object instance gets its own copy of the class configuration, so
        # that any modifications they make are local to the object instance.
        def config
            @config ||= self.class.config.clone
        end

    end

end

