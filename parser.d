import std.conv;
import std.stdio;
import std.string;
import lexer, symbol;

void parse(File src)
{
    tokens = new Lexer(src);

    firstPass = true;
    compilation_unit(); // first pass

    tokens.rewind();

    firstPass = false;
    compilation_unit(); // second pass
}

class SyntaxError : Exception
{
    this(Args...)(size_t line, Args args)
    {
        super(text("(",line,"): ",args));
    }
}

/****************************
 * Module-level data
 ***************************/
private:
bool firstPass;
Lexer tokens;
Token ct;

struct Scope
{
private:
    static string _scope;

public:    
    static void push(string s)
    {
        _scope ~= _scope.length ? '.' ~ s : s;
    }

    static void pop()
    {
        auto pos = lastIndexOf(_scope,'.');
        _scope = pos ? _scope[0..pos] : null;
    }

    static void reset()
    {
        _scope = null;
    }

    static auto toString()
    {
        return _scope;
    }
}

/****************************
* Helper functions
/***************************/
void next()
{
    ct = tokens.next();
}

auto peek()
{
    return tokens.peek();
}

void assertType(TType types[] ...)
{
    foreach (t; types)
        if (ct.type == t)
            return;

    throw new SyntaxError(ct.line,"Expected ",types,". Found ",ct.type," \"",ct.value,"\"");
}

void assertValue(string values[] ...)
{
    foreach (v; values)
        if (ct.value == v)
            return;

    throw new SyntaxError(ct.line,"Expected ",values,". Found \"",ct.value,"\"");
}

/****************************
* Nonterminal procedures
****************************/
void compilation_unit()
{
    // compilation_unit::= 
    //    {class_declaration} 
    //    "void" "main" "(" ")" method_body
    // ;

    Scope.reset();
    Scope.push("g");

    next();
    while (ct.type == TType.CLASS)
        class_declaration();

    assertValue("void");
    auto returnType = ct.value;
    
    next();
    assertType(TType.MAIN);
    auto methodName = ct.value;

    if (firstPass)
        SymbolTable.add(new MethodSymbol(methodName,returnType,PUBLIC_MODIFIER,Scope.toString,ct.line));

    Scope.push(methodName);

    next();
    assertType(TType.PAREN_OPEN); 
    next();
    assertType(TType.PAREN_CLOSE);     
    next();
    method_body();

    Scope.pop();
}

void class_declaration()
{
    // class_declaration::=
    //    "class" class_name "{" 
    //    {class_member_declaration} "}" 
    // ;

    assertType(TType.CLASS);    
    next();
    assertType(TType.IDENTIFIER);
    auto className = ct.value;

    if (firstPass)
        SymbolTable.add(new ClassSymbol(className,Scope.toString,ct.line));

    Scope.push(className);    

    next();
    assertType(TType.BLOCK_BEGIN);     
    next();
    while (ct.type != TType.BLOCK_END)
        class_member_declaration(className);
    assertType(TType.BLOCK_END); 
    next();

    Scope.pop();
}

void class_member_declaration(string className)
{
    // class_member_declaration::=
    //      modifier type identifier field_declaration
    //    | constructor_declaration  
    // ;

    if (ct.type == TType.MODIFIER) {
        auto modifier = ct.value;

        next();
        assertType(TType.TYPE,TType.IDENTIFIER);
        auto type = ct.value;

        next();        
        assertType(TType.IDENTIFIER);
        auto identifier = ct.value;

        next();
        field_declaration(modifier,type,identifier);
    }
    else if (ct.value == className) {
        constructor_declaration();
    }
    else {
        throw new SyntaxError(ct.line,"Expected modifier or constructor. Found ",ct.type," \"",ct.value,"\"");
    }
}

void field_declaration(string modifier, string type, string identifier)
{
    // field_declaration::=
    //     ["[" "]"] ["=" assignment_expression ] ";"  
    //    | "(" [parameter_list] ")" method_body
    //    ;

    Symbol s;

    if (ct.type == TType.PAREN_OPEN) {
        s = new MethodSymbol(identifier,type,modifier,Scope.toString,ct.line);

        Scope.push(identifier);

        next();
        if (ct.type != TType.PAREN_CLOSE)
            parameter_list(cast(MethodSymbol)s);
        assertType(TType.PAREN_CLOSE);
        next();
        method_body();

        Scope.pop();
    }
    else {        
        if (ct.type == TType.ARRAY_BEGIN) {
            type ~= "[]";
            
            next();
            assertType(TType.ARRAY_END); 
            next();            
        }

        s = new IVarSymbol(identifier,type,modifier,Scope.toString,ct.line);

        if (ct.type == TType.ASSIGN_OP) {
            next();
            assignment_expression();
        }

        assertType(TType.SEMICOLON); 
        next();
    }

    if (firstPass)
        SymbolTable.add(s);
}

