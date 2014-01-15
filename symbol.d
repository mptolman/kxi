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
            writeln(s);
    }
}

abstract class Symbol
{
private:
    static size_t counter = 0;
    string id;
    string value;
    string scop;
    string modifier;
    size_t line;

public:
    this(string prefix, string value, string modifier, string scop, size_t line)
    {
        this.id = text(prefix,++counter);
        this.value = value;
        this.modifier = modifier;
        this.scop = scop;
        this.line = line;
    }

    override string toString() const
    {
        return text(id,": ",value,' ',scop);
    }

    auto getId() const
    {
        return id;
    }
}

class ClassSymbol : Symbol
{
    this(string className, string scop, size_t line)
    {
        super("C",className,PUBLIC_MODIFIER,scop,line);
    }
}

class MethodSymbol : Symbol
{
private:
    string returnType;
    string[] params;

public:
    this(string methodName, string returnType, string modifier, string scop, size_t line)
    {
        super("M",methodName,modifier,scop,line);
        this.returnType = returnType;
    }

    void addParam(Symbol s)
    {
        params ~= s.id;
    }
}

abstract class VarSymbol : Symbol
{
private:
    string type;

public:
    this(string prefix, string identifier, string type, string modifier, string scop, size_t line)
    {
        super(prefix,identifier,modifier,scop,line);
        this.type = type;
    }
}

class GlobalSymbol : VarSymbol
{
    this(string value, string type, size_t line)
    {
        super("G",value,type,PUBLIC_MODIFIER,"g",line);
    }
}

class LVarSymbol : VarSymbol
{
    this(string identifier, string type, string scop, size_t line)
    {
        super("L",identifier,type,PRIVATE_MODIFIER,scop,line);
    }
}

class ParamSymbol : VarSymbol
{
    this(string identifier, string type, string scop, size_t line)
    {
        super("P",identifier,type,PRIVATE_MODIFIER,scop,line);
    }
}

class IVarSymbol : VarSymbol
{
    this(string identifier, string type, string modifier, string scop, size_t line)
    {
        super("V",identifier,type,modifier,scop,line);
    }
}
