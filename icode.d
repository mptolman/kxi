import std.conv;
import std.stdio;
import container, symbol;


//----------------------------
// Methods
//----------------------------
void initMain()
{
    auto main = SymbolTable.findMethod("main",Scope(GLOBAL_SCOPE),false);
    if (!main)
        throw new Exception("initMain: Failed to locate main in symbol table");
    funcCall(main.id,"this");
    addQuad("QUIT");
}

void funcCall(string symbolId, string opd1, string[] args=null)
{
    addQuad("FRAME",symbolId,opd1);
    foreach (a; args)
        addQuad("PUSH",a);
    addQuad("CALL",symbolId);
}

void funcBody(string method, Scope scpe)
{
    auto symbol = SymbolTable.findMethod(method,scpe,false);
    if (!symbol)
        throw new Exception(text("funcBody: Failed to find method ",method," in symbol table"));
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
void refVar(string opd1, string opd2, string opd3)
{
    addQuad("REF",opd1,opd2,opd3);
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
// operators
//----------------------------
void operator(string op, string opd1, string opd2, string opd3=null)
{
    auto lv = SymbolTable.getById(opd1);
    auto rv = SymbolTable.getById(opd2);

    if (op == "+" && cast(GlobalSymbol)rv && rv.type == "int")
        addQuad("ADI",lv.id,rv.id,opd3);
    else if (op == "+" && cast(GlobalSymbol)lv && lv.type == "int")
        addQuad("ADI",rv.id,lv.id,opd3);
    else
        addQuad(_opMap[op],opd1,opd2,opd3);
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

//void setLabel(Label label)
//{
//    if (_currentLabel && _currentLabelTakesPriority) {
//        backPatch(label,_currentLabel);
//    }
//    else if (_currentLabel) {
//        backPatch(_currentLabel,label);
//        _currentLabel = label;
//    }
//    else {
//        _currentLabel = label;
//    }
//}

//void pushLabel(string label, bool priority=false)
//{
//    pushLabel(Label(label,priority));
//}

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

private:
Quad[] _quads;

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

struct Label
{
    string label;
    bool priority;

    this(string label, bool priority=false)
    {
        this.label = label;
        this.priority = priority;
    }

    auto toString() const
    {
        return label;
    }

    auto opCast(T : bool)() const
    {
        return cast(bool)(label.length);
    }

    auto opEquals()(auto ref const Label l) const
    {
        return this.label == l.label;
    }
}

void addQuad(string opcode, string opd1=null, string opd2=null, string opd3=null)
{
    _quads ~= Quad(opcode,opd1,opd2,opd3,_currentLabel);
    _currentLabel = null;
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
        "=":    "MOV",
        "<<":   "WRITE",
        ">>":   "READ"
    ];
}