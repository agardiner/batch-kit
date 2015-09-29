class Batch

    module FileExtensions

        # Return just the name (without any extension) of a path.
        def nameonly(path)
            File.basename(path, File.extname(path))
        end

    end

end


File.class_eval do
    include Batch::FileExtensions
end
