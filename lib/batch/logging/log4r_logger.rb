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


            Batch::Logging::LEVELS.each do |lvl|
                class_eval <<-EOD
                    def #{lvl}(msg)
                        @log4r_logger.#{lvl}(msg)
                    end
                EOD
            end


            def method_missing(mthd, *args)
                @log4r_logger.send(mthd, *args)
            end

        end

    end

end
