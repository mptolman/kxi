enum TokType
{
	INTEGER,
	CHARACTER,
	IDENTIFIER,
	PUNCTUATION,
	KEYWORD,
	MATH_OP,
	REL_OP,
	BOOL_OP,
	ASSIGN_OP,
	ARRAY_BEGIN,
	ARRAY_END,
	BLOCK_BEGIN,
	BLOCK_END,
	PAREN_OPEN,
	PAREN_CLOSE,
	UNKNOWN,
	EOT,
	EOF
}

struct Tok
{
	TokType type;
	string lexeme;
}

private:
immutable TokRegex[] rules;

struct TokRegex
{
	TokType type;
	string regex;
}

static this()
{
	rules = [
		TokRegex(TokType.CHARACTER, r"[a-zA-Z]")
	];
}
