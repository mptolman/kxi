import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.string;

immutable PUBLIC_MODIFIER = "public";
immutable PRIVATE_MODIFIER = "private";

auto byScope(Symbol[] set, Scope scp)
{
    return filter!(a => a._scope == scp)(set).array;
}

auto byName(Symbol[] set, string name)
{
    return filter!(a => a._name == name)(set).array;
}

auto byType(T)(Symbol[] set)
{
    return filter!(a => cast(T) a !is null)(set).array;
}

struct SymbolTable
{
private:
    static Symbol[string] _table;

public:
    static void add(Symbol s)
    {
        _table[s._id] = s;
    }

    static auto get(string id)
    {
        return id in _table ? _table[id] : null;
    }

    static auto values()
    {
        return _table.values.dup;
    }

    static string toString()
    {
        string s;
        foreach (i,j; _table)
            s ~= j.toString() ~ "\n";            
        return s;
    }
}

struct Scope
{
private:
    string _scope;

public:    
    void push(string s)
    {
        _scope ~= _scope.length ? '.' ~ s : s;
    }

    void pop()
    {
        auto pos = lastIndexOf(_scope,'.');
        _scope = pos >= 0 ? _scope[0..pos] : null;
    }

    void reset()
    {
        _scope = null;
    }

    auto toString()
    {
        return _scope;
    }
}

abstract class Symbol
{
private:
    static size_t _counter = 0;
    string _id;
    string _name;
    Scope _scope;
    string _modifier;
    size_t _line;

public:
    this(string prefix, string name, string modifier, Scope scop, size_t line)
    {
        _id = text(prefix,++_counter);
        _name = name;
        _modifier = modifier;
        _scope = scop;
        _line = line;
    }

    override string toString()
    {
        return text("\nid: ",_id,"\nvalue: ",_name,"\nscope: ",_scope,"\nmodifier: ",_modifier,"\n");
    }

    auto getId() const
    {
        return _id;
    }
}

class ClassSymbol : Symbol
{
    this(string className, Scope scop, size_t line)
    {
        super("C",className,PUBLIC_MODIFIER,scop,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString);
    }
}

class MethodSymbol : Symbol
{
private:
    string _returnType;
    string[] _params;

public:
    this(string methodName, string returnType, string modifier, Scope scop, size_t line)
    {
        super("M",methodName,modifier,scop,line);
        _returnType = returnType;
    }

    void addParam(Symbol s)
    {
        _params ~= s._id;
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString(),"returnType: ",_returnType,"\nparams: ",_params,"\n");
    }
}

abstract class VarSymbol : Symbol
{
private:
    string _type;
    //bool isArray;

public:
    this(string prefix, string name, string type, string modifier, Scope scop, size_t line)
    {
        super(prefix,name,modifier,scop,line);
        _type = type;
    }

    override string toString()
    {
        return text(Symbol.toString(),"type: ",_type,"\n");
    }
}

class GlobalSymbol : VarSymbol
{
    this(string name, string type, size_t line)
    {
        super("G",name,type,PUBLIC_MODIFIER,Scope("g"),line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class LVarSymbol : VarSymbol
{
    this(string name, string type, Scope scop, size_t line)
    {
        super("L",name,type,PRIVATE_MODIFIER,scop,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class ParamSymbol : VarSymbol
{
    this(string name, string type, Scope scop, size_t line)
    {
        super("P",name,type,PRIVATE_MODIFIER,scop,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class IVarSymbol : VarSymbol
{
    this(string name, string type, string modifier, Scope scop, size_t line)
    {
        super("V",name,type,modifier,scop,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}
