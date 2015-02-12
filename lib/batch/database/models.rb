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
                    [md5.md5_id, md5]
                else
                    [nil, self.new(obj_type, obj_name, string, digest)]
                end
            end


            # Create a new MD5 hash of an object
            def initialize(obj_type, obj_name, string, digest = nil)
                obj_ver = self.class.where('UPPER(OBJECT_NAME) = ? AND UPPER(OBJECT_TYPE) = ?',
                           obj_name.upcase, obj_type.upcase).max(:object_version) || 0
                super(object_type: obj_type, object_name: obj_name,
                      object_version: obj_ver + 1,
                      md5_digest: digest || Digest::MD5.hexdigest(string),
                      md5_created_at: model.dataset.current_datetime)
            end

        end



        # Records details of job definitions
        class Job < Sequel::Model(:batch_job)

            many_to_one :md5, class: MD5, key: :job_file_md5_id

            plugin :timestamps, create: :job_created_at, update: :job_modified_at,
                update_on_create: true


            # Ensures that the job described by +job_def+ has been registered in
            # the batch database.
            def self.register(job_def)
                job = self.where(job_class: job_def.job_class.name,
                                 job_host: job_def.computer).first
                job_file = IO.read(job_def.file)
                ok, md5 = MD5.check('JOB', "//#{job_def.computer}/#{job_def.file}", job_file)
                md5.save unless ok
                if job
                    # Existing job
                    unless ok == job.job_file_md5_id
                        job.update(job_name: job_def.name, job_method: job_def.method_name,
                                   job_desc: job_def.description, job_file: job_def.file,
                                   job_version: md5.object_version, md5: md5)
                    end
                else
                    # New job
                    job = self.new(job_def, md5).save
                end
                job
            end


            def log
                @log ||= Batch::LogManager.logger('batch.job')
            end


            def initialize(job_def, md5)
                log.detail "Registering job '#{job_def.name}' on #{job_def.computer} in batch database"
                super(job_name: job_def.name, job_class: job_def.job_class.name,
                      job_method: job_def.method_name, job_desc: job_def.description,
                      job_host: job_def.computer, job_file: job_def.file,
                      job_version: md5.object_version, md5: md5,
                      job_run_count: 0, job_success_count: 0, job_fail_count: 0,
                      job_abort_count: 0, job_min_success_duration_ms: 0,
                      job_max_success_duration_ms: 0, job_mean_success_duration_ms: 0,
                      job_m2_success_duration_ms: 0)
            end

        end

    end

end
