import std.conv;
import std.stdio;
import icode, stack, symbol;

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
    FUNC_SAR,
    NEW_SAR,
    ARR_SAR
}

struct SAR
{
    SARType type;
    string name;
    string id;
    Scope scpe;
    size_t line;
    string[] params;  

    this(SARType type)
    {
        this.type = type;
    }

    this(SARType type, string id)
    {
        this.type = type;
        this.id = id;
    }

    this(SARType type, string name, size_t line)
    {
        this.type = type;
        this.name = name;
        this.line = line;
    }

    this(SARType type, string name, Scope scpe, size_t line)
    {
        this.type = type;
        this.name = name;
        this.scpe = scpe;
        this.line = line;
    }
}

void arr_sa()
{
    writeln("arr_sa");

    auto index_symbol = SymbolTable.get(_sas.top.id);
    if (!index_symbol)
        throw new Exception("Could not get index from symbol table");
    if (index_symbol.type != "int")
        throw new Exception("Index must be an integer");

    auto id_sar = _sas.top;
    _sas.pop();

    // push arr_sar
}

void atoi_sa()
{
    writeln("atoi_sa");

    auto symbol = SymbolTable.get(_sas.top.id);
    if (!symbol)
        throw new Exception("Could not get atoi argument");
    if (symbol.type != "char")
        throw new Exception("Invalid type for atoi");
    try {
        auto i = to!int(symbol.name);
        auto temp = new TempSymbol(symbol.name,"int");
        _sas.push(SAR(SARType.LIT_SAR,temp.id));
        SymbolTable.add(temp);
    }
    catch (Exception) {
        throw new Exception("Argument cannot be converted to integer");
    }
}

void bal_sa()
{
    writeln("bal_sa");

    _sas.push(SAR(SARType.BAL_SAR));
}

void cbracket_sa()
{
    writeln("cbracket_sa");
    while (_os.top != "[")
        doStackOp();

    _os.pop();
}

void cd_sa(string cname, Scope scpe, size_t line)
{
    writeln("cd_sa");

    auto className = scpe.top();
    if (cname != className)
        throw new Exception(text("(",line,"): Constructor name \"",cname,"\" does not match class name \"",className,"\""));
}

void cin_sa()
{
    writeln("cin_sa");

    while (!_os.empty)
        doStackOp();

    auto symbol = SymbolTable.get(_sas.top.id);
    _sas.pop();

    if (symbol.type == "int" || symbol.type == "char") {
        // gen icode
    }
    else {
        throw new Exception("Invalid type for cin");
    }
}

void comma_sa()
{
    writeln("comma_sa");

    while (_os.top != "(")
        doStackOp();
}

void cout_sa()
{
    writeln("cout_sa");

    while (!_os.empty)
        doStackOp();

    auto symbol = SymbolTable.get(_sas.top.id);
    _sas.pop();

    if (symbol.type == "int" || symbol.type == "char") {
        // gen icode
    }
    else {
        throw new Exception("Invalid type for cout");
    }
}

void cparen_sa(size_t line)
{
    writeln("cparen_sa");

    while (_os.top != "(")
        doStackOp();
    _os.pop();
}

void eal_sa()
{
    writeln("eal_sa");

    auto al_sar = SAR(SARType.AL_SAR);

    while (_sas.top.type != SARType.BAL_SAR) {
        al_sar.params ~= _sas.top.id;
        _sas.pop(); 
    }

    _sas.pop();
    _sas.push(al_sar);
}

void eoe_sa()
{
    writeln("eoe_sa");

    while (!_os.empty)
        doStackOp();
    _sas.clear();
}

void func_sa()
{
    writeln("func_sa");

    auto al_sar = _sas.top(); _sas.pop();
    auto id_sar = _sas.top(); _sas.pop();

    auto f_sar = SAR(SARType.FUNC_SAR,id_sar.name,id_sar.scpe,id_sar.line);
    f_sar.params = al_sar.params.dup;
    _sas.push(f_sar);
}

void iExist()
{
    auto id_sar = _sas.top();
    _sas.pop();    

    writefln("iExist: %s",id_sar.name);

    auto symbol = findSymbol(id_sar);
    if (!symbol)
        throw new SemanticError(id_sar.line,"Identifier ",id_sar.name," does not exist in this scope");

    id_sar.id = symbol.id;
    _sas.push(id_sar);
    //switch(id_sar.type) {
    //case SARType.ID_SAR:
    //    auto symbol = SymbolTable.findVariable(id_sar.name,id_sar.scpe);
    //    if (!symbol)
    //        throw new SemanticError(id_sar.line,"Identifier ",id_sar.name," does not exist in this scope");
    //    id_sar.id = symbol.id;
    //    _sas.push(id_sar);
    //    break;
    //case SARType.FUNC_SAR:
    //    auto symbol = cast(MethodSymbol)SymbolTable.findMethod(id_sar.name,id_sar.scpe);
    //    if (!symbol)
    //        throw new SemanticError(id_sar.line,"Method ",id_sar.name," does not exist in this scope");

    //    break;
    //case SARType.ARR_SAR:

    //    break;
    //default:
    //    throw new Exception("Unsupported type for iExist");
    //}
}

