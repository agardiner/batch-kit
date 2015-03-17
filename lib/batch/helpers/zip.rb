require 'fileutils'
require 'zip/zip'


class Batch

    module Helpers

        module Zip

            # Creates a new +zip_file+, adding +files+ to it.
            #
            # @param zip_file [String] A path to the zip file to be created
            # @param files [String] One or more paths to files to be added to
            #   the zip.
            def create_zip(zip_file, *files)
                FileUtils.rm_f(zip_file)
                Zip::ZipFile.open(zip_file, Zip::ZipFile::CREATE) do |zip|
                    files.each do |file|
                        zip.add(File.basename(file), file)
                    end
                    yield zip if block_given?
                end
            end

        end

    end

end
