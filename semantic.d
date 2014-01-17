import stack, symbol;

enum SARType : byte
{
    ID
}

struct SAR
{
    SARType type;
    string name;
}

void iPush(string name)
{
    _sas.push(SAR(SARType.ID,name));
}

void iExist(Scope scp)
{
    auto sar = _sas.top();
    _sas.pop();
}

void tPush(string type)
{

}

void tExist()
{
    
}

void lPush(string value)
{
    
}

void vPush(string name)
{

}

void oPush(string op)
{

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

private:
Stack!SAR _sas;
Stack!string _os;