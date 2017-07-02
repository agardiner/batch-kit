require 'test/unit'
require 'batch/job'
require 'batch/sequence'


class TestSequence < Test::Unit::TestCase

    class Job1 < Batch::Job
        job {}
    end

    class Job2 < Batch::Job
        job {}
    end

    class Seq1 < Batch::Sequence
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
