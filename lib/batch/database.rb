require_relative 'database/schema'


class Batch

    class Database


        def initialize(options = {})
            @schema = Schema.new
        end


        def connect(*args)
            @schema.connect(*args)
            @schema.create_tables unless @schema.deployed?

            require_relative 'database/models'

            MD5.check_schema(@schema)
        end

    end

end
