import std.array; // split
import std.conv;
import std.stdio;
import std.string;
import container, exception, global, icode, scpe, symbol;

enum SARType : byte
{
    AL_SAR,
    ARR_SAR,
    BAL_SAR,
    FUNC_SAR,
    ID_SAR,
    LIT_SAR,
    NEW_SAR,
    SID_SAR,
    TEMP_SAR,
    TYPE_SAR
}

struct SAR
{
    SARType sarType;
    string name;
    string id;
    Scope scpe;
    size_t line;
    string[] args;

    this(SARType sarType)
    {
        this.sarType = sarType;
    }

    this(SARType sarType, string id)
    {
        this.sarType = sarType;
        this.id = id;
    }

    this(SARType sarType, string name, size_t line, string id=null)
    {
        this.sarType = sarType;
        this.name = name;
        this.line = line;
        this.id = id;
    }

    this(SARType sarType, string name, Scope scpe, size_t line, string id=null)
    {
        this.sarType = sarType;
        this.name = name;
        this.scpe = scpe;
        this.line = line;
        this.id = id;
    }
}

void arr_sa()
{
    debug writeln("arr_sa");

    auto index_sar = _sas.top();
    _sas.pop();

    auto id_sar = _sas.top();
    _sas.pop();

    auto index_symbol = SymbolTable.getById(index_sar.id);
    if (!index_symbol)
        throw new SemanticError(id_sar.line,"arr_sa: Failed to load index symbol");
    if (index_symbol.type != "int")
        throw new SemanticError(id_sar.line,"Invalid array index. Expected int, not ", index_symbol.type);

    _sas.push(SAR(SARType.ARR_SAR,id_sar.name,id_sar.scpe,id_sar.line,index_symbol.id));
}

void atoi_sa()
{
    debug writeln("atoi_sa");

    auto sar = _sas.top();
    _sas.pop();

    auto symbol = SymbolTable.getById(sar.id);
    if (!symbol)
        throw new SemanticError(sar.line,"atoi: Failed to load symbol");    
    if (symbol.type != "char")
        throw new SemanticError(sar.line,"Invalid argument for atoi. Expected char, not ",symbol.type);

    auto temp = global.currentMethod.addTemporary("int");
    _sas.push(SAR(SARType.TEMP_SAR,sar.name,sar.line,temp.id));

    icode.atoi(symbol.id, temp.id);
}

void bal_sa()
{
    debug writeln("bal_sa");

    _sas.push(SAR(SARType.BAL_SAR));
}

void cbracket_sa()
{
    debug writeln("cbracket_sa");

    while (_os.top() != "[")
        doStackOp();
    _os.pop();
}

void cd_sa()
{
    debug writeln("cd_sa");

    if (global.currentMethod.name != global.currentClass.name)
        throw new SemanticError(global.currentLineNum,"Constructor '",global.currentMethod.name,"' does not match class name ",global.currentClass.name);
}

void cin_sa()
{
    debug writeln("cin_sa");

    while (!_os.empty)
        doStackOp();

    auto sar = _sas.top();
    _sas.pop();

    auto symbol = SymbolTable.getById(sar.id);
    if (!symbol)
        throw new SemanticError(sar.line,"cin_sa: Failed to load symbol");
    if (symbol.type != "int" && symbol.type != "char")
        throw new SemanticError(sar.line,"Invalid type for cin. Expected char or int, not ",symbol.type);

    icode.read(symbol.id);
}

void comma_sa()
{
    debug writeln("comma_sa");

    while (_os.top() != "(")
        doStackOp();
}

void cout_sa()
{
    debug writeln("cout_sa");

    while (!_os.empty)
        doStackOp();

    auto sar = _sas.top();
    _sas.pop();

    auto symbol = SymbolTable.getById(sar.id);
    if (!symbol)
        throw new SemanticError(sar.line,"cout_sa: Failed to load symbol");
    if (symbol.type != "int" && symbol.type != "char")
        throw new SemanticError(sar.line,"Invalid type for cout. Expected char or int, not ",symbol.type);

    icode.write(symbol.id);
}

