import std.conv;
import stack, symbol;

enum SARType : byte
{
    ID_SAR,
    VAR_SAR,
    TYPE_SAR,
    LIT_SAR
}

struct SAR
{
    SARType sarType;
    string name;
    Scope scpe;
    size_t line;
    string symbolId;

    this(SARType sarType, string name, Scope scpe, size_t line)
    {
        this.sarType = sarType;
        this.name = name;
        this.scpe = scpe;
        this.line = line;
    }

    this(SARType sarType, string symbolId)
    {
        this.sarType = sarType;
        this.symbolId = symbolId;
    }
}

//abstract class SAR
//{    
//    string name;
//    Scope scpe;
//    size_t line;

//    this(string name, Scope, scpe, size_t line)
//    {
//        this.name = name;
//        this.scpe = scpe;
//        this.line = line;
//    }
//}

//class ID_SAR : SAR
//{
//    string type;

//    this(string name, Scope scpe, size_t line, string type)
//    {
//        super(name,scpe,line);
//        this.type = type;
//    }
//}

//class VAR_SAR : ID_SAR
//{
//    string symbolId;

//    this(string name, string type, Scope scpe, size_t line)
//    {
//        super(name,scpe,line);
//        this.type = type;
//    }
//}

struct Operator
{
    string op;
    size_t weight;
}

void iPush(string name, Scope scpe, size_t line)
{
    _sas.push(SAR(SARType.ID_SAR,name,scpe,line));
}

void iExist()
{
    auto sar = _sas.top();
    _sas.pop();

    auto matches = SymbolTable.findIdentifier(sar.name, sar.scpe);
    if (!matches)
        throw new SemanticError("Identifier not found");

    auto symbol = matches[0];
    _sas.push(SAR(SARType.VAR_SAR,symbol.id));
}

void tPush(string type, size_t line)
{
    _sas.push(SAR(SARType.TYPE_SAR,type,Scope(GLOBAL_SCOPE),line));
}

void tExist()
{
    auto sar = _sas.top();
    _sas.pop();

    auto matches = SymbolTable.findClass(sar.name,sar.scpe);
    if (!matches)
        throw new SemanticError(text("(",sar.line,"): Type ",sar.name," does not exist."));
}

void lPush(string value)
{
    auto match = SymbolTable.findGlobal(value);
    if (!match)
        throw new SemanticError(text("Could not find global literal \"",value,"\""));
    _sas.push(SAR(SARType.LIT_SAR,match[0].id));
}

void vPush(string name, Scope scpe, size_t line)
{
    auto match = SymbolTable.findIdentifier(name,scpe);
    if (!match)
        throw new SemanticError("Could not find symbol");
    _sas.push(SAR(SARType.VAR_SAR,match[0].id));
}

void oPush(string op)
{
    auto weight = _opWeights[op];
    if (!_os.empty) {
        auto top = _os.top();
        auto topWeight = _opWeights[top];
        if (topWeight >= weight) {
            auto rval = _sas.top(); _sas.pop();
            auto lval = _sas.top(); _sas.pop();
            
        }
    }
    _os.push(op);
}

void EOE()
{

}

void CD(string cname)
{

}

void cparen_sa()
{

}

void atoi_sa()
{

}

void itoa_sa()
{

}

void if_sa()
{

}

void while_sa()
{

}

void return_sa()
{

}

void cout_sa()
{

}

void cin_sa()
{

}

class SemanticError : Exception
{
    this(string err)
    {
        super(err);
    }
}

private:
size_t[string] _opWeights;
Stack!SAR _sas;
Stack!string _os;

static this()
{
    _sas = new Stack!SAR;
    _os = new Stack!Operator;
    _opWeights = [
        "="  : 1,
        "||" : 3,
        "&&" : 5,
        "==" : 7,
        "!=" : 7,
        "<"  : 9,
        ">"  : 9,
        "<=" : 9,
        ">=" : 9,
        "+"  : 11,
        "-"  : 11,
        "*"  : 13,
        "/"  : 13,
        "%"  : 13,
        ")"  : 0,
        "]"  : 0,
        "."  : 15,
        "("  : 15,
        "["  : 15
    ];
}