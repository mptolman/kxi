import std.algorithm;
import std.array;
import std.conv;
import std.string;
import exception;

immutable PUBLIC_MODIFIER = "public";
immutable PRIVATE_MODIFIER = "private";
immutable GLOBAL_SCOPE = "g";

struct SymbolTable
{
private:
    static Symbol[string] byId;
    static Symbol[][Scope] byScope;
    @disable this();

    static void insert(Symbol s)
    {
        byId[s.id] = s;
        byScope[s.scpe] ~= s;
    }

public:
//--------------------------
// Add to symbol table 
//--------------------------
    static auto addGlobal(string value, string type)
    {
        auto symbol = findGlobal(value, type);
        if (!symbol) {
            symbol = new GlobalSymbol(value, type);
            insert(symbol);
        }
        return symbol;
    }

    static auto addClass(string name, size_t line)
    {
        if (findClass(name))
            throw new SemanticError(line,"Duplicate declaration for class ",name);

        auto symbol = new ClassSymbol(name, Scope(GLOBAL_SCOPE));
        insert(symbol);
        return symbol;
    }

    static auto addMethod(string name, string returnType, string modifier, Scope scpe, size_t line)
    {
        if (findMethod(name, scpe, false))
            throw new SemanticError(line,"Duplicate declaration for method ",name);

        auto symbol = new MethodSymbol(name, returnType, modifier, scpe);
        insert(symbol);
        return symbol;
    }

    static auto addVar(T)(string name, string type, Scope scpe, size_t line)
        if (is(T:VarSymbol))
    {
        if (findVariable(name, scpe, false))
            throw new SemanticError(line,"Duplicate declaration for variable ",name);

        auto symbol = new T(name, type, scpe);
        insert(symbol);
        return symbol;
    }

    static auto addIVar(string name, string type, string modifier, Scope scpe, size_t line)
    {
        if (findVariable(name, scpe, false))
            throw new SemanticError(line,"Duplicate declaration for variable ",name);
      
        auto symbol = new IVarSymbol(name, type, modifier, scpe);
        
        auto classSymbol = cast(ClassSymbol)SymbolTable.findClass(scpe.top());
        if (!classSymbol)
            throw new Exception("addIVar: Failed to load class symbol");

        symbol.offset = classSymbol.size;
        if (symbol.type == "char")
            classSymbol.size += char.sizeof;
        else if (symbol.type == "bool")
            classSymbol.size += bool.sizeof;
        else
            classSymbol.size += int.sizeof;

        insert(symbol);
        return symbol;
    }

    static auto addTemporary(string name, string type)
    {
        auto symbol = new TempSymbol(name, type);
        insert(symbol);
        return symbol;
    }

    static auto addReference(string name, string type)
    {
        auto symbol = new RefSymbol(name, type);
        insert(symbol);
        return symbol;
    }

//--------------------------
// Search symbol table
//--------------------------    
    static auto getById(string id)
    {
        return id in byId ? byId[id] : null;
    }

    static auto getByScope(Scope scpe)
    {
        return byScope[scpe];
    }

    static auto getGlobals()
    {
        return byScope[Scope(GLOBAL_SCOPE)].filter!(a => cast(GlobalSymbol)a).array;
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
                        .filter!(a => cast(T)a)
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
    static size_t[string] counter;

    this(string prefix, string name, string type, string modifier, Scope scpe)
    {
        this.id = text(prefix,++counter[prefix]);
        this.name = name;
        this.type = type;
        this.modifier = modifier;
        this.scpe = scpe;
    }

public:
    string id;
    string name;
    string type;
    string modifier;
    size_t line;
    Scope scpe;

    override string toString()
    {
        return text("\nid: ",id,"\nvalue: ",name,"\ntype: ",type,"\nscope: ",scpe,"\nmodifier: ",modifier,"\n");
    }

    void afterInsert() {}
}

class ClassSymbol : Symbol
{
    size_t size;

    this(string className, Scope scpe)
    {
        super("C",className,className,PUBLIC_MODIFIER,scpe);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString);
    }
}

class MethodSymbol : Symbol
{
    string[] params;

    this(string methodName, string returnType, string modifier, Scope scpe)
    {
        super("M",methodName,returnType,modifier,scpe);
    }

    void addParam(Symbol s)
    {
        params ~= s.id;
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString(),"\nparams: ",params,"\n");
    }
}

abstract class VarSymbol : Symbol
{
    this(string prefix, string name, string type, string modifier, Scope scpe)
    {
        super(prefix,name,type,modifier,scpe);
    }
}

class LVarSymbol : VarSymbol
{
    this(string name, string type, Scope scpe)
    {
        super("L",name,type,PRIVATE_MODIFIER,scpe);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class ParamSymbol : VarSymbol
{
    this(string name, string type, Scope scpe)
    {
        super("P",name,type,PRIVATE_MODIFIER,scpe);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}

class IVarSymbol : VarSymbol
{
    size_t offset;
    
    this(string name, string type, string modifier, Scope scpe)
    {
        super("V",name,type,modifier,scpe);
    }

    override void afterInsert()
    {

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
        super("G",name,type,PUBLIC_MODIFIER,Scope(GLOBAL_SCOPE));
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString);
    }
}

class TempSymbol : Symbol
{
    this(string name, string type)
    {
        super("T",name,type,PUBLIC_MODIFIER,Scope(GLOBAL_SCOPE));
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
        super("R",name,type,PUBLIC_MODIFIER,Scope(GLOBAL_SCOPE));
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString);
    }
}