void cparen_sa()
{
    debug writeln("cparen_sa");

    while (_os.top() != "(")
        doStackOp();
    _os.pop();
}

void eal_sa()
{
    debug writeln("eal_sa");

    auto al_sar = SAR(SARType.AL_SAR);

    while (_sas.top().sarType != SARType.BAL_SAR) {
        al_sar.args ~= _sas.top().id;
        _sas.pop(); 
    }

    _sas.pop();
    _sas.push(al_sar);
}

void eoe_sa()
{
    debug writeln("eoe_sa");

    while (!_os.empty)
        doStackOp();
    _sas.clear();
}

void func_sa()
{
    debug writeln("func_sa");

    auto al_sar = _sas.top(); 
    _sas.pop();
    
    auto id_sar = _sas.top(); 
    _sas.pop();

    auto func_sar = SAR(SARType.FUNC_SAR,id_sar.name,id_sar.scpe,id_sar.line);
    func_sar.args = al_sar.args;
    _sas.push(func_sar);
}

void iExist()
{
    auto id_sar = _sas.top();
    _sas.pop();

    debug writefln("iExist: %s",id_sar.name);

    Symbol tempSymbol;

    switch (id_sar.sarType) {
    case SARType.ID_SAR:
        tempSymbol = SymbolTable.findVariable(id_sar.name, id_sar.scpe);
        if (!tempSymbol)
            throw new SemanticError(id_sar.line,"Variable '",id_sar.name,"' does not exist in this scope");
        break;
    case SARType.FUNC_SAR:
        auto methodSymbol = cast(MethodSymbol)SymbolTable.findMethod(id_sar.name, id_sar.scpe);
        if (!methodSymbol)
            throw new SemanticError(id_sar.line,"Method '",id_sar.name,"' does not exist in this scope");

        checkFuncArgs(id_sar, methodSymbol);

        tempSymbol = global.currentMethod.addTemporary(methodSymbol.type);

        icode.funcCall(methodSymbol.id, "this", id_sar.args, tempSymbol.id);
        break;
    case SARType.ARR_SAR:
        auto varSymbol = SymbolTable.findVariable(id_sar.name, id_sar.scpe);
        if (!varSymbol)
            throw new SemanticError(id_sar.line,"Variable '",id_sar.name,"' does not exist in this scope");

        auto splitType = varSymbol.type.split(":");
        if (splitType[0] != "@")
            throw new SemanticError(id_sar.line,"Identifier '",id_sar.name,"' is not an array");

        tempSymbol = global.currentMethod.addReference(text(id_sar.name,'[',id_sar.id,']'),splitType[1]);

        icode.arrRef(varSymbol.id, id_sar.id, tempSymbol.id);
        break;
    default:
        throw new SemanticError(id_sar.line,"iExist: Invalid SARType ",id_sar.sarType);
        break;
    }
    
    id_sar.id = tempSymbol.id;
    _sas.push(id_sar);
}

void if_sa()
{
    debug writeln("if_sa");
    
    if (_sas.empty())
        throw new SemanticError(global.currentLineNum,"Expected boolean expression");

    auto sar = _sas.top();
    _sas.pop();

    auto symbol = SymbolTable.getById(sar.id);
    if (!symbol)
        throw new SemanticError(global.currentLineNum,"if_sa: Failed to load symbol");
    if (symbol.type != "bool")
        throw new SemanticError(global.currentLineNum,"Expected boolean expression, not ",symbol.type);

    icode.ifCond(symbol.id);
}

void iPush(string name)
{
    debug writefln("(%s) iPush: %s",global.currentLineNum,name);

    _sas.push(SAR(SARType.ID_SAR,name,global.currentScope,global.currentLineNum));
}

void itoa_sa()
{
    debug writeln("itoa_sa");

    auto sar = _sas.top();
    _sas.pop();

    auto symbol = SymbolTable.getById(sar.id);
    if (!symbol)
        throw new SemanticError(sar.line,"itoa: Failed to load symbol");
    if (symbol.type != "int")
        throw new SemanticError(sar.line,"Invalid argument for itoa. Expected int, not ",symbol.type);

    auto temp = global.currentMethod.addTemporary("char");
    _sas.push(SAR(SARType.TEMP_SAR,sar.name,sar.line,temp.id));

    icode.itoa(symbol.id, temp.id);
}

