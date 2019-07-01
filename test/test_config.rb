require 'test/unit'
require 'batch-kit/config'
require 'fileutils'


class TestConfig < Test::Unit::TestCase

    DIR = File.dirname(__FILE__)
    KEY = '$CDq7;s[p'

    def test_empty
        cfg = BatchKit::Config.new
        assert_equal(0, cfg.size)
    end


    def test_from_hash
        cfg = BatchKit::Config.new('key1' => 1, :key2 => 'Two')
        assert_equal(1, cfg['key1'])
        assert_equal('Two', cfg[:key2])
    end


    def test_key_conversion
        cfg = BatchKit::Config.new('key1' => 1, :key2 => 'Two')
        assert_equal(1, cfg[:key1])
        assert_equal(1, cfg[:KEY1])
        assert_equal(1, cfg['KEY1'])
        assert_equal('Two', cfg['key2'])
        assert_equal('Two', cfg['KEY2'])
        assert_equal('Two', cfg[:KEY2])
    end


    def test_property_access
        cfg = BatchKit::Config.new('key1' => 1, :key2 => 'Two')
        assert_equal(1, cfg.key1)
        assert_equal('Two', cfg.key2)
    end


    def test_property_exists
        cfg = BatchKit::Config.new('key1' => 1, :key2 => 'Two')
        assert_equal(true, cfg.key1?)
        assert_equal(false, cfg.key3?)
    end


    def test_properties
        str = IO.read("#{DIR}/test_config.properties")
        hsh = BatchKit::Config.properties_to_hash(str)
        assert_equal('Top', hsh['TOP_LEVEL_PROPERTY'])
        assert_equal(Hash, hsh['SECTION_TEST'].class)
        assert_equal('One', hsh['SECTION_TEST']['PROP1'])
        assert_equal('%{PROP1}_Two', hsh['SECTION_TEST']['PROP2'])
        assert_equal('Section Top', hsh['SECTION_TEST']['TOP_LEVEL_PROPERTY'])
    end


    def test_config_from_properties
        cfg = BatchKit::Config.load("#{DIR}/test_config.properties")
        assert_equal('Top', cfg['TOP_LEVEL_PROPERTY'])
        assert_equal('Top', cfg[:top_level_property])
        assert_equal('Top', cfg.top_level_property)
        assert_equal(BatchKit::Config, cfg.section_test.class)
        assert_equal('One', cfg.section_test.prop1)

        assert_equal('One_Two', cfg.section_test[:prop2])
    end


    def test_decryption
        cfg = BatchKit::Config.load("#{DIR}/test_config.properties")
        assert_equal('Top', cfg['TOP_LEVEL_PROPERTY'])
        assert_equal('admin', cfg.secret.user_id)
        assert_equal('!AES:6BLBRr54rJ3q2wxOujo0yUtocZNgub7xH1belKLRANQ=!', cfg.secret.password)
        cfg.decryption_key = KEY
        assert_equal('foo', cfg.secret.password)
    end


    def test_encryption
        master_key = 'AxY^tIPd$'
        cfg = BatchKit::Config.new(user_id: 'test', password: 'A secret',
                                ess_user: 'admin', ess_pwd: 'Another secret')
        cfg.encryption_key = master_key
        cfg.encrypt('password')
        assert_equal('test', cfg[:user_id])
        assert_equal('A secret', cfg['Password'])
        assert_equal('Another secret', cfg['Ess Pwd'])
        cfg.encryption_key = nil
        assert_equal('test', cfg[:user_id])
        assert_not_equal('A secret', cfg[:password])
        assert_equal('Another secret', cfg['Ess Pwd'])

        cfg.encryption_key = master_key
        cfg.encrypt(/password|pwd/i, 'Foo')
        assert_equal('A secret', cfg['Password'])
        assert_equal('Another secret', cfg['Ess Pwd'])
        cfg.encryption_key = nil
        assert_not_equal('A secret', cfg['Password'])
        assert_not_equal('Another secret', cfg['Ess Pwd'])
    end


    def test_save_yaml
        cfg_props = BatchKit::Config.load("#{DIR}/test_config.properties")
        out_file = "#{DIR}/config.yaml"
        cfg_props.save_yaml(out_file)
        assert(File.exists?(out_file))
        cfg = BatchKit::Config.load(out_file)
        cfg_props.each do |k, v|
            assert_equal(cfg_props[k], cfg[k])
        end
        FileUtils.rm_f(out_file)
    end

end
