enum TokenType
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

struct Token
{
	TokenType type;
	string lexeme;
}

private:
immutable TokenRegex[] rules;

struct TokenRegex
{
	TokenType type;
	string regex;
}

static this()
{
	rules = [
		TokenRegex(TokenType.KEYWORD, r"atoi|bool|class|char|cin|cout|else|false|if|int|itoa|main|new|null|object|public|private|return|string|this|true|void|while"),
		TokenRegex(TokenType.CHARACTER, r"[a-zA-Z]")
	];
}
