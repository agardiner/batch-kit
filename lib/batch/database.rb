require_relative 'database/schema'


class Batch

    class Database


        def initialize(options = {})
            @schema = Schema.new(options)
        end


        def connect(*args)
            @schema.connect(*args)

            MD5.check_schema(@schema)
        end

    end

end
