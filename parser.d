import std.conv;
import std.stdio;
import container, exception, global, icode, lexer, scpe, semantic, symbol;

void parse(string srcFileName)
{
    _tokens = new Lexer(srcFileName);

    _firstPass = true;
    compilation_unit(); // first pass

    _tokens.rewind();
    _tokens.toggleRecordKxi(); // for embedding kxi into assembly file

    _firstPass = false;
    compilation_unit(); // second pass
}

/****************************
 * Module-level data
 ***************************/
private:
Queue!Symbol _symbolQueue;
bool _firstPass;
Lexer _tokens;
Token _ct;

/****************************
* Helper functions
/***************************/
void next()
{
    _ct = _tokens.next();
    currentLineNum = _ct.line;
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
    throw new SyntaxError(_ct.line, s);
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

    currentScope = Scope(GLOBAL_SCOPE);

    next();
    while (_ct.type == TType.CLASS)
        class_declaration();

    assertValue("void");
    auto returnType = _ct.value;
    
    next();
    assertType(TType.MAIN);
    auto methodName = _ct.value;

    if (_firstPass) {
        currentMethod = SymbolTable.addMethod(methodName, returnType, PUBLIC_MODIFIER, currentScope, _ct.line);
        _symbolQueue.push(currentMethod);

        icode.funcCall(currentMethod.id, "main");
        icode.terminate();
    }
    else {
        currentMethod = cast(MethodSymbol)_symbolQueue.front;
        _symbolQueue.pop();
    }

    currentScope.push(methodName);

    next();
    assertType(TType.PAREN_OPEN); 
    next();
    assertType(TType.PAREN_CLOSE);     
    next();

    method_body();

    currentScope.pop();
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

    if (_firstPass) {
        currentClass = SymbolTable.addClass(className, _ct.line);
        _symbolQueue.push(currentClass);

        currentStaticInit = SymbolTable.addMethod("__"~className, "void", PRIVATE_MODIFIER, currentScope, _ct.line);
        _symbolQueue.push(currentStaticInit);
    }
    else {
        currentClass = cast(ClassSymbol)_symbolQueue.front;
        _symbolQueue.pop();

        currentStaticInit = cast(MethodSymbol)_symbolQueue.front;
        _symbolQueue.pop();

        icode.classBegin();
    }

    currentScope.push(className);

    next();
    assertType(TType.BLOCK_BEGIN);     
    next();
    while (_ct.type != TType.BLOCK_END)
        class_member_declaration();

    if (!_firstPass)
        icode.classEnd();

    assertType(TType.BLOCK_END);
    next();

    currentScope.pop();
}

void class_member_declaration()
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
            tPush(type);
            tExist();
        }

        next();        
        assertType(TType.IDENTIFIER);
        auto identifier = _ct.value;

        next();
        field_declaration(identifier, type, modifier);
    }
    else if (_ct.type == TType.IDENTIFIER) {
        constructor_declaration();
    }
    else {
        error("modifier","constructor");
    }
}

void field_declaration(string identifier, string type, string modifier)
{
    // field_declaration::=
    //     ["[" "]"] ["=" assignment_expression ] ";"  
    //    | "(" [parameter_list] ")" method_body
    //    ;

    if (_ct.type == TType.PAREN_OPEN) {
        if (_firstPass) {
            currentMethod = SymbolTable.addMethod(identifier, type, modifier, currentScope, _ct.line);
            _symbolQueue.push(currentMethod);
        }
        else {
            currentMethod = cast(MethodSymbol)_symbolQueue.front;
            _symbolQueue.pop();
        }

        currentScope.push(identifier);

        next();
        if (_ct.type != TType.PAREN_CLOSE)
            parameter_list();
        assertType(TType.PAREN_CLOSE);        
        next();

        method_body();

        currentScope.pop();
    }
    else {
        auto saveCurrentMethod = currentMethod;

        if (_ct.type == TType.ARRAY_BEGIN) {
                type = "@:" ~ type;
                next();
                assertType(TType.ARRAY_END); 
                next();
            }

        if (_firstPass) {
            _symbolQueue.push(currentClass.addInstanceVar(identifier, type, modifier, _ct.line));
        }
        else {
            vPush(_symbolQueue.front);
            _symbolQueue.pop();

            // Add field declarations to built-in static initializer function            
            icode._insideClass = true;
            currentMethod = currentStaticInit;
        }

        if (_ct.type == TType.ASSIGN_OP) {
            if (!_firstPass)
                oPush(_ct.value);            
            next();
            assignment_expression();
        }

        assertType(TType.SEMICOLON);
        next();

        if (!_firstPass) {
            eoe_sa();
            icode._insideClass = false;
            currentMethod = saveCurrentMethod;
        }
    }
}