void lPush(Symbol symbol)
{
    debug writefln("lPush: %s",symbol.name);

    _sas.push(SAR(SARType.LIT_SAR,symbol.name,global.currentLineNum,symbol.id));
}

void newarr_sa()
{
    debug writeln("newarr_sa");

    auto size_sar = _sas.top();
    _sas.pop();

    auto type_sar = _sas.top();
    _sas.pop();

    auto arrsz_symbol = SymbolTable.getById(size_sar.id);
    if (!arrsz_symbol)
        throw new SemanticError(size_sar.line,"newarr_sa: Failed to load symbol");
    if (arrsz_symbol.type != "int")
        throw new SemanticError(size_sar.line,"Invalid array size. Expected int, not ",arrsz_symbol.type);

    size_t elemsz;
    if (type_sar.name == "char")
        elemsz = char.sizeof;
    else
        elemsz = int.sizeof;

    auto elemsz_symbol  = SymbolTable.addGlobal(to!string(elemsz), "int");
    auto totalsz_symbol = global.currentMethod.addTemporary("int");
    auto arr_symbol     = global.currentMethod.addTemporary("@:"~type_sar.name);

    icode.mathOp("*", elemsz_symbol.id, arrsz_symbol.id, totalsz_symbol.id);
    icode.malloc(totalsz_symbol.id, arr_symbol.id);

    _sas.push(SAR(SARType.NEW_SAR, arr_symbol.name, type_sar.line, arr_symbol.id));
}

void newobj_sa()
{
    debug writeln("newobj_sa");

    auto al_sar = _sas.top();
    _sas.pop();
    
    auto type_sar = _sas.top();
    _sas.pop();

    // Make sure type exists
    auto class_symbol = cast(ClassSymbol)SymbolTable.findClass(type_sar.name);
    if (!class_symbol)
        throw new SemanticError(type_sar.line,"Invalid class type ",type_sar.name);

    // Make sure ctor exists
    auto scpe = class_symbol.scpe;
    scpe.push(class_symbol.name);
    auto ctor_symbol = cast(MethodSymbol)SymbolTable.findMethod(class_symbol.name, scpe, false);
    if (!ctor_symbol)
        throw new SemanticError(type_sar.line,"Type ",class_symbol.name," has no constructor");

    // Check arguments
    al_sar.name = type_sar.name; // For descriptive errors in checkFuncArgs
    al_sar.line = type_sar.line;
    checkFuncArgs(al_sar, ctor_symbol);

    // Allocate memory for object
    auto mem_symbol = global.currentMethod.addTemporary(type_sar.name);
    icode.malloc(class_symbol.offset, mem_symbol.id);

    // Call constructor
    auto temp_symbol = global.currentMethod.addTemporary(type_sar.name);
    icode.funcCall(ctor_symbol.id, mem_symbol.id, al_sar.args, temp_symbol.id);

    auto new_sar = SAR(SARType.NEW_SAR, type_sar.name, type_sar.line, temp_symbol.id);
    new_sar.args = al_sar.args;

    _sas.push(new_sar);
}

void oPush(string op)
{    
    debug writefln("(%s) oPush: %s",global.currentLineNum,op);

    while (!_os.empty && _opWeights[_os.top] >= _opWeights[op] && _opWeights[_os.top] != _opWeights["("]) {
        if (op == "=" && _os.top == "=")
            throw new SemanticError(global.currentLineNum,"Nested assignment not supported");
        doStackOp();
    }

    _os.push(op);
}

void return_sa()
{
    debug writeln("return_sa");

    while (!_os.empty())
        doStackOp();

    auto expectedRtnType = global.currentMethod.type;

    if (_sas.empty) {
        if (expectedRtnType != "void")
            throw new SemanticError(global.currentLineNum,"Method ",global.currentMethod.name," must return ",expectedRtnType,", not void");

        icode.funcReturn();
    }
    else {
        auto ret_sar = _sas.top();
        _sas.pop();

        auto ret_symbol = SymbolTable.getById(ret_sar.id);
        if (!ret_symbol)
            throw new SemanticError(global.currentLineNum,"return_sa: Failed to load return symbol");
        if (ret_symbol.type != expectedRtnType)
            throw new SemanticError(global.currentLineNum,"Return statement for method ",global.currentMethod.name," must be of type ",expectedRtnType,", not ",ret_symbol.type);

        icode.funcReturn(ret_symbol.id);        
    }
}

