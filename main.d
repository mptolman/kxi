import std.stdio;
import compiler;

int main(string[] args)
{
    if (args.length != 2) {
        writefln("Usage: %s <file>",args[0]);
        return 1;
    }

    try {   
        compile(args[1]);
        writeln("success");
    }
    catch (Exception e) {
        writeln(e.msg);
    }

    return 0;
}