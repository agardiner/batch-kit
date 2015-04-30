require 'test/unit'
require 'batch/job'
require 'batch/database'
require 'color_console'


class TestSchema < Test::Unit::TestCase

    Batch::LogManager.configure(log_framework: :log4r)


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
        #@db = Batch::Database.new(log_level: :info)
        @db = Batch::Database.new(log_level: :error)
        if RUBY_ENGINE == 'jruby'
            require 'java'
            require 'C:/oracle/product/11.2.0/dbhome_1/jdbc/lib/ojdbc6.jar'
            @db.connect('jdbc:oracle:thin:BATCH/b4tch@localhost:1521:ORCL')
        else
            require 'oci8'
            @db.connect(adapter: 'oracle', user: 'BATCH', password: 'b4tch')
        end
    end


    def test_job
        # Run the job and then check the database contents
        MyJob.run
    end

end
