
class Batch

    module Helpers

        # Methods for displaying times/durations
        module DateTime

            # Converts the elapsed time in seconds to a string showing days, hours,
            # minutes and seconds.
            def display_duration(elapsed)
                return nil unless elapsed
                elapsed = elapsed.round
                display = ''
                [['days', 86400], ['h', 3600], ['m', 60], ['s', 1]].each do |int, seg|
                    if elapsed >= seg
                        count, elapsed = elapsed.divmod(seg)
                        display << "#{count}#{int.length > 1 && count == 1 ? int[0..-2] : int} "
                    elsif display.length > 0
                        display << "0#{int}"
                    end
                end
                display = "0s" if display == ''
                display.strip
            end


            # Displays a date/time in abbreviated format, suppressing elements of
            # the format string for more recent dates/times.
            #
            # @param ts [Time, Date, DateTime] The date/time object to be displayed
            # @return [String] A formatted representation of the date/time.
            def display_timestamp(ts)
                return unless ts
                ts_date = ts.to_date
                today = Date.today
                if today - ts_date < 7
                    # Date is within the last week
                    ts.strftime('%a %H:%M:%S')
                elsif today.year != ts.year
                    # Data is from a different year
                    ts.strftime('%a %b %d %Y %H:%M:%S')
                else
                    ts.strftime('%a %b %d %H:%M:%S')
                end
            end

        end

    end

end
