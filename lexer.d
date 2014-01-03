import std.algorithm : find;
import std.ascii : isAlpha, isAlphaNum, isDigit, isWhite;
import std.regex;
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

/**********************************
 Types
***********************************/
enum TType : byte 
{
	NUMBER,
	CHARACTER,
	IDENTIFIER,
	PUNCTUATION,
	KEYWORD,
	MATH_OP,
	RELATIONAL_OP,
	LOGICAL_OP,
	ASSIGN_OP,
	IO_OP,
	ARRAY_BEGIN,
	ARRAY_END,
	BLOCK_BEGIN,
	BLOCK_END,
	PAREN_OPEN,
	PAREN_CLOSE,
	EOT,
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
	private Token[] _tokens;
	private size_t _lineNum;
	private static immutable LINES_TO_BUFFER = 5;

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
			auto line = strip(truncate(buf,"//"));
			if (line.length == 0) continue;

			for (auto c = line.ptr; c < line.ptr+line.length; ++c) {
				string tok = [*c];

				if (isAlpha(*c)) {
					while (isAlphaNum(*(c+1)))
						tok ~= *++c;

					if (isKeyword(tok))
						_tokens ~= Token(TType.KEYWORD,tok,_lineNum);
					else
						_tokens ~= Token(TType.IDENTIFIER,tok,_lineNum);
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

				else if (isDigit(*c)) {
					while (isDigit(*(c+1)))
						tok ~= *++c;
					_tokens ~= Token(TType.NUMBER,tok,_lineNum);
				}

				else if (match(tok, regex(r"[,\.]"))) {
					_tokens ~= Token(TType.PUNCTUATION,tok,_lineNum);
				}

				else if (match(tok, regex(r"[\+\-\*/%]"))) {
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
					if (*++c == '\\') {
						switch (*++c) {
						case 'n':
							tok = "\\n";
							break;
						case 't':
							tok = "\\t";
							break;
						case '\\':
							tok = "\\";
							break;
						}
					}
					else {
						tok = [*c];
					}
				}

				else if (isWhite(*c)) {
					// Ignore whitespace
				}

				else {
					_tokens ~= Token(TType.UNKNOWN,tok,_lineNum);
				}
			}

			if (_lineNum % LINES_TO_BUFFER == 0)
				break;
		}

		if (_file.eof())
			_tokens ~= Token(TType.EOF);

		return next();
	}
}

void main() {
	Lexer lexer = new Lexer(File("A.kxi"));
	Token t;
	do {
		t = lexer.next();
		writeln(t);
	} while (t.type != TType.EOF);
}

/**********************************
 Private data
***********************************/
private:
immutable string[] keywords;
immutable string punctuation;

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
}