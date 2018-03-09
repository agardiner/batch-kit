require 'openssl'
require 'digest/sha1'
require 'base64'


class Batch

    # Performs password-based encryption (PBE) and decryption using the AES 128-bit
    # cipher algorithm. Password-based encryption uses a password or passphrase
    # as the shared secret key with which to encrypt/decrypt other text.
    #
    # As with all key-based encryption schemes, the encrypted values are only as
    # secure as the key used to encrypt them. If the key is accessible to a
    # hacker, any values encrypted with the key can be decrypted, so the key
    # should be stored separately from the encrypted values, and be kept as
    # secure as possible.
    module Encryption

        # Use PBKDF2 with SHA-1 as the key hashing algorithm
        # The NIST specifically names SHA1 as an acceptable hashing algorithm
        # for PKBDF2
        KEY_ALGORITHM = :pbkdf2_hmac_sha1

        # Iteration count; NIST recommends at least 1000 iterations
        KEY_ITERATION_COUNT = 5000

        # Length of the generated key in bits
        KEY_DERIVED_LENGTH = 128

        # Algorithm to use for encryption
        CIPHER_ALGORITHM = 'AES-128-CBC'

        # Salt; a random 8 bytes used to generate an encryption key from a key
        # password / passphrase.
        #
        # @note The same value *must* be used for the salt when converting a key
        # password/passphrase into an encryption key for both encryptionn and
        # decryption.
        SALT = [70, 211, 28, 57, 192, 6, 78, 163].pack("CCCCCCCC")


        # Generate a random master key that can be used to encrypt/decrypt other
        # sensitive data such as passwords. The master key must be stored some
        # place separate from the values it is used to encrypt.
        #
        # @return [String] A random string of text that can be used as a master
        #   key for encrypting/decrypting other values.
        def generate_master_key()
            require 'securerandom'
            SecureRandom.uuid
        end
        module_function :generate_master_key


        # Encrypt the supplied +clear_text+, using +key_text+ as the pass-phrase.
        #
        # @param key_text [String] The clear-text pass-phrase to use as the key
        #   for encryption.
        # @param clear_text [String] The cleartext string to be encrypted.
        # @param salt [Array<Byte>] An 8-byte array of random values to use as
        #   the salt.
        # @return [String] A base-64 encoded string representing the encrypted
        #   +clear_text+ value.
        def encrypt(key_text, clear_text, salt = SALT)
            key = generate_key(key_text, salt)
            encipher(key, clear_text)
        end
        module_function :encrypt


        # Encipher the supplied +clear_text+, using +key+ as the encryption key.
        #
        # Note: this method is possibly less secure than #encrypt, since it uses
        # the actual key in the enciphering, rather than an SHA1 hash of the key.
        #
        # @param key [String] The key to use for encryption.
        # @param clear_text [String] The cleartext string to be encrypted.
        # @param cipher_algorithm [String] The name of the cipher algorithm to
        #   use when encrypting the clear_text.
        # @return [String] A base-64 encoded string representing the encrypted
        #   +clear_text+ value.
        def encipher(key, clear_text, cipher_algorithm = CIPHER_ALGORITHM)
            cipher = OpenSSL::Cipher.new(cipher_algorithm)
            cipher.encrypt
            cipher.key = key

            iv = cipher.random_iv
            cipher_bytes = cipher.update(clear_text) + cipher.final

            # Combine IV and cipher bytes, and base-64 encode
            base64_encode([iv + cipher_bytes])
        end
        module_function :encipher


        # Decrypt the supplied +cipher_text+, using +key_text+ as the pass-phrase.
        #
        # @param key_text [String] The clear-text pass-phrase to use as the key
        #   for decryption.
        # @param cipher_text [String] A base-64 encoded cipher text string that
        #   is to be decrypted.
        # @param salt [Array<Byte>] An 8-byte array of random values to use as
        #   the salt. Like the +key_text+, it is imperative that the same value
        #   is used for the salt when decrypting a previously encrypted value.
        # @return [String] The clear text that was encrypted.
        def decrypt(key_text, cipher_text, salt = SALT)
            key = generate_key(key_text, salt)
            decipher(key, cipher_text)
        end
        module_function :decrypt


        # Decipher the supplited +cipher_text+, using +key+ as the decipher key.
        #
        # @param key [String] The key used for encryption.
        # @param cipher_text [String] A base-64 encoded cipher text string that
        #   is to be decrypted.
        # @param cipher_algorithm [String] The name of the cipher algorithm used
        #   to encrypt the clear_text.
        # @return [String] The clear text that was encrypted.
        def decipher(key, cipher_text, cipher_algorithm = CIPHER_ALGORITHM)
            cipher = OpenSSL::Cipher.new(cipher_algorithm)
            cipher.decrypt
            cipher.key = key

            # Base-64 decode, and unpack IV and cipher from cipher_text
            iv_cipher = base64_decode(cipher_text)
            iv_len = KEY_DERIVED_LENGTH / 8
            cipher.iv = iv_cipher[0...iv_len]
            cipher_bytes = iv_cipher[iv_len..-1]
            cipher.update(cipher_bytes) + cipher.final
        end
        module_function :decipher


        # Convert a byte array to a base-64 encoded string representation.
        #
        # @param bytes [String, Array<String>] A String or Java byte-array to be
        #   encoded.
        # @return [String] A base-64 encoded String.
        def base64_encode(bytes)
            bytes = [bytes] if bytes.is_a?(String)
            bytes.pack('m').chomp
        end
        module_function :base64_encode


        # Convert a base-64 encoded string to a byte array.
        #
        # @param str [String] A base-64 encoded String.
        # @return [Array<byte>] A String containing the decoded bytes.
        def base64_decode(str)
            str.unpack('m').first
        end
        module_function :base64_decode


        private

        # Generates the key to be used for encryption/decryption, based on
        # +key_text+ and +salt+.
        #
        # @param key_text [String] A clear-text password or pass phrase that is
        #   to be used to derive the encryption key.
        # @param salt [String] A String containing a random salt.
        # @return [SecretKey] A key that can be used for encryption/decryption.
        def generate_key(key_text, salt)
            OpenSSL::PKCS5.send(KEY_ALGORITHM, key_text, salt,
                                KEY_ITERATION_COUNT, KEY_DERIVED_LENGTH)
        end
        module_function :generate_key

    end

end
