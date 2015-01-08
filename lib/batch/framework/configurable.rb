class Batch

    # Adds a configure class method that can be used to load a configuration file
    # and make it available to the class and instances of it.
    module Configurable

        module ClassMethods

            def configure(cfg_file = nil, options = {})
                if cfg_file.is_a?(Hash)
                    options = cfg_file
                    cfg_file = nil
                end
                config.decryption_key = options[:decryption_key] if options[:decryption_key]
                if cfg_file
                    config.load(cfg_file, !options.fetch(:ignore_unknown_placeholders, true))
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

