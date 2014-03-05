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
}

auto processICode()
{
    foreach (quad; icode.getQuads()) {
        debug writefln("%s\t%s %s %s %s",quad.label,quad.opcode,quad.opd1,quad.opd2,quad.opd3);

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
            genFuncReturn(quad);
            break;
        case "PUSH":
        case "POP":
        case "PEEK":
            genStackCode(quad);
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
        case "AEF":
            genArrayRefCode(quad);
            break;
        case "REF":
            genRefCode(quad);
            break;
        case "READ":
            genReadCode(quad);
            break;
        case "WRITE":
            genWriteCode(quad);
            break;
        case "NEW":
        case "NEWI":
            genMallocCode(quad);
            break;
        case "ATOI":
        case "ITOA":
            genConvertCode(quad);
            break;
        case "QUIT":
            writeAsm("TRP", "0");
            break;
        default:
            throw new Exception("processICode: Unimplemented instruction "~to!string(quad));
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
        writeAsm("MOV", "R1", "SP");
        writeAsm("ADI", "R1", "-12");
        writeAsm("CMP", "R1", "SL");
        writeAsm("BLT", "R1", "OVERFLOW");
        loadRegister("R2", quad.opd2);
        writeAsm("MOV", "R1", "FP");
        writeAsm("MOV", "FP", "SP");
        writeAsm("ADI", "SP", "-4");
        writeAsm("STR", "R1", "(SP)", "Push PFP");
        writeAsm("ADI", "SP", "-4");
        writeAsm("STR", "R2", "(SP)", "Push `this` pointer");
        writeAsm("ADI", "SP", "-4");
        break;
    case "CALL":
        writeAsm("MOV", "R1", "PC");
        writeAsm("ADI", "R1", "36");
        writeAsm("STR", "R1", "(FP)", "Push return address");
        writeAsm("JMP", quad.opd1);
        break;
    case "FUNC":
        if (methodSymbol.locals) {
            int stackOffset = methodSymbol.locals.length * -4;
            writeAsm("MOV", "R1", "SP");
            writeAsm("ADI", "R1", to!string(stackOffset));
            writeAsm("CMP", "R1", "SL");
            writeAsm("BLT", "R1", "OVERFLOW");
            writeAsm("ADI", "SP", to!string(stackOffset));
        }
        else {
            writeAsm("ADI", "R1", "0");
        }
        break;
    default:
        throw new Exception("genFuncCode: Invalid opcode "~quad.opcode);
    }
}

auto genFuncReturn(Quad quad)
{
    if (quad.opcode == "RETURN")
        loadRegister("R3", quad.opd1);
    writeAsm("MOV", "SP", "FP");
    writeAsm("MOV", "R1", "SP");
    writeAsm("CMP", "R1", "SB");
    writeAsm("BGT", "R1", "UNDERFLOW");
    writeAsm("LDR", "R1", "(FP)");
    writeAsm("MOV", "R2", "FP");
    writeAsm("ADI", "R2", "-4");
    writeAsm("LDR", "FP", "(R2)");
    if (quad.opcode == "RETURN")
        writeAsm("STR", "R3", "(SP)");
    writeAsm("JMR", "R1");
}

