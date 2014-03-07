import scpe, symbol;

Scope currentScope;

size_t currentLineNum;
ClassSymbol currentClass;
MethodSymbol currentMethod;
MethodSymbol currentStaticInit;

string kxi;
bool kxiIsNew;