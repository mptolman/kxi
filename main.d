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
        File output = File(r"C:\out.txt", "w");
        Lexer l = new Lexer(input);

        parse(l);
    }
    catch (Exception e) {
        writeln(e.msg);
    }

    return 0;
}