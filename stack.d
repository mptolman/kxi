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

    auto empty()
    {
        return _data.length == 0;
    }
}