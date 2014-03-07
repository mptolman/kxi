import std.conv;
import std.stdio;
import container, global, symbol;

bool _insideClass;
string _line;

struct Quad
{
    string opcode;
    string opd1;
    string opd2;
    string opd3;
    string label;
}

//----------------------------
// Methods
//----------------------------
void funcCall(string symId, string opd1, string[] args=null, string returnId=null)
{
    auto method = SymbolTable.getById(symId);
    if (!method)
        throw new Exception("funcCall: Failed to load method symbol");

    addQuad("FRAME", symId, opd1);

    foreach (arg; args.dup.reverse)
        addQuad("PUSH", arg);

    addQuad("CALL", symId);

    if (returnId && method.type != "void")
        addQuad("PEEK", returnId);
}

void funcBegin()
{
    setLabel(currentMethod.id, true);
    addQuad("FUNC", currentMethod.id);
}

void funcReturn(string r=null)
{
    if (!r)
        addQuad("RTN");
    else
        addQuad("RETURN", r);
}

void terminate()
{
    addQuad("QUIT");
}

//----------------------------
// Class member initialization
//----------------------------
void classBegin()
{
    _classInitLabel = currentStaticInit.id;
    addStaticInitQuad("FUNC", currentStaticInit.id);
}

void classEnd()
{    
    addStaticInitQuad("RTN");
    _quads ~= _classInitQuads;
    _classInitQuads = null;
}

//----------------------------
// if statement
//----------------------------
void ifCond(string symId)
{
    auto skipIf = makeLabel("SKIPIF");
    addQuad("BF", symId, skipIf);
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

void whileCond(string symId)
{
    auto endWhile = makeLabel("ENDWHILE");
    addQuad("BF", symId, endWhile);
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
void read(string symId)
{
    addQuad("READ", symId);
}

void write(string symId)
{
    addQuad("WRITE", symId);
}

//----------------------------
// Operators
//----------------------------
void assignOp(string opd1, string opd2)
{
    string opcode = "MOV";
    auto rhs = SymbolTable.getById(opd1);

    if (cast(GlobalSymbol)rhs) {
        switch (rhs.type) {
        case "int":
            opcode = "MOVI";
            opd1   = rhs.name;
            break;
        case "bool":
            opcode = "MOVI";
            opd1   = rhs.name == "true" ? "1" : "0";
            break;
        case "null":
            opcode = "MOVI";
            opd1   = "0";
            break;
        default:
            break;
        }
    }

    addQuad(opcode, opd1, opd2);
}

void mathOp(string op, string opd1, string opd2, string opd3)
{
    auto lhs = SymbolTable.getById(opd1);
    auto rhs = SymbolTable.getById(opd2);

    switch (op) {
    case "+":
        if (cast(GlobalSymbol)rhs && rhs.type == "int")            
            addQuad("ADI", opd1, rhs.name, opd3);
        else if (cast(GlobalSymbol)lhs && lhs.type == "int")
            addQuad("ADI", opd2, lhs.name, opd3);
        else
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

void atoi(string opd1, string opd2)
{
    addQuad("ATOI", opd1, opd2);
}

void itoa(string opd1, string opd2)
{
    addQuad("ITOA", opd1, opd2);
}

//----------------------------
// Memory allocation
//----------------------------
void malloc(size_t size, string addrId)
{
    addQuad("NEWI", to!string(size), addrId);
}

void malloc(string sizeId, string addrId)
{
    addQuad("NEW", sizeId, addrId);
}

auto makeLabel(string prefix=null)
{
    static size_t[string] _labelCount;
    
    if (!prefix)
        prefix = "L";
    return text(prefix,++_labelCount[prefix]);
}

auto getQuads()
{
    return _quads;
}

private:
Quad[] _quads;
Quad[] _classInitQuads;

string _currentLabel;
string _classInitLabel;
bool _currentLabelTakesPriority;

Stack!string _labelStack;

void addQuad(string opcode, string opd1=null, string opd2=null, string opd3=null)
{
    if (_insideClass) {
        addStaticInitQuad(opcode,opd1,opd2,opd3);
    }
    else {
        if (global.kxiIsNew) {
            _quads ~= Quad("COMMENT",global.kxi);
            global.kxiIsNew = false;
        }
        _quads ~= Quad(opcode,opd1,opd2,opd3,_currentLabel);
        _currentLabel = null;
    }
}

void addStaticInitQuad(string opcode, string opd1=null, string opd2=null, string opd3=null)
{
    _classInitQuads ~= Quad(opcode,opd1,opd2,opd3,_classInitLabel);
    _classInitLabel = null;
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
}