void if_sa()
{
    writeln("if_sa");
}

void iPush(string name, Scope scpe, size_t line)
{
    writefln("(%s) iPush: %s",line,name);
    _sas.push(SAR(SARType.ID_SAR,name,scpe,line));
}

void itoa_sa()
{
    writeln("itoa_sa");
}

void lPush(string value)
{
    writefln("lPush: %s",value);

    //auto symbol = SymbolTable.findGlobal(value);
    //if (!symbol)
    //    throw new Exception(text("Could not find global literal \"",value,"\""));

    //_sas.push(SAR(SARType.LIT_SAR,symbol.id));
}

void newarr_sa()
{
    writeln("newarr_sa");
    auto index_sar = _sas.top;
    _sas.pop();

    auto type_sar = _sas.top;
    _sas.pop();

    auto index_symbol = SymbolTable.get(index_sar.id);
    if (!index_symbol)
        throw new Exception("Could not find arr index in symbol table");
    if (index_symbol.type != "int")
        throw new Exception("Arr index must be an integer");

    switch(type_sar.name) {
    case "int":
    case "char":
    case "bool":
        // allow
        break;
    default:
        if (!SymbolTable.findClass(type_sar.name))
            throw new Exception("newarr_sa: Invalid type");
    }

    auto temp = new TempSymbol(index_symbol.name,text("@:",type_sar.name));
    _sas.push(SAR(SARType.NEW_SAR,temp.id));
    SymbolTable.add(temp);
}

void newobj_sa()
{
    writeln("newobj_sa");
    auto al_sar = _sas.top();
    _sas.pop();
    
    auto type_sar = _sas.top();
    _sas.pop();

    // Make sure type exists
    //auto class_symbol = SymbolTable.findClass(type_sar.name);
    //if (!class_symbol)
    //    throw new Exception(text("Invalid type ",type_sar.name));

    //// Make sure ctor exists
    //auto scpe = class_symbol.scpe;
    //scpe.push(class_symbol.name);

    //auto ctor_symbol = cast(MethodSymbol)SymbolTable.findMethod(class_symbol.name,scpe,false);
    //if (!ctor_symbol)
    //    throw new Exception(text("Type ",class_symbol.name," has no constructor"));

    //// Check arguments vs parameters
    //if (al_sar.params.length != ctor_symbol.params.length)
    //    throw new Exception("Ctor parameter count does not match");

    //foreach (i,p; al_sar.params.dup.reverse) {
    //    auto arg = SymbolTable.get(p);
    //    auto param = SymbolTable.get(ctor_symbol.params[i]);
    //    if (arg.type != param.type)
    //        throw new Exception("Parameter types don't match");
    //}

    //auto temp = new TempSymbol(type_sar.name,type_sar.name);
    //auto new_sar = SAR(SARType.NEW_SAR,temp.id);
    //new_sar.params = al_sar.params.dup;
    //_sas.push(new_sar);
    //SymbolTable.add(temp);
}

void oPush(string op, size_t line)
{    
    writefln("(%s) oPush: %s",line,op);

    while (!_os.empty && _opWeights[_os.top] >= _opWeights[op]) {
        if (op == "=" && _os.top == "=")
            throw new SemanticError(line,"Nested assignment not supported");
        doStackOp();
    }
    _os.push(op);
}

void return_sa(Scope scpe)
{
    writeln("return_sa");

    //while (!_os.empty)
    //    doStackOp();

    //auto methodName = scpe.top;
    //scpe.pop();

    //auto methodSymbol = SymbolTable.findMethod(methodName, scpe, false);
    //if (!methodSymbol)
    //    throw new Exception(text("Could not find method ",methodName));

    //auto returnType = methodSymbol.type;

    //if (_sas.empty) {
    //    if (returnType != "void") {
    //        throw new Exception("Missing return type");
    //    }
    //}
    //else {
    //    auto ret_sar = _sas.top();
    //    _sas.pop();
    //    if (returnType != SymbolTable.get(ret_sar.id).type)
    //        throw new Exception("Return type mismatch");
    //}
}

