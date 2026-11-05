#include "constructor_lexical_seh.h"
__declspec(noinline) void *__cdecl constructor_lexical_seh(void *context,ConstructorLexicalInvoke invoke,ConstructorLexicalAbort abort){
 int completed=0;void *result=0;
 __try {result=invoke(context);completed=1;}
 __finally {if(!completed)abort(context);}
 return result;
}
