class BatchKit

    module NumericExtensions

        # Converts an integer to a comma-separated string, e.g. 1024 becomes "1,024"
        def with_commas
            self.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
        end

    end

end


Numeric.class_eval do
    include BatchKit::NumericExtensions
end
