require 'batch-kit/job'


class TestException < BatchKit::Job

    task :throw_exc do
        raise "This is an exception"
    end

    job do
        throw_exc
    end

end

TestException.run