void constructor_declaration()
{
    // constructor_declaration::=
    //    class_name "(" [parameter_list] ")" method_body ;

    assertType(TType.IDENTIFIER);
    auto className = ct.value;
    auto methodSymbol = new MethodSymbol(className,"this",PUBLIC_MODIFIER,Scope.toString,ct.line);

    Scope.push(className);

    next();
    assertType(TType.PAREN_OPEN);
    next();
    if (ct.type != TType.PAREN_CLOSE)
        parameter_list(methodSymbol);
    assertType(TType.PAREN_CLOSE); 
    next();
    method_body();

    Scope.pop();

    if (firstPass)
        SymbolTable.add(methodSymbol);
}

void parameter_list(MethodSymbol methodSymbol)
{
    // parameter_list::= parameter { "," parameter } ;

    parameter(methodSymbol);
    while (ct.type == TType.COMMA) {
        next();
        parameter(methodSymbol); 
    }
}

void parameter(MethodSymbol methodSymbol)
{
    // parameter::= type identifier ["[" "]"] ;

    assertType(TType.TYPE,TType.IDENTIFIER);
    auto type = ct.value;

    next();    
    assertType(TType.IDENTIFIER); 
    auto identifier = ct.value;

    next();
    if (ct.type == TType.ARRAY_BEGIN) {
        type ~= "[]";

        next();
        assertType(TType.ARRAY_END); 
        next();
    }

    if (firstPass) {
        auto p = new ParamSymbol(identifier,type,Scope.toString,ct.line);
        methodSymbol.addParam(p);
        SymbolTable.add(p);
    }
}

void method_body()
{
    // method_body::=
    //    "{" {variable_declaration} {statement} "}" ;

    assertType(TType.BLOCK_BEGIN);
    next();

    while ((ct.type == TType.TYPE || ct.type == TType.IDENTIFIER) && peek().type == TType.IDENTIFIER)
        variable_declaration();

    while (ct.type != TType.BLOCK_END)
        statement();

    assertType(TType.BLOCK_END);
    next();
}

void variable_declaration()
{
    // variable_declaration::= 
    //    type identifier ["[" "]"] ["=" assignment_expression ] ";" ;

    assertType(TType.TYPE,TType.IDENTIFIER);
    auto type = ct.value;

    next();
    assertType(TType.IDENTIFIER);
    auto identifier = ct.value;

    next();
    if (ct.type == TType.ARRAY_BEGIN) {
        type ~= "[]";

        next();
        assertType(TType.ARRAY_END);
        next();
    }

    if (firstPass)
        SymbolTable.add(new LVarSymbol(identifier,type,Scope.toString,ct.line));

    if (ct.type == TType.ASSIGN_OP) {
        next();
        assignment_expression();
    }

    assertType(TType.SEMICOLON);
    next();
}

void assignment_expression()
{
    // assignment_expression::=
    //        expression
    //      | "this"
    //      | "new" type new_declaration
    //      | "atoi" "(" expression ")"
    //      | "itoa" "(" expression ")"
    // ;

    switch (ct.type) {
    case TType.THIS:
        next();
        break;
    case TType.NEW:
        next();
        assertType(TType.TYPE,TType.IDENTIFIER);
        next();
        new_declaration();
        break;
    case TType.ATOI:
    case TType.ITOA:
        next();
        assertType(TType.PAREN_OPEN);
        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        next();
        break;
    default:
        expression();
        break;
    }
}

void statement()
{
    // statement::=
    //      "{" {statement} "}" 
    //    | expression ";"
    //    | "if" "(" expression ")" statement [ "else" statement ]
    //    | "while" "(" expression ")" statement
    //    | "return" [ expression ] ";" 
    //    | "cout" "<<" expression ";"
    //    | "cin" ">>" expression ";"
    // ;

    switch (ct.type) {
    case TType.BLOCK_BEGIN:
        next();
        while (ct.type != TType.BLOCK_END)
            statement();
        assertType(TType.BLOCK_END);
        next();
        break;
    case TType.IF:
        next();
        assertType(TType.PAREN_OPEN);
        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        next();
        statement();
        if (ct.type == TType.ELSE) {
            next();
            statement();
        }
        break;
    case TType.WHILE:
        next();
        assertType(TType.PAREN_OPEN);
        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        next();
        statement();
        break;
    case TType.RETURN:
        next();
        if (ct.type != TType.SEMICOLON)
            expression();
        assertType(TType.SEMICOLON);
        next();
        break;
    case TType.COUT:
        next();
        assertType(TType.STREAM_OUTPUT);
        next();
        expression();
        assertType(TType.SEMICOLON);
        next();
        break;
    case TType.CIN:
        next();
        assertType(TType.STREAM_INPUT);
        next();
        expression();
        assertType(TType.SEMICOLON);
        next();
        break;
    default:
        expression();
        assertType(TType.SEMICOLON);
        next();
        break;
    }
}

