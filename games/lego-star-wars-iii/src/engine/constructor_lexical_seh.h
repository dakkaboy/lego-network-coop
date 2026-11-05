#pragma once
typedef void *(__cdecl *ConstructorLexicalInvoke)(void *);
typedef void (__cdecl *ConstructorLexicalAbort)(void *);
void *__cdecl constructor_lexical_seh(void *,ConstructorLexicalInvoke,ConstructorLexicalAbort);
