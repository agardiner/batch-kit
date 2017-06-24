class Batch

    # Defines a class for managing configuration properties; essentially, this
    # is a hash that is case and Strng/Symbol insensitive with respect to keys;
    # this means a value can be retrieved using any mix of case using either a
    # String or Symbol as the lookup key.
    #
    # In addition, there are some further conveniences added on:
    # - Items can be accessed by either [] (using a String or Symbol key) or as
    #   methods on the Config object, i.e. the following are all equivalent:
    #
    #     config['Foo']
    #     config[:foo]
    #     config.foo
    #
    # - Contents can be loaded from:
    #   - an existing Hash object
    #   - a properties file using [Section] and KEY=VALUE syntax
    #   - a YAML file
    # - String values can contain placeholder variables that will be replaced
    #   when the item is added to the Config collection. Placeholder variables
    #   are denoted by ${<variable>} or %{<variable>} syntax, where <variable>
    #   is the name of another configuration variable or a key in a supplied
    #   expansion properties hash.
    # - Support for encrypted values. These are decrypted on the fly, provided
    #   a decryption key has been set on the Config object.
    #
    # Internally, the case and String/Symbol insensitivity is managed by
    # maintaining a second Hash that converts the lower-cased symbol value
    # of all keys to the actual keys used to store the object. When looking up
    # a value, we use this lookup Hash to find the actual key used, and then
    # lookup the value.
    #
    # @note As this Config object is case and String/Symbol insensitive,
    #   different case and type keys that convert to the same lookup key are
    #   considered the same. The practical implication is that you can't have
    #   two different values in this Config object where the keys differ only
    #   in case and/or String/Symbol class.
    class Config < Hash

        # Create a new Config object, and initialize it from the specified
        # +file+.
        #
        # @param file [String] A path to a properties or YAML file to load.
        # @param props [Hash, Config] An optional Hash (or Config) object to
        #   seed this Config object with.
        # @param options [Hash] An options hash.
        # @option options [Boolean] :raise_on_unknown_var Whether to raise an
        #   error if an unrecognised placeholder variable is encountered in the
        #   file.
        # @option options [Boolean] :use_erb If true, the contents of +file+
        #   is first run through ERB.
        # @option options [Binding] :binding The binding to use when evaluating
        #   expressions in ERB
        # @return [Config] A new Config object populated from +file+ and
        #   +props+, where placeholder variables have been expanded.
        def self.load(file, props = nil, options = {})
            cfg = self.new(props, options)
            cfg.load(file, options)
            cfg
        end


        # Converts a +str+ in the form of a properties file into a Hash.
        def self.properties_to_hash(str)
            hsh = props = {}
            str.each_line do |line|
                line.chomp!
                if match = /^\s*\[([A-Za-z0-9_ ]+)\]\s*$/.match(line)
                    # Section heading
                    props = hsh[match[1]] = {}
                elsif match = /^\s*([A-Za-z0-9_\.]+)\s*=\s*([^#]+)/.match(line)
                    # Property setting
                    val = match[2]
                    props[match[1]] = case val
                    when /^\d+$/ then val.to_i
                    when /^\d*\.\d+$/ then val.to_f
                    when /^:/ then val.intern
                    when /false/i then false
                    when /true/i then true
                    else val
                    end
                end
            end
            hsh
        end


        # Expand any ${<variable>} or %{<variable>} placeholders in +str+ from
        # either the supplied +props+ hash or the system environment variables.
        # The props hash is assumed to contain string or symbol keys matching the
        # variable name between ${ and } (or %{ and }) delimiters.
        # If no match is found in the supplied props hash or the environment, the
        # default behaviour returns the string with the placeholder variable still in
        # place, but this behaviour can be overridden to cause an exception to be
        # raised if desired.
        #
        # @param str [String] A String to be expanded from 0 or more placeholder
        #   substitutions
        # @param properties [Hash, Array<Hash>] A properties Hash or array of Hashes
        #   from which placeholder variable values can be looked up.
        # @param raise_on_unknown_var [Boolean] Whether or not an exception should
        #   be raised if no property is found for a placeholder expression. If false,
        #   unrecognised placeholder variables are left in the returned string.
        # @return [String] A new string with placeholder variables replaced by
        #   the values in +props+.
        def self.expand_placeholders(str, properties, raise_on_unknown_var = false)
            chain = properties.is_a?(Hash) ? [properties] : properties.reverse
            str.gsub(/(?:[$%])\{([a-zA-Z0-9_]+)\}/) do
                case
                when src = chain.find{ |props| props.has_key?($1) } then src[$1]
                when src = chain.find{ |props| props.has_key?($1.intern) } then src[$1.intern]
                when src = chain.find{ |props| props.has_key?($1.downcase.intern) } then src[$1.downcase.intern]
                when ENV[$1] then ENV[$1]
                when raise_on_unknown_var
                    raise KeyError, "No value supplied for placeholder variable '#{$&}'"
                else
                    $&
                end
            end
        end


        # Create a Config object, optionally initialized from +hsh+.
        #
        # @param hsh [Hash] An optional Hash to seed this Config object with.
        # @param options [Hash] An options hash.
        def initialize(hsh = nil, options = {})
            super(nil)
            @lookup_keys = {}
            @decryption_key = nil
            merge!(hsh, options) if hsh
        end


        # Read a properties or YAML file at the path specified in +path+, and
        # load the contents to this Config object.
        #
        # @param path [String] The path to the properties or YAML file to be
        #   loaded.
        # @param options [Hash] An options hash.
        # @option options [Boolean] @raise_on_unknown_var Whether to raise an
        #   error if an unrecognised placeholder variable is encountered in the
        #   file.
        def load(path, options = {})
            props = case File.extname(path)
            when /\.yaml/i then self.load_yaml(path, options)
            else self.load_properties(path, options)
            end
        end


        # Process a property file, returning its contents as a Hash.
        # Only lines of the form KEY=VALUE are processed, and # indicates the start
        # of a comment. Property files can contain sections, denoted by [SECTION].
        #
        # @example
        #   If a properties file contains the following:
        #
        #     FOO=Bar             # This is a comment
        #     BAR=${FOO}\Baz
        #
        #     [BAT]
        #     Car=Ford
        #
        #   Then we would return a Config object containing the following:
        #
        #     {'FOO' => 'Bar', 'BAR' => 'Bar\Baz', 'BAT' => {'Car' => 'Ford'}}
        #
        #   This config content could be accessed via #[] or as properties of
        #   the Config object, e.g.
        #
        #     cfg[:foo]    # => 'Bar'
        #     cfg.bar      # => 'Bar\Baz'
        #     cfg.bat.car  # => 'Ford'
        #
        # @param prop_file [String] A path to the properties file to be parsed.
        # @param options [Hash] An options hash.
        # @option options [Boolean] :use_erb If true, the contents of +prop_file+
        #   is first passed through ERB before being processed. This allows for
        #   the use of <% %> and <%= %> directives in +prop_file+. The binding
        #   passed to ERB is the value of any :binding option specified, or else
        #   this Config object. If not specified, ERB is used if the file is
        #   found to contain the string '<%'.
        # @option options [Binding] :binding The binding for ERB to use when
        #   processing expressions. Defaults to this Config instance if not
        #   specified.
        # @return [Hash] The parsed contents of the file as a Hash.
        def load_properties(prop_file, options = {})
            str = read_file(prop_file, options)
            hsh = self.class.properties_to_hash(str)
            self.merge!(hsh, options)
        end


        # Load the YAML file at +yaml_file+.
        #
        # @param yaml_file [String] A path to a YAML file to be loaded.
        # @param options [Hash] An options hash.
        # @option options [Boolean] :use_erb If true, the contents of +yaml_file+
        #   are run through ERB before being parsed as YAML. This allows for use
        #   of <% %> and <%= %> directives in +yaml_file+. The binding passed to
        #   ERB is the value of any :binding option specified, or else this
        #   Config object. If not specified, ERB is used if the file is found to
        #   contain the string '<%'.
        # @option options [Binding] :binding The binding for ERB to use when
        #   processing expressions. Defaults to this Config instance if not
        #   specified.
        # @return [Object] The results of parsing the YAML contents of +yaml_file+.
        def load_yaml(yaml_file, options = {})
            require 'yaml'
            str = read_file(yaml_file, options)
            yaml = YAML.load(str)
            self.merge!(yaml, options)
        end


        # Save this config object as a YAML file at +yaml_file+.
        #
        # @param yaml_file [String] A path to the YAML file to be saved.
        # @param options [Hash] An options hash.
        def save_yaml(yaml_file, options = {})
            require 'yaml'
            str = self.to_yaml
            File.open(yaml_file, 'wb'){ |f| f.puts(str) }
        end


        # Merge the contents of the specified +hsh+ into this Config object.
        #
        # @param hsh [Hash] The Hash object to merge into this Config object.
        # @param options [Hash] An options hash.
        # @option options [Boolean] :raise_on_unknown_var Whether to raise an
        #   exception if an unrecognised placeholder variable is encountered in
        #   +hsh+.
        def merge!(hsh, options = {})
            if hsh && !hsh.is_a?(Hash)
                raise ArgumentError, "Only Hash objects can be merged into Config (got #{hsh.class.name})"
            end
            hsh && hsh.each do |key, val|
                self[key] = convert_val(val, options[:raise_on_unknown_var])
            end
            if hsh.is_a?(Config)
                @decryption_key = hsh.instance_variable_get(:@decryption_key) unless @decryption_key
            end
            self
        end


        # Merge the contents of the specified +hsh+ into a new Config object.
        #
        # @param hsh [Hash] The Hash object to merge with this Config object.
        # @param options [Hash] An options hash.
        # @option options [Boolean] @raise_on_unknown_var Whether to raise an
        #   error if an unrecognised placeholder variable is encountered in the
        #   file.
        # @return A new Config object with the combined contents of this Config
        #   object plus the contents of +hsh+.
        def merge(hsh, options = {})
            cfg = self.dup
            cfg.merge!(hsh, options)
            cfg
        end


        # If set, encrypted strings (only) will be decrypted when accessed via
        # #[] or #method_missing (for property-like access, e.g. +cfg.password+).
        #
        # @param key [String] The master encryption key used to encrypt sensitive
        #   values in this Config object.
        def decryption_key=(key)
            require_relative 'encryption'
            self.each do |_, val|
                val.decryption_key = key if val.is_a?(Config)
            end
            @decryption_key = key
        end
        alias_method :encryption_key=, :decryption_key=


        # Recursively encrypts the values of all keys in this Config object that
        # match +key_pat+.
        #
        # Note: +key_pat+ will be compared against the standardised key values of
        # each object (i.e. lowercase, with spaces converted to _).
        #
        # @param key_pat [Regexp|String] A regular expression to be used to identify
        #   the keys that should be encrypted, e.g. /password/ would encrypt all
        #   values that have "password" in their key.
        # @param master_key [String] The master key that should be used when
        #   encrypting. If not specified, uses the current value of the
        #   +decryption_key+ set for this Config object.
        def encrypt(key_pat, master_key = @decryption_key)
            key_pat = Regexp.new(key_pat, true) if key_pat.is_a?(String)
            raise ArgumentError, "key_pat must be a Regexp or String" unless key_pat.is_a?(Regexp)
            raise ArgumentError, "No master key has been set or passed" unless master_key
            require_relative 'encryption'
            self.each do |key, val|
                if Config === val
                    val.encrypt(key_pat, master_key)
                else
                    if @decryption_key && val.is_a?(String) && val =~ /!AES:([a-zA-Z0-9\/+=]+)!/
                        # Decrypt using old master key
                        val = self[key]
                        self[key] = val
                    end
                    if val.is_a?(String) && convert_key(key) =~ key_pat
                        self[key] = "!AES:#{Encryption.encrypt(master_key, val).strip}!"
                    end
                end
            end
            @decryption_key = master_key
        end


        # Override #[] to be agnostic as to the case of the key, and whether it
        # is a String or a Symbol.
        def [](key)
            key = @lookup_keys[convert_key(key)]
            val = super(key)
            if @decryption_key && val.is_a?(String) && val =~ /!AES:([a-zA-Z0-9\/+=]+)!/
                begin
                    val = Encryption.decrypt(@decryption_key, $1)
                rescue Exception => ex
                    raise ex.class, "An error occurred while decrypting the value for key '#{key}': #{ex.message}"
                end
            end
            val
        end


        # Override #[]= to be agnostic as to the case of the key, and whether it
        # is a String or a Symbol.
        def []=(key, val)
            std_key = convert_key(key)
            if @lookup_keys[std_key] != key
                delete(key)
                @lookup_keys[std_key] = key
            end
            super key, val
        end


        # Override #delete to be agnostic as to the case of the key, and whether
        # it is a String or a Symbol.
        def delete(key)
            key = @lookup_keys.delete(convert_key(key))
            super key
        end


        # Override #has_key? to be agnostic as to the case of the key, and whether
        # it is a String or a Symbol.
        def has_key?(key)
            key = @lookup_keys[convert_key(key)]
            super key
        end
        alias_method :include?, :has_key?


        # Override #fetch to be agnostic as to the case of the key, and whether it
        # is a String or a Symbol.
        def fetch(key, *rest)
            key = @lookup_keys[convert_key(key)] || key
            super
        end


        # Override #clone to also clone contents of @lookup_keys.
        def clone
            copy = super
            copy.instance_variable_set(:@lookup_keys, @lookup_keys.clone)
            copy
        end


        # Override #dup to also clone contents of @lookup_keys.
        def dup
            copy = super
            copy.instance_variable_set(:@lookup_keys, @lookup_keys.dup)
            copy
        end


        # Override Hash core extension method #to_cfg and just return self.
        def to_cfg
            self
        end


        # Override method_missing to respond to method calls with the value of the
        # property, if this Config object contains a property of the same name.
        def method_missing(name, *args)
            if name =~ /^(.+)\?$/
                has_key?($1)
            elsif has_key?(name)
                self[name]
            elsif has_key?(name.to_s.gsub('_', ''))
                self[name.to_s.gsub('_', '')]
            elsif name =~ /^(.+)=$/
                self[$1]= args.first
            else
                raise ArgumentError, "No configuration entry for key '#{name}'"
            end
        end


        # Override respond_to? to indicate which methods we will accept.
        def respond_to?(name)
            if name =~ /^(.+)\?$/
                has_key?($1)
            elsif has_key?(name)
                true
            elsif has_key?(name.to_s.gsub('_', ''))
                true
            elsif name =~ /^(.+)=$/
                true
            else
                super
            end
        end


        # Expand any ${<variable>} or %{<variable>} placeholders in +str+ from
        # this Config object or the system environment variables.
        # This Config object is assumed to contain string or symbol keys matching
        # the variable name between ${ and } (or %{ and }) delimiters.
        # If no match is found in the supplied props hash or the environment, the
        # default behaviour is to raise an exception, but this can be overriden
        # to leave the placeholder variable still in place if desired.
        #
        # @param str [String] A String to be expanded from 0 or more placeholder
        #   substitutions
        # @param raise_on_unknown_var [Boolean] Whether or not an exception should
        #   be raised if no property is found for a placeholder expression. If false,
        #   unrecognised placeholder variables are left in the returned string.
        # @return [String] A new string with placeholder variables replaced by
        #   the values in +props+.
        def expand_placeholders(str, raise_on_unknown_var = true)
            self.class.expand_placeholders(str, self, raise_on_unknown_var)
        end


        # Reads a template file at +template_name+, and expands any substitution
        # variable placeholder strings from this Config object.
        #
        # @param template_name [String] The path to the template file containing
        #   placeholder variables to expand from this Config object.
        # @return [String] The contents of the template file with placeholder
        #   variables replaced by the content of this Config object.
        def read_template(template_name, raise_on_unknown_var = true)
            template = IO.read(template_name)
            expand_placeholders(template, raise_on_unknown_var)
        end


        private


        # Reads the contents of +file+ into a String. The +file+ is passed
        # through ERB if the :use_erb option is true, or if the options does
        # not contain the :use_erb key and the file does contain the string
        # '<%'.
        def read_file(file, options)
            str = IO.read(file)
            if (options.has_key?(:use_erb) && options[:use_erb]) || str =~ /<%/
                require 'erb'
                str = ERB.new(str).result(options[:binding] || binding)
            end
            str
        end


        # Convert the supplied key to a lower-case symbol representation, which
        # is the key to the @lookup_keys hash.
        def convert_key(key)
            key.to_s.downcase.gsub(' ', '_').intern
        end


        # Convert a value before merging it into the Config. This consists of
        # these tasks:
        #   - Converting Hashes to Config objects
        #   - Propogating decryption keys to child Config objects
        #   - Expanding placeholder variables in strings
        def convert_val(val, raise_on_unknown_var, parents = [self])
            case val
            when Config then val
            when Hash
                cfg = Config.new
                cfg.instance_variable_set(:@decryption_key, @decryption_key)
                new_parents = parents.clone
                new_parents << cfg
                val.each do |k, v|
                    cfg[k] = convert_val(v, raise_on_unknown_var, new_parents)
                end
                cfg
            when Array
                val.map{ |v| convert_val(v, raise_on_unknown_var, parents) }
            when /[$%]\{[a-zA-Z0-9_]+\}/
                self.class.expand_placeholders(val, parents, raise_on_unknown_var)
            else val
            end
        end

    end

end

