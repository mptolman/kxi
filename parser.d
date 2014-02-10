import std.conv;
import std.stdio;
import icode, lexer, semantic, symbol;

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

void assertType(TType[] types ...)
{
    foreach (t; types)
        if (_ct.type == t)
            return;

    error(types);
}

void assertValue(string[] values ...)
{
    foreach (v; values)
        if (_ct.value == v)
            return;

    error(values);
}

void error(T)(T[] types...)
{
    string s = text("Expected ",types[0]);
    if (types.length > 1) {
        foreach (t; types[1..$])
            s ~= text(" or ",t);
    }
    s ~= text(", not ",_ct.type," \"",_ct.value,"\"");
    throw new SyntaxError(_ct.line,s);
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
    _scope.push(GLOBAL_SCOPE);

    next();
    while (_ct.type == TType.CLASS)
        class_declaration();

    assertValue("void");
    auto returnType = _ct.value;
    
    next();
    assertType(TType.MAIN);
    auto methodName = _ct.value;

    if (_firstPass) {
        SymbolTable.add(new MethodSymbol(methodName,returnType,PUBLIC_MODIFIER,_scope,_ct.line));
        iMain();
    }

    _scope.push(methodName);

    next();
    assertType(TType.PAREN_OPEN); 
    next();
    assertType(TType.PAREN_CLOSE);     
    next();

    if (!_firstPass) {
        
    }

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

        if (!_firstPass && _ct.type == TType.IDENTIFIER) {
            tPush(type,_ct.line);
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
        error("modifier","constructor");
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
        if (_firstPass)
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

        if (_firstPass)
            s = new IVarSymbol(identifier,type,modifier,_scope,_ct.line);
        else
            vPush(identifier,_scope,_ct.line);

        if (_ct.type == TType.ASSIGN_OP) {
            if (!_firstPass)
                oPush(_ct.value,_ct.line);            
            next();
            assignment_expression();
        }

        assertType(TType.SEMICOLON);
        if (!_firstPass)
            eoe_sa();
        next();
    }

    if (s !is null)
        SymbolTable.add(s);
}

