require_relative 'config'


class BatchKit

    # Adds a configure class method that can be used to load a configuration file
    # and make it available to the class and instances of it.
    module Configurable

        # Defines the methods that are to be added as class methods to the class
        # that includes the Configurable module.
        module ClassMethods

            # Configure the class by loading the configuration files specifed.
            # If the last argument passed to this method is a Hash, it is
            # treated an options hash, which is passed into {BatchKit::Config}.
            #
            # @param cfg_files [Array<String>] Path(s) to the configuration
            #   file(s) to be loaded into a single {BatchKit::Config} object.
            # @option cfg_files [String] :decryption_key The master key for
            #   decrypting any encrypted values in the configuration files.
            def configure(*cfg_files)
                options = cfg_files.last.is_a?(Hash) ? cfg_files.pop.clone : {}
                if defined?(BatchKit::Events)
                    Events.publish(self, 'config.pre-load', config, cfg_files)
                end
                config.decryption_key = options.delete(:decryption_key) if options[:decryption_key]
                config.merge!(options)
                cfg_files.each do |cfg_file|
                    config.load(find_config(cfg_file), options)
                end
                if defined?(BatchKit::Events)
                    Events.publish(self, 'config.post-load', config)
                end
                config
            end


            def config_paths
                @config_paths ||= []
            end


            def find_config(cfg_file)
                if Pathname.new(cfg_file).absolute? || File.exists?(cfg_file)
                    cfg_file
                elsif config_dir = config_paths.find{ |p| File.exist?(File.join(p, cfg_file)) }
                    File.join(config_dir, cfg_file)
                else
                    cfg_file
                end
            end


            def load_config_file(cfg_file)
                cfg_path = find_config(cfg_file)
                BatchKit::Config.load(cfg_path)
            end


            # Returns the {BatchKit::Config} object produced when loading the
            # configuration files (or creates a new instance if no files were
            # loaded).
            def config
                @config ||= Config.new
            end

        end


        # Used to extend the including class with the class methods defined in
        # {ClassMethods}.
        def self.included(base)
            base.extend(ClassMethods)
        end


        def load_config_file(cfg_file)
            self.class.load_config_file(cfg_file)
        end


        # Each object instance gets its own copy of the class configuration, so
        # that any modifications they make are local to the object instance.
        #
        # @return [BatchKit::Config] a copy of the class configuration specific
        #   to this instance.
        def config
            @config ||= self.class.config.clone
        end

    end

end

