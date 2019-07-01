require 'test/unit'
require 'batch-kit/job'


class TestJob < Test::Unit::TestCase


    class JobE < BatchKit::Job
        positional_arg :pos_arg, 'A positional arg'
    end

    class JobF < JobE
    end


    def test_job_defn
        assert_equal(BatchKit::Job::Definition, JobE.job_definition.class)
        assert_equal(BatchKit::Job::Definition, JobF.job_definition.class)
        assert_equal(File.realpath(__FILE__), JobE.job_definition.file)
    end

    def test_configuration
        assert_equal(BatchKit::Config, JobE.config.class)
    end

end