auto genStackCode(Quad quad)
{
    switch (quad.opcode) {
    case "PUSH":
        // Save FP
        writeAsm("MOV", "R9", "FP");

        // Point to PFP
        writeAsm("MOV", "R1", "FP");
        writeAsm("ADI", "R1", "-4");
        writeAsm("LDR", "FP", "(R1)");

        // Push parameter to current stack frame
        loadRegister("R1", quad.opd1);
        writeAsm("STR", "R1", "(SP)");
        writeAsm("ADI", "SP", "-4");

        // Restore FP
        writeAsm("MOV", "FP", "R9");
        break;
    case "POP":
        writeAsm("ADI", "SP", "4");
        writeAsm("LDR", "R1", "(SP)");
        break;
    case "PEEK":
        writeAsm("LDR", "R1", "(SP)");
        storeRegister("R1", quad.opd1);
        break;
    default:
        throw new Exception("genStackCode: Invalid opcode"~quad.opcode);
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
    writeAsm("SUB", "R3", "R3");    
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

auto genArrayRefCode(Quad quad)
{
    auto baseSymbol = SymbolTable.getById(quad.opd1);
    auto indexSymbol = SymbolTable.getById(quad.opd2);
    auto addrSymbol = SymbolTable.getById(quad.opd3);

    loadRegister("R1", baseSymbol);
    loadRegister("R2", indexSymbol);

    writeAsm("SUB", "R3", "R3");
    switch (addrSymbol.type) {
    case "char":
        writeAsm("ADI", "R3", to!string(char.sizeof));
        break;
    case "bool":
        writeAsm("ADI", "R3", to!string(bool.sizeof));
        break;
    default:
        writeAsm("ADI", "R3", to!string(int.sizeof));
        break;
    }
    writeAsm("MUL", "R2", "R3");
    writeAsm("ADD", "R1", "R2");
    storeRegister("R1", addrSymbol, false);
}

auto genRefCode(Quad quad)
{
    auto objSymbol = SymbolTable.getById(quad.opd1);
    auto varSymbol = SymbolTable.getById(quad.opd2);
    auto refSymbol = SymbolTable.getById(quad.opd3);

    loadRegister("R1", objSymbol);
    writeAsm("ADI", "R1", to!string(varSymbol.offset));
    storeRegister("R1", refSymbol, false);
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

auto genMallocCode(Quad quad)
{
    storeRegister("HP", quad.opd2);

    if (quad.opcode == "NEW") {
        loadRegister("R1", quad.opd1);
        writeAsm("ADD", "HP", "R1");
    }
    else {
        writeAsm("ADI", "HP", quad.opd1);
    }
}

auto genConvertCode(Quad quad)
{
    loadRegister("R0", quad.opd1);
    if (quad.opcode == "ITOA")
        writeAsm("TRP", "11");
    else
        writeAsm("TRP", "10");
    storeRegister("R0", quad.opd2);
}

auto genBuiltIns()
{
    _label = "OVERFLOW";
    writeAsm("LDA", "R1", "STROVERFLOW");
    writeAsm("LDR", "R2", "STROVERFLOW_SZ");

    _label = "PRNTOVERFLOW";
    writeAsm("LDB", "R0", "(R1)");
    writeAsm("TRP", "3");
    writeAsm("ADI", "R1", "1");
    writeAsm("ADI", "R2", "-1");
    writeAsm("BNZ", "R2", "PRNTOVERFLOW");
    writeAsm("TRP", "0");

    _label = "UNDERFLOW";
    writeAsm("LDA", "R1", "STRUNDERFLOW");
    writeAsm("LDR", "R2", "STRUNDERFLOW_SZ");

    _label = "PRNTUNDERFLOW";
    writeAsm("LDB", "R0", "(R1)");
    writeAsm("TRP", "3");
    writeAsm("ADI", "R1", "1");
    writeAsm("ADI", "R2", "-1");
    writeAsm("BNZ", "R2", "PRNTUNDERFLOW");
    writeAsm("TRP", "0");
}

auto loadRegister(string reg, Symbol symbol)
{
    auto loadOp = symbol.type == "char" ? "LDB" : "LDR";

    if (cast(GlobalSymbol)symbol) {
        writeAsm(loadOp, reg, symbol.id);
    }
    else if (cast(IVarSymbol)symbol) {
        writeAsm("MOV", reg, "FP");
        writeAsm("ADI", reg, "-8");
        writeAsm("LDR", reg, "("~reg~")");
        writeAsm("ADI", reg, to!string(symbol.offset));
        writeAsm(loadOp, reg, "("~reg~")");
    }
    else {
        writeAsm("MOV", reg, "FP");
        writeAsm("ADI", reg, to!string(symbol.offset));
        writeAsm("LDR", reg, "("~reg~")");
        if (cast(RefSymbol)symbol)
            writeAsm(loadOp, reg, "("~reg~")");
    }
}

auto loadRegister(string reg, string symId)
{
    if (symId == "this") {
        writeAsm("MOV", reg, "FP");
        writeAsm("ADI", reg, "-8");
        writeAsm("LDR", reg, "("~reg~")");
    }
    else if (symId == "main") {
        writeAsm("SUB", reg, reg);
    }
    else {
        loadRegister(reg, SymbolTable.getById(symId));
    }
}

auto storeRegister(string reg, Symbol symbol, bool indirect=true)
{
    auto storeOp = symbol.type == "char" ? "STB" : "STR";

    if (cast(GlobalSymbol)symbol) {
        writeAsm(storeOp, reg, symbol.id);
    }
    else if (cast(IVarSymbol)symbol) {
        writeAsm("MOV", "R9", "FP"); // use `this` as base address
        writeAsm("ADI", "R9", "-8");
        writeAsm("LDR", "R9", "(R9)");
        writeAsm("ADI", "R9", to!string(symbol.offset));
        writeAsm(storeOp, reg, "(R9)");
    }
    else if (cast(RefSymbol)symbol) {
        writeAsm("MOV", "R9", "FP");
        writeAsm("ADI", "R9", to!string(symbol.offset));
        if (indirect) {
            writeAsm("LDR", "R9", "(R9)");
            writeAsm(storeOp, reg, "(R9)");
        }
        else {
            writeAsm("STR", reg, "(R9)");
        }
    }
    else {
        writeAsm("MOV", "R9", "FP");
        writeAsm("ADI", "R9", to!string(symbol.offset));
        writeAsm(storeOp, reg, "(R9)");
    }
}

auto storeRegister(string reg, string symId)
{
    storeRegister(reg, SymbolTable.getById(symId));
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
