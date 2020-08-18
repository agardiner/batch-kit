class BatchKit

    class Sequence

        # Captures details about a sequence definition: the jobs contained,
        # order of execution, etc.
        class Definition < Definable

            add_properties(
                # Properties from job/task declarations
                :sequence_class, :method_name, :computer, :file, :do_not_track, :jobs,
                # Properties required by persistence layer
                :sequence_id, :sequence_version
            )


            def initialize(sequence_class, sequence_file, sequence_name = nil)
                raise ArgumentError, "sequence_class must be a Class" unless sequence_class.is_a?(Class)
                @sequence_class = sequence_class
                @file = sequence_file
                @name = sequence_name || sequence_class.name.gsub(/([^A-Z ])([A-Z])/, '\1 \2').
                    gsub(/_/, ' ').gsub('::', ':').gsub(/\b([a-z])/) { $1.upcase }
                @computer = Socket.gethostname
                @method_name = nil
                @tasks = {}
                super()
            end


            # Define a sequence method - the method to be run to trigger the execution
            # of the sequence.
            #
            # @param mthd_name [Symbol] The name of a method on the sequence class
            #   that is executed to begin the sequence processing. Note: This method
            #   must already exist on the sequence class when this setter is called, so
            #   that it can be wrapped in an aspect with before/after processing.
            def method_name=(mthd_name)
                unless sequence_class.instance_methods.include?(mthd_name)
                    raise ArgumentError, "Sequence class #{sequence_class.name} does not define a ##{mthd_name} method"
                end
                if @method_name
                    raise "Sequence class #{sequence_class.name} already has a sequence method defined (##{@method_name})"
                end
                @method_name = mthd_name

                # Add an aspect for executing sequence
                add_aspect(sequence_class, mthd_name)
            end


            # Create a new Sequence::Run object for a run of this sequence.
            #
            # @param seq_obj [Object] The sequence object that is running this sequence.
            # @param args [Array<Object>] The arguments passed to the sequence method.
            def create_run(seq_obj, *args)
                seq_run = Sequence::Run.new(self, seq_obj, *args)
                @runs << seq_run
                seq_run
            end


            def to_s
                "<BatchKit::Sequence::Definition #{name}>"
            end

        end

    end

end
