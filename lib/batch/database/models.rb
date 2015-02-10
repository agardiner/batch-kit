require 'digest'

class Batch

    class Database


        # Records an MD5 hash of String objects, which are used to detect when
        # items such as jobs have changed. This in turn is used to increment a
        # version number on objects.
        class MD5 < Sequel::Model(:batch_md5)

            # Locate the MD5 record for the object named +obj_name+ whose type
            # is +obj_type+.
            def self.for(obj_name, obj_type, digest)
                self.where('UPPER(OBJECT_NAME) = ? AND UPPER(OBJECT_TYPE) = ? AND MD5_DIGEST = ?',
                           obj_name.upcase, obj_type.upcase, digest).first
            end


            # Checks that the Batch database tables have been deployed and match
            # the table definitions in schema.rb.
            def self.check_schema(schema)
                schema_file = IO.read("#{File.dirname(__FILE__)}/schema.rb")
                ok, md5 = self.check('SCHEMA', 'schema.rb', schema_file)
                unless ok
                    # TODO: Find a better way to update schema for table changes;
                    #       This method throws away all history
                    schema.drop_tables
                    schema.create_tables
                    md5.save
                end
            end


            # Checks to see if the recorded MD5 digest of +string+ matches the MD5
            # digest of +string+ as calculated by Digest::MD5.
            #
            # @return [Boolean, String] Returns two values in an array: a boolean
            #   indicating whether the digest value is the same, and the actual
            #   calculated value for the MD5 digest of +string+.
            def self.check(obj_type, obj_name, string)
                digest = Digest::MD5.hexdigest(string)
                # Attempt to retrieve the MD5 for the schema; could fail if not deployed
                md5 = self.for(obj_name, obj_type, digest) rescue nil
                if md5
                    [true, md5]
                else
                    [nil, self.new(obj_type, obj_name, string, digest)]
                end
            end


            def initialize(obj_type, obj_name, string, digest = nil)
                obj_ver = self.class.where('UPPER(OBJECT_NAME) = ? AND UPPER(OBJECT_TYPE) = ?',
                           obj_name.upcase, obj_type.upcase).max(:object_version) || 0
                super(object_type: obj_type, object_name: obj_name,
                      object_version: obj_ver + 1,
                      md5_digest: digest || Digest::MD5.hexdigest(string))
            end

        end

    end

end
