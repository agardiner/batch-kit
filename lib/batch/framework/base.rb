require 'batch/arguments'
require 'batch/config'


class Batch

    module Job

        class Base

            include Arguments
            include Configurable


            # Include ActsAsJob into any inheriting class
            def self.inherited(sub_class)
                sub_class.class_eval do
                    include ActsAsJob
                end
            end

        end

    end

end

