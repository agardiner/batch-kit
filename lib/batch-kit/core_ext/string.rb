class BatchKit

    module StringExtensions

        unless String.instance_methods.include?(:titleize)

            # A very simple #titleize method to capitalise the first letter of
            # each word, and replace underscores with spaces. Nowhere near as
            # powerful as ActiveSupport#titleize, so we only define it if no
            # existing #titleize method is found on String.
            def titleize
                self.gsub(/_/, ' ').gsub(/\b([a-z])/){ $1.upcase }
            end

        end


        # Convert a wildcard or regex string to a Regexp object
        # Useful for converting patterns supplied by a user into a Regexp object
        # to be used for comparisons. If a user supplies simple wildcards, these
        # are converted to Regexp equivalents (i.e. * -> .* and ? -> .). If 
        # commas are present, this is converted to an alternation regex.
        # If other punctuation is used, the pattern is assumed to be a regular
        # expression, and is converted as-is.
        def pattern_to_regex(regexp_options=nil)
            if self =~ /[\^$!\\+()]/
                Regexp.new("^#{self}$", regexp_options)
            else
                pat = self.split(',').map{ |pat| pat.gsub('*', '.*').gsub('?', '.') }.join('|')
                Regexp.new("^(#{pat})$", regexp_options)
            end
        end


        # Wraps the text in +self+ to lines no longer than +width+.
        #
        # The algorithm uses the following variables:
        #   - end_pos is the last non-space character in self
        #   - start is the position in self of the start of the next line to be
        #     processed.
        #   - nl_pos is the location of the next new-line character after start.
        #   - ws_pos is the location of the last space character between start and
        #     start + width.
        #   - wb_pos is the location of the last word-break character between start
        #     and start + width - 1.
        #
        # @param width [Fixnum] The maximum number of characters in each line.
        def wrap_text(width)
            if width > 0 && (self.length > width || self.index("\n"))
                lines = []
                start, nl_pos, ws_pos, wb_pos, end_pos = 0, 0, 0, 0, self.rindex(/[^\s]/)
                while start < end_pos
                    last_start = start
                    nl_pos = self.index("\n", start)
                    ws_pos = self.rindex(/ +/, start + width)
                    wb_pos = self.rindex(/[\-,.;#)}\]\/\\]/, start + width - 1)
                    ### Debug code ###
                    #STDERR.puts self
                    #ind = ' ' * end_pos
                    #ind[start] = '('
                    #ind[start+width < end_pos ? start+width : end_pos] = ']'
                    #ind[nl_pos] = 'n' if nl_pos
                    #ind[wb_pos] = 'b' if wb_pos
                    #ind[ws_pos] = 's' if ws_pos
                    #STDERR.puts ind
                    ### End debug code ###
                    if nl_pos && nl_pos <= start + width
                        lines << self[start...nl_pos].strip
                        start = nl_pos + 1
                    elsif end_pos < start + width
                        lines << self[start..end_pos]
                        start = end_pos
                    elsif ws_pos && ws_pos > start && ((wb_pos.nil? || ws_pos > wb_pos) ||
                          (wb_pos && wb_pos > 5 && wb_pos - 5 < ws_pos))
                        lines << self[start...ws_pos]
                        start = self.index(/[^\s]/, ws_pos + 1)
                    elsif wb_pos && wb_pos > start
                        lines << self[start..wb_pos]
                        start = wb_pos + 1
                    else
                        lines << self[start...(start+width)]
                        start += width
                    end
                    if start <= last_start
                        # Detect an infinite loop, and just return the original text
                        STDERR.puts "Inifinite loop detected at #{__FILE__}:#{__LINE__}"
                        STDERR.puts "  width: #{width}, start: #{start}, nl_pos: #{nl_pos}, " +
                                    "ws_pos: #{ws_pos}, wb_pos: #{wb_pos}"
                        return [self]
                    end
                end
                lines
            else
                [self]
            end
        end

    end

end


String.class_eval do
     include BatchKit::StringExtensions
end
