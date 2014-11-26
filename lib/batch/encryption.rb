if Ruby.platform =~ /java/
    # JRuby OpenSSL support does not include the PKCS5 module, so we use the
    # built-in Java crypto classes instead
    require_relative 'encryption/java_encryption'
else
    require_relative 'encryption/ruby_encryption'
end
