class Batch

    # When included into a class, marks the class as a Batch sequence.
    # The including class has the following class methods added, which act as a
    # DSL for specifying the sequence properties and behaviour:
    # - {ClassMethods#desc desc} A method for setting a description for a
    #   subsequent sequence
    # - {ClassMethods#sequence sequence} Defines a sequence entry method
    # - {ClassMethods#sequence_definition sequence_definition} Returns the
    #   Sequence::Definition object for the including class
    # - {ClassMethods#on_success on_success} defines a callback to be called if
    #   the sequence completes successfully.
    # - {ClassMethods#on_failure on_failure} defines a callback to be called if
    #   the sequence encounters an unhandled exception.
    #
    # Instances of the including class also get the following instance methods:
    # - {#sequence} Returns the Sequence::Definition for the class
    # - {#sequence_run} Returns the Sequence::Run associated with this object instance.
    module ActsAsSequence

        # Define methods to be added to the class that includes this module.
        module ClassMethods

            # @return The Sequence::Definition object used to hold attributes of this
            #   sequence.
            def sequence_definition
                @__sequence__
            end
            alias_method :definition, :sequence_definition


            # Captures a description for the following sequence definition.
            #
            # @param desc [String] The description to associate with the next
            #   sequence, job, or task that is defined.
            def desc(desc)
                @__desc__ = desc
            end


            # Defines the method that is used to run this job.
            # This may be an existing method, in which case the name of the
            # method must be passed as the first argument.
            # Alternatively, a block may be supplied, which will be used to
            # create the job method.
            #
            # @param sequence_method [Symbol] The name of an existing method that is
            #   to be the sequence entry point.
            # @param sequence_opts [Hash] Options that affect the sequence definition.
            # @option sequence_opts [Symbol] :method_name The name to be assigned to
            #   the sequence method created from the supplied block. Default is
            #   :execute.
            # @option sequence_opts [String] :description A description for the sequence.
            def sequence(sequence_method = nil, sequence_opts = @__desc__, &body)
                # If called as an accessor, just return the @__sequence__
                if  sequence_method || sequence_opts || body
                    unless sequence_method.is_a?(Symbol)
                        sequence_opts = sequence_method
                        sequence_method = (sequence_opts && sequence_opts.is_a?(Hash) &&
                            sequence_opts[:method_name]) || :execute
                    end

                    sequence_desc = nil
                    if sequence_opts.is_a?(Hash)
                        sequence_desc = @__desc__
                    elsif sequence_opts.is_a?(String)
                        sequence_desc = sequence_opts
                        sequence_opts = {}
                    elsif sequence_opts.nil?
                        sequence_opts = {}
                    end
                    @__desc__ = nil

                    # Define sequence method if a body block was supplied
                    define_method(sequence_method, &body) if body

                    opts = sequence_opts.clone
                    opts[:description] = sequence_desc unless opts[:description]
                    opts[:method_name] = sequence_method
                    # The @__sequence__ instance variable is crated when this module is included
                    @__sequence__.set_from_options(opts)
                end
                @__sequence__
            end

        end


        # Hook used to extend the including class with class methods defined in
        # the ActsAsSequence::ClassMethods module.
        #
        # Creates a Sequence::Definition object to hold details of the sequence,
        # and stores it away in a @__sequence__ class instance variable.
        def self.included(base)
            base.extend(ClassMethods)
            caller.find{ |f| !(f =~ /batch.framework/) } =~ /^((?:[a-zA-Z]:)?[^:]+)/
            sequence_file = File.realpath($1)
            sequence_defn = Sequence::Definition.new(base, sequence_file)
            base.instance_variable_set :@__sequence__, sequence_defn
        end


        def parallel
            # TODO: Implement running contents of block in parallel
            yield
        end


        # @return [Sequence::Definition] The SequenceDefinition for this Sequence instance.
        def sequence
            self.class.sequence_definition
        end


        # @return [Sequence::Run] The SequenceRun for this Sequence instance.
        def sequence_run
            @__sequence_run__
        end

    end

end

