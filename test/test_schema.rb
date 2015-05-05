require 'test/unit'
require 'batch/configurable'
require 'batch/database/schema'
require 'color_console'


class TestSchema < Test::Unit::TestCase

    include Batch::Configurable
    
    configure File.dirname(__FILE__) + '/connections.yaml'

    
    def setup
        @schema = Batch::Database::Schema.new
        @schema.connect(config.batch_db)
    end

    def test_create_schema
        @schema.create_tables
    end


    def test_drop_schema
        @schema.drop_tables
    end

end
