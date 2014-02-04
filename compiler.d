import std.stdio;
import icode, parser, symbol;

void compile(string srcFileName)
{
    File src = File(srcFileName);
    parse(src);
    printICode();
}