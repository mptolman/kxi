import std.container;

class Stack(T)
{
private:
    DList!T dlist;

public:
    auto push(T t)
    {
        dlist.stableInsertFront(t);
    }

    auto pop()
    {
        dlist.stableRemoveFront();
    }

    auto top()
    {
        return dlist.front();
    }

    auto empty() const
    {
        return dlist.empty();
    }

    auto clear()
    {
        dlist.clear();
    }
}

class Queue(T)
{
private:
    DList!T dlist;

public:
    auto push(T t)
    {
        dlist.stableInsertBack(t);
    }

    auto pop()
    {
        dlist.stableRemoveFront();
    }

    auto front()
    {
        return dlist.front();
    }

    auto empty() const
    {
        return dlist.empty();
    }

    auto clear()
    {
        dlist.clear();
    }
}