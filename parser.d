import std.conv;
import std.stdio;
import lexer, symbol, semantic;

void parse(File src)
{
    _tokens = new Lexer(src);

    _firstPass = true;
    compilation_unit(); // first pass

    _tokens.rewind();

    _firstPass = false;
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
bool _firstPass;
Lexer _tokens;
Scope _scope;
Token _ct;

/****************************
* Helper functions
/***************************/
void next()
{
    _ct = _tokens.next();
}

auto peek()
{
    return _tokens.peek();
}

void assertType(TType types[] ...)
{
    foreach (t; types)
        if (_ct.type == t)
            return;

    throw new SyntaxError(_ct.line,"Expected ",types,". Found ",_ct.type," \"",_ct.value,"\"");
}

void assertValue(string values[] ...)
{
    foreach (v; values)
        if (_ct.value == v)
            return;

    throw new SyntaxError(_ct.line,"Expected ",values,". Found \"",_ct.value,"\"");
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

    _scope = Scope.init;
    _scope.push("g");

    next();
    while (_ct.type == TType.CLASS)
        class_declaration();

    assertValue("void");
    auto returnType = _ct.value;
    
    next();
    assertType(TType.MAIN);
    auto methodName = _ct.value;

    if (_firstPass)
        SymbolTable.add(new MethodSymbol(methodName,returnType,PUBLIC_MODIFIER,_scope,_ct.line));

    _scope.push(methodName);

    next();
    assertType(TType.PAREN_OPEN); 
    next();
    assertType(TType.PAREN_CLOSE);     
    next();
    method_body();

    _scope.pop();
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
    auto className = _ct.value;

    if (_firstPass)
        SymbolTable.add(new ClassSymbol(className,_scope,_ct.line));

    _scope.push(className);    

    next();
    assertType(TType.BLOCK_BEGIN);     
    next();
    while (_ct.type != TType.BLOCK_END)
        class_member_declaration(className);
    assertType(TType.BLOCK_END); 
    next();

    _scope.pop();
}

void class_member_declaration(string className)
{
    // class_member_declaration::=
    //      modifier type identifier field_declaration
    //    | constructor_declaration  
    // ;

    if (_ct.type == TType.MODIFIER) {
        auto modifier = _ct.value;

        next();
        assertType(TType.TYPE,TType.IDENTIFIER);
        auto type = _ct.value;

        if (!_firstPass) {
            tPush(type);
            tExist();
        }

        next();        
        assertType(TType.IDENTIFIER);
        auto identifier = _ct.value;

        next();
        field_declaration(modifier,type,identifier);
    }
    else if (_ct.type == TType.IDENTIFIER) {
        constructor_declaration();
    }
    else {
        throw new SyntaxError(_ct.line,"Expected modifier or constructor. Found ",_ct.type," \"",_ct.value,"\"");
    }
}

void field_declaration(string modifier, string type, string identifier)
{
    // field_declaration::=
    //     ["[" "]"] ["=" assignment_expression ] ";"  
    //    | "(" [parameter_list] ")" method_body
    //    ;

    Symbol s;

    if (_ct.type == TType.PAREN_OPEN) {
        s = new MethodSymbol(identifier,type,modifier,_scope,_ct.line);

        _scope.push(identifier);

        next();
        if (_ct.type != TType.PAREN_CLOSE)
            parameter_list(cast(MethodSymbol)s);
        assertType(TType.PAREN_CLOSE);
        next();
        method_body();

        _scope.pop();
    }
    else {        
        if (_ct.type == TType.ARRAY_BEGIN) {
            type = "@:" ~ type;
            
            next();
            assertType(TType.ARRAY_END); 
            next();            
        }

        if (!_firstPass)
            vPush(identifier);          

        s = new IVarSymbol(identifier,type,modifier,_scope,_ct.line);

        if (_ct.type == TType.ASSIGN_OP) {
            if (!_firstPass)
                oPush(_ct.value);            
            next();
            assignment_expression();
        }

        assertType(TType.SEMICOLON);
        next();

        if (!_firstPass)
            EOE();
    }

    if (_firstPass)
        SymbolTable.add(s);
}

void constructor_declaration()
{
    // constructor_declaration::=
    //    class_name "(" [parameter_list] ")" method_body ;

    assertType(TType.IDENTIFIER);
    auto className = _ct.value;
    auto methodSymbol = new MethodSymbol(className,"void",PUBLIC_MODIFIER,_scope,_ct.line);

    if (!_firstPass)
        CD(className);

    _scope.push(className);

    next();
    assertType(TType.PAREN_OPEN);
    next();
    if (_ct.type != TType.PAREN_CLOSE)
        parameter_list(methodSymbol);
    assertType(TType.PAREN_CLOSE); 
    next();
    method_body();

    _scope.pop();

    if (_firstPass)
        SymbolTable.add(methodSymbol);
}

void parameter_list(MethodSymbol methodSymbol)
{
    // parameter_list::= parameter { "," parameter } ;

    parameter(methodSymbol);
    while (_ct.type == TType.COMMA) {
        next();
        parameter(methodSymbol); 
    }
}

void parameter(MethodSymbol methodSymbol)
{
    // parameter::= type identifier ["[" "]"] ;

    assertType(TType.TYPE,TType.IDENTIFIER);
    auto type = _ct.value;

    if (!_firstPass) {
        tPush(type);
        tExist();
    }

    next();    
    assertType(TType.IDENTIFIER); 
    auto identifier = _ct.value;

    next();
    if (_ct.type == TType.ARRAY_BEGIN) {
        type = "@:" ~ type;;

        next();
        assertType(TType.ARRAY_END); 
        next();
    }

    if (_firstPass) {
        auto p = new ParamSymbol(identifier,type,_scope,_ct.line);
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

    while ((_ct.type == TType.TYPE || _ct.type == TType.IDENTIFIER) && peek().type == TType.IDENTIFIER)
        variable_declaration();

    while (_ct.type != TType.BLOCK_END)
        statement();

    assertType(TType.BLOCK_END);
    next();
}

void variable_declaration()
{
    // variable_declaration::= 
    //    type identifier ["[" "]"] ["=" assignment_expression ] ";" ;

    assertType(TType.TYPE,TType.IDENTIFIER);
    auto type = _ct.value;

    if (!_firstPass) {
        tPush(type);
        tExist();
    }

    next();
    assertType(TType.IDENTIFIER);
    auto identifier = _ct.value;

    next();
    if (_ct.type == TType.ARRAY_BEGIN) {
        type = "@:" ~ type;

        next();
        assertType(TType.ARRAY_END);
        next();
    }

    if (!_firstPass)
        vPush(identifier);

    if (_firstPass)
        SymbolTable.add(new LVarSymbol(identifier,type,_scope,_ct.line));

    if (_ct.type == TType.ASSIGN_OP) {
        if (!_firstPass)
            oPush(_ct.value);
        next();
        assignment_expression();
    }

    assertType(TType.SEMICOLON);    
    next();

    if (!_firstPass)
        EOE();
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

    switch (_ct.type) {
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
        if (!_firstPass)
            oPush(_ct.value);
        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        if (!_firstPass) {
            cparen_sa();
            if (_ct.type == TType.ATOI)
                atoi_sa();
            else
                itoa_sa();
        }        
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

    switch (_ct.type) {
    case TType.BLOCK_BEGIN:
        next();
        while (_ct.type != TType.BLOCK_END)
            statement();
        assertType(TType.BLOCK_END);
        next();
        break;
    case TType.IF:
        next();
        assertType(TType.PAREN_OPEN);

        if (!_firstPass)
            oPush(_ct.value);

        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        next();

        if (!_firstPass) {
            cparen_sa();
            if_sa();
        }

        statement();
        if (_ct.type == TType.ELSE) {
            next();
            statement();
        }
        break;
    case TType.WHILE:
        next();
        assertType(TType.PAREN_OPEN);

        if (!_firstPass)
            oPush(_ct.value);

        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        next();

        if (!_firstPass) {
            cparen_sa();
            while_sa();
        }

        statement();
        break;
    case TType.RETURN:
        next();
        if (_ct.type != TType.SEMICOLON)
            expression();
        assertType(TType.SEMICOLON);
        next();

        if (!_firstPass)
            return_sa();
        break;
    case TType.COUT:
        next();
        assertType(TType.STREAM_OUTPUT);
        next();
        expression();
        assertType(TType.SEMICOLON);
        next();

        if(!_firstPass)
            cout_sa();
        break;
    case TType.CIN:
        next();
        assertType(TType.STREAM_INPUT);
        next();
        expression();
        assertType(TType.SEMICOLON);
        next();

        if (!_firstPass)
            cin_sa();
        break;
    default:
        expression();
        assertType(TType.SEMICOLON);
        next();

        if (!_firstPass)
            EOE();
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

    if (_ct.type == TType.PAREN_OPEN) {
        if (!_firstPass)
            oPush(_ct.value);

        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        next();

        if (!_firstPass)
            cparen_sa();

        expressionz();
    }
    else if (_ct.type == TType.IDENTIFIER) {
        if (!_firstPass)
            iPush(_ct.value);

        next();
        if (_ct.type == TType.PAREN_OPEN || _ct.type == TType.ARRAY_BEGIN)
            fn_arr_member();

        if (!_firstPass)
            iExist();
        
        if (_ct.type == TType.PERIOD)
            member_refz();        
        expressionz();
    }
    else {
        switch (_ct.type) {
        case TType.TRUE:
        case TType.FALSE:        
        case TType.NULL:
            if (!_firstPass)
                lPush(_ct.value);            
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
            throw new SyntaxError(_ct.line,"Expected expression; found ",_ct.type," \"",_ct.value,"\"");
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

    switch (_ct.type) {
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
        if (_ct.value[0] == '-' || _ct.value[0] == '+') {
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

    if (_ct.type == TType.PAREN_OPEN) {
        next();
        if (_ct.type != TType.PAREN_CLOSE)
            argument_list();
        assertType(TType.PAREN_CLOSE);
        next();
    }
    else if (_ct.type == TType.ARRAY_BEGIN) {
        next();
        expression();
        assertType(TType.ARRAY_END);
        next();
    }
    else {
        throw new SyntaxError(_ct.line,"Expected ( or [. Found ",_ct.type," \"",_ct.value,"\"");
    }
}

void fn_arr_member()
{
    // fn_arr_member::= 
    //        "(" [ argument_list ] ")" 
    //      | "[" expression "]" ;

    if (_ct.type == TType.PAREN_OPEN) {
        next();
        if (_ct.type != TType.PAREN_CLOSE)
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
    if (_ct.type == TType.PAREN_OPEN || _ct.type == TType.ARRAY_BEGIN)
        fn_arr_member();
    if (_ct.type == TType.PERIOD)
        member_refz();
}

void argument_list()
{
    // argument_list::= expression { "," expression } ;

    expression();
    while (_ct.type == TType.COMMA) {
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

    if (_ct.value == "\\") {
        next();
        assertType(TType.CHAR_LITERAL);
        switch (_ct.value) {
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
            throw new SyntaxError(_ct.line,"Invalid character escape sequence \'\\",_ct.value,"\'");
        }
    }
    else {
        s = _ct.value;
    }

    next();
    assertType(TType.CHAR_DELIM);

    if (_firstPass)
        SymbolTable.add(new GlobalSymbol(s,"char",_ct.line));

    next();
}

void numeric_literal()
{
    // numeric_literal::= ["+" | "-"]number ;

    assertType(TType.INT_LITERAL);

    if (_firstPass)
        SymbolTable.add(new GlobalSymbol(_ct.value,"int",_ct.line));

    next();
}
