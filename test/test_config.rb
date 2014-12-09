require 'test/unit'
require 'batch/config'


class TestConfig < Test::Unit::TestCase

    DIR = File.dirname(__FILE__)
    KEY = '$CDq7;s[p'

    def test_empty
        cfg = Batch::Config.new
        assert_equal(0, cfg.size)
    end


    def test_from_hash
        cfg = Batch::Config.new('key1' => 1, :key2 => 'Two')
        assert_equal(1, cfg['key1'])
        assert_equal('Two', cfg[:key2])
    end


    def test_key_conversion
        cfg = Batch::Config.new('key1' => 1, :key2 => 'Two')
        assert_equal(1, cfg[:key1])
        assert_equal(1, cfg[:KEY1])
        assert_equal(1, cfg['KEY1'])
        assert_equal('Two', cfg['key2'])
        assert_equal('Two', cfg['KEY2'])
        assert_equal('Two', cfg[:KEY2])
    end


    def test_property_access
        cfg = Batch::Config.new('key1' => 1, :key2 => 'Two')
        assert_equal(1, cfg.key1)
        assert_equal('Two', cfg.key2)
    end


    def test_property_exists
        cfg = Batch::Config.new('key1' => 1, :key2 => 'Two')
        assert_equal(true, cfg.key1?)
        assert_equal(false, cfg.key3?)
    end


    def test_properties
        hsh = Batch::Config.load_properties("#{DIR}/test_config.properties")
        assert_equal('Top', hsh['TOP_LEVEL_PROPERTY'])
        assert_equal(Hash, hsh['SECTION_TEST'].class)
        assert_equal('One', hsh['SECTION_TEST']['PROP1'])
        assert_equal('%{PROP1}_Two', hsh['SECTION_TEST']['PROP2'])
        assert_equal('Section Top', hsh['SECTION_TEST']['TOP_LEVEL_PROPERTY'])
    end


    def test_config_from_properties
        cfg = Batch::Config.load("#{DIR}/test_config.properties")
        assert_equal('Top', cfg['TOP_LEVEL_PROPERTY'])
        assert_equal('Top', cfg[:top_level_property])
        assert_equal('Top', cfg.top_level_property)
        assert_equal(Batch::Config, cfg.section_test.class)
        assert_equal('One', cfg.section_test.prop1)

        assert_equal('One_Two', cfg.section_test[:prop2])
    end


    def test_decryption
        cfg = Batch::Config.load("#{DIR}/test_config.properties")
        assert_equal('Top', cfg['TOP_LEVEL_PROPERTY'])
        assert_equal('admin', cfg.secret.user_id)
        assert_equal('!AES:6BLBRr54rJ3q2wxOujo0yUtocZNgub7xH1belKLRANQ=!', cfg.secret.password)
        cfg.decryption_key = KEY
        assert_equal('foo', cfg.secret.password)
    end


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
