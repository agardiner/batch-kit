class BatchKit

    module HashExtensions

        # Converts a Hash object to a BatchKit::Config object
        def to_cfg
            self.is_a?(BatchKit::Config) ? self : BatchKit::Config.new(self)
        end

    end

end


Hash.class_eval do
    include BatchKit::HashExtensions
end
