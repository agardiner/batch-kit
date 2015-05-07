require 'test/unit'
require 'batch/lockable'



class TestLocking < Test::Unit::TestCase

    include Batch::Lockable


    def setup
        @locks = {}
        Batch::Events.subscribe(self, 'lock?') do |requestor, lock_name, lock_timeout|
            #puts "Lock request received for #{lock_name}"
            if @locks[lock_name] == nil || @locks[lock_name][:expires] < Time.now
                @locks[lock_name] = {holder: requestor, expires: Time.now + lock_timeout}
            end
        end
        Batch::Events.subscribe(self, 'unlock?') do |requestor, lock_name|
            #puts "Unlock request received for #{lock_name}"
            assert_equal(requestor, @locks[lock_name][:holder])
            @locks.delete(lock_name)
        end
    end


    def teardown
        Batch::Events.unsubscribe(self, 'lock?')
        Batch::Events.unsubscribe(self, 'unlock?')
    end


    def test_no_lock_manager
        teardown
        lock('test_no_lock_manager', 3)
        assert_equal(0, @locks.size)
        ran = false
        with_lock('test_with_lock_no_lock_manager', 3) do
            ran = true
        end
        assert(ran)
        unlock('test_no_lock_manager')
    end


    def test_lock_when_available
        lock('test_lock', 3)
        assert_equal(1, @locks.size)
        unlock('test_lock')
        assert_equal(0, @locks.size)
    end


    def test_wait_timeout
        lock('test_wait_timeout', 5)
        assert_raises(Timeout::Error) do
            lock('test_wait_timeout', 1, 1)
        end
    end


    def test_lock_timeout
        lock('test_lock_timeout', 1)
        sleep 2
        lock('test_lock_timeout', 5)
        assert_equal(1, @locks.size)
    end


    def test_with_lock
        ran = false
        assert_raises(ArgumentError) do
            with_lock('with_lock', 5) do
                ran = true
                assert_equal(1, @locks.size)
                raise ArgumentError
            end
        end
        assert(ran)
        assert_equal(0, @locks.size)
    end

end
