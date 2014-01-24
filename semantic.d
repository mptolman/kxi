import std.conv;
import std.stdio;
import stack, symbol;

enum SARType : byte
{
    ID_SAR,
    VAR_SAR,
    TYPE_SAR,
    LIT_SAR,
    BAL_SAR,
    AL_SAR,
    TEMP_SAR,
    REF_SAR,
    FUNC_SAR
}

struct SAR
{
    SARType type;
    string name;
    string id;
    Scope scpe;
    size_t line;
    string[] parameters;  

    this(SARType type)
    {
        this.type = type;
    }

    this(SARType type, string name, Scope scpe, size_t line)
    {
        this.type = type;
        this.name = name;
        this.scpe = scpe;
        this.line = line;
    }

    this(SARType type, string id)
    {
        this.type = type;
        this.id = id;
    }
}

void iPush(string name, Scope scpe, size_t line)
{
    writefln("(%s) iPush: %s",line,name);
    _sas.push(SAR(SARType.ID_SAR,name,scpe,line));
}

void iExist()
{
    auto sar = _sas.top();
    _sas.pop();

    writefln("iExist: %s",sar.name);

    switch (sar.type) {
    case SARType.ID_SAR:
        auto symbol = SymbolTable.findVariable(sar.name, sar.scpe);
        if (!symbol)
            throw new Exception(text("(",sar.line,"): Identifier '",sar.name,"' does not exist in this scope"));
        _sas.push(SAR(SARType.VAR_SAR,symbol.id));
        break;
    default:
        throw new Exception("Incompatible type for iExist");
        break;
    }
}

void tExist(string type, size_t line)
{
    writefln("tExist: %s",type);

    auto match = SymbolTable.findClass(type);
    if (!match)
        throw new Exception(text("(",line,"): Invalid type '",type,"'"));
}

void lPush(string value)
{
    writefln("lPush: %s",value);

    auto symbol = SymbolTable.findGlobal(value);
    if (!symbol)
        throw new Exception(text("Could not find global literal \"",value,"\""));

    _sas.push(SAR(SARType.LIT_SAR,symbol.id));
}

void vPush(string name, Scope scpe, size_t line)
{
    writefln("(%s) vPush: %s",line,name);

    auto symbol = SymbolTable.findVariable(name,scpe);
    if (!symbol)
        throw new SemanticError("Could not find symbol");

    _sas.push(SAR(SARType.VAR_SAR,symbol.id));
}

void oPush(string op, size_t line)
{    
    writefln("(%s) oPush: %s",line,op);

    while (!_os.empty && _opWeights[_os.top] >= _opWeights[op]) {
        if (op == "=" && _os.top == "=")
            throw new Exception("Nested assignment not supported");
        doStackOp();
    }
    _os.push(op);
}

void rExist()
{
    auto member_sar = _sas.top(); _sas.pop();
    auto obj_sar = _sas.top(); _sas.pop();

    writefln("rExist: %s.%s",obj_sar.name,member_sar.name);

    auto class_symbol = SymbolTable.findClass(SymbolTable.get(obj_sar.id).type);
    if (class_symbol is null)
        throw new Exception("Not class type");

    auto scpe = class_symbol.scpe;
    scpe.push(class_symbol.name);

    Symbol symbol;

    switch (member_sar.type) {
    case SARType.ID_SAR:
        symbol = SymbolTable.findVariable(member_sar.name,scpe,false);
        if (!symbol)
            throw new Exception(text("Class ",class_symbol.name," has no member ",member_sar.name));
        else if (symbol.modifier != PUBLIC_MODIFIER)
            throw new Exception("Member is private");
        break;
    case SARType.FUNC_SAR:
        symbol = SymbolTable.findMethod(member_sar.name,scpe,false);
        if (!symbol)
            throw new Exception(text("Class ",class_symbol.name," has no method ",member_sar.name));
        else if (symbol.modifier != PUBLIC_MODIFIER)
            throw new Exception("Method is private");    
        break;
    default:
        throw new Exception("Incompatible type for rExist");
        break;
    }

    if (symbol !is null) {
        auto refSymbol = new TempSymbol(text(obj_sar.name,'.',member_sar.name),symbol.type);
        _sas.push(SAR(SARType.REF_SAR,refSymbol.id));
        SymbolTable.add(refSymbol);
    }
}

