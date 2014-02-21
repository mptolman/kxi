import std.conv;
import std.stdio;
import container, symbol;

//----------------------------
// Methods
//----------------------------
void callMain()
{
    auto main = SymbolTable.findMethod("main", Scope(GLOBAL_SCOPE), false);
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

    addQuad("FRAME", methodId, opd1);
    foreach (arg; args)
        addQuad("PUSH", arg);
    addQuad("CALL", methodId);

    if (returnId && method.type != "void")
        addQuad("PEEK", returnId);
}

void funcBody(string methodName, Scope scpe)
{
    auto symbol = SymbolTable.findMethod(methodName, scpe, false);
    if (!symbol)
        throw new Exception(text("funcBody: Failed to find method ",methodName," in symbol table"));
    setLabel(symbol.id, true);
}

void funcReturn(string r=null)
{
    if (!r)
        addQuad("RTN");
    else
        addQuad("RETURN", r);
}

//----------------------------
// class member initialization
//----------------------------
void classBegin(string className)
{
    auto symbol = SymbolTable.findMethod("__"~className, Scope(GLOBAL_SCOPE), false);
    if (!symbol)
        throw new Exception("classBegin: Failed to load symbol for static initializer for class "~className);
    _classInitLabel = symbol.id;
}

void classInit(string className)
{
    auto symbol = SymbolTable.findMethod("__"~className, Scope(GLOBAL_SCOPE), false);
    if (!symbol)
        throw new Exception(text("classInit: Failed to load symbol for static initializer for class ",className));
    funcCall(symbol.id, "this");
}

void classEnd()
{
    addClassInitQuad("RTN");
    _quads ~= _classInitQuads;
    _classInitQuads = null;
}

//----------------------------
// if statement
//----------------------------
void ifCond(string symbolId)
{
    auto skipIf = makeLabel("SKIPIF");
    addQuad("BF", symbolId, skipIf);
    _labelStack.push(skipIf);
}

void elseCond()
{
    auto skipElse = makeLabel("SKIPELSE");
    addQuad("JMP", skipElse);

    setLabel(_labelStack.top());
    _labelStack.pop();

    _labelStack.push(skipElse);
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
    _labelStack.push(_currentLabel);
}

void whileCond(string symbolId)
{
    auto endWhile = makeLabel("ENDWHILE");
    addQuad("BF", symbolId, endWhile);
    _labelStack.push(endWhile);
}

void endWhile()
{
    auto endWhile = _labelStack.top();
    _labelStack.pop();

    auto begin = _labelStack.top();
    _labelStack.pop();

    addQuad("JMP", begin);
    setLabel(endWhile);
}

//----------------------------
// References
//----------------------------
void varRef(string opd1, string opd2, string opd3)
{
    addQuad("REF", opd1, opd2, opd3);
}

void arrRef(string opd1, string opd2, string opd3)
{
    addQuad("AEF", opd1, opd2, opd3);
}

//----------------------------
// I/O
//----------------------------
void read(string symId, string type)
{
    if (type == "int")
        addQuad("RDI", symId);
    else if (type == "char")
        addQuad("RDC", symId);
    else
        throw new Exception(text("icode.read: Invalid type ",type));
}

void write(string symId, string type)
{
    if (type == "int")
        addQuad("WRTI", symId);
    else if (type == "char")
        addQuad("WRTC", symId);
    else
        throw new Exception(text("icode.write: Invalid type ",type));
}

//----------------------------
// Operators
//----------------------------
void assignOp(string opd1, string opd2, bool memberInit=false)
{
    if (memberInit)
        addClassInitQuad("MOV",opd2,opd1);
    else
        addQuad("MOV",opd1,opd2);
}

void mathOp(string op, string opd1, string opd2, string opd3)
{
    switch (op) {
    case "+":
        addQuad("ADD", opd1, opd2, opd3);
        break;
    case "-":
        addQuad("SUB", opd1, opd2, opd3);
        break;
    case "*":
        addQuad("MUL", opd1, opd2, opd3);
        break;
    case "/":
        addQuad("DIV", opd1, opd2, opd3);
        break;
    default:
        throw new Exception("mathOp: Invalid math operator '"~op~"'");
    }
}

void relOp(string op, string opd1, string opd2, string opd3)
{
    switch (op) {
    case "<":
        addQuad("LT", opd1, opd2, opd3);
        break;
    case ">":
        addQuad("GT", opd1, opd2, opd3);
        break;
    case "<=":
        addQuad("LE", opd1, opd2, opd3);
        break;
    case ">=":
        addQuad("GE", opd1, opd2, opd3);
        break;
    case "==":
        addQuad("EQ", opd1, opd2, opd3);
        break;
    case "!=":
        addQuad("NE", opd1, opd2, opd3);
        break;
    default:
        throw new Exception("relOp: Invalid relational operator '"~op~"'");
    }
}

void boolOp(string op, string opd1, string opd2, string opd3)
{
    switch (op) {
    case "&&":
        addQuad("AND", opd1, opd2, opd3);
        break;
    case "||":
        addQuad("OR", opd1, opd2, opd3);
        break;
    default:
        throw new Exception("boolOp: Invalid boolean operator '"~op~"'");
    }
}

void genericOp(string op, string opd1, string opd2, string opd3)
{
    if (op !in _opMap)
        throw new Exception("genericOp: Invalid operator '"~op~"'");
    addQuad(_opMap[op], opd1, opd2, opd3);
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

auto getQuads()
{
    return _quads.idup;
}

void printICode()
{
    foreach (q; _quads)
        writefln("%s\t%s %s %s %s",q.label,q.opcode,q.opd1,q.opd2,q.opd3);
}

private:
Quad[] _quads;
Quad[] _classInitQuads;

string _currentLabel;
string _classInitLabel;
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

void addClassInitQuad(string opcode, string opd1=null, string opd2=null, string opd3=null)
{
    _classInitQuads ~= Quad(opcode,opd1,opd2,opd3,_classInitLabel);
    _classInitLabel = null;
}

auto makeLabel(string prefix=null)
{
    if (!prefix)
        prefix = "L";
    return text(prefix,++_labelCount[prefix]);
}

void setLabel(string label, bool priority=false)
{
    if (_currentLabel && _currentLabelTakesPriority) {        
        backPatch(label, _currentLabel);
    }
    else if (_currentLabel) {
        backPatch(_currentLabel, label);
        _currentLabel = label;
        _currentLabelTakesPriority = priority;
    }
    else {
        _currentLabel = label;
        _currentLabelTakesPriority = priority;
    }
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