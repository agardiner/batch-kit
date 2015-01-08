require 'test/unit'
require 'batch/process'

class TestProcess < Test::Unit::TestCase


    def test_popen
    end


    def test_launch
        Batch::Process.launch('cmd.exe /C dir', log_level: :info)
    end

end
