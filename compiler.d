import std.stdio;
import parser;

void compile(string srcFileName)
{
    File src = File(srcFileName);
    parse(src);
}