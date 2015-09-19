class Batch

    module Helpers

        # Defines helper methods for working with trees stored in parent/child,
        # form and in particular, adding visitation numbers to those trees to
        # support simplified querying for ancestors and descendants.
        module Tree

            # Takes an enumeration of +rows+, where fields of each row can be
            # accessed using #[] (e.g. Hash, Array). Iterates over the tree
            # (which must be ordered in left-most traversal order), calculating
            # and adding left and right visitation numbers.
            #
            # @param rows [Enumerable] A collection of rows representing the
            #   tree in order.
            # @param options [Hash] An options hash.
            # @option options [Object] :parent_col The accessor to use to obtain
            #   the parent value. May be a hash key, array index, or whatever
            #   type is needed to access the parent column from a row.
            # @option options [Object] :child_col The accessor to use to obtain
            #   the child value.
            # @option options [Object] :left_col The accessor to use to set the
            #   left column value on a row as it is visited.
            # @options options [Object] :right_col The accessor to use to set
            #   the right column value on a row once all its descendants have
            #   been visited.
            # @return [Enumerable] Returns the now updated +rows+ object.
            def calculate_visitation_numbers(rows, options = {})
                parent_col = options.fetch(:parent_col, 'PARENT')
                child_col = options.fetch(:child_col, 'CHILD')
                lvn_col = options.fetch(:left_col, 'LVN')
                rnv_col = options.fetch(:right_col, 'RVN')

                stack, vn = [], 0
                rows.each do |row|
                    while stack.size > 0 && row[parent_col] != stack.last[child_col]
                        p = stack.pop
                        p[rvn_col] = vn += 1
                    end
                    row[lvn_col] = vn += 1
                    stack << row
                end
                # Add RVNs for items remaining on the stack
                while p = stack.pop
                    p[rvn_col] = vn += 1
                end
                rows
            end

        end

    end

end
