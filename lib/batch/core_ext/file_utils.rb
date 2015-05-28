require 'fileutils'
require 'date'


module FileUtils

    # Archive existing files at +paths+, where +paths+ is one or more
    # Dir#glob patterns. Archiving consists of renaming files to include a
    # timestamp in the file name. This permits multiple copies of the same
    # file to exist in a single directory. The timestamp is created from
    # the last modification date of the file being archived.
    #
    # The last argument passed may be an options Hash, which can be used
    # to change the default behaviour. Valid options are:
    # @option options [String] :archive_dir The directory in which to place
    #   archived files. If not specified, archived files are placed in the
    #   same directory.
    # @option options [Fixnum] :archive_days The number of days for which to
    #   keep archived files. Defaults to nil, meaning there is no maximum
    #   number of days.
    # @option options [Fixnum] :archive_copies The maximum number of copies
    #   to keep of an archived file. Defaults to 10.
    def archive(*paths)
        if paths.last.is_a?(Hash)
            options = paths.pop
        else
            options = {archive_copies: 10}
        end
        archive_dir = options[:archive_dir]
        archive_copies = options[:archive_copies]
        if archive_copies && 1 > archive_copies
            raise ArgumentError, ":archive_copies option must be positive"
        end
        archive_days = options[:archive_days]
        if archive_days && 1 > archive_days
            raise ArgumentError, ":archive_days option must be positive"
        end
        cutoff_date = archive_days && (Date.today - archive_days)

        FileUtils.mkdir_p(archive_dir) rescue nil if archive_dir

        # Create archives of files that match the patterns in +paths+
        archive_count = 0
        Dir[*paths].each do |file_name|
            next if file_name =~ /\d{8}.\d{6}(?:\.[^.]+)?$/
            File.rename(file_name, '%s/%s.%s%s' % [
                            archive_dir || File.dirname(file_name),
                            File.basename(file_name, File.extname(file_name)),
                            File.mtime(file_name).strftime('%Y%m%d.%H%M%S'),
                            File.extname(file_name)
                        ]) rescue next
            archive_count += 1
        end

        if archive_copies || cutoff_date
            # Find all copies of each unique file matching +paths+
            purge_sets = Hash.new{ |h, k| h[k] = [] }
            folders = archive_dir ? [archive_dir] : paths.map{ |path| File.dirname(path) }.uniq
            folders.each do |folder|
                Dir["#{folder}/*.????????.??????.*"].each do |path|
                    if path =~ /^(.+)\.\d{8}\.\d{6}(\.[^.]+)?$/
                        purge_sets["#{$1}#{$2}"] << path
                    end
                end
            end

            # Now purge the oldest archives, such that we keep a maximum of
            # +archive_copies+, and no file older than +cutoff_date+.
            purge_sets.each do |orig_name, old_files|
                old_files.sort!
                old_size = old_files.size
                purge_files = []
                if archive_copies && old_size > archive_copies
                    purge_files = old_files.slice!(0, old_size - archive_copies)
                end
                if cutoff_date
                    vold_files = old_files.reject! do |path|
                        path =~ /(\d{4})(\d{2})(\d{2})\.\d{6}(?:\.[^.]+)?$/
                        file_date = Date.new($1.to_i, $2.to_i, $3.to_i)
                        file_date >= cutoff_date
                    end
                    purge_files.concat(vold_files) if vold_files
                end
                if purge_files.size > 0
                    FileUtils.rm_f(purge_files) rescue nil
                end
            end
        end
        archive_count
    end
    module_function :archive

end
