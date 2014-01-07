import lexer;
import parse;
import std.stdio;

int main(string[] args)
{
	File file = File("A.kxi");
	File ofile = File(r"C:\out.txt", "w");
	Lexer l = new Lexer(file);

	Token t;
	do {
		t = l.next();
		ofile.writeln(t);
	} while (t.type != TType.EOF);

	return 0;
}