import std.array; // split
import std.conv;
import std.stdio;
import icode, stack, symbol;

enum SARType : byte
{
    ID_SAR,
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

    this(SARType type, string name, size_t line, string id=null)
    {
        this.type = type;
        this.name = name;
        this.line = line;
        this.id = id;
    }

    this(SARType type, string name, Scope scpe, size_t line, string id=null)
    {
        this.type = type;
        this.name = name;
        this.scpe = scpe;
        this.line = line;
        this.id = id;
    }
}

void arr_sa()
{
    writeln("arr_sa");

    auto index_sar = _sas.top();
    _sas.pop();

    auto id_sar = _sas.top();
    _sas.pop();

    auto index_symbol = findSymbol(index_sar);
    if (!index_symbol)
        throw new SemanticError(id_sar.line,"arr_sa: Failed to load index symbol");

    if (index_symbol.type != "int")
        throw new SemanticError(id_sar.line,"Invalid array index. Expected int, not ", index_symbol.type);

    id_sar.type = SARType.ARR_SAR;
    _sas.push(id_sar);
}

void atoi_sa()
{
    writeln("atoi_sa");

    auto sar = _sas.top();
    _sas.pop();

    auto symbol = findSymbol(sar);    
    if (!symbol)
        throw new SemanticError(sar.line,"atoi: Failed to load symbol");    
    if (symbol.type != "char")
        throw new SemanticError(sar.line,"Invalid argument type for atoi. Expected char, not ",symbol.type);

    try {

    }
    catch (Exception) {
        throw new SemanticError(sar.line,"atoi argument cannot be converted to integer");
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

    while (_os.top() != "[")
        doStackOp();
    _os.pop();
}

void cd_sa(string ctorName, Scope scpe, size_t line)
{
    writeln("cd_sa");

    auto className = scpe.top();
    if (ctorName != className)
        throw new SemanticError(line,"Constructor '",ctorName,"' does not match class name ",className);
}

void cin_sa()
{
    writeln("cin_sa");

    while (!_os.empty())
        doStackOp();

    auto sar = _sas.top();
    _sas.pop();

    auto symbol = findSymbol(sar);
    if (!symbol)
        throw new SemanticError(sar.line,"cin_sa: Failed to load symbol");

    if (symbol.type == "int" || symbol.type == "char") {
        // gen icode
    }
    else {
        throw new SemanticError(sar.line,"Invalid type for cin. Expected char or int, found ",symbol.type);
    }
}

void comma_sa()
{
    writeln("comma_sa");

    while (_os.top() != "(")
        doStackOp();
}

void cout_sa()
{
    writeln("cout_sa");

    while (!_os.empty())
        doStackOp();

    auto sar = _sas.top();
    _sas.pop();

    auto symbol = findSymbol(sar);
    if (!symbol)
        throw new SemanticError(sar.line,"cout_sa: Could not load symbol");

    if (symbol.type == "int" || symbol.type == "char") {
        // gen icode
    }
    else {
        throw new SemanticError(sar.line,"Invalid type for cout. Expected int or char, found ",symbol.type);
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

    while (_sas.top().type != SARType.BAL_SAR) {
        al_sar.params ~= _sas.top().id;
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

    auto al_sar = _sas.top(); 
    _sas.pop();
    
    auto id_sar = _sas.top(); 
    _sas.pop();

    auto func_sar = SAR(SARType.FUNC_SAR,id_sar.name,id_sar.scpe,id_sar.line);
    func_sar.params = al_sar.params.dup;
    _sas.push(func_sar);
}

void iExist()
{
    auto id_sar = _sas.top();
    _sas.pop();    

    writefln("iExist: %s",id_sar.name);

    auto symbol = findSymbol(id_sar);
    if (!symbol)
        throw new SemanticError(id_sar.line,"Identifier '",id_sar.name,"' does not exist in this scope");

    if (id_sar.type == SARType.FUNC_SAR) {
        checkFuncArgs(id_sar,cast(MethodSymbol)symbol);
    }
    else if (id_sar.type == SARType.ARR_SAR) {
        auto splitType = symbol.type.split(":");
        if (splitType[0] != "@")
            throw new SemanticError(id_sar.line,"Identifier '",id_sar.name,"' is not an array");
        symbol.type = splitType[1];
    }
    
    id_sar.id = symbol.id;
    _sas.push(id_sar);
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

void lPush(string value, size_t line)
{
    writefln("lPush: %s",value);

    auto lit_sar = SAR(SARType.LIT_SAR,value,line);
    auto symbol = findSymbol(lit_sar);
    if (!symbol)
        throw new SemanticError(line,"lPush: Failed to locate global symbol '",value,"'");

    lit_sar.id = symbol.id;
    _sas.push(lit_sar);
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
    auto class_symbol = SymbolTable.findClass(type_sar.name);
    if (!class_symbol)
        throw new SemanticError(type_sar.line,"Invalid type ",type_sar.name);

    // Make sure ctor exists
    auto scpe = class_symbol.scpe;
    scpe.push(class_symbol.name);
    auto ctor_symbol = cast(MethodSymbol)SymbolTable.findMethod(class_symbol.name,scpe,false);
    if (!ctor_symbol)
        throw new SemanticError(type_sar.line,"Type ",class_symbol.name," has no constructor");

    // Check arguments
    al_sar.name = type_sar.name;
    al_sar.line = type_sar.line;
    checkFuncArgs(al_sar,ctor_symbol);

    auto temp_symbol = new TempSymbol(type_sar.name,type_sar.name);
    auto new_sar = SAR(SARType.NEW_SAR,type_sar.name,type_sar.line,temp_symbol.id);
    new_sar.params = al_sar.params.dup;

    _sas.push(new_sar);
    SymbolTable.add(temp_symbol);
}

void oPush(string op, size_t line)
{    
    writefln("(%s) oPush: %s",line,op);

    while (!_os.empty && _opWeights[_os.top] >= _opWeights[op] && _opWeights[_os.top] != _opWeights["("]) {
        if (op == "=" && _os.top == "=")
            throw new SemanticError(line,"Nested assignment not supported");
        doStackOp();
    }

    _os.push(op);
}

void return_sa(Scope scpe, size_t line)
{
    writeln("return_sa");

    while (!_os.empty())
        doStackOp();

    auto methodName = scpe.top();
    scpe.pop();

    auto methodSymbol = SymbolTable.findMethod(methodName,scpe,false);
    if (!methodSymbol)
        throw new SemanticError(line,"return_sa: Failed to load method symbol");

    auto returnType = methodSymbol.type;

    if (_sas.empty()) {
        if (returnType != "void")
            throw new SemanticError(line,"Method '",methodName,"' must return value of type ",returnType);
    }
    else {
        auto ret_sar = _sas.top();
        _sas.pop();
        auto ret_symbol = findSymbol(ret_sar);
        if (!ret_symbol)
            throw new SemanticError(ret_sar.line,"return_sa: Failed to load return symbol");
        if (ret_symbol.type != returnType)
            throw new SemanticError(line,"Return statement for method '",methodName,"' must be of type ",returnType,", not ",ret_symbol.type);
    }
}

void rExist()
{
    auto member_sar = _sas.top();
    _sas.pop();
    
    auto obj_sar = _sas.top();
    _sas.pop();

    writefln("rExist: %s.%s",obj_sar.name,member_sar.name);

    auto obj_symbol = findSymbol(obj_sar);
    if (!obj_symbol)
        throw new SemanticError(obj_sar.line,"rExist: Failed to load object symbol ",obj_sar.id);

    auto class_symbol = SymbolTable.findClass(obj_symbol.type);
    if (!class_symbol)
        throw new SemanticError(obj_sar.line,"Identifier ",obj_symbol.name," is not a class type");

    auto class_scope = class_symbol.scpe;
    class_scope.push(class_symbol.name);

    member_sar.scpe = class_scope;
    auto member_symbol = findSymbol(member_sar,false);
    if (!member_symbol)
        throw new SemanticError(member_sar.line,"Member '",member_sar.name,"' does not exist in class '",class_symbol.name,"'");
    if (member_symbol.modifier != PUBLIC_MODIFIER && !class_scope.contains(obj_sar.scpe))
        throw new SemanticError(member_sar.line,"Member ",class_symbol.name,".",member_sar.name," is private");

    if (member_sar.type == SARType.FUNC_SAR)
        checkFuncArgs(member_sar,cast(MethodSymbol)member_symbol);

    auto ref_symbol = new RefSymbol(text(obj_symbol.name,'.',member_symbol.name),member_symbol.type);
    SymbolTable.add(ref_symbol);
    _sas.push(SAR(SARType.REF_SAR,ref_symbol.name,obj_sar.scpe,obj_sar.line,ref_symbol.id));
}

void tExist()
{
    auto type_sar = _sas.top();
    _sas.pop();

    writefln("tExist: %s",type_sar.name);

    if (!SymbolTable.findClass(type_sar.name))
        throw new SemanticError(type_sar.line,"Invalid type ",type_sar.name);
}

void tPush(string type, size_t line)
{
    _sas.push(SAR(SARType.TYPE_SAR,type,line));
}

void vPush(string name, Scope scpe, size_t line)
{
    writefln("(%s) vPush: %s",line,name);

    auto symbol = SymbolTable.findVariable(name,scpe,false);
    if (!symbol)
        throw new SemanticError(line,"Could not find variable declaration for ",name);

    _sas.push(SAR(SARType.ID_SAR,name,scpe,line,symbol.id));
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
immutable size_t[string] _opWeights;

void doStackOp()
{
    auto op = _os.top();
    _os.pop();
    writefln("Doing '%s' op",op);

    auto r_sar = _sas.top();
    _sas.pop();

    auto l_sar = _sas.top();
    _sas.pop();

    auto r_symbol = findSymbol(r_sar);
    auto l_symbol = findSymbol(l_sar);

    switch(op) {
    case "=":
        if (l_symbol.type != r_symbol.type)
            throw new SemanticError(l_sar.line,"Cannot assign type ",r_symbol.type," to type ",l_symbol.type);
        break;
    case "+":
    case "-":
    case "*":
    case "/":
    case "%":
        if (l_symbol.type != r_symbol.type)
            throw new SemanticError(l_sar.line,"Invalid operands for '",op,"' operator. Types do not match");
        auto temp_symbol = new TempSymbol(text(l_symbol.id,op,r_symbol.id),l_symbol.type);
        auto temp_sar = SAR(SARType.TEMP_SAR,temp_symbol.name,l_sar.scpe,l_sar.line,temp_symbol.id);
        _sas.push(temp_sar);
        SymbolTable.add(temp_symbol);
        break;
    default:
        throw new SemanticError(l_sar.line,"doStackOp: Invalid operation ",op);
    }
}

auto findSymbol(SAR sar, bool recurse=true)
{
    Symbol symbol;

    if (sar.id) {
        symbol = SymbolTable.get(sar.id);
    }
    else {
        switch (sar.type) {
        case SARType.ID_SAR:
        case SARType.ARR_SAR:
            symbol = SymbolTable.findVariable(sar.name,sar.scpe,recurse);
            break;
        case SARType.FUNC_SAR:
            symbol = SymbolTable.findMethod(sar.name,sar.scpe,recurse);
            break;
        case SARType.TYPE_SAR:
            symbol = SymbolTable.findClass(sar.name);
            break;
        case SARType.LIT_SAR:
            symbol = SymbolTable.findGlobal(sar.name);
            break;
        default:
            throw new SemanticError(sar.line,"findSymbol: Invalid SARType ",sar.type);
        }
    }

    return symbol;
}

auto checkFuncArgs(SAR sar, MethodSymbol methodSymbol)
{
    if (sar.params.length != methodSymbol.params.length)
        throw new SemanticError(sar.line,"Wrong number of arguments for method ",sar.name);

    foreach (i,a; sar.params.dup.reverse) {
        auto arg = SymbolTable.get(a);
        auto param = SymbolTable.get(methodSymbol.params[i]);
        if (arg.type != param.type)
            throw new SemanticError(sar.line,"Wrong parameter type. Found ",arg.type, "; expected ",param.type);        
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