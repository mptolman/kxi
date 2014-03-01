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
string _label;
string _comment;

void genGlobalData()
{
    foreach (symbol; SymbolTable.getGlobals()) {
        _label = symbol.id;

        switch (symbol.type) {
        case "int":
            writeAsm(".INT", symbol.name);
            break;
        case "char":
            writeAsm(".BYT", "'"~symbol.name~"'");
            break;
        case "bool":
            writeAsm(".INT", symbol.name == "true" ? "1" : "0");
            break;
        case "null":
            writeAsm(".INT", "0");
            break;
        default:
            throw new Exception("generateGlobals: Invalid global variable type " ~ symbol.type);
        }
    }

    // Built-in globals
    _label = "STROVERFLOW";
    writeAsm(".BYT", "'Stack overflow has occurred! Terminating application.\\n'");

    _label = "STROVERFLOW_SZ";
    writeAsm(".INT", "54");

    _label = "STRUNDERFLOW";
    writeAsm(".BYT", "'Stack underflow has occurred! Terminating application.\\n'");

    _label = "STRUNDERFLOW_SZ";
    writeAsm(".INT", "55");

    _label = "FREE";
    writeAsm(".INT", "0");
}

auto processICode()
{
    foreach (quad; icode.getQuads()) {
        _label = quad.label;
        _comment = text("[",quad.opcode,"] ",quad.opd1,' ',quad.opd2,' ',quad.opd3);

        switch (quad.opcode) {
        case "FRAME":
        case "CALL":
        case "FUNC":
            genFuncCode(quad);
            break;
        case "RETURN":
        case "RTN":
            //genReturnCode(quad);
            break;
        case "ADD":
        case "ADI":
        case "SUB":
        case "MUL":
        case "DIV":
            genMathCode(quad);
            break;
        case "EQ":
        case "NE":
        case "LT":
        case "GT":
        case "LE":
        case "GE":
            genBoolCode(quad);
            break;
        case "BF":
        case "BT":
        case "JMP":
            genControlFlowCode(quad);
            break;
        case "AND":
        case "OR":
            genLogicCode(quad);
            break;
        case "MOV":
        case "MOVI":
            genMoveCode(quad);
            break;
        case "READ":
            genReadCode(quad);
            break;
        case "WRITE":
            genWriteCode(quad);
            break;
        case "QUIT":
            writeAsm("TRP", "0");
            break;
        default:
            break;
        }
    }
}

auto genFuncCode(Quad quad)
{
    auto methodSymbol = cast(MethodSymbol)SymbolTable.getById(quad.opd1);
    if (!methodSymbol)
        throw new Exception("genFuncCode: Failed to load symbol for method " ~ quad.opd1);

    switch (quad.opcode) {
    case "FRAME":
        writeAsm("MOV", "R1", "SP", "[FRAME] "~quad.opd1);
        writeAsm("ADI", "R1", "-12");
        writeAsm("CMP", "R1", "SL");
        writeAsm("BLT", "R1", "OVERFLOW");
        writeAsm("MOV", "FP", "SP");
        writeAsm("ADI", "SP", "-4");
        writeAsm("STR", "R1", "(SP)");
        writeAsm("ADI", "SP", "-4");
        break;
    case "CALL":
        writeAsm("MOV", "R1", "PC", "[CALL] "~quad.opd1);
        writeAsm("ADI", "R1", "36");
        writeAsm("STR", "R1", "(FP)");
        writeAsm("JMP", quad.opd1);
        break;
    case "FUNC":
        writeAsm("FUNC", quad.opd1);
        break;
    default:
        throw new Exception("genFuncCode: Invalid opcode "~quad.opcode);
    }
}

auto genMathCode(Quad quad)
{
    auto s1 = SymbolTable.getById(quad.opd1);
    auto s2 = SymbolTable.getById(quad.opd2);
    auto s3 = SymbolTable.getById(quad.opd3);

    switch (quad.opcode) {
    case "ADD":
    case "SUB":
    case "MUL":
    case "DIV":
        loadRegister("R1", s1);
        loadRegister("R2", s2);
        writeAsm(quad.opcode, "R1", "R2");
        storeRegister("R1", s3);
        break;
    case "ADI":
        loadRegister("R1", s1);
        writeAsm("ADI", "R1", quad.opd2);
        storeRegister("R1", s3);
        break;
    default:
        throw new Exception("genMathCode: Invalid opcode "~quad.opcode);
    }
}

auto genBoolCode(Quad quad)
{
    auto s1 = SymbolTable.getById(quad.opd1);
    auto s2 = SymbolTable.getById(quad.opd2);
    auto s3 = SymbolTable.getById(quad.opd3);

    auto label1 = icode.makeLabel();
    auto label2 = icode.makeLabel();

    loadRegister("R1", s1);
    loadRegister("R2", s2);
    loadRegister("R3", s3);

    writeAsm("MOV", "R3", "R1");
    writeAsm("CMP", "R3", "R2");

    switch (quad.opcode) {
    case "EQ":
        writeAsm("BRZ", "R3", label1);
        break;
    case "NE":
        writeAsm("BNZ", "R3", label1);
        break;        
    case "LT":
        writeAsm("BLT", "R3", label1);
        break;
    case "GT":
        writeAsm("BGT", "R3", label1);
        break;
    case "LE":
        writeAsm("BLT", "R3", label1);
        writeAsm("BRZ", "R3", label1);
        break;
    case "GE":
        writeAsm("BGT", "R3", label1);
        writeAsm("BRZ", "R3", label1);
        break;
    default:
        throw new Exception("genBoolCode: Invalid opcode "~quad.opcode);
    }

    // Set to FALSE
    writeAsm("SUB", "R3", "R3");
    writeAsm("JMP", label2);

    // Set to TRUE
    _label = label1;
    writeAsm("ADI", "R3", "1");

    _label = label2;
    storeRegister("R3", s3);
}

