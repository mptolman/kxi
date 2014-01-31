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

    auto size() const
    {
        return _data.length;
    }

    auto empty() const
    {
        return _data.length == 0;
    }

    auto clear()
    {
        _data = null;
    }
}

class Queue(T)
{
private:
    T[] data;

public:
    void push(T t)
    {
        data ~= t;
    }

    void pop()
    {
        assert(data.length);
        data = data[1..$];      
    }

    auto front()
    {
        assert(data.length);
        return data[0];
    }

    auto size() const
    {
        return data.length;
    }    

    auto empty() const
    {
        return data.length == 0;
    }

    void clear()
    {
        data = null;
    }
}