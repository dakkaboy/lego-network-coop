#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "diagnostics.h"

static char report_path[MAX_PATH];
static volatile LONG captured;
static int readable(const void *p,SIZE_T size) {
    MEMORY_BASIC_INFORMATION m;
    return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT &&
           !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
           (uintptr_t)p+size <= (uintptr_t)m.BaseAddress+m.RegionSize;
}
static void words(FILE *f,const char *name,uintptr_t address,unsigned count) {
    fprintf(f,"%s @ %08lx\n",name,(unsigned long)address);
    for (unsigned i=0;i<count;++i) {
        uint32_t *p=(uint32_t *)(address+i*4);
        if (!readable(p,4)) break;
        fprintf(f,"%08lx: %08lx\n",(unsigned long)(uintptr_t)p,(unsigned long)*p);
    }
}
static LONG CALLBACK on_exception(EXCEPTION_POINTERS *exception) {
    if (exception->ExceptionRecord->ExceptionCode!=EXCEPTION_ACCESS_VIOLATION ||
        InterlockedCompareExchange(&captured,1,0)) return EXCEPTION_CONTINUE_SEARCH;
    FILE *f=fopen(report_path,"w");
    if (!f) return EXCEPTION_CONTINUE_SEARCH;
    CONTEXT *c=exception->ContextRecord;
    fprintf(f,"fault=%08lx read_write=%lu address=%08lx\nEAX=%08lx EBX=%08lx ECX=%08lx EDX=%08lx\nESI=%08lx EDI=%08lx EBP=%08lx ESP=%08lx\n",
            c->Eip,(unsigned long)exception->ExceptionRecord->ExceptionInformation[0],
            (unsigned long)exception->ExceptionRecord->ExceptionInformation[1],c->Eax,c->Ebx,c->Ecx,c->Edx,c->Esi,c->Edi,c->Ebp,c->Esp);
    uintptr_t root=*(uintptr_t *)0xfb2e60;
    words(f,"root flow",root+0x1b44,32);
    words(f,"players",0xfb4940,8);
    words(f,"EAX object",c->Eax,48);
    words(f,"EBX object",c->Ebx,48);
    words(f,"ECX object",c->Ecx,48);
    words(f,"EDX object",c->Edx,48);
    words(f,"ESI object",c->Esi,48);
    words(f,"EDI object",c->Edi,48);
    words(f,"EDI manager views",c->Edi+0xf24,12);
    words(f,"EDI manager cameras",c->Edi+0x13a4,8);
    words(f,"stack",c->Esp,192);
    fclose(f);
    return EXCEPTION_CONTINUE_SEARCH;
}
void diagnostics_install(HMODULE module) {
    GetModuleFileNameA(module,report_path,MAX_PATH);
    char *last=strrchr(report_path,'\\');
    if (last) snprintf(last+1,MAX_PATH-(last+1-report_path),"crash-%lu.txt",GetCurrentProcessId());
    AddVectoredExceptionHandler(1,on_exception);
}