void rExist()
{
    auto member_sar = _sas.top();
    _sas.pop();
    
    auto obj_sar = _sas.top();
    _sas.pop();

    //auto obj_symbol = SymbolTable.get(obj_sar.id);
    //writefln("rExist: %s.%s",obj_symbol.name,member_sar.name);

    //auto class_symbol = SymbolTable.findClass(obj_symbol.type);
    //if (!class_symbol)
    //    throw new SemanticError(obj_sar.line,"Identifier ",obj_symbol.name," is not a class type");

    //auto class_scope = class_symbol.scpe;
    //class_scope.push(class_symbol.name);

    //Symbol member_symbol;
    //switch (member_sar.type) {
    //case SARType.ID_SAR:
    //    // Does the instance variable exist in this class?
    //    member_symbol = SymbolTable.findVariable(member_sar.name,class_scope,false);
    //    if (!member_symbol)
    //        throw new SemanticError(obj_sar.line,"Class ",class_symbol.name," has no member ",member_sar.name);
    //    // Is it accessible from the current scope?
    //    if (member_symbol.modifier != PUBLIC_MODIFIER && !class_scope.contains(obj_symbol.scpe))
    //        throw new SemanticError(obj_sar.line,"Instance variable ",member_sar.name," of type ",class_symbol.name," is private");
    //    break;
    //case SARType.FUNC_SAR:
    //    // Does the method exist in this class?
    //    member_symbol = SymbolTable.findMethod(member_sar.name,class_scope,false);
    //    if (!member_symbol)
    //        throw new SemanticError(obj_sar.line,"Class ",class_symbol.name," has no method ",member_sar.name);
    //    // Is it accessible from the current scope?
    //    if (member_symbol.modifier != PUBLIC_MODIFIER && !class_scope.contains(obj_symbol.scpe))
    //        throw new SemanticError(obj_sar.line,"Method ",member_sar.name," of type ",class_symbol.name," is private");
    //    break;
    //default:
    //    throw new Exception("Incompatible type for rExist");
    //}

    //auto ref_symbol = new RefSymbol(text(obj_symbol.name,'.',member_symbol.name),member_symbol.type);
    //SymbolTable.add(ref_symbol);

    //auto ref_sar = member_sar;    
    //ref_sar.id = ref_symbol.id;
    //_sas.push(ref_sar);
}

void tExist()
{
    auto t_sar = _sas.top();
    _sas.pop();

    writefln("tExist: %s",t_sar.name);

    if (!findSymbol(t_sar))
        throw new SemanticError(t_sar.line,"Invalid type ",t_sar.name);
}

void tPush(string type, size_t line)
{
    _sas.push(SAR(SARType.TYPE_SAR,type,line));
}

void vPush(string name, Scope scpe, size_t line)
{
    writefln("(%s) vPush: %s",line,name);

    //auto symbol = SymbolTable.findVariable(name,scpe,false);
    //if (!symbol)
    //    throw new SemanticError(line,"Could not find variable declaration for ",name);
    //auto id_sar = SAR(SARType.ID_SAR,name,scpe,line);
    //id_sar.id = symbol.id;
    //_sas.push(id_sar);
}

void while_sa()
{
    writeln("while_sa");
}

class SemanticError : Exception
{
    this(Args...)(size_t line, Args args)
    {
        super(text("(",line,"): ",args));
    }
}

private:
Stack!SAR _sas;
Stack!string _os;
size_t[string] _opWeights;

void processStack(lazy bool pred)
{
    while (pred) {
        doStackOp();
    }
}

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
            throw new Exception("Invalid assignment");
        break;
    case "+":
    case "-":
    case "*":
    case "/":
    case "%":
        if (lval.type != rval.type)
            throw new Exception("Incompatible types");
        auto symbol = new TempSymbol(text(lval.id,op,rval.id),lval.type);
        SymbolTable.add(symbol);
        _sas.push(SAR(SARType.TEMP_SAR,symbol.id));
        break;
    default:
        break;
    }
}

auto findSymbol(SAR sar, bool recurse=true)
{
    Symbol symbol;

    switch (sar.type) {
    case SARType.ID_SAR:
        symbol = SymbolTable.findVariable(sar.name,sar.scpe,recurse);
        break;
    case SARType.FUNC_SAR:
        symbol = SymbolTable.findMethod(sar.name,sar.scpe,recurse);
        break;
    case SARType.TYPE_SAR:
        symbol = SymbolTable.findClass(sar.name);
        break;
    default:
        throw new Exception("Invalid SARType for findSymbol");
    }

    return symbol;
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