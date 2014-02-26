//import std.stdio;
import std.conv;
import std.stream;
import container, icode, symbol;

immutable REG_COUNT = 15;

void generateTCode(string destFileName)
{
    _file = new BufferedFile(destFileName, FileMode.Out);
    scope (exit) _file.close();

    // Global data first
    genGlobalData();

    // Process ICode
    processICode();
}

private:
Stream _file;
string[][size_t] _regs;
Stack!string _regPool;

void genGlobalData()
{
    foreach(symbol; SymbolTable.getGlobals()) {
        switch (symbol.type) {
        case "int":
            write(symbol.id, ".INT", symbol.name);
            break;
        case "char":
            write(symbol.id, ".BYT", "'"~symbol.name~"'");
            break;
        case "bool":
            write(symbol.id, ".INT", symbol.name == "true" ? "1" : "0");
            break;
        case "null":
            write(symbol.id, ".INT", "0");
            break;
        default:
            throw new Exception("generateGlobals: Invalid global variable type " ~ symbol.type);
        }
    }
}

void processICode()
{
    foreach (quad; icode.getQuads()) {
        switch (quad.opcode) {
        case "FRAME":
        case "CALL":
        case "FUNC":
            break;
        default:
            break;
        }
    }
}

void genFuncCode(Quad quad)
{

}

auto write(string label, string opcode, string opd1, string opd2=null, string comment=null)
{
    static auto format = "%-10s %-5s %-5s %-5s %s";

    label   = label ? label : "";
    opd1    = opd1 ? opd1 ~ (opd2 ? "," : null) : "";
    opd2    = opd2 ? opd2 : "";
    comment = comment ? ";"~comment : "";

    _file.writefln(format, label, opcode, opd1, opd2, comment);
}

auto getRegister()
{
    string reg;

    if (_regPool.size) {
        reg = _regPool.top;
        _regPool.pop();
    }    
}

void fillRegPool()
{
    _regPool.clear();
    foreach (i; 1..REG_COUNT+1)
        _regPool.push(text("R",i));
}

static this()
{
    _regPool = new Stack!string;
}