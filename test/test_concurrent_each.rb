require 'batch/core_ext/enumerable'


(0...50).concurrent_each(threads: 8) do |i|
    print "#{i}."
    sleep 1
    puts
end
