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
    static Symbol[string] table;
    @disable this();

public:
    static void add(Symbol s)
    {        
        //if (cast(VarSymbol)s) {
        //    if (findIdentifier(s.name, s.scpe, false))
        //        throw new Exception(text("(",s.line,"): Duplicate definition for identifier ",s.name));
        //}
        //else if (cast(MethodSymbol)s) {
        //    if (findMethod(s.name, s.scpe, false))
        //        throw new Exception(text("(",s.line,"): Duplicate definition for method ",s.name));
        //}
        //else if (cast(ClassSymbol)s) {
        //    if (findClass(s.name, s.scpe, false))
        //        throw new Exception(text("(",s.line,"): Duplicate definition for class ",s.name));
        //}
        table[s.id] = s;
    }

    static auto get(string id)
    {
        return id in table ? table[id] : null;
    }

    static auto findVariable(string name, Scope scpe, bool recurse=true)
    {
        return find!VarSymbol(name, scpe, recurse);
    }

    static auto findClass(string name, Scope scpe, bool recurse=true)
    {
        return find!ClassSymbol(name, scpe, recurse);
    }

    static auto findMethod(string name, Scope scpe, bool recurse=true)
    {
        return find!MethodSymbol(name, scpe, recurse);
    }

    static auto findGlobal(string name)
    {
        return find!GlobalSymbol(name,Scope(GLOBAL_SCOPE),false);
    }

    static auto find(T)(string name, Scope scpe, bool recurse=true)
    {
        Symbol[] result;
        while (!result.length && scpe.length) {
            result = table.values
                        .filter!(a => a.scpe == scpe)
                        .filter!(a => a.name == name)
                        .filter!(a => cast(T) a !is null)
                        .array;
            if (!recurse) break;
            scpe.pop();            
        }
        return result;
    }

    static string toString()
    {
        string s;
        foreach (i,j; table)
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
        return pos >= 0 ? Scope(scpe[pos+1..$]) : Scope(scpe);
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
}

abstract class Symbol
{
private:
    static size_t counter = 0;

public:
    string id;
    string name;
    string modifier;
    Scope scpe;
    size_t line;

    this(string prefix, string name, string modifier, Scope scpe, size_t line)
    {
        this.id = text(prefix,++counter);
        this.name = name;
        this.modifier = modifier;
        this.scpe = scpe;
        this.line = line;
    }

    override string toString()
    {
        return text("\nid: ",id,"\nvalue: ",name,"\nscope: ",scpe,"\nmodifier: ",modifier,"\n");
    }
}

class ClassSymbol : Symbol
{
    this(string className, Scope scpe, size_t line)
    {
        super("C",className,PUBLIC_MODIFIER,scpe,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),Symbol.toString);
    }
}

class MethodSymbol : Symbol
{
    string returnType;
    string[] params;

    this(string methodName, string returnType, string modifier, Scope scpe, size_t line)
    {
        super("M",methodName,modifier,scpe,line);
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
    string type;

    this(string prefix, string name, string type, string modifier, Scope scpe, size_t line)
    {
        super(prefix,name,modifier,scpe,line);
        this.type = type;
    }

    override string toString()
    {
        return text(Symbol.toString(),"type: ",type,"\n");
    }
}

class GlobalSymbol : VarSymbol
{
    this(string name, string type, size_t line)
    {
        super("G",name,type,PUBLIC_MODIFIER,Scope(GLOBAL_SCOPE),line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
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
    this(string name, string type, string modifier, Scope scpe, size_t line)
    {
        super("V",name,type,modifier,scpe,line);
    }

    override string toString()
    {
        return text(typeid(typeof(this)),VarSymbol.toString);
    }
}
