require 'test/unit'
require 'batch-kit/encryption'

class TestEncryption < Test::Unit::TestCase

  KEY = '$CDq7;s[p'

  def test_encryption
    enc = BatchKit::Encryption.encrypt(KEY, 'foo')
    pt = BatchKit::Encryption.decrypt(KEY, enc)
    assert_equal 'foo', pt
  end


  def test_decryption
    pt = BatchKit::Encryption.decrypt(KEY, '6BLBRr54rJ3q2wxOujo0yUtocZNgub7xH1belKLRANQ=')
    assert_equal 'foo', pt
  end

end
