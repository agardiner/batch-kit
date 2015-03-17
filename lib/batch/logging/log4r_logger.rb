require 'log4r'
require 'log4r/configurator'

Log4r::Configurator.custom_levels(*Logging::LEVELS.reverse.map{ |l| l.to_s.upcase })

