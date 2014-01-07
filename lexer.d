import std.algorithm : find;
import std.ascii : isAlpha, isAlphaNum, isDigit, isWhite;
import std.stdio;
import std.string;

enum TType : byte 
{
	ARRAY_BEGIN,
	ARRAY_END,
	ASSIGN_OP,
	BLOCK_BEGIN,
	BLOCK_END,
	CHARACTER,
	EOT,
	EOF,
	IDENTIFIER,
	IO_OP,
	KEYWORD,
	LOGICAL_OP,
	MATH_OP,
	MODIFIER,
	NUMBER,
	PAREN_OPEN,
	PAREN_CLOSE,		
	PUNCTUATION,
	RELATIONAL_OP,
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
private:
	File _file;
	Token[] _tokens;
	size_t _lineNum;
	static immutable BUFFER_SIZE = 100;

public:
	this(File file) 
	{
		this._file = file;
	}

	Token next()
	{
		if (_tokens.length) {
			Token t = _tokens[0];
			_tokens = _tokens[1..$];
			return t;
		}

		char[] buf;
		while (_file.readln(buf)) {
			++_lineNum;
			auto line = strip(truncate(buf,"//")); // ignore comments
			if (!line.length) continue; // skip empty lines

			for (auto c = line.ptr; c < line.ptr+line.length; ++c) {
				string tok = [*c];

				if (isWhite(*c)) {
					// ignore whitespace	
				}

				else if (isAlpha(*c)) {
					while (isAlphaNum(*(c+1)))
						tok ~= *++c;

					if (isModifier(tok))
						_tokens ~= Token(TType.MODIFIER,tok,_lineNum);
					else if (isKeyword(tok))
						_tokens ~= Token(TType.KEYWORD,tok,_lineNum);
					else
						_tokens ~= Token(TType.IDENTIFIER,tok,_lineNum);
				}

				else if (isDigit(*c)) {
					while (isDigit(*(c+1)))
						tok ~= *++c;
					_tokens ~= Token(TType.NUMBER,tok,_lineNum);
				}

				else if (*c == '-' || *c == '+') {
					if (isDigit(*(c+1))) {
						do {
							tok ~= *++c;
						} while (isDigit(*(c+1)));
						_tokens ~= Token(TType.NUMBER,tok,_lineNum);
					}
					else {
						_tokens ~= Token(TType.MATH_OP,tok,_lineNum);
					}
				}

				else if (*c == ',' || *c == '.') {
					_tokens ~= Token(TType.PUNCTUATION,tok,_lineNum);
				}

				else if (*c == '+' || *c == '-' || *c == '*' || *c == '/' || *c == '%') {
					_tokens ~= Token(TType.MATH_OP,tok,_lineNum);
				}

				else if (*c == '{') {
					_tokens ~= Token(TType.BLOCK_BEGIN,tok,_lineNum);
				}

				else if (*c == '}') {
					_tokens ~= Token(TType.BLOCK_END,tok,_lineNum);
				}

				else if (*c == '(') {
					_tokens ~= Token(TType.PAREN_OPEN,tok,_lineNum);
				}

				else if (*c == ')') {
					_tokens ~= Token(TType.PAREN_CLOSE,tok,_lineNum);
				}

				else if (*c == '[') {
					_tokens ~= Token(TType.ARRAY_BEGIN,tok,_lineNum);
				}

				else if (*c == ']') {
					_tokens ~= Token(TType.ARRAY_END,tok,_lineNum);
				}

				else if (*c == '=') {
					if (*(c+1) == '=') {
						tok ~= *++c;
						_tokens ~= Token(TType.RELATIONAL_OP,tok,_lineNum);
					}
					else {
						_tokens ~= Token(TType.ASSIGN_OP,tok,_lineNum);
					}
				}

				else if (*c == '!' && *(c+1) == '=') {
					tok ~= *++c;
					_tokens ~= Token(TType.RELATIONAL_OP,tok,_lineNum);
				}

				else if (*c == '<') {
					if (*(c+1) == '<') {
						tok ~= *++c;
						_tokens ~= Token(TType.IO_OP,tok,_lineNum);
					}
					else if (*(c+1) == '=') {
						tok ~= *++c;
						_tokens ~= Token(TType.RELATIONAL_OP,tok,_lineNum);
					}
					else {
						_tokens ~= Token(TType.RELATIONAL_OP,tok,_lineNum);
					}
				}

				else if (*c == '>') {
					if (*(c+1) == '>') {
						tok ~= *++c;
						_tokens ~= Token(TType.IO_OP,tok,_lineNum);
					}
					else if (*(c+1) == '=') {
						tok ~= *++c;
						_tokens ~= Token(TType.RELATIONAL_OP,tok,_lineNum);		
					}
					else {
						_tokens ~= Token(TType.RELATIONAL_OP,tok,_lineNum);
					}
				}

				else if (*c == '&' && *(c+1) == '&') {
					tok ~= *++c;
					_tokens ~= Token(TType.LOGICAL_OP,tok,_lineNum);
				}

				else if (*c == '|' && *(c+1) == '|') {
					tok ~= *++c;
					_tokens ~= Token(TType.LOGICAL_OP,tok,_lineNum);
				}

				else if (*c == ';') {					
					_tokens ~= Token(TType.EOT,tok,_lineNum);
				}

				else if (*c == '\'') {
					if (*(c+1) == '\\')
						tok ~= *++c; // escape character
					tok ~= *++c; // character
					tok ~= *++c; // single quote
					_tokens ~= Token(TType.CHARACTER,tok,_lineNum);
				}

				else {
					_tokens ~= Token(TType.UNKNOWN,tok,_lineNum);
				}
			}

			if (_tokens.length >= BUFFER_SIZE)
				break;
		}

		if (_file.eof())
			_tokens ~= Token(TType.EOF);

		return next();
	}
}

/**********************************
 Private data
***********************************/
private:
immutable string[] keywords;
immutable string[] modifiers;

static this()
{
	keywords = [
		"atoi",
		"bool",
		"class",
		"char",
		"cin",
		"cout",
		"else",
		"false",
		"if",
		"int",
		"itoa",
		"main",
		"new",
		"null",
		"object",
		"public",
		"private",
		"return",
		"string",
		"this",
		"true",
		"void",
		"while"
	];

	modifiers = [
		"private",
		"public"
	];
}

/**********************************
 Helper functions
***********************************/
auto truncate(T,U)(T t, U delim)
{
	auto pos = indexOf(t, delim);
	return pos >= 0 ? t[0..pos] : t;
}

auto isKeyword(string s)
{
	return cast(bool)find(keywords,s).length;
}

auto isModifier(string s)
{
	return cast(bool)find(modifiers,s).length;
}
