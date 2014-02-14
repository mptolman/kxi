import std.stdio;
import std.string;
import compiler;

int main(string[] args)
{
    if (args.length < 2) {
        writefln("Usage: %s <source> [<dest>]",args[0]);
        return 1;
    }

    try {
        string srcFileName = args[1];
        string destFileName = args.length > 2 ? args[2] : stripRight(args[1]) ~ ".asm";

        compile(srcFileName, destFileName);
        writeln("success");
    }
    catch (Exception e) {
        writeln(e.msg);
    }

    return 0;
}