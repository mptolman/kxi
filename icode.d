import std.conv;
import std.stdio;
import container, symbol;

//----------------------------
// Methods
//----------------------------
void callMain()
{
    auto main = SymbolTable.findMethod("main",Scope(GLOBAL_SCOPE),false);
    if (!main)
        throw new Exception("initMain: Failed to locate main in symbol table");
    funcCall(main.id,"this");
    addQuad("QUIT");
}

void funcCall(string methodId, string opd1, string[] args=null, string returnId=null)
{
    auto method = SymbolTable.getById(methodId);
    if (!method)
        throw new Exception("funcCall: Failed to load method symbol");

    addQuad("FRAME",methodId,opd1);
    foreach (a; args)
        addQuad("PUSH",a);
    addQuad("CALL",methodId);

    if (returnId && method.type != "void")
        addQuad("PEEK",returnId);
}

void funcBody(string methodName, Scope scpe)
{
    auto symbol = SymbolTable.findMethod(methodName,scpe,false);
    if (!symbol)
        throw new Exception(text("funcBody: Failed to find method ",methodName," in symbol table"));
    setLabel(symbol.id,true);
}

void funcReturn(string r=null)
{
    if (!r)
        addQuad("RTN");
    else
        addQuad("RETURN",r);
}

//----------------------------
// class member initialization
//----------------------------
void staticInit(string className)
{
    auto symbol = SymbolTable.findMethod("__"~className,Scope(GLOBAL_SCOPE),false);
    if (!symbol)
        throw new Exception(text("staticInit: Failed to load symbol for static initializer for class ",className));
    funcCall(symbol.id, "this");
}

void endOfClass()
{
    _quads ~= _classInitQuads;
    _classInitQuads = null;
}

//----------------------------
// if statement
//----------------------------
void ifCond(string symbolId)
{
    auto skipIf = makeLabel("SKIPIF");
    addQuad("BF",symbolId,skipIf);
    pushLabel(skipIf);
}

void elseCond()
{
    auto skipElse = makeLabel("SKIPELSE");
    addQuad("JMP",skipElse);

    setLabel(_labelStack.top());
    _labelStack.pop();
    pushLabel(skipElse);
}

void endIf()
{
    setLabel(_labelStack.top());
    _labelStack.pop();
}

//----------------------------
// while statement
//----------------------------
void beginWhile()
{
    setLabel(makeLabel("BEGIN"));
    pushLabel(_currentLabel);
}

void whileCond(string symbolId)
{
    auto endWhile = makeLabel("ENDWHILE");
    addQuad("BF",symbolId,endWhile);
    pushLabel(endWhile);
}

void endWhile()
{
    auto endWhile = _labelStack.top();
    _labelStack.pop();

    auto begin = _labelStack.top();
    _labelStack.pop();
    addQuad("JMP",begin);

    setLabel(endWhile);
}

//----------------------------
// References
//----------------------------
void varRef(string opd1, string opd2, string opd3)
{
    addQuad("REF",opd1,opd2,opd3);
}

void arrRef(string opd1, string opd2, string opd3)
{
    addQuad("AEF",opd1,opd2,opd3);
}

//----------------------------
// I/O
//----------------------------
void read(string symId, string type)
{
    if (type == "int")
        addQuad("RDI",symId);
    else if (type == "char")
        addQuad("RDC",symId);
    else
        throw new Exception(text("read: Invalid type ",type));
}

void write(string symId, string type)
{
    if (type == "int")
        addQuad("WRTI",symId);
    else if (type == "char")
        addQuad("WRTC",symId);
    else
        throw new Exception(text("write: Invalid type ",type));
}

//----------------------------
// Operators
//----------------------------
void operator(string op, string opd1, string opd2, string opd3=null)
{
    auto lv = SymbolTable.getById(opd1);
    auto rv = SymbolTable.getById(opd2);

    switch (op) {
    case "=":
        if (cast(IVarSymbol)rv)
            addStaticQuad("MOV",opd1,opd2);
        else
            addQuad("MOV",opd1,opd2);
        break;
    default:
        throw new Exception(text("icode.operator: Invalid operator ",op));
    }
    //if (op == "+" && cast(GlobalSymbol)rv && rv.type == "int")
    //    addQuad("ADI",lv.id,rv.name,opd3);
    //else if (op == "+" && cast(GlobalSymbol)lv && lv.type == "int")
    //    addQuad("ADI",rv.id,lv.name,opd3);
    //else if (op == "=" && cast(GlobalSymbol)lv && lv.type == "int")
    //    addQuad("MOVI",lv.name,rv.id);
}

//----------------------------
// Memory allocation
//----------------------------
void malloc(size_t size, string addrId)
{
    addQuad("NEWI",to!string(size),addrId);
}

void malloc(string sizeId, string addrId)
{
    addQuad("NEW",sizeId,addrId);
}

void setLabel(string label, bool priority=false)
{
    if (_currentLabel && _currentLabelTakesPriority) {        
        backPatch(label,_currentLabel);
    }
    else if (_currentLabel) {
        backPatch(_currentLabel,label);
        _currentLabel = label;
        _currentLabelTakesPriority = priority;
    }
    else {
        _currentLabel = label;
        _currentLabelTakesPriority = priority;
    }
}

void pushLabel(string label)
{
    _labelStack.push(label);
}

void popLabel()
{
    setLabel(_labelStack.top());
    _labelStack.pop();
}

void printICode()
{
    foreach (q; _quads)
        writefln("%s\t%s %s %s %s",q.label,q.opcode,q.opd1,q.opd2,q.opd3);
}

auto getQuads()
{
    return _quads.idup;
}

private:
Quad[] _quads;
Quad[] _classInitQuads;

string _currentLabel;
bool _currentLabelTakesPriority;

Stack!string _labelStack;
size_t[string] _labelCount;

string[string] _opMap;

struct Quad
{
    string opcode;
    string opd1;
    string opd2;
    string opd3;
    string label;
}

void addQuad(string opcode, string opd1=null, string opd2=null, string opd3=null)
{
    _quads ~= Quad(opcode,opd1,opd2,opd3,_currentLabel);
    _currentLabel = null;
}

void addStaticQuad(string opcode, string opd1=null, string opd2=null, string opd3=null)
{
    _classInitQuads ~= Quad(opcode,opd1,opd2,opd3);
}

auto makeLabel(string prefix=null)
{
    if (!prefix)
        prefix = "L";
    return text(prefix,++_labelCount[prefix]);
}

void backPatch(string oldLabel, string newLabel)
{
    foreach (ref q; _quads) {
        q.opd1 = q.opd1 == oldLabel ? newLabel : q.opd1;
        q.opd2 = q.opd2 == oldLabel ? newLabel : q.opd2;
        q.opd3 = q.opd3 == oldLabel ? newLabel : q.opd3;
        q.label = q.label == oldLabel ? newLabel : q.label;
    }
}

static this()
{
    _labelStack = new Stack!string;

    _opMap = [
        "+":    "ADD",
        "-":    "SUB",
        "/":    "DIV",
        "*":    "MUL",
        "<":    "LT",
        ">":    "GT",
        "<=":   "LE",
        ">=":   "GE",
        "==":   "EQ",
        "!=":   "NE",
        "&&":   "AND",
        "||":   "OR",
        "=":    "MOV"
    ];
}