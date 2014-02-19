import std.file;
import std.stdio;
import icode, parser, tcode;

void compile(string srcFileName, string destFileName)
{    
    File src = File(srcFileName);
    File dest; // = File(destFileName,"w");

    //scope (failure) { 
    //    try {
    //        dest.close();
    //        remove(destFileName);
    //    }
    //    catch (Exception) {
    //        // ignore
    //    }
    //}

    parse(src);
    debug printICode();
    generateTCode(dest);
}