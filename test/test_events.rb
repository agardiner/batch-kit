require 'test/unit'
require 'batch-kit/events'


class TestEvents < Test::Unit::TestCase

    module TestInclude; end

    class TestSource; include TestInclude; end

    
    def subscribe(src, event)
        BatchKit::Events.subscribe(src, event) do |source|
            @events[event] += 1
        end
    end


    def publish(src, event)
        BatchKit::Events.publish(src, event)
    end


    def test_receive_obj_of_class_events
        s = TestSource.new
        @events = Hash.new{ |h, k| h[k] = 0 }
        publish(s, 'a')
        assert_equal(0, @events['a'])
        subscribe(TestSource, 'a')
        publish(s, 'a')
        assert_equal(1, @events['a'])
        publish(s, 'b')
        assert_equal(1, @events['a'])
        assert_equal(0, @events['b'])
    end


    def test_receive_obj_of_module_events
        s = TestSource.new
        @events = Hash.new{ |h, k| h[k] = 0 }
        publish(s, 'a')
        assert_equal(0, @events['a'])
        subscribe(TestInclude, 'a')
        publish(s, 'a')
        assert_equal(1, @events['a'])
        publish(s, 'b')
        assert_equal(1, @events['a'])
        assert_equal(0, @events['b'])
    end


    def test_receive_class_of_class_events
        @events = Hash.new{ |h, k| h[k] = 0 }
        publish(TestSource, 'a')
        assert_equal(0, @events['a'])
        subscribe(TestSource, 'a')
        publish(TestSource, 'a')
        assert_equal(1, @events['a'])
        publish(TestSource, 'b')
        assert_equal(1, @events['a'])
        assert_equal(0, @events['b'])
    end


    def test_receive_class_of_module_events
        @events = Hash.new{ |h, k| h[k] = 0 }
        publish(TestSource, 'a')
        assert_equal(0, @events['a'])
        subscribe(TestInclude, 'a')
        publish(TestSource, 'a')
        assert_equal(1, @events['a'])
        publish(TestSource, 'b')
        assert_equal(1, @events['a'])
        assert_equal(0, @events['b'])
    end


    def test_receive_nil_source_events
        @events = Hash.new{ |h, k| h[k] = 0 }
        publish(TestSource, 'a')
        assert_equal(0, @events['a'])
        subscribe(nil, 'a')
        publish(TestSource, 'a')
        assert_equal(1, @events['a'])
        publish(TestInclude, 'a')
        assert_equal(2, @events['a'])
        publish(TestSource, 'b')
        assert_equal(0, @events['b'])
        publish(nil, 'a')
        assert_equal(3, @events['a'])
    end


end
