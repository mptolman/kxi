import std.algorithm;
import std.array;
import std.conv;
import exception, scpe;

immutable PUBLIC_MODIFIER = "public";
immutable PRIVATE_MODIFIER = "private";

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

        auto symbol = new ClassSymbol(name);
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

//--------------------------
// Search symbol table
//--------------------------    
    static auto getById(string id)
    {
        return id in byId ? byId[id] : null;
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

    static auto findReference(string name, Scope scpe)
    {
        return findFirst!RefSymbol(name,scpe,false);
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
}

abstract class Symbol
{
private:
    static size_t[string] counter;

    this(string prefix, string name, string type, string modifier, Scope scpe, int offset=0)
    {
        this.id       = text(prefix,++counter[prefix]);
        this.name     = name;
        this.type     = type;
        this.modifier = modifier;
        this.scpe     = scpe;
        this.offset   = offset;
    }

public:
    string id;
    string name;
    string type;
    string modifier;
    int offset;
    Scope scpe;
}

class ClassSymbol : Symbol
{
    this(string className)
    {
        super("C",className,className,PUBLIC_MODIFIER,Scope(GLOBAL_SCOPE));
    }

    auto addInstanceVar(string name, string type, string modifier, size_t line)
    {
        auto classScope = this.scpe;
        classScope.push(this.name);

        if (SymbolTable.findVariable(name, classScope, false))
            throw new SemanticError(line, "Duplicate declaration for variable ",name);

        auto varSymbol = new IVarSymbol(name, type, modifier, classScope, this.offset); 
        SymbolTable.insert(varSymbol);

        this.offset += type == "char" ? char.sizeof : int.sizeof;
        return varSymbol;
    }
}

class MethodSymbol : Symbol
{
    string[] params;
    string[] locals;

    this(string methodName, string returnType, string modifier, Scope scpe)
    {
        super("M",methodName,returnType,modifier,scpe,-12);
    }

    auto addParam(string name, string type, size_t line)
    {
        auto methodScope = this.scpe;
        methodScope.push(this.name);

        if (SymbolTable.findVariable(name, methodScope, false))
            throw new SemanticError(line, "Duplicate declaration for variable ",name);

        auto varSymbol = new ParamSymbol(name, type, methodScope, this.offset);
        SymbolTable.insert(varSymbol);

        this.offset -= 4;
        this.params ~= varSymbol.id;
        
        return varSymbol;
    }

    auto addLocal(string name, string type, size_t line)
    {
        auto methodScope = this.scpe;
        methodScope.push(this.name);

        if (SymbolTable.findVariable(name, methodScope, false))
            throw new SemanticError(line, "Duplicate declaration for variable ",name);

        auto varSymbol = new LVarSymbol(name, type, methodScope, this.offset);
        SymbolTable.insert(varSymbol);

        this.offset -= 4;
        this.locals ~= varSymbol.id;

        return varSymbol;
    }

    auto addTemporary(string type)
    {
        auto methodScope = this.scpe;
        methodScope.push(this.name);

        auto tempSymbol = new TempSymbol(type, methodScope, this.offset);
        SymbolTable.insert(tempSymbol);

        this.offset -= 4;
        this.locals ~= tempSymbol.id;

        return tempSymbol;
    }

    auto addReference(string name, string type)
    {
        auto methodScope = this.scpe;
        methodScope.push(this.name);

        auto refSymbol = SymbolTable.findReference(name, methodScope);
        if (!refSymbol) {
            refSymbol = new RefSymbol(name, type, methodScope, this.offset);
            SymbolTable.insert(refSymbol);

            this.offset -= 4;
            this.locals ~= refSymbol.id;
        }

        return refSymbol;
    }
}

abstract class VarSymbol : Symbol
{
    this(string prefix, string name, string type, string modifier, Scope scpe, int offset)
    {
        super(prefix,name,type,modifier,scpe,offset);
    }
}

class LVarSymbol : VarSymbol
{
    this(string name, string type, Scope scpe, int offset)
    {
        super("L",name,type,PRIVATE_MODIFIER,scpe,offset);
    }
}

class ParamSymbol : VarSymbol
{
    this(string name, string type, Scope scpe, int offset)
    {
        super("P",name,type,PRIVATE_MODIFIER,scpe,offset);
    }
}

class IVarSymbol : VarSymbol
{
    this(string name, string type, string modifier, Scope scpe, int offset)
    {
        super("V",name,type,modifier,scpe,offset);
    }
}

class GlobalSymbol : Symbol
{
    this(string name, string type)
    {
        super("G",name,type,PUBLIC_MODIFIER,Scope(GLOBAL_SCOPE));
    }
}

class TempSymbol : Symbol
{
    this(string type, Scope scpe, int offset)
    {
        super("T",null,type,PRIVATE_MODIFIER,scpe,offset);
    }
}

class RefSymbol : Symbol
{
    this(string name, string type, Scope scpe, int offset)
    {
        super("R",name,type,PRIVATE_MODIFIER,scpe,offset);
    }
}
