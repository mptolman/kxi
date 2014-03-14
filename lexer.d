import std.ascii;
import std.conv;
import std.stream;
import container, global;

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
    STREAM_INPUT, STREAM_OUTPUT,

    // Punctuation [,.;']
    COMMA, PERIOD, SEMICOLON, CHAR_DELIM,

    // End of file
    EOF,
    
    UNKNOWN
}

struct Token
{
    TType type;
    string lexeme;
    size_t line;
}

class Lexer
{
public:
    bool recordKxi;

    this(string fileName)
    {
        _file   = new BufferedFile(fileName);
        _tokens = new Queue!Token;
    }

    Token peek()
    {
        if (!_tokens.empty)
            return _tokens.front;

        loadMoreTokens();
        return peek();
    }

    Token next()
    {
        if (!_tokens.empty) {
            auto t = _tokens.front;
            _tokens.pop();
            return t;
        }

        loadMoreTokens();
        return next();
    }

    void rewind()
    {
        _file.seek(0, SeekPos.Set);
        _tokens.clear();
        _lineNum = 0;
    }

private:
    Stream _file;
    Queue!Token _tokens;

    string _line;
    string _lexeme;
    size_t _pos;
    size_t _lineNum;

    void loadMoreTokens()
    {
        static char[] buffer;

        if (_file.eof) {
            _tokens.push(Token(TType.EOF, null, _lineNum));
            return;
        }

        _line = to!string(_file.readLine(buffer));
        _line ~= '\n';
        ++_lineNum;

        if (recordKxi && global.kxiIsNew) {
            global.kxi ~= _line;
        }
        else if (recordKxi) {
            global.kxi = _line;
            global.kxiIsNew = true;
        }

        for (_pos = 0; _pos < _line.length;) {
            char c  = _line[_pos++];
            _lexeme = [c];

            if (isWhite(c)) {
                // ignore whitespace
            }
            else if (isAlpha(c)) {
                alphaNum();
            }
            else if (isDigit(c)) {
                digit();
            }
            else if (c == '<') {
                lt();
            }
            else if (c == '>') {
                gt();
            }
            else if (c == '&') {
                and();
            }
            else if (c == '|') {
                or();
            }
            else if (c == '=') {
                equals();
            }
            else if (c == '!') {
                not();
            }
            else if (c == '/') {
                divide();
            }
            else if (c == '\'') {
                charLiteral();
            }
            else if (c == '+' || c == '-') {
                plusOrMinus();
            }
            else if (_lexeme in tokenMap) {
                _tokens.push(Token(tokenMap[_lexeme], _lexeme, _lineNum));
            }
            else {
                _tokens.push(Token(TType.UNKNOWN, _lexeme, _lineNum));
            }
        }
    }

    auto collectWhile(bool function(char) f)
    {
        string tok;

        for (; _pos < _line.length; ++_pos) {
            if (f(_line[_pos]))
                tok ~= _line[_pos];
            else
                break;
        }

        return tok;
    }

    void alphaNum()
    {    
        _lexeme ~= collectWhile(c => isAlphaNum(c) || c == '_');
        _tokens.push(Token(_lexeme in tokenMap ? tokenMap[_lexeme] : TType.IDENTIFIER, _lexeme, _lineNum));
    }

    void digit()
    {
        _lexeme ~= collectWhile(c => isDigit(c));
        _tokens.push(Token(TType.INT_LITERAL, _lexeme, _lineNum));
    }

    void lt()
    {
        if (_line[_pos] == '<') {
            _lexeme ~= _line[_pos++];
            _tokens.push(Token(TType.STREAM_OUTPUT, _lexeme, _lineNum));
        }
        else if (_line[_pos] == '=') {
            _lexeme ~= _line[_pos++];
            _tokens.push(Token(TType.REL_OP, _lexeme, _lineNum));
        }
        else {
            _tokens.push(Token(TType.REL_OP, _lexeme, _lineNum));
        }
    }

    void gt()
    {
        if (_line[_pos] == '>') {
            _lexeme ~= _line[_pos++];
            _tokens.push(Token(TType.STREAM_INPUT, _lexeme, _lineNum));
        }
        else if (_line[_pos] == '=') {
            _lexeme ~= _line[_pos++];
            _tokens.push(Token(TType.REL_OP, _lexeme, _lineNum));
        }
        else {
            _tokens.push(Token(TType.REL_OP, _lexeme, _lineNum));
        }   
    }

    void equals()
    {
        if (_line[_pos] == '=') {
            _lexeme ~= _line[_pos++];
            _tokens.push(Token(TType.REL_OP, _lexeme, _lineNum));
        }
        else {
            _tokens.push(Token(TType.ASSIGN_OP, _lexeme, _lineNum));
        }
    }

    void not()
    {
        if (_line[_pos] == '=') {
            _lexeme ~= _line[_pos++];
            _tokens.push(Token(TType.REL_OP, _lexeme, _lineNum));
        }
    }

    void and()
    {
        if (_line[_pos] == '&') {
            _lexeme ~= _line[_pos++];
            _tokens.push(Token(TType.LOGIC_OP, _lexeme, _lineNum));
        }
    }

    void or()
    {
        if (_line[_pos] == '|') {
            _lexeme ~= _line[_pos++];
            _tokens.push(Token(TType.LOGIC_OP, _lexeme, _lineNum));
        }
    }

    void divide()
    {
        if (_line[_pos] == '/')
            _pos = _line.length; // comment--skip to end of line
        else
            _tokens.push(Token(TType.MATH_OP, _lexeme, _lineNum));
    }

    void charLiteral()
    {
        _tokens.push(Token(TType.CHAR_DELIM, _lexeme, _lineNum));

        char c = _line[_pos++];
        _tokens.push(Token(TType.CHAR_LITERAL, [c], _lineNum));

        if (c == '\\')
            _tokens.push(Token(TType.CHAR_LITERAL, [_line[_pos++]], _lineNum));

        if (_line[_pos] == '\'')
            _tokens.push(Token(TType.CHAR_DELIM, [_line[_pos++]], _lineNum));
    }

    void plusOrMinus()
    {    
        if (isDigit(_line[_pos]))
            digit();
        else
            _tokens.push(Token(TType.MATH_OP, _lexeme, _lineNum));
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
        "while"     : TType.WHILE,
        "int"       : TType.TYPE,
        "char"      : TType.TYPE,
        "bool"      : TType.TYPE,
        "void"      : TType.TYPE,
        "{"         : TType.BLOCK_BEGIN,
        "}"         : TType.BLOCK_END,
        "("         : TType.PAREN_OPEN,
        ")"         : TType.PAREN_CLOSE,
        "["         : TType.ARRAY_BEGIN,
        "]"         : TType.ARRAY_END,
        "."         : TType.PERIOD,
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
        ";"         : TType.SEMICOLON,
        "\'"        : TType.CHAR_DELIM
    ];
}