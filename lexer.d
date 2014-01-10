import std.ascii;
import std.stdio;

enum TType : byte 
{
    // Keywords
    ATOI, CLASS, CIN, COUT, ELSE, FALSE,
    IF, ITOA, MAIN, NEW, NULL, OBJECT, RETURN,
    STRING, THIS, TRUE, VOID, WHILE,

    // Types (bool, char, int)
    TYPE,

    // Modifiers (private, public)
    MODIFIER,

    // Identifiers
    IDENTIFIER,

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
    MATH_OP,   // +,-,*,/,%

    // IO operations
    STREAM_INPUT, STREAM_OUTPUT

    // Punctuation [,.]
    COMMA, DOT

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

    void rewind()
    {
        _tokens = null;
        _lineNum = 0;
        _file.rewind();
    }

private:
    File _file;
    Token[] _tokens;
    size_t _lineNum;
    static immutable BUFFER_SIZE = 500;

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
            COMMENT,
            DIGIT,
            EQUALS,
            GT,
            LT,
            NOT,
            OR,
            PLUS_OR_MINUS,
            POSSIBLE_COMMENT
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
                        _tokens ~= Token(TType.IDENTIFIER,tok,_lineNum);
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
        "atoi"      : TType.ATOI,
        "class"     : TType.CLASS,
        "cin"       : TType.CIN,
        "cout"      : TType.COUT,
        "else"      : TType.ELSE,
        "false"     : TType.FALSE,
        "if"        : TType.IF,
        "itoa"      : TType.ITOA,
        "main"      : TType.MAIN,
        "new"       : TType.NEW,
        "null"      : TType.NULL,
        "object"    : TType.OBJECT,
        "private"   : TType.MODIFIER,
        "public"    : TType.MODIFIER,
        "return"    : TType.RETURN,
        "string"    : TType.STRING,
        "this"      : TType.THIS,
        "true"      : TType.TRUE,
        "void"      : TType.VOID,
        "while"     : TType.WHILE,
        "bool"      : TType.TYPE,
        "char"      : TType.TYPE,
        "int"       : TType.TYPE,
        "{"         : TType.BLOCK_BEGIN,
        "}"         : TType.BLOCK_END,
        "("         : TType.PAREN_OPEN,
        ")"         : TType.PAREN_CLOSE,
        "["         : TType.ARRAY_BEGIN,
        "]"         : TType.ARRAY_END,
        "."         : TType.DOT,
        ","         : TType.COMMA,
        "+"         : TType.MATH_OP,
        "-"         : TType.MATH_OP,
        "*"         : TType.MATH_OP,
        "/"         : TType.MATH_OP,
        "%"         : TType.MATH_OP,
        "<"         : TType.REL_OP,
        ">"         : TType.REL_OP,
        "<="        : TType.REL_OP,
        ">="        : TType.REL_OP,
        "!="        : TType.REL_OP,
        "=="        : TType.REL_OP,
        "<<"        : TType.STREAM_OUTPUT,
        ">>"        : TType.STREAM_INPUT,
        "="         : TType.ASSIGN_OP,
        "&&"        : TType.LOGIC_OP,
        "||"        : TType.LOGIC_OP,
        ";"         : TType.EOS
    ];
}
