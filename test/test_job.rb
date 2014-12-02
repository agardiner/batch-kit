require 'test/unit'
require 'batch/job'


class TestJob < Test::Unit::TestCase

    class JobA

        include Batch::ActsAsJob

        def task1; end
        def task2; end
        def run; end

    end


    def test_inclusion_creates_job_definition
        job_def = JobA.job
        assert_equal(Batch::Job::Definition, job_def.class)
        assert_equal(JobA, job_def.job_class)
        assert_equal(File.realpath(__FILE__), job_def.file)
        assert_equal(Socket.gethostname, job_def.server)
    end

    def test_including_class_gets_delegated_properties
        assert_equal(File.realpath(__FILE__), JobA.job.file)
        assert_equal(Socket.gethostname, JobA.job.server)
        assert_equal('TestJob::JobA', JobA.job.name)
        JobA.job.name = 'Job A'
        assert_equal('Job A', JobA.job.name)
    end

    def test_including_class_instances_gets_delegated_properties
        job_a = JobA.new
        assert_equal(File.realpath(__FILE__), job_a.job.file)
        assert_equal(Socket.gethostname, job_a.job.server)
        assert_equal('Job A', job_a.job.name)
    end


    def test_set_job_method
        JobA.job.method_name = :run
        assert_equal(:run, JobA.job.method_name)
        assert_raise ArgumentError do
            JobA.job.method_name = :some_method
        end
        assert_raise RuntimeError do
            JobA.job.method_name = :task1
        end
    end


    def test_set_task_method
        task = JobA.task :task1
        assert_equal(:task1, task.method_name)
        assert_equal(JobA, task.task_class)
        assert_equal('task1', task.name)
        assert_equal(task, JobA.job.tasks[:task1])
    end


    class JobB
        include Batch::ActsAsJob
    end


    def test_set_job_options
        JobB.job :run_job, instance_expr: 'An $1 expression', lock: 'Foo' do
            puts 'Running'
        end
        assert_equal(:run_job, JobB.job.method_name)
        assert_equal('Foo', JobB.job.lock)
        assert_equal('An $1 expression', JobB.job.instance_expr)
    end


    class JobC
        include Batch::ActsAsJob

        def foo
            42
        end

        def bar
            'Baah!'
        end

        job :foo
        task :bar
    end


    def test_running_job
        job_c = JobC.new
        assert_equal(42, job_c.foo)
    end


    def test_running_task
        job_c = JobC.new
        job_c.foo
        assert_equal('Baah!', job_c.bar)
    end


    def test_job_run
        job_c = JobC.new
        job_c.foo
        job_run = job_c.job_run
        assert_equal(Batch::Job::Run, job_run.class)
        assert_not_nil(job_run.start_time)
        assert_not_nil(job_run.end_time)
        job_runs = job_c.job.runs
        assert(job_c.job.runs.size > 0, "Expected job_runs.size > 0, got #{job_runs.size}")
    end

    def test_task_run
        job_c = JobC.new
        job_c.foo
        job_c.bar
        task_runs = job_c.job.tasks[:bar].runs
        assert(task_runs.size > 0, "Expected task_runs.size > 0, got #{task_runs.size}")
    end

end
