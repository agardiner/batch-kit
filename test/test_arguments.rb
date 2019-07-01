require 'test/unit'
require 'batch-kit/arguments'

class TestArguments < Test::Unit::TestCase

    include BatchKit::Arguments

    positional_arg :pos_arg, 'A positional arg'
    keyword_arg :kw_arg, 'A keyword arg'
    usage_break 'FLAGS'
    flag_arg :flag1, 'Flag arg 1'


    def test_parse
        args_def.title = 'Test Arguments'
        args_def.purpose = 'Test that parsing can be added to any class'
        args = self.parse_arguments(['--kw_arg', 'kw_val', 'MyPos', '--flag1'])
        assert_equal('MyPos', args.pos_arg)
        # Parsed args should also be available via self#arguments
        assert_equal('kw_val', arguments.kw_arg)
        assert_equal(true, arguments.flag1)
    end

end
