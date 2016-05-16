class Batch

    module FileExtensions

        module ClassMethods

            # Return just the name (without any extension) of a path.
            def nameonly(path)
                File.basename(path, File.extname(path))
            end


            unless defined?(:open_without_bom)

                # Add support for writing a BOM if the +mode_string+ includes 'bom',
                # and the mode is write.
                alias_method :open_without_bom, :open
                def open(*args, &blk)
                    if args.length >= 2 && (mode_string = args[1]).is_a?(String) &&
                        mode_string =~ /^(w|a):(.*)bom/i
                        args[1] = mode_string.sub(/bom\||[\-|]bom/, '')
                        f = open_without_bom(*args)
                        bom_hex = case mode_string
                        when /utf.*8/i
                            "\xEF\xBB\xBF"
                        when /utf-16be/i
                            "\xFE\xFF"
                        when /utf-16le/i
                            "\xFF\xFE"
                        when /utf-32be/i
                            "\x00\x00\xFE\xFF"
                        when /utf-32le/i
                            "\xFE\xFF\x00\x00"
                        end
                        f << bom_hex.force_encoding(f.external_encoding)
                        if block_given?
                            yield f
                            f.close
                        else
                            f
                        end
                    else
                        open_without_bom(*args, &blk)
                    end
                end

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
