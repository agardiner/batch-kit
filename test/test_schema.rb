require 'test/unit'
require 'batch/database/schema'
require 'java'
require 'C:/oracle/product/11.2.0/dbhome_1/jdbc/lib/ojdbc6.jar'


class TestSchema < Test::Unit::TestCase

    def setup
        @schema = Batch::Database::Schema.new
        @schema.connect('jdbc:oracle:thin:BATCH/b4tch@localhost:1521:ORCL')
    end

    def test_create_schema
        @schema.create_tables
    end


    def test_drop_schema
        @schema.drop_tables
    end

end
