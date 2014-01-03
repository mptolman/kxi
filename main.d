import lexer;
import parse;
import std.stdio;

int main(string[] args)
{
	File file = File("A.kxi");
	Parser p = new Parser(new Lexer(file));

	return 0;
}