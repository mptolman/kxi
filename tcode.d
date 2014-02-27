import std.conv;
import std.file;
import std.stdio;
import std.stream;
import container, icode, symbol;

void generateTCode(string destFileName)
{
    _file = new BufferedFile(destFileName, FileMode.OutNew);

    scope (failure) remove(destFileName);
    scope (exit) _file.close();

    // Global data first
    genGlobalData();

    // Process ICode
    processICode();

    // Built-in code
    genBuiltIns();
}

private:
Stream _file;

void genGlobalData()
{
    foreach (symbol; SymbolTable.getGlobals()) {
        switch (symbol.type) {
        case "int":
            writeAsm(symbol.id, ".INT", symbol.name);
            break;
        case "char":
            writeAsm(symbol.id, ".BYT", "'"~symbol.name~"'");
            break;
        case "bool":
            writeAsm(symbol.id, ".INT", symbol.name == "true" ? "1" : "0");
            break;
        case "null":
            writeAsm(symbol.id, ".INT", "0");
            break;
        default:
            throw new Exception("generateGlobals: Invalid global variable type " ~ symbol.type);
        }
    }

    // Built-in globals
    writeAsm("STROVERFLOW", ".BYT", "'Stack overflow has occurred! Terminating application.\\n'");
    writeAsm("STROVERFLOW_SZ", ".INT", "54");
    writeAsm("STRUNDERFLOW", ".BYT", "'Stack underflow has occurred! Terminating application.\\n'");
    writeAsm("STRUNDERFLOW_SZ", ".INT", "55");
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
        case "QUIT":
            writeAsm(quad.label, "TRP", "0", null, "[QUIT]");
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
        writeAsm(quad.label, "MOV", "R1", "SP", "[FRAME] "~quad.opd1);
        writeAsm(null, "ADI", "R1", "-12");
        writeAsm(null, "CMP", "R1", "SL");
        writeAsm(null, "BLT", "R1", "OVERFLOW");
        writeAsm(null, "MOV", "FP", "SP");
        writeAsm(null, "ADI", "SP", "-4");
        writeAsm(null, "STR", "R1", "(SP)");
        writeAsm(null, "ADI", "SP", "-4");
        break;
    case "CALL":
        writeAsm(quad.label, "MOV", "R1", "PC", "[CALL] "~quad.opd1);
        writeAsm(null, "ADI", "R1", "36");
        writeAsm(null, "STR", "R1", "(FP)");
        writeAsm(null, "JMP", quad.opd1);
        break;
    case "FUNC":
        writeAsm(quad.label, "FUNC", quad.opd1);
        break;
    default:
        break;
    }
}

void genMathCode(Quad quad)
{
    auto s1 = SymbolTable.getById(quad.opd1);
    auto s2 = SymbolTable.getById(quad.opd2);
    auto s3 = SymbolTable.getById(quad.opd3);

    switch (quad.opcode) {
    case "ADD":        
        break;
    default:
        break;
    }
}

auto getLocation(string symId)
{
    auto symbol = SymbolTable.getById(symId);

}

auto genBuiltIns()
{
    writeAsm("OVERFLOW", "LDA", "R1", "STROVERFLOW");
    writeAsm(null, "LDR", "R2", "STROVERFLOW_SZ");
    writeAsm("PRNTOVERFLOW", "LDB", "R0", "(R1)");
    writeAsm(null, "TRP", "3");
    writeAsm(null, "ADI", "R1", "1");
    writeAsm(null, "ADI", "R2", "-1");
    writeAsm(null, "BNZ", "R2", "PRNTOVERFLOW");
    writeAsm(null, "TRP", "0");

    writeAsm("UNDERFLOW", "LDA", "R1", "STRUNDERFLOW");
    writeAsm(null, "LDR", "R2", "STRUNDERFLOW_SZ");
    writeAsm("PRNTUNDERFLOW", "LDB", "R0", "(R1)");
    writeAsm(null, "TRP", "3");
    writeAsm(null, "ADI", "R1", "1");
    writeAsm(null, "ADI", "R2", "-1");
    writeAsm(null, "BNZ", "R2", "PRNTUNDERFLOW");
    writeAsm(null, "TRP", "0");
}

auto writeAsm(string label, string opcode, string opd1, string opd2=null, string comment=null)
{
    static auto format = "%-15s %-4s %-3s %-15s %s";

    comment = comment ? ";" ~ comment : comment;
    
    _file.writefln(format, label, opcode, opd1, opd2, comment);
}
