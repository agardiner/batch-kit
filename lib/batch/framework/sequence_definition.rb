class Batch

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


            def to_s
                "<Batch::Sequence::Definition #{name}>"
            end

        end

    end

end
