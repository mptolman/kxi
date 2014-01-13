import std.conv;

Symbol[string] symbolTable;

//enum SymbolType : byte
//{
//    CLASS,
//    IVAR,
//    LVAR,
//    METHOD,
//    PARAM
//}

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
    string id;
    string value;
    string scop;
    string accessMod;

    this(string prefix)
    {
        this.id = text(prefix,++counter);
    }
}

class ClassSymbol : Symbol
{
    this() { super("C"); }
}

class MethodSymbol : Symbol
{
    string returnType;
    string[] params;

    this() { super("M"); }
}


abstract class VarSymbol : Symbol
{
    string type;

    this(string prefix) { super(prefix); }
}

class LVarSymbol : VarSymbol
{
    this() { super("L"); }
}
class ParamSymbol : VarSymbol
{
    this() { super("P"); }
}
class IVarSymbol : VarSymbol
{
    this() { super("V"); }
}