void rExist()
{
    auto member_sar = _sas.top();
    _sas.pop();
    
    auto obj_sar = _sas.top();
    _sas.pop();

    debug writefln("rExist: %s.%s",obj_sar.name,member_sar.name);

    // Load object symbol
    auto obj_symbol = SymbolTable.getById(obj_sar.id);
    if (!obj_symbol)
        throw new SemanticError(obj_sar.line,"rExist: Failed to load object symbol ",obj_sar.id);

    // Load class symbol
    auto class_symbol = SymbolTable.findClass(obj_symbol.type);
    if (!class_symbol)
        throw new SemanticError(obj_sar.line,"Identifier ",obj_symbol.name," is not a class type");

    auto class_scope = class_symbol.scpe;
    class_scope.push(class_symbol.name);

    Symbol ref_symbol;

    switch (member_sar.sarType) {
    case SARType.ID_SAR:
    case SARType.ARR_SAR:
        auto varSymbol = SymbolTable.findVariable(member_sar.name, class_scope, false);
        if (!varSymbol)
            throw new SemanticError(member_sar.line,"Variable ",member_sar.name," does not exist in class ",class_symbol.name);
        if (varSymbol.modifier != PUBLIC_MODIFIER && !class_scope.contains(obj_sar.scpe))
            throw new SemanticError(member_sar.line,"Variable ",class_symbol.name,".",member_sar.name," is private");

        ref_symbol = global.currentMethod.addReference(text(obj_sar.name,'.',member_sar.name), varSymbol.type);

        if (member_sar.sarType == SARType.ARR_SAR)
            icode.arrRef(varSymbol.id, member_sar.id, ref_symbol.id);
        else
            icode.varRef(obj_symbol.id, varSymbol.id, ref_symbol.id);
        break;
    case SARType.FUNC_SAR:
        auto methodSymbol = cast(MethodSymbol)SymbolTable.findMethod(member_sar.name, class_scope, false);
        if (!methodSymbol)
            throw new SemanticError(member_sar.line,"Method ",member_sar.name," does not exist in class ",class_symbol.name);
        if (methodSymbol.modifier != PUBLIC_MODIFIER && !class_scope.contains(obj_sar.scpe))
            throw new SemanticError(member_sar.line,"Method ",class_symbol.name,".",member_sar.name," is private");

        checkFuncArgs(member_sar, methodSymbol);

        ref_symbol = global.currentMethod.addTemporary(methodSymbol.type);

        icode.funcCall(methodSymbol.id, obj_symbol.id, member_sar.args, ref_symbol.id);
        break;

    default:
        throw new SemanticError(member_sar.line,"rExist: Invalid SARType ",member_sar.sarType);
    }

    member_sar.id = ref_symbol.id;
    _sas.push(member_sar);
}

void tExist()
{
    auto type_sar = _sas.top();
    _sas.pop();

    debug writefln("tExist: %s",type_sar.name);

    if (!SymbolTable.findClass(type_sar.name))
        throw new SemanticError(type_sar.line,"Invalid type ",type_sar.name);
}

void tPush(string type)
{
    debug writefln("(%s) tPush: %s",global.currentLineNum,type);
    
    _sas.push(SAR(SARType.TYPE_SAR,type,global.currentLineNum));
}

void vPush(Symbol symbol)
{
    debug writefln("(%s) vPush: %s",global.currentLineNum,symbol.name);

    _sas.push(SAR(SARType.ID_SAR,symbol.type,symbol.scpe,global.currentLineNum,symbol.id));
}