auto genControlFlowCode(Quad quad)
{
    auto s1 = SymbolTable.getById(quad.opd1);

    switch (quad.opcode) {
    case "BF":
        loadRegister("R1", s1);
        writeAsm("BRZ", "R1", quad.opd2);
        break;
    case "BT":
        loadRegister("R1", s1);
        writeAsm("BNZ", "R1", quad.opd2);
        break;
    case "JMP":
        writeAsm("JMP", quad.opd1);
        break;
    default:
        throw new Exception("genControlFlowCode: Invalid opcode ",quad.opcode);
    }
}

auto genLogicCode(Quad quad)
{
    auto s1 = SymbolTable.getById(quad.opd1);
    auto s2 = SymbolTable.getById(quad.opd2);
    auto s3 = SymbolTable.getById(quad.opd3);

    loadRegister("R1", s1);
    loadRegister("R2", s2);

    if (quad.opcode == "AND")
        writeAsm("AND", "R1", "R2");
    else if (quad.opcode == "OR")
        writeAsm("OR", "R1", "R2");
    else
        throw new Exception("genLogicalCode: Invalid opcode " ~ quad.opcode);

    storeRegister("R1", s3);
}

auto genMoveCode(Quad quad)
{
    auto s1 = SymbolTable.getById(quad.opd1);
    auto s2 = SymbolTable.getById(quad.opd2);

    switch (quad.opcode) {
    case "MOV":
        loadRegister("R1", s1);
        storeRegister("R1", s2);        
        break;
    case "MOVI":
        writeAsm("SUB", "R1", "R1");
        writeAsm("ADI", "R1", quad.opd1);
        storeRegister("R1", s2);
        break;
    default:
        break;
    }
}

auto genReadCode(Quad quad)
{
    auto s = SymbolTable.getById(quad.opd1);

    writeAsm("TRP", s.type == "char" ? "4" : "2");
    storeRegister("R0", s);
}

auto genWriteCode(Quad quad)
{
    auto s = SymbolTable.getById(quad.opd1);

    loadRegister("R0", s);
    writeAsm("TRP", s.type == "char" ? "3" : "1");
}

auto genBuiltIns()
{
    //writeAsm("OVERFLOW", "LDA", "R1", "STROVERFLOW");
    //writeAsm("LDR", "R2", "STROVERFLOW_SZ");
    //writeAsm("PRNTOVERFLOW", "LDB", "R0", "(R1)");
    //writeAsm("TRP", "3");
    //writeAsm("ADI", "R1", "1");
    //writeAsm("ADI", "R2", "-1");
    //writeAsm("BNZ", "R2", "PRNTOVERFLOW");
    //writeAsm("TRP", "0");

    //writeAsm("UNDERFLOW", "LDA", "R1", "STRUNDERFLOW");
    //writeAsm("LDR", "R2", "STRUNDERFLOW_SZ");
    //writeAsm("PRNTUNDERFLOW", "LDB", "R0", "(R1)");
    //writeAsm("TRP", "3");
    //writeAsm("ADI", "R1", "1");
    //writeAsm("ADI", "R2", "-1");
    //writeAsm("BNZ", "R2", "PRNTUNDERFLOW");
    //writeAsm("TRP", "0");
}

auto loadRegister(string reg, Symbol symbol)
{
    if (cast(GlobalSymbol)symbol) {
        writeAsm(symbol.type == "char" ? "LDB" : "LDR", reg, symbol.id);
    }
    else if (cast(IVarSymbol)symbol) {
        writeAsm("MOV", reg, "FP");
        writeAsm("ADI", reg, "-8");
        writeAsm("LDR", reg, "("~reg~")");
        writeAsm("ADI", reg, to!string(symbol.offset));
        writeAsm("LDR", reg, "("~reg~")");
    }
    else if (cast(RefSymbol)symbol) {

    }
    else {
        writeAsm("MOV", reg, "FP");
        writeAsm("ADI", reg, to!string(symbol.offset));
        writeAsm("LDR", reg, "("~reg~")");
    }
}

auto storeRegister(string reg, Symbol symbol)
{
    if (cast(GlobalSymbol)symbol) {
        writeAsm(symbol.type == "char" ? "STB" : "STR", reg, symbol.id);
    }
    else if (cast(IVarSymbol)symbol) {

    }
    else if (cast(RefSymbol)symbol) { 

    }
    else {
        writeAsm("MOV", reg, "FP");
        writeAsm("ADI", reg, to!string(symbol.offset));
        writeAsm("STR", reg, "("~reg~")");
    }
}

auto writeAsm(string opcode, string opd1, string opd2=null, string comment=null)
{
    static auto format = "%-15s %-4s %-3s %-15s %s";

    if (comment)
        comment = ";" ~ comment;
    else if (_comment)
        comment = ";" ~ _comment;
    
    _file.writefln(format, _label, opcode, opd1, opd2, comment);
    _label = null;
    _comment = null;
}
