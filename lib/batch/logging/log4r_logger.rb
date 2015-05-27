require 'log4r'
require 'log4r/configurator'

Log4r::Configurator.custom_levels(*Batch::Logging::LEVELS.reverse.map{ |l| l.to_s.upcase })



class Batch

    module Logging

        class Log4rFacade

            def initialize(logger)
                @log4r_logger = logger
            end

            def level
                Log4r::LNAMES[@log4r_logger.level].downcase.intern
            end

            def level=(lvl)
                @log4r_logger.level = Log4r::LNAMES.index(lvl.to_s.upcase)
            end


            def log_file
                out_name = "#{self.name}_file"
                fo = @log4r_logger.outputters.find{ |o| o.name == out_name }
                fo && fo.filename
            end


            def log_file=(log_path)
                out_name = "#{self.name}_file"
                if outputter = Log4r::Outputter[out_name]
                    outputter.close
                    @log4r_logger.remove out_name
                end
                if log_path
                    FileUtils.mkdir_p(File.dirname(log_path))
                    formatter = Log4r::PatternFormatter.new(pattern: '[%d] %-6l %x %M\r')
                    outputter = Log4r::FileOutputter.new(out_name, filename: log_path,
                                                         trunc: false, formatter: formatter)
                    @log4r_logger.add out_name
                end
            end


            Batch::Logging::LEVELS.each do |lvl|
                class_eval <<-EOD
                    def #{lvl}(msg)
                        @log4r_logger.#{lvl}(msg)
                    end
                EOD
            end

            alias_method :warn, :warning


            def method_missing(mthd, *args)
                @log4r_logger.send(mthd, *args)
            end

        end

    end

end
