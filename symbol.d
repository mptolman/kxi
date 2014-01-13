import std.conv;
import std.stdio;

immutable PUBLIC_MODIFIER = "public";
immutable PRIVATE_MODIFIER = "private";

struct SymbolTable
{
private:
    static Symbol[string] _table;

public:
    static void add(Symbol s)
    {
        _table[s.id] = s;
    }

    static auto get(string id)
    {
        return _table[id];
    }

    static void print()
    {
        foreach (s;  _table)
            writeln(s.id,": ",s.value," [",s.modifier,"]");
    }
}

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
    string modifier;

    this(string prefix, string value, string modifier)
    {
        this.id = text(prefix,++counter);
        this.value = value;
        this.modifier = modifier;
    }
}

class ClassSymbol : Symbol
{
    this(string className)
    {
        super("C",className,PUBLIC_MODIFIER);
    }
}

class MethodSymbol : Symbol
{
    string returnType;
    string[] params;

    this(string methodName, string returnType, string modifier)
    {
        super("M",methodName,modifier);
        this.returnType = returnType;
    }
}


abstract class VarSymbol : Symbol
{
    string type;

    this(string prefix, string identifier, string type, string modifier)
    {
        super(prefix,identifier,modifier);
        this.type = type;
    }
}

class GlobalSymbol : VarSymbol
{
    this(string value, string type)
    {
        super("G",value,type,PUBLIC_MODIFIER);
    }
}

class LVarSymbol : VarSymbol
{
    this(string identifier, string type)
    {
        super("L",identifier,type,PRIVATE_MODIFIER);
    }
}
class ParamSymbol : VarSymbol
{
    this(string identifier, string type)
    {
        super("P",identifier,type,PRIVATE_MODIFIER);
    }
}
class IVarSymbol : VarSymbol
{
    this(string identifier, string type, string modifier)
    {
        super("V",identifier,type,modifier);
    }
}


