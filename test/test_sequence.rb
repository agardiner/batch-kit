require 'test/unit'
require 'batch-kit/job'
require 'batch-kit/sequence'


class TestSequence < Test::Unit::TestCase

    class Job1 < BatchKit::Job
        job {}
    end

    class Job2 < BatchKit::Job
        job {}
    end

    class Seq1 < BatchKit::Sequence
        sequence do
            run Job1
            run Job2
        end
    end


    def test_simple_sequence
        Seq1.run
        # TODO: assert Job1 and Job2 were run
    end

end
