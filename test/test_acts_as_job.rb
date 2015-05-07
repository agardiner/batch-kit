require 'test/unit'
require 'batch/job'


class TestActsAsJob < Test::Unit::TestCase

    class JobA

        include Batch::ActsAsJob

        def task1; end
        def task2; end
        def run
            task1
            task2
        end

    end


    def test_inclusion_creates_job_definition
        job_def = JobA.job
        assert_equal(Batch::Job::Definition, job_def.class)
        assert_equal(JobA, job_def.job_class)
        assert_equal(File.realpath(__FILE__), job_def.file)
        assert_equal(Socket.gethostname, job_def.computer)
    end

    def test_including_class_gets_delegated_properties
        assert_equal(File.realpath(__FILE__), JobA.job.file)
        assert_equal(Socket.gethostname, JobA.job.computer)
        assert_equal('TestActsAsJob::JobA', JobA.job.job_class.name)
        JobA.job.name = 'Job A'
        assert_equal('Job A', JobA.job.name)
    end

    def test_including_class_instances_gets_delegated_properties
        JobA.job.name = 'Job A'
        job_a = JobA.new
        assert_equal(File.realpath(__FILE__), job_a.job.file)
        assert_equal(Socket.gethostname, job_a.job.computer)
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
        JobB.job :run_job, instance: 'An $1 expression', lock_name: 'Foo' do
            puts 'Running'
        end
        assert_equal(:run_job, JobB.job.method_name)
        assert_equal('Foo', JobB.job.lock_name)
        assert_equal('An $1 expression', JobB.job.instance)
    end


    class JobC
        include Batch::ActsAsJob

        def foo
            bar
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
        #assert_equal('Baah!', job_c.bar)
    end


    def test_job_run
        job_c = JobC.new
        job_c.foo
        job_run = job_c.job.runs.last
        assert_equal(Batch::Job::Run, job_run.class)
        assert_not_nil(job_run.start_time)
        assert_not_nil(job_run.end_time)
        job_runs = job_c.job.runs
        assert(job_c.job.runs.size > 0, "Expected job_runs.size > 0, got #{job_runs.size}")
    end

    def test_task_run
        job_c = JobC.new
        job_c.foo
        task_runs = job_c.job.tasks[:bar].runs
        assert(task_runs.size > 0, "Expected task_runs.size > 0, got #{task_runs.size}")
    end

    class JobD
        include Batch::ActsAsJob

        def task1(a, b = nil)
        end

        def task2(a, b = nil, *rest)
        end

        def task3(a, b = nil, *rest)
            yield :foo
        end

        def task4(a, b = nil, *rest, &blk)
            blk.call :foo
        end

        job do |task_name, *args, &blk|
            send task_name, *args, &blk
        end

        task :task1
        task :task2
        task :task3
        task :task4
    end


    def test_arity_handling
        job_d = JobD.new

        assert_raise(ArgumentError) { job_d.execute :task1 }
        assert_nothing_raised{ job_d.execute(:task1, 1) }
        assert_nothing_raised{ job_d.execute(:task1, 1, 'a') }
        assert_raise(ArgumentError) { job_d.execute(:task1, 1, 'a', :b) }

        assert_raise(ArgumentError) { job_d.execute :task2 }
        assert_nothing_raised{ job_d.execute(:task2, 1) }
        assert_nothing_raised{ job_d.execute(:task2, 1, 'a') }
        assert_nothing_raised{ job_d.execute(:task2, 1, 'a', 3) }
        assert_nothing_raised{ job_d.execute(:task2, 1, 'a', 3, 4) }

        assert_raise(LocalJumpError) { job_d.execute(:task3, 1) }
        assert_nothing_raised{ job_d.execute(:task3, 1) {} }

        assert_raise(NoMethodError) { job_d.execute(:task4, 1) }
        assert_nothing_raised{ job_d.execute(:task4, 1) {} }
    end

end
