import std.ascii : isAlpha, isAlphaNum, isDigit, isWhite;
import std.stdio;

enum TType : byte 
{
    // Keywords
    ATOI, BOOL, CLASS, CHAR, CIN, COUT, ELSE, FALSE,
    IF, INT, ITOA, MAIN, NEW, NULL, OBJECT, RETURN,
    STRING, THIS, TRUE, VOID, WHILE,

    // Modifiers
    PRIVATE, PUBLIC,

    // Identifiers
    ID,

    // Literals
    CHAR_LITERAL, INT_LITERAL,

    // Arrays
    ARRAY_BEGIN, ARRAY_END,

    // Blocks
    BLOCK_BEGIN, BLOCK_END,

    // Parenthesis
    PAREN_OPEN, PAREN_CLOSE,

    // Operators    
    ASSIGN_OP, // =
    LOGIC_OP,  // &&, ||
    REL_OP,    // <,>,<=,>=,==,!=
    IO_OP,     // <<,>>
    MATH_OP,   // +,-,*,/,%

    // Punctuation [,.]
    PUNCTUATION,

    // End of statement [;]
    EOS,

    // End of file
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
public:
    this(File file) 
    {
        _file = file;
    }

    Token peek()
    {
        if (_tokens.length)
            return _tokens[0];

        loadMoreTokens();
        return peek();
    }

    Token next()
    {
        if (_tokens.length) {
            Token t = _tokens[0];
            _tokens = _tokens[1..$];
            return t;
        }

        loadMoreTokens();
        return next();
    }

private:
    File _file;
    Token[] _tokens;
    size_t _lineNum;
    static immutable BUFFER_SIZE = 100;

    void loadMoreTokens()
    {
        enum State : byte
        {
            ALPHANUM,
            AND,
            BEGIN,
            CHAR_BEGIN,
            CHAR_END,
            CHAR_ESCAPE,
            DIGIT,
            EQUALS,
            GT,
            LT,
            OR,
            NOT,
            PLUS_OR_MINUS,
            POSSIBLE_COMMENT,
            COMMENT
        }

        immutable MAX_ID_LEN = 80;

        char[] line;
        while (_file.readln(line)) {
            ++_lineNum;

            string tok;
            State state = State.BEGIN;
            for (auto i = 0; i < line.length; ++i) {
                auto c = line[i];

                final switch (state) {
                case State.BEGIN:
                    tok = [c];

                    if (isWhite(c)) { /* ignore whitespace */ }
                    else if (isAlpha(c))
                        state = State.ALPHANUM;
                    else if (isDigit(c))
                        state = State.DIGIT;
                    else if (c == '<')
                        state = State.LT;
                    else if (c == '>')
                        state = State.GT;
                    else if (c == '=')
                        state = State.EQUALS;
                    else if (c == '&')
                        state = State.AND;
                    else if (c == '|')
                        state = State.OR;
                    else if (c == '!')
                        state = State.NOT;
                    else if (c == '\'')
                        state = State.CHAR_BEGIN;
                    else if (c == '/')
                        state = State.POSSIBLE_COMMENT;
                    else if (c == '+' || c == '-')
                        state = State.PLUS_OR_MINUS;
                    else if (tok in tokenMap)
                        _tokens ~= Token(tokenMap[tok],tok,_lineNum);
                    break;

                case State.ALPHANUM:
                    if (isAlphaNum(c)) {
                        tok ~= c;
                        break;
                    }
                    if (tok in tokenMap)
                        _tokens ~= Token(tokenMap[tok],tok,_lineNum);
                    else if (tok.length < MAX_ID_LEN)
                        _tokens ~= Token(TType.ID,tok,_lineNum);
                    state = State.BEGIN;
                    --i;
                    break;

                case State.DIGIT:
                    if (isDigit(c)) {
                        tok ~= c;
                        break;
                    }
                    _tokens ~= Token(TType.INT_LITERAL,tok,_lineNum);
                    state = State.BEGIN;
                    --i;
                    break;

                case State.PLUS_OR_MINUS:
                    if (isDigit(c)) {
                        tok ~= c;
                        state = State.DIGIT;
                        break;
                    }
                    _tokens ~= Token(tokenMap[tok],tok,_lineNum);
                    state = State.BEGIN;
                    --i;
                    break;

                case State.EQUALS:
                    if (c == '=')
                        tok ~= c;
                    else
                        --i;
                    _tokens ~= Token(tokenMap[tok],tok,_lineNum);
                    state = State.BEGIN;
                    break;

                case State.AND:
                    if (c == '&') {
                        tok ~= c;
                        _tokens ~= Token(tokenMap[tok],tok,_lineNum);
                    }
                    else {
                        --i;
                    }
                    state = State.BEGIN;
                    break;

                case State.OR:
                    if (c == '|') {
                        tok ~= c;
                        _tokens ~= Token(tokenMap[tok],tok,_lineNum);
                    }
                    else {
                        --i;
                    }
                    state = State.BEGIN;
                    break;

                case State.NOT:
                    if (c == '=') {
                        tok ~= c;
                        _tokens ~= Token(tokenMap[tok],tok,_lineNum);                       
                    }
                    else {
                        --i;
                    }
                    state = State.BEGIN;
                    break;

                case State.LT:
                    if (c == '=' || c == '<')
                        tok ~= c;
                    else
                        --i;
                    _tokens ~= Token(tokenMap[tok],tok,_lineNum);
                    state = State.BEGIN;
                    break;

                case State.GT:
                    if (c == '=' || c == '>')
                        tok ~= c;
                    else
                        --i;
                    _tokens ~= Token(tokenMap[tok],tok,_lineNum);
                    state = State.BEGIN;
                    break;

                case State.CHAR_BEGIN:
                    tok ~= c;
                    if (c == '\\')
                        state = State.CHAR_ESCAPE;
                    else
                        state = State.CHAR_END;
                    break;

                case State.CHAR_ESCAPE:
                    tok ~= c;
                    state = State.CHAR_END;
                    break;

                case State.CHAR_END:
                    if (c == '\'') {
                        tok ~= c;
                        _tokens ~= Token(TType.CHAR_LITERAL,tok,_lineNum);
                        break;
                    }
                    state = State.BEGIN;
                    --i;
                    break;

                case State.POSSIBLE_COMMENT:
                    if (c == '/') {
                        state = State.COMMENT;
                        break;
                    }
                    else {
                        // Divide operator
                        _tokens ~= Token(tokenMap[tok],tok,_lineNum);
                    }
                    state = State.BEGIN;
                    --i;
                    break;

                case State.COMMENT:
                    if (c == '\n')
                        state = State.BEGIN;
                    break;
                }
            }

            if (_tokens.length >= BUFFER_SIZE)
                break;
        }

        if (_file.eof)
            _tokens ~= Token(TType.EOF);
    }
}

