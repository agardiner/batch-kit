require 'batch/config'


class Batch

    # Adds a configure class method that can be used to load a configuration file
    # and make it available to the class and instances of it.
    module Configurable

        # Defines the methods that are to be added as class methods to the class
        # that includes the Configurable module.
        module ClassMethods

            # Configure the class by loading the configuration files specifed.
            # If the last argument passed to this method is a Hash, it is
            # treated an options hash, which is passed into {Batch::Config}.
            #
            # @param cfg_files [Array<String>] Path(s) to the configuration
            #   file(s) to be loaded into a single {Batch::Config} object.
            # @option cfg_files [String] :decryption_key The master key for
            #   decrypting any encrypted values in the configuration files.
            def configure(*cfg_files)
                options = cfg_files.last.is_a?(Hash) ? cfg_files.pop.clone : {}
                if defined?(Batch::Events)
                    Batch::Events.publish(self, 'config.pre-load', config, cfg_files)
                end
                config.decryption_key = options.delete(:decryption_key) if options[:decryption_key]
                config.merge!(options)
                cfg_files.each do |cfg_file|
                    config.load(cfg_file, options)
                end
                if defined?(Batch::Events)
                    Batch::Events.publish(self, 'config.post-load', config)
                end
                config
            end


            # Returns the {Batch::Config} object produced when loading the
            # configuration files (or creates a new instance if no files were
            # loaded).
            def config
                @config ||= Batch::Config.new
            end

        end


        # Used to extend the including class with the class methods defined in
        # {ClassMethods}.
        def self.included(base)
            base.extend(ClassMethods)
        end


        # Each object instance gets its own copy of the class configuration, so
        # that any modifications they make are local to the object instance.
        #
        # @return [Batch::Config] a copy of the class configuration specific to
        #  this instance.
        def config
            @config ||= self.class.config.clone
        end

    end

end

