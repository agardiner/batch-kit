require 'batch/arguments'
require 'batch/config'


class Batch

    module Job

        class Base

            include ActsAsJob
            include Arguments
            include Configurable

        end

    end

end

