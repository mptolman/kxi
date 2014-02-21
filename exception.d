import std.conv;

class SyntaxError : Exception
{
    this(Args...)(size_t line, Args args)
    {
        super(text("(",line,"): ",args));
    }
}

class SemanticError : Exception
{
    this(Args...)(size_t line, Args args)
    {
        super(text("(",line,"): ",args));
    }
}