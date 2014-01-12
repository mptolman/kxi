import std.conv;

Symbol[string] symbolTable;

enum SymbolType : byte
{
    CLASS,
    IVAR,
    LVAR,
    METHOD,
    PARAM
}

//struct Symbol
//{
//    string id;
//    SymbolType type;
//    string value;
//    string _scope;
//}

abstract class Symbol
{
    static size_t counter = 0;
    size_t id;
    string value;
    string _scope;
    string accessMod;

    this()
    {
        this.id = ++counter;
    }
}

abstract class SymVar : Symbol
{
    string type;
}

class LVar : SymVar {}
class Param : SymVar {}
class IVar : SymVar {}

class SymMethod : Symbol
{
    string returnType;
    string[] params;
}

auto generateSymId(T)(T prefix)
{
    static auto counter = 0;
    return text(prefix,++counter);
}