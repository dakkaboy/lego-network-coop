#include "tag_lexical_seh.h"
__declspec(noinline) int __cdecl tag_lexical_seh(void *context, TagLexicalInvoke invoke,
                                                 TagLexicalLeave leave) {
    int completed = 0, result = 0;
    __try {
        result = invoke(context);
        completed = 1;
    } __finally {
        leave(context, completed);
    }
    return result;
}
