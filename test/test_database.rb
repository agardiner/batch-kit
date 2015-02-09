require 'test/unit'
require 'batch/database'
require 'color_console'


class TestSchema < Test::Unit::TestCase

    def setup
        @db = Batch::Database.new
        if RUBY_ENGINE == 'jruby'
            require 'java'
            require 'C:/oracle/product/11.2.0/dbhome_1/jdbc/lib/ojdbc6.jar'
            @db.connect('jdbc:oracle:thin:BATCH/b4tch@localhost:1521:ORCL')
        else
            require 'oci8'
            @db.connect(adapter: 'oracle', user: 'BATCH', password: 'b4tch')
        end
    end


    def test_connect
    end

end
