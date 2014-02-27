import std.conv;
import std.file;
import std.stdio;
import std.stream;
import container, icode, symbol;

immutable REG_COUNT = 15;

void generateTCode(string destFileName)
{
    _file = new BufferedFile(destFileName, FileMode.Out);

    scope (failure)
        remove(destFileName);
    scope (exit) 
        _file.close();

    // Global data first
    genGlobalData();

    // Process ICode
    processICode();
}

private:
Stream _file;

void genGlobalData()
{
    foreach (symbol; SymbolTable.getGlobals()) {
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
            genFuncCode(quad);
            break;
        case "ADD":
        case "ADI":
        case "SUB":
        case "MUL":
        case "DIV":
            genMathCode(quad);
            break;
        default:
            break;
        }
    }
}

void genFuncCode(Quad quad)
{
    auto methodSymbol = cast(MethodSymbol)SymbolTable.getById(quad.opd1);
    if (!methodSymbol)
        throw new Exception("genFuncCode: Failed to load symbol for method " ~ quad.opd1);

    switch (quad.opcode) {
    case "FRAME":
        write(quad.label, "MOV", "R1", "SP");
        write(null, "ADI", "R1", "-8");
        write(null, "CMP", "R1", "SL");
        write(null, "BLT", "R1", "OVERFLOW");
        write(null, "MOV", "FP", "SP");
        write(null, "ADI", "SP", "-4");
        write(null, "STR", "R1", "(SP)");
        write(null, "ADI", "SP", "-4");
        break;
    case "CALL":
        write(quad.label, "MOV", "R1", "PC");
        write(null, "ADI", "R1", "36");
        write(null, "STR", "R1", "(FP)");
        write(null, "JMP", quad.opd1);
        break;
    case "FUNC":
        break;
    default:
        break;
    }
}

void genMathCode(Quad quad)
{

}

auto write(string label, string opcode, string opd1, string opd2=null, string comment=null)
{
    static auto format = "%-10s %-5s %-5s %-5s %s";

    label   = label ? label : "";
    opd1    = opd1 ? opd1 ~ (opd2 ? "," : null) : "";
    opd2    = opd2 ? opd2 : "";
    comment = comment ? ";" ~ comment : "";

    _file.writefln(format, label, opcode, opd1, opd2, comment);
}
