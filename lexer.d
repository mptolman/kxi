import std.algorithm : find;
import std.ascii : isAlpha, isAlphaNum, isDigit, isWhite;
import std.conv;
import std.regex;
import std.stdio;
import std.string;

enum TType : byte 
{
	// Keywords
	ATOI, BOOL, CLASS, CHAR, CIN, COUT, ELSE, FALSE,
	IF, INT, ITOA, MAIN, NEW, NULL, OBJECT, RETURN,
	STRING, THIS, TRUE, VOID, WHILE,

	// Modifiers
	PRIVATE, PUBLIC,

	// Arrays
	ARRAY_BEGIN,
	ARRAY_END,

	// Operators	
	ASSIGN_OP, IO_OP, LOGIC_OP, MATH_OP, REL_OP,

	// Literals
	CHAR_LITERAL, INT_LITERAL,

	BLOCK_BEGIN,
	BLOCK_END,
	
	EOT,
	EOF,
	ID,	
	
	PAREN_OPEN,
	PAREN_CLOSE,		
	PUNCTUATION,
	
	UNKNOWN
}

struct Token
{
	TType type;
	string value;
	size_t line;
}

struct Rule
{
	Regex!char rgx;
	TType type;
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

			while(line.length) {
				auto matchFound = false;
				foreach (r; rules) {
					auto m = match(line, r.rgx);
					if (!m) continue;
					matchFound = true;
					Token t = Token(r.type, to!string(m.captures[1]), _lineNum);
					_tokens ~= t;
					//writeln(t);
					line = line[m.captures[1].length..$];
				}
				if (!matchFound)
					line = line[1..$];
			}

			if (_tokens.length >= BUFFER_SIZE)
				break;
		}

		if (_file.eof)
			_tokens ~= Token(TType.EOF);

		return next();
	}
}

/**********************************
 Private data
***********************************/
private:
Rule[] rules;

static this()
{
	rules = [

		// Keywords
		Rule(regex(r"^(atoi)(?:\W|$)"), TType.ATOI),
		Rule(regex(r"^(bool)(?:\W|$)"), TType.BOOL),
		Rule(regex(r"^(class)(?:\W|$)"), TType.CLASS),
		Rule(regex(r"^(char)(?:\W|$)"), TType.CHAR),
		Rule(regex(r"^(cin)(?:\W|$)"), TType.CIN),
		Rule(regex(r"^(cout)(?:\W|$)"), TType.COUT),
		Rule(regex(r"^(else)(?:\W|$)"), TType.ELSE),
		Rule(regex(r"^(false)(?:\W|$)"), TType.FALSE),
		Rule(regex(r"^(if)(?:\W|$)"), TType.IF),
		Rule(regex(r"^(int)(?:\W|$)"), TType.INT),
		Rule(regex(r"^(itoa)(?:\W|$)"), TType.ITOA),
		Rule(regex(r"^(main)(?:\W|$)"), TType.MAIN),
		Rule(regex(r"^(new)(?:\W|$)"), TType.NEW),
		Rule(regex(r"^(null)(?:\W|$)"), TType.NULL),
		Rule(regex(r"^(object)(?:\W|$)"), TType.OBJECT),
		Rule(regex(r"^(return)(?:\W|$)"), TType.RETURN),
		Rule(regex(r"^(string)(?:\W|$)"), TType.STRING),
		Rule(regex(r"^(this)(?:\W|$)"), TType.THIS),
		Rule(regex(r"^(true)(?:\W|$)"), TType.TRUE),
		Rule(regex(r"^(void)(?:\W|$)"), TType.VOID),
		Rule(regex(r"^(while)(?:\W|$)"), TType.WHILE),
		Rule(regex(r"^(public)(?:\W|$)"), TType.PUBLIC),
		Rule(regex(r"^(private)(?:\W|$)"), TType.PRIVATE),

		// Identifiers
		Rule(regex(r"^([a-zA-Z]+\w*)(?:\W|$)"), TType.ID),

		// Literals
		Rule(regex(r"^('\\?.')"), TType.CHAR_LITERAL),
		Rule(regex(r"^((\+|\-)?\d+)(?:\D|$)"), TType.INT_LITERAL),

		// Operators
		Rule(regex(r"^(<<|>>)"), TType.IO_OP),
		Rule(regex(r"^(&&|\|\|)"), TType.LOGIC_OP),
		Rule(regex(r"^(==|<=|<|>=|>)"), TType.REL_OP),
		Rule(regex(r"^(=)"), TType.ASSIGN_OP),
		Rule(regex(r"^(\+|\-|\*|/|%)(?:\D|$)"), TType.MATH_OP),

		Rule(regex(r"^(,|\.)"), TType.PUNCTUATION),

		Rule(regex(r"^(\[)"), TType.ARRAY_BEGIN),
		Rule(regex(r"^(\])"), TType.ARRAY_END),
		Rule(regex(r"^(\()"), TType.PAREN_OPEN),
		Rule(regex(r"^(\))"), TType.PAREN_CLOSE),
		Rule(regex(r"^(\{)"), TType.BLOCK_BEGIN),
		Rule(regex(r"^(\})"), TType.BLOCK_END),

		Rule(regex(r"^(;)"), TType.EOT)
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

//auto isKeyword(string s)
//{
//	return cast(bool)find(keywords,s).length;
//}

//auto isModifier(string s)
//{
//	return cast(bool)find(modifiers,s).length;
//}
