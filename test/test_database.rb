require 'test/unit'
require 'batch/job'
require 'batch/database'
require 'color_console'
require 'sequel'
if RUBY_ENGINE == 'jruby'
    require 'java'
    #require 'ojdbc6.jar'
else
    require 'oci8'
end


class TestSchema < Test::Unit::TestCase

    include Batch::Configurable

    configure File.dirname(__FILE__) + '/connections.yaml'

    Batch::LogManager.configure(log_framework: RUBY_ENGINE == 'jruby' ?
                                :java_util_logging :
                                :log4r)


    class MyJob < Batch::Job

        positional_arg :pos_arg, 'Pos arg', default: 'None'
        keyword_arg :foo, 'More foo'


        task :first, 'First task' do
            log.info "Doing first task work"
        end

        task :second, 'Second task' do
            log.info 'Doing second task work'
            sleep(3)
            log.info 'Second task complete'
        end

        job do
            first
            second
        end
    end


    def setup
        @db = Batch::Database.new(log_level: :error)
        @db.connect(config.batch_db)
    end


    def test_job
        # Run the job and then check the database contents
        MyJob.run
    end

end
