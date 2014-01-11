import std.stdio;
import lexer, parser;

int main(string[] args)
{
    if (args.length != 2) {
        writefln("Usage: %s <file>",args[0]);
        return 1;
    }

    try {   
        File input = File(args[1]);
        parse(new Lexer(input));
        writeln("success");
    }
    catch (SyntaxError e) {
        writeln("Syntax error. ",e.msg);
    }
    catch (Exception e) {
        writeln(e.msg);
    }

    return 0;
}