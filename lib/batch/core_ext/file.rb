class Batch

    module FileExtensions

        module ClassMethods

            # Return just the name (without any extension) of a path.
            def nameonly(path)
                File.basename(path, File.extname(path))
            end


            # Add support for writing a BOM if the +mode_string+ includes 'bom',
            # and the mode is write.
            alias_method :open_without_bom, :open
            def open(filename, mode_string = 'r', options = {})
                if mode_string.is_a?(Hash) && options.empty?
                    options = mode_string
                    mode_string = nil
                end
                bom = mode_string =~ /(w|a):(.*)bom/i
                wa = $1
                if mode_string.is_a?(String)
                    mode_string = mode_string.sub(/(\-|\|)?bom\|?/, '')
                end
                f = open_without_bom(filename, mode_string, options)
                if wa = 'w' && bom
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
                end
                f
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
