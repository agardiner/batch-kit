require 'minitest/autorun'
require 'batch-kit/resources'
require 'batch-kit/configurable'
require 'batch-kit/job'

require 'sequel'
if RUBY_ENGINE == 'jruby'
    require 'java'
    require 'C:/oracle/product/11.2.0/dbhome_1/jdbc/lib/ojdbc6.jar'
else
    require 'oci8'
end

# Register various resource types
BatchKit::ResourceManager.register(File, :get_file)

BatchKit::ResourceManager.register(Sequel::Database, :get_db_connection, disposal_method: :disconnect) do |*args|
    Sequel.default_timezone = :utc
    log.detail "Connecting to database"
    conn = Sequel.connect(*args)
end

BatchKit::Events.subscribe(nil, 'resource.disposed') do |rsrc_cls, rsrc|
    puts "Disposed of #{rsrc_cls} resource"
end


if RUBY_ENGINE == 'jruby'
    require 'ess4r'
    require 'ess4r/cube'
    BatchKit::ResourceManager.register(Essbase::Server, :get_essbase_server,
                                    disposal_method: :disconnect, use_send: true) do |cfg = config|
        log.detail "Connecting to Essbase as #{cfg.essbase_user} on #{cfg.essbase_server}"
        Essbase.connect(cfg.essbase_user, cfg.essbase_pwd, cfg.essbase_server)
    end


    BatchKit::ResourceManager.register(Essbase::Cube, :get_essbase_cube,
                                    disposal_method: :clear_active) do |app, db, cfg = config|
        srv = self.get_essbase_server(cfg)
        log.detail "Opening Essbase cube #{app}:#{db}"
        cube = srv.open_cube(app, db)
    end
end


class MyJob

    include BatchKit::ActsAsJob
    include BatchKit::ResourceHelper

end



class TestResources < Minitest::Test

    include BatchKit::ResourceHelper
    include BatchKit::Configurable
    include BatchKit::Loggable

    configure File.dirname(__FILE__) + '/connections.yaml'

    def db
        if RUBY_ENGINE == 'jruby'
            get_db_connection(config.batch_db_jdbc)
        else
            get_db_connection(config.batch_db)
        end
    end


    def test_file
        f = get_file(File.dirname(__FILE__) + '/connections.yaml')
        assert(File, f.class)
    end


    def test_db
        assert('1', db["SELECT '1' Key FROM DUAL"].first[:key])
    end


    def test_essbase
        if RUBY_ENGINE == 'jruby'
            ess = get_essbase_server()
            assert(Essbase::Server, ess)
        end
    end


    def test_essbase_cube
        if RUBY_ENGINE == 'jruby'
            cube = get_essbase_cube('Sample', 'Basic')
            assert(Essbase::Cube, cube)
        end
    end


    def test_disposal
        db
        assert(@__resources__.size > 0)
        cleanup_resources
        assert_nil(@__resources__)
    end


    def teardown
        cleanup_resources
    end

end
