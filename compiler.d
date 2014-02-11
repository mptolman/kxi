import std.stdio;
import icode, parser, tcode;

void compile(string srcFileName)
{
    File src = File(srcFileName);
    parse(src);
    debug printICode();
    generateTCode();
}