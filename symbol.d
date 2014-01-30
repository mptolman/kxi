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
        if (cast(GlobalSymbol)s && findGlobal(s.name)) {
            // don't error--just keep one copy
        }
        else if (cast(VarSymbol)s && findVariable(s.name,s.scpe,false)) {
            //throw new Exception(text("(",s.line,"): Variable '",s.name,"' has already been declared"));
        }
        else if (cast(MethodSymbol)s && findMethod(s.name,s.scpe,false)) {
            //throw new Exception(text("(",s.line,"): Method '",s.name,"' has already been declared"));
        }
        else if (cast(ClassSymbol)s && findClass(s.name)) {
            //throw new Exception(text("(",s.line,"): Class '",s.name,"' has already been declared"));
        }
        else {
            table[s.id] = s;
        }
    }

    static auto get(string id)
    {
        return id in table ? table[id] : null;
    }

    static auto findVariable(string name, Scope scpe, bool recurse=true)
    {
        return find!VarSymbol(name,scpe,recurse);
    }

    static auto findClass(string name)
    {
        return find!ClassSymbol(name,Scope(GLOBAL_SCOPE),false);
    }

    static auto findMethod(string name, Scope scpe, bool recurse=true)
    {
        return find!MethodSymbol(name,scpe,recurse);
    }

    static auto findGlobal(string name)
    {
        return find!GlobalSymbol(name,Scope(GLOBAL_SCOPE),false);
    }

    static auto find(T)(string name, Scope scpe, bool recurse=true)
    {
        for ( ; scpe.length; scpe.pop()) {
            auto matches = table.values
                            .filter!(a => a.scpe == scpe)
                            .filter!(a => a.name == name)
                            .filter!(a => cast(T) a !is null)
                            .array;
            if (matches.length)
                return matches[0];
            if (!recurse) 
                return null;
        }

        return null;
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
        return pos >= 0 ? scpe[pos+1..$] : scpe;
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
        while (s.length) {
            if (s.scpe == this.scpe)
                return true;
            s.pop();
        }
        return false;
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
    Scope scpe;

    this(string prefix, string name, string type, string modifier, Scope scpe)
    {
        this.id = text(prefix,++counter);
        this.name = name;
        this.type = type;
        this.modifier = modifier;
        this.scpe = scpe;
    }

    auto isAccessibleFrom(Scope scpe)
    {
        if (this.modifier == PUBLIC_MODIFIER)
            return true;

        Scope currScope = this.scpe;
        while (currScope.length) {
            if (currScope == scpe)
                return true;
            currScope.pop();
        }
        
        return false;
    }

    override string toString()
    {
        return text("\nid: ",id,"\nvalue: ",name,"\ntype: ",type,"\nscope: ",scpe,"\nmodifier: ",modifier,"\n");
    }
}

class ClassSymbol : Symbol
{
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
    this(string name, string type, string modifier, Scope scpe)
    {
        super("V",name,type,modifier,scpe);
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
