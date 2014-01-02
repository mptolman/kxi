import std.algorithm : find;
import std.ascii;
import std.stdio;
import std.string;

/**********************************
 Helper functions
***********************************/
auto truncate(T,U)(T t, U delim)
{
	auto pos = indexOf(t, delim);
	if (pos >= 0)
		return t[0..pos];
	return t;
}

auto isKeyword(string s)
{
	return cast(bool)find(keywords,s).length;
}

auto isModifier(string s)
{
	return cast(bool)find(modifiers,s).length;
}

/**********************************
 Types
***********************************/
enum TType : byte {
	KEYWORD,
	MODIFIER,
	IDENTIFIER,
	NUMERIC_LITERAL,
	CHARACTER_LITERAL,
	ARITHMETIC_OP,
	EOR,
	EOF,
	UNKNOWN
}

struct Token
{
	TType type;
	string value;
	size_t line;
}

class Lexer
{
	private File _file;
	private Token[] tokens;

	this(File file) {
		this._file = file;
	}

	Token next()
	{
		static auto lineNum = 1;

		if (tokens.length) {
			Token t = tokens[0];
			tokens = tokens[1..$];
			return t;
		}
		
		char[] buf;		
		for (; _file.readln(buf); ++lineNum) {
			auto line = strip(truncate(buf,"//"));
			if (line.length == 0) continue;

			for (auto c = line.ptr; c < line.ptr+line.length;) {
				string tok = [*c];
				if (isAlpha(*c)) {
					while (isAlphaNum(*++c))
						tok ~= *c;
					if (isModifier(tok))
						tokens ~= Token(TType.MODIFIER,tok,lineNum);
					else if (isKeyword(tok))
						tokens ~= Token(TType.KEYWORD,tok,lineNum);
					else
						tokens ~= Token(TType.IDENTIFIER,tok,lineNum);
				}
				else if (isDigit(*c))  {
					while (isDigit(*++c))
						tok ~= *c;
					tokens ~= Token(TType.NUMERIC_LITERAL,tok,lineNum);
				}
				else if (isWhite(*c)) {
					continue; // Ignore whitespace
				}
			}
		}

		if (_file.eof)
			tokens ~= Token(TType.EOF);

		return next();
	}
}

unittest {
	Lexer lexer = new Lexer(File("A.kxi"));
	auto t = lexer.next();
}

/**********************************
 Private data
***********************************/
private:
immutable string[] keywords;
immutable string[] modifiers;

static this()
{

}