/**********************************
 Private data
***********************************/
private:
immutable TType[string] tokenMap;

static this()
{
    tokenMap = [
        "atoi" : TType.ATOI,
        "bool" : TType.BOOL,
        "class" : TType.CLASS,
        "char" : TType.CHAR,
        "cin" : TType.CIN,
        "cout" : TType.COUT,
        "else" : TType.ELSE,
        "false" : TType.FALSE,
        "if" : TType.IF,
        "int" : TType.INT,
        "itoa" : TType.ITOA,
        "main" : TType.MAIN,
        "new" : TType.NEW,
        "null" : TType.NULL,
        "object" : TType.OBJECT,
        "private" : TType.PRIVATE,
        "public" : TType.PUBLIC,
        "return" : TType.RETURN,
        "string" : TType.STRING,
        "this" : TType.THIS,
        "true" : TType.TRUE,
        "void" : TType.VOID,
        "while" : TType.WHILE,
        "{" : TType.BLOCK_BEGIN,
        "}" : TType.BLOCK_END,
        "(" : TType.PAREN_OPEN,
        ")" : TType.PAREN_CLOSE,
        "[" : TType.ARRAY_BEGIN,
        "]" : TType.ARRAY_END,
        "." : TType.PUNCTUATION,
        "," : TType.PUNCTUATION,
        "+" : TType.MATH_OP,
        "-" : TType.MATH_OP,
        "*" : TType.MATH_OP,
        "/" : TType.MATH_OP,
        "%" : TType.MATH_OP,
        "<" : TType.REL_OP,
        ">" : TType.REL_OP,
        "<=" : TType.REL_OP,
        ">=" : TType.REL_OP,
        "!=" : TType.REL_OP,
        "==" : TType.REL_OP,
        "<<" : TType.IO_OP,
        ">>" : TType.IO_OP,
        "=" : TType.ASSIGN_OP,
        "&&" : TType.LOGIC_OP,
        "||" : TType.LOGIC_OP,
        ";" : TType.EOS
    ];
}
