require 'fileutils'
require 'zip'


class BatchKit

    module Helpers

        module Zip

            # Creates a new +zip_file+, adding +files+ to it.
            #
            # @param zip_file [String] A path to the zip file to be created
            # @param files [String] One or more paths to files to be added to
            #   the zip.
            def create_zip(zip_file, *files)
                FileUtils.rm_f(zip_file)
                if RUBY_PLATFORM == 'java' && !block_given?
                    # Use Java's zip stream capabilities to handle larger files
                    fos = java.io.FileOutputStream.new(zip_file)
                    zos = java.util.zip.ZipOutputStream.new(fos)
                    begin
                        buffer = Java::byte[8196].new
                        files.flatten.each do |file|
                            f = java.io.File.new(file)
                            ze = java.util.zip.ZipEntry.new(f.getName())
                            fis = java.io.FileInputStream.new(f)
                            begin
                                zos.putNextEntry(ze)
                                while (len = fis.read(buffer)) >= 0 do
                                    zos.write(buffer, 0, len)
                                end
                            ensure
                                fis.close()
                            end
                        end
                    ensure
                        zos.close()
                        fos.close()
                    end
                else
                    ::Zip::File.open(zip_file, ::Zip::File::CREATE) do |zip|
                        files.flatten.each do |file|
                            zip.add(File.basename(file), file)
                        end
                        yield zip if block_given?
                    end
                end
            end


            # Unzip a +zip_flie+ to +output_dir+.
            #
            # @param zip_file [String] A path to the zip file to be created
            # @param output_dir [String] A path to an output directory where
            #   the zip content should be unzipped.
            # @param file_spec [String] An optional file pattern of zip entries
            #   to be unzipped. If not specified, all files are extracted.
            def unzip(zip_file, output_dir, file_spec=nil)
                paths = []
                ::Zip::File.open(zip_file) do |zip|
                    zip.each do |entry|
                        if file_spec
                            pn = Pathname.new(entry.name)
                            next unless pn.fnmatch(file_spec)
                        end
                        path = File.join(output_dir, entry.name)
                        entry.extract(path)
                        paths << path
                    end
                end
                paths
            end

        end

    end

end