void expression()
{
    // expression::=
    //      "(" expression ")" [ expressionz ]
    //    | "true" [ expressionz ]
    //    | "false" [ expressionz ]
    //    | "null" [ expressionz ]
    //    | numeric_literal [ expressionz ]
    //    | character_literal [ expressionz ]
    //    | identifier [ fn_arr_member ] [ member_refz ] [ expressionz ]
    // ;

    if (ct.type == TType.PAREN_OPEN) {
        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        next();
        expressionz();
    }
    else if (ct.type == TType.IDENTIFIER) {
        next();
        if (ct.type == TType.PAREN_OPEN || ct.type == TType.ARRAY_BEGIN)
            fn_arr_member();
        if (ct.type == TType.PERIOD)
            member_refz();        
        expressionz();
    }
    else {
        switch (ct.type) {
        case TType.TRUE:
        case TType.FALSE:        
        case TType.NULL:
            next();
            expressionz();
            break;
        case TType.INT_LITERAL:
            numeric_literal();
            expressionz();
            break;
        case TType.CHAR_DELIM:
            character_literal();
            expressionz();
            break;
        default:
            throw new SyntaxError(ct.line,"Expected expression; found ",ct.type," \"",ct.value,"\"");
        }
    }
}

void expressionz()
{
    // expressionz::=
    //        "=" assignment_expression 
    //      | "&&" expression       /* logical connective expression */
    //      | "||" expression       /* logical connective expression */
    //      | "==" expression       /* boolean expression */
    //      | "!=" expression       /* boolean expression */
    //      | "<=" expression       /* boolean expression */
    //      | ">=" expression       /* boolean expression */
    //      | "<" expression        /* boolean expression */
    //      | ">" expression        /* boolean expression */
    //      | "+" expression        /* mathematical expression */
    //      | "-" expression        /* mathematical expression */
    //      | "*" expression        /* mathematical expression */
    //      | "/" expression        /* mathematical expression */
    // ;

    switch (ct.type) {
    case TType.ASSIGN_OP:
        next();
        assignment_expression();
        break;
    case TType.LOGIC_OP:
    case TType.REL_OP:
    case TType.MATH_OP:
        next();
        expression();
        break;
    case TType.INT_LITERAL:
        if (ct.value[0] == '-' || ct.value[0] == '+') {
            // push operation
            expression();
        }
        break;
    default:
        break;
    } 
}

void new_declaration()
{
    // new_declaration::=
    //      "(" [ argument_list ] ")"
    //    | "[" expression "]"
    // ;

    if (ct.type == TType.PAREN_OPEN) {
        next();
        if (ct.type != TType.PAREN_CLOSE)
            argument_list();
        assertType(TType.PAREN_CLOSE);
        next();
    }
    else if (ct.type == TType.ARRAY_BEGIN) {
        next();
        expression();
        assertType(TType.ARRAY_END);
        next();
    }
    else {
        throw new SyntaxError(ct.line,"Expected ( or [. Found ",ct.type," \"",ct.value,"\"");
    }
}

void fn_arr_member()
{
    // fn_arr_member::= 
    //        "(" [ argument_list ] ")" 
    //      | "[" expression "]" ;

    if (ct.type == TType.PAREN_OPEN) {
        next();
        if (ct.type != TType.PAREN_CLOSE)
            argument_list();
        assertType(TType.PAREN_CLOSE);
        next();
    }
    else {
        assertType(TType.ARRAY_BEGIN);
        next();
        expression();
        assertType(TType.ARRAY_END);
        next();
    }
}

void member_refz()
{
    // member_refz::= "." identifier [ fn_arr_member ] [ member_refz ] ;

    assertType(TType.PERIOD);
    next();
    assertType(TType.IDENTIFIER);
    next();
    if (ct.type == TType.PAREN_OPEN || ct.type == TType.ARRAY_BEGIN)
        fn_arr_member();
    if (ct.type == TType.PERIOD)
        member_refz();
}

void argument_list()
{
    // argument_list::= expression { "," expression } ;

    expression();
    while (ct.type == TType.COMMA) {
        next();
        expression();
    }
}

void character_literal()
{
    // character_literal::= "\’" character "\’" ;

    string s;

    assertType(TType.CHAR_DELIM);
    next();
    assertType(TType.CHAR_LITERAL);

    if (ct.value == "\\") {
        next();
        assertType(TType.CHAR_LITERAL);
        switch (ct.value) {
        case "\\":
            s = "\\";
            break;
        case "n":
            s = "\n";
            break;
        case "t":
            s = "\t";
            break;
        case "\'":
            s = "\'";
            break;
        default:        
            throw new SyntaxError(ct.line,"Invalid character escape sequence \'\\",ct.value,"\'");
        }
    }
    else {
        s = ct.value;
    }

    next();
    assertType(TType.CHAR_DELIM);

    if (firstPass)
        SymbolTable.add(new GlobalSymbol(s,"char",ct.line));

    next();
}

void numeric_literal()
{
    // numeric_literal::= ["+" | "-"]number ;

    assertType(TType.INT_LITERAL);

    if (firstPass)
        SymbolTable.add(new GlobalSymbol(ct.value,"int",ct.line));

    next();
}
