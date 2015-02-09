require 'digest'

class Batch

    class Database

        class MD5 < Sequel::Model(:batch_md5)

            # Locate the MD5 record for the object named +obj_name+ whose type
            # is +obj_type+.
            def self.for(obj_name, obj_type)
                self.where('UPPER(OBJECT_NAME) = ? AND UPPER(OBJECT_TYPE) = ?',
                           obj_name.upcase, obj_type.upcase).first
            end


            # Checks that the Batch database tables have been deployed and match
            # the table definitions in schema.rb.
            def self.check_schema(schema)
                schema_file = IO.read("#{File.dirname(__FILE__)}/schema.rb")
                ok, md5 = MD5.check('SCHEMA', 'schema.rb', schema_file)
                unless ok
                    # TODO: Find a better way to update schema for table changes;
                    #       This method throws away all history
                    schema.drop_tables
                    schema.create_tables
                    self.new('SCHEMA', 'schema.rb', schema_file).save
                end
            end


            # Checks to see if the recorded MD5 digest of +string+ matches the MD5
            # digest of +string+ as calculated by Digest::MD5.
            #
            # @return [Boolean, String] Returns three values in an array: a boolean
            #   indicating whether the digest value is the same, and the actual
            #   calculated value for the MD5 digest of +string+.
            def self.check(obj_type, obj_name, string)
                digest = Digest::MD5.hexdigest(string)
                md5 = self.for(obj_name, obj_type)
                puts md5.inspect
                if md5
                    puts "Found match"
                    puts md5.inspect
                    ok = digest == md5.md5_digest
                    md5.md5_digest = digest
                    [ok, md5]
                else
                    [nil, self.new(obj_name, obj_type, digest)]
                end
            end


            # Updates the MD5 digest for +obj_name+.
            def self.create_or_update(obj_type, obj_name, string, digest = nil)
                digest = Digest::MD5.hexdigest(string) unless digest
                md5_rec = MD5.where(object_name: obj_name.upcase, object_type: obj_type.upcase).first
                if md5_rec
                    @schema[:md5].update(md5_digest: digest).where(md5_id: md5_rec[:md5_id])
                else
                    @schema[:md5].insert(object_name: obj_name, object_type: obj_type, md5_digest: digest)
                end
            end


            def initialize(obj_type, obj_name, string, digest = nil)
                super(object_type: obj_type, object_name: obj_name,
                      md5_digest: digest || Digest::MD5.hexdigest(string))
            end


        end

    end

end
