import std.algorithm;
import std.ascii;
import std.array;
import std.conv;
import std.stdio;
import std.string;

auto truncate(T,D)(T t, D delim)
{
	auto pos = countUntil(t, delim);
	if (pos >= 0)
		return t[0..pos];
	return t;
}

auto isKeyword(T)(T t)
{
	return !find(keywords,t).empty;
}

auto isModifier(T)(T t)
{
	return !find(modifiers,t).empty;
}

enum TType {
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

immutable string[] keywords;
immutable string[] modifiers;

struct Token
{
	TType type;
	string value;
	size_t line;
}

void main()
{
	File file = File(r"C:\A.kxi","r");
	Token[] tokens;

	char[] buf;
	string tok;
	for (size_t lineNum = 1; file.readln(buf); ++lineNum) {
		auto line = strip(truncate(buf,"//"));
		if (line.empty) continue;

		for (auto c = line.ptr; c < line.ptr+line.length; ++c) {
			tok = [*c];

			if (isAlpha(*c)) {
				while (isAlphaNum(*++c))
					tok ~= *c;
				--c;
				if (isModifier(tok))
					tokens ~= Token(TType.MODIFIER, tok, lineNum);
				else if (isKeyword(tok))
					tokens ~= Token(TType.KEYWORD, tok, lineNum);
				else
					tokens ~= Token(TType.IDENTIFIER, tok, lineNum);
			}

			else if (isDigit(*c)) {
				while (isDigit(*++c))
					tok ~= *c;
				--c;
				tokens ~= Token(TType.NUMERIC_LITERAL, tok, lineNum);
			}

			else if (*c == '+' || *c == '-') {
				if (isDigit(*(c+1))) {
					while (isDigit(*++c))
						tok ~= *c;
					tokens ~= Token(TType.NUMERIC_LITERAL, tok, lineNum);
				}
				else {
					tokens ~= Token(TType.ARITHMETIC_OP, tok, lineNum);
				}
			}

			else if (*c == '\'') {

			}
			
			else if (isWhite(*c)) {
				continue; // ignore whitespace
			}
		}			
	}

	foreach (t; tokens)
		writeln(t);
}

static this()
{
	keywords = [
		"if","false","true","class"
	];

	modifiers = [
		"private","public"
	];
}