import std.conv;
import std.stdio;
import icode, symbol;

void generateTCode(File dest)
{
    foreach(s; SymbolTable.getGlobals())
        writeln(s);
}

private:
string[][size_t] _regs;

auto getRegister()
{

}
