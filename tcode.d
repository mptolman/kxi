//import std.stdio;
import std.stream;
import icode, symbol;

void generateTCode(string destFileName)
{
    _file = new BufferedFile(destFileName, FileMode.Out);
    scope (exit) _file.close();

    // Global variables first
    generateGlobals();

    // Process ICode
    processICode();
}

private:
Stream _file;
string[][size_t] _regs;

void generateGlobals()
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

}
