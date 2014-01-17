import std.conv;
import std.stdio;
import std.string;

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
        return id in _table ? _table[id] : null;
    }

    static auto find(string name, Scope scp)
    {
        
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
        _scope = pos ? _scope[0..pos] : null;
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
    static size_t counter = 0;
    string id;
    string value;
    string scop;
    string modifier;
    size_t line;

public:
    this(string prefix, string value, string modifier, Scope scop, size_t line)
    {
        this.id = text(prefix,++counter);
        this.value = value;
        this.modifier = modifier;
        this.scop = scop._scope;
        this.line = line;
    }

    override string toString()
    {
        return text("\nid: ",id,"\nvalue: ",value,"\nscope: ",scop,"\nmodifier: ",modifier,"\n");
    }

    auto getId() const
    {
        return id;
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
    string returnType;
    string[] params;

public:
    this(string methodName, string returnType, string modifier, Scope scop, size_t line)
    {
        super("M",methodName,modifier,scop,line);
        this.returnType = returnType;
    }

    void addParam(Symbol s)
    {
        params ~= s.id;
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString(),"returnType: ",returnType,"\nparams: ",params,"\n");
    }
}

abstract class VarSymbol : Symbol
{
private:
    string type;
    //bool isArray;

public:
    this(string prefix, string identifier, string type, string modifier, Scope scop, size_t line)
    {
        super(prefix,identifier,modifier,scop,line);
        this.type = type;
    }

    override string toString()
    {
        return text(Symbol.toString(),"type: ",type,"\n");
    }
}

class GlobalSymbol : VarSymbol
{
    this(string value, string type, size_t line)
    {
        super("G",value,type,PUBLIC_MODIFIER,Scope("g"),line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class LVarSymbol : VarSymbol
{
    this(string identifier, string type, Scope scop, size_t line)
    {
        super("L",identifier,type,PRIVATE_MODIFIER,scop,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class ParamSymbol : VarSymbol
{
    this(string identifier, string type, Scope scop, size_t line)
    {
        super("P",identifier,type,PRIVATE_MODIFIER,scop,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class IVarSymbol : VarSymbol
{
    this(string identifier, string type, string modifier, Scope scop, size_t line)
    {
        super("V",identifier,type,modifier,scop,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}
