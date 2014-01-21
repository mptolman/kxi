import std.conv;
import stack, symbol;

enum SARType : byte
{
    ID_SAR,
    VAR_SAR,
    TYPE_SAR,
    LIT_SAR,
    BAL_SAR,
    AL_SAR
}

struct SAR
{
    SARType sarType;
    string name;
    string type;
    string symbolId;
    Scope scpe;
    size_t line;    

    this(SARType sarType)
    {
        this.sarType = sarType;
    }

    this(SARType sarType, string name, Scope scpe, size_t line)
    {
        this.sarType = sarType;
        this.name = name;
        this.scpe = scpe;
        this.line = line;
    }

    this(SARType sarType, string symbolIdm, string type)
    {
        this.sarType = sarType;
        this.symbolId = symbolId;
        this.type = type;
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

    auto match = SymbolTable.findVariable(sar.name, sar.scpe);
    if (!match)
        throw new Exception(text("(",sar.line,"): Identifier '",sar.name,"' does not exist in this scope"));

    auto symbol = cast(VarSymbol) match[0];
    _sas.push(SAR(SARType.VAR_SAR,symbol.id,symbol.type));
}

void tPush(string type, size_t line)
{
    _sas.push(SAR(SARType.TYPE_SAR,type,Scope(GLOBAL_SCOPE),line));
}

void tExist()
{
    auto sar = _sas.top();
    _sas.pop();

    auto match = SymbolTable.findClass(sar.name,sar.scpe);
    if (!match)
        throw new Exception(text("(",sar.line,"): Invalid type '",sar.name,"'"));
}

void lPush(string value)
{
    auto match = SymbolTable.findGlobal(value);
    if (!match)
        throw new Exception(text("Could not find global literal \"",value,"\""));

    auto symbol = cast(VarSymbol) match[0];
    _sas.push(SAR(SARType.LIT_SAR,symbol.id,symbol.type));
}

void vPush(string name, Scope scpe, size_t line)
{
    auto match = SymbolTable.findVariable(name,scpe);
    if (!match)
        throw new SemanticError("Could not find symbol");

    auto symbol = cast(VarSymbol) match[0];
    _sas.push(SAR(SARType.VAR_SAR,symbol.id,symbol.type));
}

void oPush(string op, size_t line)
{
    auto weight = _opWeights[op];
    if (!_os.empty) {
        auto opr = _os.top();
        auto topWeight = _opWeights[opr];
        if (topWeight >= weight) {
            assert(_sas.size >= 2);
            auto rval = _sas.top(); _sas.pop();
            auto lval = _sas.top(); _sas.pop();

            switch (opr)
            {
            case "+":
                
                break;
            default:
                break;
            }
        }
    }
    _os.push(op);
}

void eoe_sa()
{

}

void cd_sa(string cname, Scope scpe, size_t line)
{
    auto topScope = scpe.top();
    if (cname != topScope.toString())
        throw new Exception(text("(",line,"): Constructor name \"",cname,"\" does not match class name \"",topScope.toString(),"\""));
}

void bal_sa()
{
    _sas.push(SAR(SARType.BAL_SAR));
}

void eal_sa()
{
    auto al_sar = SAR(SARType.AL_SAR);

    auto top = _sas.top();
    while (top.sarType != SARType.BAL_SAR) {
        _sas.pop(); 
        top = _sas.top();
        // TODO: Add arguments to al_sar     
    }

    _sas.pop();
    _sas.push(al_sar);
}

void func_sa()
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
    _os = new Stack!string;
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