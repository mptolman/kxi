import symbol;

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

private:
Quad[] _quads;

void push(string opcode, string opd1, string opd2=null, string opd3=null)
{
    _quads ~= Quad(opcode,opd1,opd2,opd3);
}