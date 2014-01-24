import std.conv;

class Stack(T)
{
private:
    T[] _data;

public:
    void push(T t)
    {
        _data ~= t;
    }

    void pop()
    {
        assert(_data.length);
        _data = _data[0..$-1];
    }

    auto top()
    {
        assert(_data.length);
        return _data[$-1];
    }

    auto size()
    {
        return _data.length;
    }

    auto empty()
    {
        return _data.length == 0;
    }

    auto clear()
    {
        _data = null;
    }

    override string toString()
    {
        return text(_data);
    }
}

unittest {
    Stack!string s = new Stack!string();
    assert(s.size() == 0);
    assert(s.empty());
    s.push("one");
    assert(s.size() == 1);
    assert(s.top() == "one");
    assert(!s.empty());
    s.push("two");
    assert(s.size() == 2);
    assert(s.top() == "two");
    assert(!s.empty());
    s.pop();
    assert(s.size() == 1);
    assert(s.top() == "one");
    assert(!s.empty());
    s.pop();
    assert(s.empty());
    assert(s.size() == 0);
}