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
}

void iFunc(string opd1, string opd2, string[] args=null)
{
    push("FRAME",opd1,opd2);
    foreach (a; args)
        push("PUSH",a);
    push("CALL",opd1);
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

void iIfCondition(string symId, string label)
{
    push("BF",symId,makeLabel(label));
}

void iArrRef(string opd1, string opd2, string opd3)
{

}

void printICode()
{
    foreach (q; _quads)
        writeln(q);
}

void iLabel(string label)
{
    _label = label;
}

private:
Quad[] _quads;
string _label;
string[string] _opMap;
size_t _labelCount;

void push(string opcode, string opd1, string opd2=null, string opd3=null)
{
    _quads ~= Quad(opcode,opd1,opd2,opd3,_label);
    _label = null;
}

auto makeLabel(string label)
{
    return text(label,++_labelCount);
}

static this()
{
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