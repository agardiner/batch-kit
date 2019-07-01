class BatchKit

    module Sequence

        # Captures details of an execution of a task.
        class Run < Runnable

            # @return [Fixnum] An integer identifier that uniquely identifies
            #    this task run.
            attr_accessor :sequence_run_id

            # Make Task::Defintion properties accessible off this Task::Run.
            add_delegated_properties(*Sequence::Definition.properties)


            # Create a new sequence run.
            #
            # @param task_def [Sequence::Definition] The Sequence::Definition to
            #   which this run relates.
            # @param job_object [Object] The job object instance from which the
            #   sequence is being executed.
            # @param run_args [Array<Object>] An array of the argument values
            #   passed to the sequence method.
            def initialize(seq_def, job_object, *run_args)
                raise ArgumentError, "seq_def not a Sequence::Definition" unless seq_def.is_a?(Sequence::Definition)
                super(seq_def, job_object, run_args)
            end


            # @return [Boolean] True if this sequence run should be persisted in
            #   any persistence layer.
            def persist?
                !definition.do_not_track
            end


            # @return [String] A short representation of this Sequence::Run.
            def to_s
                "<BatchKit::Sequence::Run label='#{label}'>"
            end

        end

    end

end


