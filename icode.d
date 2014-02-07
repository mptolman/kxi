import std.conv;
import std.stdio;
import container, symbol;

struct Quad
{
    string opcode;
    string opd1;
    string opd2;
    string opd3;
    string label;
}

void iMain()
{
    auto main = SymbolTable.findMethod("main",Scope(GLOBAL_SCOPE),false);
    if (!main)
        throw new Exception("iMain: Failed to locate main in symbol table");
    iFunc(main.id,"this");
    push("QUIT","0");
    iPushLabel(main.id);
}

void iFunc(string opd1, string opd2, string[] args=null)
{
    push("FRAME",opd1,opd2);
    foreach (a; args)
        push("PUSH",a);
    push("CALL",opd1);
}

void iFuncBody()
{
}

void iMathOp(string op, string opd1, string opd2, string opd3)
{
    auto lv = SymbolTable.getById(opd1);
    auto rv = SymbolTable.getById(opd2);

    if (op == "+" && cast(GlobalSymbol)rv && rv.type == "int")
        push("ADI",lv.id,rv.id,opd3);
    else if (op == "+" && cast(GlobalSymbol)lv && lv.type == "int")
        push("ADI",rv.id,lv.id,opd3);
    else
        iGenericOp(op,opd1,opd2,opd3);
}

void iGenericOp(string op, string opd1, string opd2, string opd3=null)
{
    push(_opMap[op],opd1,opd2,opd3);
}

void iVarRef(string opd1, string opd2, string opd3)
{
    push("REF",opd1,opd2,opd3);
}

void iIfCondition(string symId)
{
    auto label = makeLabel("SKIPIF");
    push("BF",symId,label);
    iPushLabel(label);
}

void iBeginWhile()
{
    auto label = makeLabel("BEGIN");
    //iPopLabel();
    iPushLabel(label);
}

void iWhile(string symId)
{
    auto label = makeLabel("ENDWHILE");
    push("BF",symId,label);
    iPushLabel(label);
}

void iEndWhile()
{
    auto endLabel = _labelStack.top();
    _labelStack.pop();
    auto startLabel = _labelStack.top();
    _labelStack.pop();

    push("JMP",startLabel);
    setLabel(endLabel);
}

void iElse()
{
    auto label = makeLabel("SKIPELSE");
    push("JMP",label);

    iPopLabel();
    iPushLabel(label);
}

void iArrRef(string opd1, string opd2, string opd3)
{

}

void printICode()
{
    foreach (q; _quads)
        writefln("%s\t%s %s %s %s",q.label,q.opcode,q.opd1,q.opd2,q.opd3);
}

void iPushLabel(string label)
{
    _labelStack.push(label);
}

void iPopLabel()
{
    if (!_currentLabel)
        _currentLabel = _labelStack.top();
    else
        backPatch(_labelStack.top(),_currentLabel);

    _labelStack.pop();
}

void setLabel(string label)
{
    if (_currentLabel)
        backPatch(_currentLabel,label);
    _currentLabel = label;
}

private:
Quad[] _quads;
string[string] _opMap;

string _currentLabel;
size_t[string] _labelCount;
Stack!string _labelStack;

void push(string opcode, string opd1, string opd2=null, string opd3=null)
{
    _quads ~= Quad(opcode,opd1,opd2,opd3,_currentLabel);
    _currentLabel = null;
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

auto makeLabel(string prefix = null)
{
    if (!prefix)
        prefix = "L";
    return text(prefix,++_labelCount[prefix]);
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