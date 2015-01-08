require 'test/unit'
require 'batch/config'
require 'batch/framework/configurable'


class TestConfig < Test::Unit::TestCase

    class ConfigA
        include Batch::Configurable
    end


    def test_configurable
        assert(ConfigA.respond_to?(:configure))
        assert_equal(Batch::Config, ConfigA.config.class)
        assert_equal(0, ConfigA.config.size)
        ConfigA.config.foo = 'bar'
        assert_equal('bar', ConfigA.config.foo)
        cfg_a = ConfigA.new
        assert(cfg_a.respond_to?(:config))
        assert_equal('bar', cfg_a.config.foo)
        cfg_a.config.foo = 'baz'
        assert_equal('baz', cfg_a.config.foo)
        assert_equal('bar', ConfigA.config.foo)
        ConfigA.configure("#{DIR}/test_config.yaml")
        assert_equal('FooBar', ConfigA.config.prop2.prop2b)
    end

end
