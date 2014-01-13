import std.conv;
import std.stdio;
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

/****************************
* Helper functions
/***************************/
void next()
{
    ct = tokens.next();
}

Token peek()
{
    return tokens.peek();
}

void assertType(TType type)
{
    if (ct.type != type)
        throw new SyntaxError(ct.line,"Expected ",type,"; found ",ct.type," \"",ct.value,"\"");
}

/****************************
* Nonterminal procedures
****************************/
void argument_list()
{
    // argument_list::= expression { "," expression } ;

    expression();
    while (ct.type == TType.COMMA) {
        next();
        expression();
    }
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
        assertType(TType.TYPE);
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

    if (firstPass) {
        auto s = new ClassSymbol();
        s.value = ct.value;
        symbol.symbolTable[s.id] = s;
    }

    next();
    assertType(TType.BLOCK_BEGIN); 
    next();
    while (ct.type != TType.BLOCK_END)
        class_member_declaration(className);
    assertType(TType.BLOCK_END); 
    next();
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
        assertType(TType.TYPE);
        next();
        assertType(TType.IDENTIFIER); 
        next();
        field_declaration();
    }
    else if (ct.value == className) {
        constructor_declaration();
    }
    else {
        throw new SyntaxError(ct.line,"Expected modifier or constructor; found ",ct.type," \"",ct.value,"\"");
    }
}

void compilation_unit()
{
    // compilation_unit::= 
    //    {class_declaration} 
    //    "void" "main" "(" ")" method_body
    // ;

    next();
    while (ct.type == TType.CLASS)
        class_declaration();

    assertType(TType.VOID);
    auto returnType = ct.value;
    
    next();
    assertType(TType.MAIN);
    auto methodName = ct.value;

    if (firstPass) {
        auto s = new MethodSymbol();
        s.value = methodName;
        s.returnType = returnType;
        symbol.symbolTable[s.id] = s;
    }

    next();
    assertType(TType.PAREN_OPEN); 
    next();
    assertType(TType.PAREN_CLOSE); 
    next();
    method_body();
}

void constructor_declaration()
{
    // constructor_declaration::=
    //    class_name "(" [parameter_list] ")" method_body ;

    next();
    assertType(TType.PAREN_OPEN);
    next();
    if (ct.type != TType.PAREN_CLOSE)
        parameter_list();
    assertType(TType.PAREN_CLOSE); 
    next();
    method_body();
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
        case TType.INT_LITERAL:
        case TType.CHAR_LITERAL:
            next();
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
    default:
        break;
    } 
}

void field_declaration()
{
    // field_declaration::=
    //     ["[" "]"] ["=" assignment_expression ] ";"  
    //    | "(" [parameter_list] ")" method_body
    //    ;

    if (ct.type == TType.PAREN_OPEN) {
        next();
        if (ct.type != TType.PAREN_CLOSE)
            parameter_list();
        assertType(TType.PAREN_CLOSE);
        next();
        method_body();
    }
    else {
        if (ct.type == TType.ARRAY_BEGIN) {
            next();
            assertType(TType.ARRAY_END); 
            next();
        }
        if (ct.type == TType.ASSIGN_OP) {
            next();
            assignment_expression();
        }
        assertType(TType.SEMICOLON); 
        next();
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

void method_body()
{
    // method_body::=
    //    "{" {variable_declaration} {statement} "}" ;

    assertType(TType.BLOCK_BEGIN);
    next();
    while (ct.type == TType.TYPE)
        variable_declaration();
    while (ct.type != TType.BLOCK_END)
        statement();
    assertType(TType.BLOCK_END);
    next();
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
        throw new SyntaxError(ct.line,"new_declaration");
    }
}

void parameter()
{
    // parameter::= type identifier ["[" "]"] ;

    assertType(TType.TYPE); 
    next();    
    assertType(TType.IDENTIFIER); 
    next();
    if (ct.type == TType.ARRAY_BEGIN) {
        next();
        assertType(TType.ARRAY_END); 
        next();
    }
}

void parameter_list()
{
    // parameter_list::= parameter { "," parameter } ;

    parameter();
    while (ct.type == TType.COMMA) {
        next();
        parameter(); 
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
        if (ct.type == TType.ELSE)
            statement();
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

void variable_declaration()
{
    // variable_declaration::= 
    //    type identifier ["[" "]"] ["=" assignment_expression ] ";" ;

    assertType(TType.TYPE);
    next();
    assertType(TType.IDENTIFIER);
    next();
    if (ct.type == TType.ARRAY_BEGIN) {
        next();
        assertType(TType.ARRAY_END);
        next();
    }
    if (ct.type == TType.ASSIGN_OP) {
        next();
        assignment_expression();
    }
    assertType(TType.SEMICOLON);
    next();
}