void constructor_declaration()
{
    // constructor_declaration::=
    //    class_name "(" [parameter_list] ")" method_body ;

    assertType(TType.IDENTIFIER);
    auto ctorName = _ct.value;

    MethodSymbol methodSymbol;

    if (_firstPass)
        methodSymbol = new MethodSymbol(ctorName,"void",PUBLIC_MODIFIER,_scope,_ct.line);
    else
        cd_sa(ctorName,_scope,_ct.line);

    _scope.push(ctorName);

    next();
    assertType(TType.PAREN_OPEN);
    next();
    if (_ct.type != TType.PAREN_CLOSE)
        parameter_list(methodSymbol);
    assertType(TType.PAREN_CLOSE); 
    next();
    method_body();

    _scope.pop();

    if (methodSymbol !is null)
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

    if (!_firstPass && _ct.type == TType.IDENTIFIER) {
        tPush(type,_ct.line);
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

    if (methodSymbol !is null) {
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

    while (_ct.type == TType.TYPE || (_ct.type == TType.IDENTIFIER && peek().type == TType.IDENTIFIER))
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

    if (!_firstPass && _ct.type == TType.IDENTIFIER) {
        tPush(type,_ct.line);
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

    if (_firstPass)
        SymbolTable.add(new LVarSymbol(identifier,type,_scope,_ct.line));
    else
        vPush(identifier,_scope,_ct.line);

    if (_ct.type == TType.ASSIGN_OP) {
        if (!_firstPass)
            oPush(_ct.value,_ct.line);
        next();
        assignment_expression();
    }

    assertType(TType.SEMICOLON);
    if (!_firstPass)
        eoe_sa();

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

    switch (_ct.type) {
    case TType.THIS:
        next();
        break;
    case TType.NEW:
        next();
        assertType(TType.TYPE,TType.IDENTIFIER);
        tPush(_ct.value,_ct.line);
        next();
        new_declaration();
        break;
    case TType.ATOI:
    case TType.ITOA:
        next();
        assertType(TType.PAREN_OPEN);
        if (!_firstPass)
            oPush(_ct.value,_ct.line);
        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        if (!_firstPass) {
            cparen_sa(_ct.line);
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

void new_declaration()
{
    // new_declaration::=
    //      "(" [ argument_list ] ")"
    //    | "[" expression "]"
    // ;

    assertType(TType.PAREN_OPEN,TType.ARRAY_BEGIN);

    if (_ct.type == TType.PAREN_OPEN) {
        if (!_firstPass) {
            oPush(_ct.value,_ct.line);
            bal_sa();
        }

        next();
        if (_ct.type != TType.PAREN_CLOSE)
            argument_list();
        assertType(TType.PAREN_CLOSE);

        if (!_firstPass) {
            cparen_sa(_ct.line);
            eal_sa();
            newobj_sa();
        }
        next();
    }
    else if (_ct.type == TType.ARRAY_BEGIN) {
        if (!_firstPass)
            oPush(_ct.value,_ct.line);
        next();
        expression();
        assertType(TType.ARRAY_END);
        if (!_firstPass) {
            cbracket_sa();
            newarr_sa();
        }
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
            oPush(_ct.value,_ct.line);

        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        if (!_firstPass) {
            cparen_sa(_ct.line);
            if_sa(_ct.line);
        }

        next();
        statement();

        if (_ct.type == TType.ELSE) {
            //if (!_firstPass)
            //    iElse();
            next();
            statement();
        }

        //if (!_firstPass)
        //    iPopLabel();
        break;
    case TType.WHILE:
        next();
        assertType(TType.PAREN_OPEN);
        if (!_firstPass) {
            //iBeginWhile();
            oPush(_ct.value,_ct.line);
        }

        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        if (!_firstPass) {
            cparen_sa(_ct.line);
            while_sa(_ct.line);
        }

        next();
        statement();

        //if (!_firstPass)
        //    iEndWhile();
        break;
    case TType.RETURN:
        next();
        if (_ct.type != TType.SEMICOLON)
            expression();
        assertType(TType.SEMICOLON);
        if (!_firstPass)
            return_sa(_scope,_ct.line);
        next();
        break;
    case TType.COUT:
        next();
        assertType(TType.STREAM_OUTPUT);
        next();
        expression();
        assertType(TType.SEMICOLON);
        if(!_firstPass)
            cout_sa();
        next();
        break;
    case TType.CIN:
        next();
        assertType(TType.STREAM_INPUT);
        next();
        expression();
        assertType(TType.SEMICOLON);
        if (!_firstPass)
            cin_sa();
        next();
        break;
    default:
        expression();
        assertType(TType.SEMICOLON);
        if (!_firstPass)
            eoe_sa();
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

    if (_ct.type == TType.PAREN_OPEN) {
        if (!_firstPass)
            oPush(_ct.value,_ct.line);

        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        if (!_firstPass)
            cparen_sa(_ct.line);

        next();
        expressionz();
    }
    else if (_ct.type == TType.IDENTIFIER) {
        if (!_firstPass)
            iPush(_ct.value,_scope,_ct.line);

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
            if (_firstPass)
                SymbolTable.add(new GlobalSymbol(_ct.value,"bool"));
            else
                lPush(_ct.value,"bool",_ct.line);                
            next();
            expressionz();   
            break;
        case TType.NULL:
            if (_firstPass)
                SymbolTable.add(new GlobalSymbol(_ct.value,"null"));
            else
                lPush(_ct.value,"null",_ct.line);           
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
            error(["expression"]);
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
        if (!_firstPass)
            oPush(_ct.value,_ct.line);
        next();
        assignment_expression();
        break;
    case TType.LOGIC_OP:
    case TType.REL_OP:
    case TType.MATH_OP:
        if (!_firstPass)
            oPush(_ct.value,_ct.line);
        next();
        expression();
        break;
    case TType.INT_LITERAL:
        if (_ct.value[0] == '-' || _ct.value[0] == '+') {
            if (!_firstPass)
                oPush(to!string(_ct.value[0]),_ct.line);
            expression();
        }
        break;
    default:
        break;
    }
}

void fn_arr_member()
{
    // fn_arr_member::= 
    //        "(" [ argument_list ] ")" 
    //      | "[" expression "]" ;

    if (_ct.type == TType.PAREN_OPEN) {
        if (!_firstPass) {
            oPush(_ct.value,_ct.line);
            bal_sa();
        }

        next();
        if (_ct.type != TType.PAREN_CLOSE)
            argument_list();

        assertType(TType.PAREN_CLOSE);
        if (!_firstPass) {
            cparen_sa(_ct.line);
            eal_sa();
            func_sa();
        }
        
        next();
    }
    else {
        assertType(TType.ARRAY_BEGIN);
        if (!_firstPass)
            oPush(_ct.value,_ct.line);

        next();
        expression();

        assertType(TType.ARRAY_END);
        if (!_firstPass) {
            cbracket_sa();
            arr_sa();
        }
        next();
    }
}

void member_refz()
{
    // member_refz::= "." identifier [ fn_arr_member ] [ member_refz ] ;

    assertType(TType.PERIOD);
    next();
    assertType(TType.IDENTIFIER);
    if (!_firstPass)
        iPush(_ct.value,_scope,_ct.line);
    next();
    if (_ct.type == TType.PAREN_OPEN || _ct.type == TType.ARRAY_BEGIN)
        fn_arr_member();
    if (!_firstPass)
        rExist();
    if (_ct.type == TType.PERIOD)
        member_refz();
}

void argument_list()
{
    // argument_list::= expression { "," expression } ;

    expression();
    while (_ct.type == TType.COMMA) {
        if (!_firstPass)
            comma_sa();
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
        SymbolTable.add(new GlobalSymbol(s,"char"));
    else
        lPush(s,"char",_ct.line);

    next();
}

void numeric_literal()
{
    // numeric_literal::= ["+" | "-"]number ;

    assertType(TType.INT_LITERAL);

    if (_firstPass)
        SymbolTable.add(new GlobalSymbol(_ct.value,"int"));
    else
        lPush(_ct.value,"int",_ct.line);

    next();
}
