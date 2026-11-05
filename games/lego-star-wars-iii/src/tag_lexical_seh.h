#pragma once
typedef int(__cdecl *TagLexicalInvoke)(void *);
typedef void(__cdecl *TagLexicalLeave)(void *, int);
int __cdecl tag_lexical_seh(void *, TagLexicalInvoke, TagLexicalLeave);
