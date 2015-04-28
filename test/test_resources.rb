require 'minitest/autorun'
require 'batch/resources'
require 'batch/configurable'
require 'batch/job'

require 'sequel'
if RUBY_ENGINE == 'jruby'
    require 'java'
    require 'C:/oracle/product/11.2.0/dbhome_1/jdbc/lib/ojdbc6.jar'
else
    require 'oci8'
end


Batch::ResourceManager.register(Sequel::Database, :get_db_connection, disposal_method: :disconnect) do |*args|
    Sequel.default_timezone = :utc
    conn = Sequel.connect(*args)
end

Batch::Events.subscribe(Sequel::Database, 'resource.acquired') do |src, db|
    puts "Retrieved database connection"
end
Batch::Events.subscribe(Sequel::Database, 'resource.disposed') do |src, db|
    puts "Closed database connection"
end


if RUBY_ENGINE == 'jruby'
    require 'ess4r'
    Batch::ResourceManager.register(Essbase, :get_essbase_server, disposal_method: :disconnect) do |cfg = config|
        Essbase.connect(cfg.essbase_user, cfg.essbase_pwd, cfg.essbase_server)
    end

    Batch::ResourceManager.register(Essbase::Cube, :get_essbase_cube, disposal_method: :clear_active) do |app, db, config = cfg|
        srv = get_essbase_server(cfg)
        cube = srv.open_cube(app, db)
    end
end


class MyJob

    include Batch::ActsAsJob
    include Batch::ResourceHelper

end



class TestResources < Minitest::Test

    include Batch::ResourceHelper
    include Batch::Configurable

    configure File.dirname(__FILE__) + '/connections.yaml'

    def db
        if RUBY_ENGINE == 'jruby'
            get_db_connection(config.batch_db_jdbc)
        else
            get_db_connection(config.batch_db)
        end
    end


    def test_db
        assert('1', db["SELECT '1' Key FROM DUAL"].first[:key])
    end


    def test_essbase
        if RUBY_ENGINE == 'jruby'
            require 'java'
            require 'C:/oracle/product/11.2.0/dbhome_1/jdbc/lib/ojdbc6.jar'
            ess = get_essbase_server(config.batch_db_jdbc)
        end
    end


    def test_disposal
        db
        assert(@__resources__.size > 0)
        cleanup_resources
        assert_nil(@__resources__)
    end

end
