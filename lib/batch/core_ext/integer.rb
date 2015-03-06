class Batch

    module IntegerExtensions

        # Converts an integer to a comma-separated string, e.g. 1024 becomes "1,024"
        def with_commas
            self.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
        end

    end

end


Integer.class_eval do
    include Batch::IntegerExtensions
end
