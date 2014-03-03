import icode, parser, symbol, tcode;

void compile(string srcFileName, string destFileName)
{    
    parse(srcFileName);
    generateTCode(destFileName);
}