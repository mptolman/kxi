import lexer;
import parse;
import std.stdio;

int main(string[] args)
{
	File file = File("kjvdat.txt");
	File output = File(r"C:\out.txt", "w");
	Lexer l = new Lexer(file);

	Token t;
	do {
		t = l.next();
		output.writeln(t);
	} while (t.type != TType.EOF);

	return 0;
}