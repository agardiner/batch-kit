require 'minitest/autorun'
require 'batch/helpers/process'

class TestProcess < Minitest::Test


    def test_popen
    end


    def test_launch
        Batch::Helpers::Process.launch('cmd.exe /C dir', log_level: :info)
    end

end
