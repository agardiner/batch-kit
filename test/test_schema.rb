require 'test/unit'
require 'batch/database/schema'


class TestSchema < Test::Unit::TestCase

    def setup
        @schema = Batch::Database::Schema.new
        if RUBY_ENGINE == 'java'
            require 'java'
            require 'C:/oracle/product/11.2.0/dbhome_1/jdbc/lib/ojdbc6.jar'
            @schema.connect('jdbc:oracle:thin:BATCH/b4tch@localhost:1521:ORCL')
        else
            require 'oci8'
            @schema.connect(adapter: 'oracle', user: 'BATCH', password: 'b4tch')
        end
    end

    def test_create_schema
        @schema.create_tables
    end


    def test_drop_schema
        @schema.drop_tables
    end

end
