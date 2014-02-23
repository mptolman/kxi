import std.file;
import std.stdio;
import icode, parser, tcode;

void compile(string srcFileName, string destFileName)
{    
    parse(srcFileName);
    debug printICode();
    generateTCode(destFileName);
}