import icode, parser, symbol, tcode;

void compile(string srcFileName, string destFileName)
{    
    parse(srcFileName);
    debug printICode();
    generateTCode(destFileName);
}