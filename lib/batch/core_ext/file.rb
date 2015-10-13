class Batch

    module FileExtensions

        module ClassMethods

            # Return just the name (without any extension) of a path.
            def nameonly(path)
                File.basename(path, File.extname(path))
            end

        end


        def self.included(cls)
            cls.extend(ClassMethods)
        end

    end

end


File.class_eval do
    include Batch::FileExtensions
end
