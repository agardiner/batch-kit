class Batch

    module HashExtensions

        # Converts a Hash object to a Batch::Config object
        def to_cfg
            self.is_a?(Batch::Config) ? self : Batch::Config.new(self)
        end

    end

end


Hash.class_eval do
    include Batch::HashExtensions
end