void constructor_declaration()
{
    // constructor_declaration::=
    //    class_name "(" [parameter_list] ")" method_body ;

    assertType(TType.IDENTIFIER);
    auto ctorName  = _ct.value;

    if (_firstPass) {
        currentMethod = SymbolTable.addMethod(ctorName, "this", PUBLIC_MODIFIER, currentScope, _ct.line);
        _symbolQueue.push(currentMethod);
    }
    else {
        currentMethod = cast(MethodSymbol)_symbolQueue.front;
        _symbolQueue.pop();
        cd_sa();
    }

    currentScope.push(ctorName);

    next();
    assertType(TType.PAREN_OPEN);
    next();
    if (_ct.type != TType.PAREN_CLOSE)
        parameter_list();
    assertType(TType.PAREN_CLOSE); 
    next();

    method_body(true);

    currentScope.pop();
}

void parameter_list()
{
    // parameter_list::= parameter { "," parameter } ;

    parameter();

    while (_ct.type == TType.COMMA) {
        next();
        parameter();
    }
}

void parameter()
{
    // parameter::= type identifier ["[" "]"] ;

    assertType(TType.TYPE,TType.IDENTIFIER);
    auto type = _ct.value;

    if (!_firstPass && _ct.type == TType.IDENTIFIER) {
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

    if (_firstPass)
        currentMethod.addParam(identifier, type, _ct.line);
}

void method_body(bool isCtor=false)
{
    // method_body::=
    //    "{" {variable_declaration} {statement} "}" ;

    assertType(TType.BLOCK_BEGIN);

    if (!_firstPass) {
        icode.funcBegin();
        if (isCtor)
            icode.funcCall(currentStaticInit.id, "this"); // call the static initializer first
    }

    next();

    while (_ct.type == TType.TYPE || (_ct.type == TType.IDENTIFIER && peek().type == TType.IDENTIFIER))
        variable_declaration();

    while (_ct.type != TType.BLOCK_END)
        statement();

    if (!_firstPass && isCtor)
        icode.funcReturn("this");
    else if (!_firstPass)
        icode.funcReturn();

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

    if (_firstPass) {
        _symbolQueue.push(currentMethod.addLocal(identifier, type, _ct.line));
    }
    else {
        vPush(_symbolQueue.front);
        _symbolQueue.pop();
    }

    if (_ct.type == TType.ASSIGN_OP) {
        if (!_firstPass)
            oPush(_ct.value);
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
        if (!_firstPass)
            tPush(_ct.value);
        next();
        new_declaration();
        break;
    case TType.ATOI:
        next();
        assertType(TType.PAREN_OPEN);
        if (!_firstPass)
            oPush(_ct.value);
        next();
        expression();
        assertType(TType.PAREN_CLOSE);
        if (!_firstPass) {
            cparen_sa();
            atoi_sa();
        }
        next();
        break;
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
            oPush(_ct.value);
            bal_sa();
        }

        next();
        if (_ct.type != TType.PAREN_CLOSE)
            argument_list();
        assertType(TType.PAREN_CLOSE);

        if (!_firstPass) {
            cparen_sa();
            eal_sa();
            newobj_sa();
        }
        next();
    }
    else if (_ct.type == TType.ARRAY_BEGIN) {
        if (!_firstPass)
            oPush(_ct.value);
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
            oPush(_ct.value);

        next();
        expression();

        assertType(TType.PAREN_CLOSE);
        if (!_firstPass) {
            cparen_sa();
            if_sa();
        }

        next();
        statement();

        if (_ct.type == TType.ELSE) {
            if (!_firstPass)
                icode.elseCond();
            next();
            statement();
        }

        if (!_firstPass)
            icode.endIf();
        break;
    case TType.WHILE:
        next();
        assertType(TType.PAREN_OPEN);
        if (!_firstPass) {
            icode.beginWhile();
            oPush(_ct.value);
        }

        next();
        expression();

        assertType(TType.PAREN_CLOSE);
        if (!_firstPass) {
            cparen_sa();
            while_sa();
        }

        next();
        statement();

        if (!_firstPass)
            icode.endWhile();
        break;
    case TType.RETURN:
        next();
        if (_ct.type != TType.SEMICOLON)
            expression();
        assertType(TType.SEMICOLON);
        if (!_firstPass)
            return_sa();
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
            oPush(_ct.value);

        next();
        expression();

        assertType(TType.PAREN_CLOSE);
        if (!_firstPass)
            cparen_sa();

        next();
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
            if (_firstPass) {
                _symbolQueue.push(SymbolTable.addGlobal(_ct.value, "bool"));
            }
            else {
                lPush(_symbolQueue.front);                
                _symbolQueue.pop();
            }
            next();
            expressionz();   
            break;
        case TType.NULL:
            if (_firstPass) {
                _symbolQueue.push(SymbolTable.addGlobal(_ct.value, "null"));
            }
            else {
                lPush(_symbolQueue.front);           
                _symbolQueue.pop();
            }
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
            oPush(_ct.value);
        next();
        assignment_expression();
        break;
    case TType.LOGIC_OP:
    case TType.REL_OP:
    case TType.MATH_OP:
        if (!_firstPass)
            oPush(_ct.value);
        next();
        expression();
        break;
    case TType.INT_LITERAL:
        if (_ct.value[0] == '-' || _ct.value[0] == '+') {
            if (!_firstPass)
                oPush("+");
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
            oPush(_ct.value);
            bal_sa();
        }

        next();
        if (_ct.type != TType.PAREN_CLOSE)
            argument_list();

        assertType(TType.PAREN_CLOSE);
        if (!_firstPass) {
            cparen_sa();
            eal_sa();
            func_sa();
        }
        next();
    }
    else {
        assertType(TType.ARRAY_BEGIN);
        if (!_firstPass)
            oPush(_ct.value);

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
        iPush(_ct.value);
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
    assertType(TType.CHAR_DELIM);
    next();

    assertType(TType.CHAR_LITERAL);
    auto character = _ct.value;

    if (_ct.value == "\\") {
        next();
        assertType(TType.CHAR_LITERAL);
        character ~= _ct.value;

        switch (_ct.value) {
        case "\\":
        case "n":
        case "t":
        case "'":
            break;
        default:        
            throw new SyntaxError(_ct.line,"Invalid character escape sequence '",character,"'");
        }
    }

    next();
    assertType(TType.CHAR_DELIM);

    if (_firstPass) {
        _symbolQueue.push(SymbolTable.addGlobal(character, "char"));
    }
    else {
        lPush(_symbolQueue.front);
        _symbolQueue.pop();
    }

    next();
}

void numeric_literal()
{
    // numeric_literal::= ["+" | "-"]number ;

    assertType(TType.INT_LITERAL);
    auto value = to!string(to!int(_ct.value));

    if (_firstPass) {
        _symbolQueue.push(SymbolTable.addGlobal(value, "int"));
    }
    else {
        lPush(_symbolQueue.front);
        _symbolQueue.pop();
    }

    next();
}

static this()
{
    _symbolQueue = new Queue!Symbol;
}