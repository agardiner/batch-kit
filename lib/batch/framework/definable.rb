class Batch

    # Captures details of a definable batch process, e.g. a Task or Job.
    class Definable

        class << self

            # Register additional properties to be recorded on this definable.
            def add_properties(*props)
                attr_accessor *props
                properties.concat(props)
            end

            # @return the names of properties available on this definition.
            def properties
                @properties ||= []
            end

            # When this class is inherited, we need to copy the common property
            # names into the sub-class, since each sub-class needs the common
            # property names defined on this base class, as well as any sub-
            # class specific properties.
            def inherited(subclass)
                subclass.instance_variable_set(:@properties, @properties.clone)
            end

        end


        # @!attribute :name [String] A user-friendly name for this process.
        # @!attribute :description [String] A short description of what this
        #   process does.
        # @!attribute :instance_expr [String] An optional expression used to
        #   assign an instance identifier to a process.
        #   An instance identifier allows a process that has different execution
        #   profiles (typically depending on the arguments it is run with)
        #   to identify which of those profiles it is executing. This expression
        #   will be evaluated at the time this process is invoked, and the
        #   result will become the instance identifier for the Runnable.
        # @!attribute :runs [Array<Runnable>] Array of runs of this process.
        #
        # @!attribute :lock_name [String] The name of any lock that this
        #   process requires before it can proceed. If nil, no lock is
        #   required and the process can commence without any co-ordination
        #   with other processes.
        # @!attribute :lock_timeout [Fixnum] Number of seconds after which a
        #   lock obtained by this process will expire. This is to ensure that
        #   locks don't remain indefinitely if a process fails to release the
        #   lock properly. As such, it should be longer than any reasonable
        #   run of this process is likely to take, but no longer.
        # @!attribute :lock_wait_timeout [Fixnum] Number of seconds before
        #   this process will give up waiting for a lock to become available.
        add_properties(:name, :description, :instance_expr, :runs,
            :lock, :lock_timeout, :lock_wait_timeout
        )


        # Create a new instance of this definition.
        def initialize
            @runs = []
        end


        # Sets job properties from an options hash.
        #
        # @param opts [Hash] A hash containing job properties to be set on
        #   this job.
        def set_from_options(opts)
            unknown = opts.keys - self.class.properties
            if unknown.size > 0
                raise ArgumentError, "The following option(s) are invalid for #{
                    self.class.name}: #{unknown.join(', ')}. Valid options are: #{
                    self.class.properties.join(', ')}"
            end
            self.class.properties.each do |prop|
                if opts.has_key?(prop)
                    self.send("#{prop}=", opts[prop])
                end
            end
        end


        # Adds an aspect (as in aspect-oriented programming, or AOP) around the
        # existing instance method +mthd_name+ on +tgt_class+. The aspect does
        # the following:
        # - Calls the #pre_execute method with the object instance on which the
        #   aspect method is being invoked. If the #pre_execute method returns
        #   false, the method call is skipped; otherwise, proceeds to the next
        #   step.
        # - Calls the #around_execute method, which must yield back at the point
        #   at which the wrapped method body should be invoked.
        # - Calls the #post_execute method with a boolean OK indicator, and the
        #   result of the method (if OK) or the exception it threw (if not OK).
        #
        # @param tgt_class [Class] The class on which the method to be wrapped
        #   is defined.
        # @param mthd_name [Symbol] The name of the instance method to be
        #   wrapped.
        def add_aspect(tgt_class, mthd_name)
            defn = self
            mthd = tgt_class.instance_method(mthd_name)
            tgt_class.class_eval do
                define_method mthd_name do |*args, &block|
                    if defn.pre_execute(self, *args)
                        ok = true
                        result = nil
                        run = defn.create_run(self, *args)
                        begin
                            defn.around_execute(run) do
                                result = mthd.bind(self).call(*args, &block)
                            end
                            result
                        rescue Exception => ex
                            ok = false
                            run.exception = result = ex
                            raise
                        ensure
                            defn.post_execute(ok, result)
                        end
                    end
                end
            end
        end


        def create_run(process_obj, *args)
            raise "Not implemented in #{self.class.name}"
        end


        def pre_execute(process_obj, *args)
            true
        end


        def around_execute(run)
            #Batch.lock(job_run, lock_name, lock_timeout, wait_timeout) if lock_name
            #begin
            run.around_execute{ yield }
            #ensure
            #    Batch.unlock(job_run, lock_name) if lock_name
            #end
        end


        def post_execute(ok, result)
        end

    end

end