void eoe_sa()
{
    writeln("eoe_sa");

    while (!_os.empty)
        doStackOp();
    _sas.clear();
}

void cd_sa(string cname, Scope scpe, size_t line)
{
    writeln("cd_sa");

    auto className = scpe.top();
    if (cname != className)
        throw new Exception(text("(",line,"): Constructor name \"",cname,"\" does not match class name \"",className,"\""));
}

void bal_sa()
{
    writeln("bal_sa");

    _sas.push(SAR(SARType.BAL_SAR));
}

void eal_sa()
{
    writeln("eal_sa");

    auto al_sar = SAR(SARType.AL_SAR);

    while (_sas.top.type != SARType.BAL_SAR) {
        al_sar.parameters ~= _sas.top.id;
        _sas.pop(); 
    }

    _sas.pop();
    _sas.push(al_sar);
}

void func_sa()
{
    writeln("func_sa");

    auto al_sar = _sas.top; _sas.pop();
    auto id_sar = _sas.top; _sas.pop();

    auto f_sar = SAR(SARType.FUNC_SAR,id_sar.name,id_sar.scpe,id_sar.line);
    f_sar.parameters = al_sar.parameters;
    _sas.push(f_sar);
}

void arr_sa()
{
    writeln("arr_sa");
}

void cparen_sa(size_t line)
{
    writeln("cparen_sa");

    while (_os.top != "(")
        doStackOp();
    _os.pop();
}

void cbracket_sa()
{
    writeln("cbracket_sa");

}

void comma_sa()
{
    writeln("comma_sa");

}

void atoi_sa()
{
    writeln("atoi_sa");
}

void itoa_sa()
{
    writeln("itoa_sa");
}

void if_sa()
{
    writeln("if_sa");
}

void while_sa()
{
    writeln("while_sa");
}

void return_sa(Scope scpe)
{
    writeln("return_sa");

    while (!_os.empty)
        doStackOp();

    auto methodName = scpe.top();
    scpe.pop();
    auto methodSymbol = SymbolTable.findMethod(methodName, scpe);
    if (!methodSymbol)
        throw new Exception(text("Could not find method ",methodName));
    auto returnType = methodSymbol.type;

    if (_sas.empty) {
        if (returnType != "void") {
            throw new Exception("Missing return type");
        }
    }
    else {
        auto ret_sar = _sas.top();
        _sas.pop();
        if (returnType != SymbolTable.get(ret_sar.id).type)
            throw new Exception("Return type mismatch");
    }
}

void cout_sa()
{
    writeln("cout_sa");
}

void cin_sa()
{
    writeln("cin_sa");
}

void newobj_sa()
{
    writeln("newobj_sa");
}

void newarr_sa()
{
    writeln("newarr_sa");
}

class SemanticError : Exception
{
    this(string err)
    {
        super(err);
    }
}

private:
Stack!SAR _sas;
Stack!string _os;
size_t[string] _opWeights;

void doStackOp()
{
    auto op = _os.top;
    _os.pop();
    writefln("Doing '%s' op",op);

    auto rval = SymbolTable.get(_sas.top.id);
    _sas.pop();

    auto lval = SymbolTable.get(_sas.top.id);
    _sas.pop();

    switch(op) {
    case "=":
        if (lval.type != rval.type)
            throw new Exception("Incompatible assignment");
        break;
    case "+":
    case "-":
    case "*":
    case "/":
    case "%":
        if (lval.type != rval.type)
            throw new Exception("Incompatible types");
        auto symbol = new TempSymbol(text(lval.name,op,rval.name),lval.type);
        SymbolTable.add(symbol);
        _sas.push(SAR(SARType.TEMP_SAR,symbol.id));
        break;
    default:
        break;
    }
}

static this()
{
    _sas = new Stack!SAR;
    _os = new Stack!string;

    _opWeights = [
        "="  : 1,
        "||" : 3,
        "&&" : 5,
        "==" : 7,
        "!=" : 7,
        "<"  : 9,
        ">"  : 9,
        "<=" : 9,
        ">=" : 9,
        "+"  : 11,
        "-"  : 11,
        "*"  : 13,
        "/"  : 13,
        "%"  : 13,
        ")"  : 0,
        "]"  : 0,
        "."  : 15,
        "("  : 15,
        "["  : 15
    ];
}