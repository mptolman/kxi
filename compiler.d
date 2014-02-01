import std.stdio;
import parser, symbol;

void compile(string srcFileName)
{
    File src = File(srcFileName);
    parse(src);
}