import std.algorithm;
import std.array;
import std.conv;
import std.string;

immutable PUBLIC_MODIFIER = "public";
immutable PRIVATE_MODIFIER = "private";
immutable GLOBAL_SCOPE = "g";

struct SymbolTable
{
private:
    static Symbol[string] byId;
    static Symbol[][Scope] byScope;
    @disable this();

public:
    static void add(Symbol s)
    {
        bool dontInsert = false;
        s.beforeInsert(dontInsert);

        if (!dontInsert) {
            byId[s.id] = s;
            byScope[s.scpe] ~= s;
            s.afterInsert();
        }
    }

    static auto getById(string id)
    {
        return id in byId ? byId[id] : null;
    }

    static auto findVariable(string name, Scope scpe, bool recurse=true)
    {
        return findFirst!VarSymbol(name,scpe,recurse);
    }

    static auto findMethod(string name, Scope scpe, bool recurse=true)
    {
        return findFirst!MethodSymbol(name,scpe,recurse);
    }

    static auto findClass(string name)
    {
        return findFirst!ClassSymbol(name,Scope(GLOBAL_SCOPE),false);
    }

    static auto findGlobal(string name, string type)
    {
        foreach (s; find!GlobalSymbol(name,Scope(GLOBAL_SCOPE),false))
            if (s.type == type)
                return s;
        return null;
    }

    static auto findFirst(T)(string name, Scope scpe, bool recurse=true)
    {
        auto matches = find!T(name,scpe,recurse);
        return matches.length ? matches[0] : null;
    }

    static auto find(T)(string name, Scope scpe, bool recurse=true)
    {
        Symbol[] matches;

        for (; scpe.length; scpe.pop()) {
            if (scpe !in byScope) {
                if (!recurse)
                    break;
                else
                    continue;
            }
            
            matches = byScope[scpe]
                        .filter!(a => a.name == name)
                        .filter!(a => cast(T)a !is null)
                        .array;

            if (matches.length || !recurse)
                break;
        }

        return matches;
    }

    static string toString()
    {
        string s;
        foreach (i,j; byId)
            s ~= j.toString() ~ "\n";            
        return s;
    }
}

struct Scope
{
private:
    string scpe;

public:    
    void push(string s)
    {
        scpe ~= scpe.length ? '.' ~ s : s;
    }

    void pop()
    {
        auto pos = lastIndexOf(scpe,'.');
        scpe = pos >= 0 ? scpe[0..pos] : null;
    }

    auto top()
    {
        auto pos = lastIndexOf(scpe,'.');
        return pos >= 0 ? scpe[pos+1..$].idup : scpe.idup;
    }

    void reset()
    {
        scpe = null;
    }

    auto length()
    {
        return scpe.length;
    }

    auto toString()
    {
        return scpe;
    }

    auto contains(Scope s)
    {
        for (; s.length; s.pop())
            if (s.scpe == this.scpe)
                return true;
        return false;
    }

    const hash_t toHash()
    {
        return typeid(scpe).getHash(&scpe);
    }

    const bool opEquals(ref const Scope s)
    {
        return cmp(this.scpe, s.scpe) == 0;
    }

    const int opCmp(ref const Scope s)
    {
        return cmp(this.scpe, s.scpe);
    }
}

abstract class Symbol
{
private:
    static size_t counter = 0;

public:
    string id;
    string name;
    string type;
    string modifier;
    size_t line;
    Scope scpe;

    this(string prefix, string name, string type, string modifier, Scope scpe, size_t line)
    {
        this.id = text(prefix,++counter);
        this.name = name;
        this.type = type;
        this.modifier = modifier;
        this.scpe = scpe;
        this.line = line;
    }

    override string toString()
    {
        return text("\nid: ",id,"\nvalue: ",name,"\ntype: ",type,"\nscope: ",scpe,"\nmodifier: ",modifier,"\n");
    }

    void beforeInsert(out bool dontInsert) {}
    void afterInsert() {}
}

class ClassSymbol : Symbol
{
    size_t size;

    this(string className, Scope scpe, size_t line)
    {
        super("C",className,className,PUBLIC_MODIFIER,scpe,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString);
    }

    override void beforeInsert(out bool dontInsert)
    {
        if (SymbolTable.findClass(this.name))
            throw new Exception(text("(",this.line,"): Duplicate definition for class ",this.name));
    }
}

class MethodSymbol : Symbol
{
    string[] params;

    this(string methodName, string returnType, string modifier, Scope scpe, size_t line)
    {
        super("M",methodName,returnType,modifier,scpe,line);
    }

    void addParam(Symbol s)
    {
        params ~= s.id;
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString(),"\nparams: ",params,"\n");
    }

    override void beforeInsert(out bool dontInsert)
    {
        if (SymbolTable.findMethod(this.name,this.scpe,false))
            throw new Exception(text("(",this.line,"): Duplicate definition for method ",this.name));
    }
}

abstract class VarSymbol : Symbol
{
    this(string prefix, string name, string type, string modifier, Scope scpe, size_t line)
    {
        super(prefix,name,type,modifier,scpe,line);
    }

    override void beforeInsert(out bool dontInsert)
    {
        if (SymbolTable.findVariable(this.name,this.scpe,false))
            throw new Exception(text("(",this.line,"): Duplicate definition for variable ",this.name));
    }
}

class LVarSymbol : VarSymbol
{
    this(string name, string type, Scope scpe, size_t line)
    {
        super("L",name,type,PRIVATE_MODIFIER,scpe,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class ParamSymbol : VarSymbol
{
    this(string name, string type, Scope scpe, size_t line)
    {
        super("P",name,type,PRIVATE_MODIFIER,scpe,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class IVarSymbol : VarSymbol
{
    size_t offset;
    
    this(string name, string type, string modifier, Scope scpe, size_t line)
    {
        super("V",name,type,modifier,scpe,line);
    }

    override void afterInsert()
    {
        auto classSym = cast(ClassSymbol)SymbolTable.findClass(this.scpe.top());
        if (!classSym)
            throw new Exception("IVarSymbol.afterInsert: Failed to load class symbol");

        this.offset = classSym.size;
        if (this.type == "char")
            classSym.size += char.sizeof;
        else
            classSym.size += int.sizeof;
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class GlobalSymbol : Symbol
{
    this(string name, string type)
    {
        super("G",name,type,PUBLIC_MODIFIER,Scope(GLOBAL_SCOPE),0);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString);
    }

    override void beforeInsert(out bool dontInsert)
    {
        if (SymbolTable.findGlobal(this.name,this.type))
            dontInsert = true;
    }
}

class TempSymbol : Symbol
{
    this(string name, string type)
    {
        super("T",name,type,PUBLIC_MODIFIER,Scope(GLOBAL_SCOPE),0);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString);
    }
}

class RefSymbol : Symbol
{
    this(string name, string type)
    {
        super("R",name,type,PUBLIC_MODIFIER,Scope(GLOBAL_SCOPE),0);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString);
    }
}
