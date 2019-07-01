require 'test/unit'
require 'batch-kit/configurable'
require 'batch-kit/database/schema'
require 'color_console'


class TestSchema < Test::Unit::TestCase

    include BatchKit::Configurable
    
    configure File.dirname(__FILE__) + '/connections.yaml'

    
    def setup
        @schema = BatchKit::Database::Schema.new
        @schema.connect(config.batch_db)
    end

    def test_create_schema
        @schema.create_tables
    end


    def test_drop_schema
        @schema.drop_tables
    end

end