void while_sa()
{
    debug writeln("while_sa");

    if (_sas.empty())
        throw new SemanticError(global.currentLineNum,"Expected boolean expression");

    auto sar = _sas.top();
    _sas.pop();

    auto symbol = SymbolTable.getById(sar.id);
    if (!symbol)
        throw new SemanticError(global.currentLineNum,"while_sa: Failed to load symbol");
    if (symbol.type != "bool")
        throw new SemanticError(global.currentLineNum,"Expected boolean expression, not ",symbol.type);

    icode.whileCond(symbol.id);
}

private:    
Stack!SAR _sas;
Stack!string _os;
immutable size_t[string] _opWeights;

void doStackOp()
{
    auto op = _os.top();
    _os.pop();
    debug writefln("Doing '%s' op",op);

    auto r_sar = _sas.top();
    _sas.pop();

    auto l_sar = _sas.top();
    _sas.pop();

    auto r_symbol = SymbolTable.getById(r_sar.id);
    if (!r_symbol)
        throw new SemanticError(l_sar.line,"doStackOp: Failed to load rval symbol");

    auto l_symbol = SymbolTable.getById(l_sar.id);
    if (!l_symbol)
        throw new SemanticError(l_sar.line,"doStackOp: Failed to load lval symbol");

    switch(op) {
    case "=":
        switch (l_sar.sarType) {
        case SARType.ID_SAR:
        case SARType.ARR_SAR:
            break;
        default:            
            throw new SemanticError(l_sar.line,"Invalid left-hand operand for assignment statement");
        }

        if (l_symbol.type != r_symbol.type) {
            if (SymbolTable.findClass(l_symbol.type) && r_symbol.type == "null") { /* allow */ }                
            else
                throw new SemanticError(l_sar.line,"Cannot assign type ",r_symbol.type," to type ",l_symbol.type);
        }

        icode.assignOp(r_symbol.id, l_symbol.id);
        break;
    case "+":
    case "-":
    case "*":
    case "/":
        if (l_symbol.type != r_symbol.type)
            throw new SemanticError(l_sar.line,"Invalid operands for '",op,"' operator. Types do not match");

        auto temp_symbol = global.currentMethod.addTemporary(l_symbol.type);
        _sas.push(SAR(SARType.TEMP_SAR,temp_symbol.name,l_sar.line,temp_symbol.id));

        icode.mathOp(op, l_symbol.id, r_symbol.id, temp_symbol.id);
        break;
    case "<":
    case ">":
    case "<=":
    case ">=":
    case "==":
    case "!=":
        if (l_symbol.type != r_symbol.type) {
            if ((op == "==" || op == "!=") && SymbolTable.findClass(l_symbol.type) && r_symbol.type == "null") { /* allow */ }
            else
                throw new SemanticError(l_sar.line,"Cannot compare objects of different types. Found ",l_symbol.type," and ",r_symbol.type);
        }

        auto temp_symbol = global.currentMethod.addTemporary("bool");
        _sas.push(SAR(SARType.TEMP_SAR,temp_symbol.name,l_sar.line,temp_symbol.id));

        icode.relOp(op, l_symbol.id, r_symbol.id, temp_symbol.id);
        break;
    case "||":
    case "&&":
        if (l_symbol.type != "bool" || l_symbol.type != r_symbol.type)
            throw new SemanticError(l_sar.line,"Invalid boolean expression");

        auto temp_symbol = global.currentMethod.addTemporary("bool");
        _sas.push(SAR(SARType.TEMP_SAR,temp_symbol.name,l_sar.line,temp_symbol.id));

        icode.boolOp(op, l_symbol.id, r_symbol.id, temp_symbol.id);
        break;
    default:
        throw new SemanticError(l_sar.line,"doStackOp: Invalid operation ",op);
    }
}

auto checkFuncArgs(SAR sar, MethodSymbol methodSymbol)
{
    if (sar.args.length != methodSymbol.params.length)
        throw new SemanticError(sar.line,"Wrong number of arguments for method ",sar.name);

    foreach (i,argSymId; sar.args.dup.reverse) {
        auto arg   = SymbolTable.getById(argSymId);
        auto param = SymbolTable.getById(methodSymbol.params[i]);        
        if (arg.type != param.type)
            throw new SemanticError(sar.line,"Wrong argument type. Found ",arg.type,"; expected ",param.type);        
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