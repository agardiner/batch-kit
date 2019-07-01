require 'minitest/autorun'
require 'batch-kit/helpers/process'

class TestProcess < Minitest::Test


    def test_popen
    end


    def test_launch
        BatchKit::Helpers::Process.launch('cmd.exe /C dir', log_level: :info)
    end

end
