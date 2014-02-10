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

}

void iOperator(string op, string opd1, string opd2, string opd3=null)
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
//void iMain()
//{
//    auto main = SymbolTable.findMethod("main",Scope(GLOBAL_SCOPE),false);
//    if (!main)
//        throw new Exception("iMain: Failed to locate main in symbol table");
//    iFunc(main.id,"this");
//    push("QUIT","0");
//    iPushLabel(main.id,true);
//}

void iFunc(string opd1, string opd2, string[] args=null)
{
    addQuad("FRAME",opd1,opd2);
    foreach (a; args)
        addQuad("PUSH",a);
    addQuad("CALL",opd1);
}

//void iFuncBody()
//{
//}

//void iVarRef(string opd1, string opd2, string opd3)
//{
//    push("REF",opd1,opd2,opd3);
//}

//void iIfCondition(string symId)
//{
//    auto label = makeLabel("SKIPIF");
//    addQuad("BF",symId,label);
//    iPushLabel(label);
//}

//void iBeginWhile()
//{
//    auto label = makeLabel("BEGIN");
//    //iPopLabel();
//    iPushLabel(label);
//}

//void iWhile(string symId)
//{
//    auto label = makeLabel("ENDWHILE");
//    push("BF",symId,label);
//    iPushLabel(label);
//}

//void iEndWhile()
//{
//    auto endLabel = _labelStack.top();
//    _labelStack.pop();
//    auto startLabel = _labelStack.top();
//    _labelStack.pop();

//    push("JMP",startLabel);
//    setLabel(endLabel);
//}

//void iElse()
//{
//    auto label = makeLabel("SKIPELSE");
//    push("JMP",label);

//    iPopLabel();
//    iPushLabel(label);
//}

//void iArrRef(string opd1, string opd2, string opd3)
//{

//}

void printICode()
{
    foreach (q; _quads)
        writefln("%s\t%s %s %s %s",q.label,q.opcode,q.opd1,q.opd2,q.opd3);
}

//void iPushLabel(string label, bool priority=false)
//{
//    _labelStack.push(new Label(label,priority));
//}

//void iPopLabel()
//{
//    auto topLabel = _labelStack.top();
//    _labelStack.pop();

//    if (_currentLabel && _currentLabel.priority) {
//        backPatch(topLabel,_currentLabel);
//    }
//    else if (_currentLabel) {
//        backPatch(_currentLabel,topLabel);
//        _currentLabel = topLabel;
//    }
//    else {
//        _currentLabel = topLabel;
//    }
//}

//void setLabel(Label label)
//{
//    if (_currentLabel)
//        backPatch(_currentLabel,label);
//    _currentLabel = label;
//}

private:
Quad[] _quads;
string[string] _opMap;

Label _currentLabel;
size_t[string] _labelCount;
Stack!Label _labelStack;

struct Label
{
    string label;
    bool priority;

    bool opEquals()(auto ref const string s) const
    {
        return label == s;
    }

    string opCast(string)() const {
        return label;
    }
}

void addQuad(string opcode, string opd1, string opd2=null, string opd3=null)
{
    _quads ~= Quad(opcode,opd1,opd2,opd3,_currentLabel.label);
    _currentLabel = Label.init;
}

void backPatch(Label oldLabel, Label newLabel)
{
    foreach (ref q; _quads) {
        q.opd1 = q.opd1 == oldLabel ? newLabel : q.opd1;
        q.opd2 = q.opd2 == oldLabel ? newLabel : q.opd2;
        q.opd3 = q.opd3 == oldLabel ? newLabel : q.opd3;
        q.label = q.label == oldLabel ? newLabel : q.label;
    }
}

auto makeLabel(string prefix = null, bool priority=false)
{
    if (!prefix)
        prefix = "L";
    return Label(text(prefix,++_labelCount[prefix]),priority);
}

static this()
{
    _labelStack = new Stack!Label;

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