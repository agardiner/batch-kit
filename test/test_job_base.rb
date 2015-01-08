require 'test/unit'
require 'batch/job'


class TestJobBase < Test::Unit::TestCase


    class JobE < Batch::Job
        positional_arg :pos_arg, 'A positional arg'
    end

    class JobF < JobE
    end


    def test_job_defn
        assert_equal(Batch::Job::Definition, JobE.job_definition.class)
        assert_equal(Batch::Job::Definition, JobF.job_definition.class)
        assert_equal(File.realpath(__FILE__), JobE.job_definition.file)
    end

    def test_configuration
        assert_equal(Batch::Config, JobE.config.class)
    end

end
