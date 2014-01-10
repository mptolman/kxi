import std.conv;
import std.stdio;
import lexer;

string[Symbol] symbols;

struct Symbol
{
    string id;
    string kind;
    string value;
    string scop;
    string data;
}

void parse(Lexer lex)
{
    tokens = lex;

    void continueParse()
    {
        // compiliation_unit::= 
        //    {class_declaration} 
        //    "void" "main" "(" ")" method_body
        // ;

        next();
        while (ct.type == TType.CLASS)
            class_declaration();

        assertType(TType.VOID);
        next();
        assertType(TType.MAIN);
        next();
        assertType(TType.PAREN_OPEN);
        next();
        assertType(TType.PAREN_CLOSE);
        next();
        method_body();
    }

    continueParse(); // first pass
    tokens.rewind();
    continueParse(); // second pass
}

class SyntaxError : Exception
{
    this(Args...)(size_t line, Args args)
    {
        super(text("[",line,"]: ",args));
    }
}

/****************************
 Private data
 /***************************/
private:
Lexer tokens;
Token ct;

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
        throw new SyntaxError(ct.line,"Expected ",type,"; found ",ct.type," (",ct.value,")");
}

void argument_list()
{

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
    next();
    assertType(TType.BLOCK_BEGIN);
    next();
    class_member_declaration();
    assertType(TType.BLOCK_END);
    next();
}

void class_member_declaration()
{
    // class_member_declaration::=
    //      modifier type identifier field_declaration
    //    | constructor_declaration  
    // ;

    if (ct.type == TType.MODIFIER) {
        next();
        assertType(TType.TYPE);
        next();
        assertType(TType.IDENTIFIER);
        next();
        field_declaration();
    }
    else {
        constructor_declaration();        
    }
}

void constructor_declaration()
{
    // constructor_declaration::=
    //    class_name "(" [parameter_list] ")" method_body ;

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
    //    "(" [ argument_list ] ")"
    //    | "[" expression "]"
    // ;

    if (ct.type == TType.PAREN_OPEN) {
        next();
        if (ct.type != TType.PAREN_CLOSE)
            argument_list();
        assertType(TType.PAREN_CLOSE);
    }
    else if (ct.type == TType.ARRAY_BEGIN) {
        next();
        expression();
        assertType(TType.ARRAY_END);
    }
    next();
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
    }
    next();

    if (ct.type == TType.ASSIGN_OP) {
        next();
        assignment_expression();
    }

    assertType(TType.EOS);
    next();
}
