#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstddef>
#include <cstring>
#include "script_shoot_dispatch_thunk.h"

extern "C" { uintptr_t script_shoot_dispatch_original; }
namespace {
struct alignas(16) DispatchMachine {
    unsigned char fx[512];
    uint32_t error;
    uint32_t *registers;
};
static_assert(offsetof(DispatchMachine,error)==512 && offsetof(DispatchMachine,registers)==516);
struct Scope {
    Scope *previous;
    NativeScriptShootDispatchSource source;
    NativeScriptShootDispatchBinding binding;
    uint32_t canonical;
    int bound;
    bool consumed;
};
thread_local Scope *current;
bool installed;
int is_shoot(uintptr_t stack,void *descriptor) {
    int identified=0;
    __try {
        void *handler=*reinterpret_cast<void **>(static_cast<unsigned char *>(descriptor)+0x10);
        if(!handler || *reinterpret_cast<uintptr_t *>(static_cast<unsigned char *>(handler)+4)!=0x963520)return 0;
        identified=1;
        void *state=*reinterpret_cast<void **>(stack+8);
        return !state || !*reinterpret_cast<void **>(static_cast<unsigned char *>(state)+4);
    } __except(EXCEPTION_EXECUTE_HANDLER){return identified?-1:0;}
}
extern "C" __attribute__((naked,noinline)) void script_shoot_dispatch_call_original(DispatchMachine *) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl 40(%esp),%eax\n\tpushl %eax\n\t"
        "movl 516(%eax),%edx\n\tleal 40(%edx),%esi\n\t"
        "pushl 24(%esi)\n\tpushl 20(%esi)\n\tpushl 16(%esi)\n\tpushl 12(%esi)\n\t"
        "pushl 8(%esi)\n\tpushl 4(%esi)\n\tpushl 0(%esi)\n\t"
        "fxrstor (%eax)\n\tmovl 512(%eax),%ecx\n\tmovl %ecx,%fs:0x34\n\t"
        "pushl 32(%edx)\n\tpopfl\n\t"
        "movl 0(%edx),%edi\n\tmovl 4(%edx),%esi\n\tmovl 8(%edx),%ebp\n\t"
        "movl 16(%edx),%ebx\n\tmovl 24(%edx),%ecx\n\tmovl 28(%edx),%eax\n\tmovl 20(%edx),%edx\n\t"
        "call *_script_shoot_dispatch_original\n\t"
        "pushfl\n\tpushal\n\tcld\n\tmovl 36(%esp),%eax\n\tmovl 516(%eax),%edi\n\t"
        "movl %esp,%esi\n\tmovl $9,%ecx\n\trep movsl\n\t"
        "fxsave (%eax)\n\tmovl %fs:0x34,%edx\n\tmovl %edx,512(%eax)\n\t"
        "addl $40,%esp\n\tpopal\n\tpopfl\n\tret\n\t");
}
extern "C" __attribute__((noinline)) void script_shoot_dispatch_run(DispatchMachine *machine) {
    const uintptr_t stack=reinterpret_cast<uintptr_t>(machine->registers)+36;
    void *descriptor=reinterpret_cast<void *>(machine->registers[6]);
    const int identified=is_shoot(stack,descriptor);
    if(!identified){script_shoot_dispatch_call_original(machine);return;}
    const bool active=cadence_script_shoot_dispatch_active()!=0;
    __asm__ volatile("cld" ::: "cc");
    const int admission=active?(identified<0?-1:native_script_shoot_dispatch_initial_admission(stack)):1;
    if(!admission){script_shoot_dispatch_call_original(machine);return;}
    Scope scope{};scope.previous=current;current=&scope;
    __try {
        if(!active)scope.bound=0;
        else if(admission<0 || !native_script_shoot_dispatch_source_resolve(descriptor,stack,&scope.source)) {
            scope.bound=-1;cadence_script_shoot_dispatch_invalid(nullptr,nullptr,1);
        } else {
            const uint32_t local=static_cast<unsigned char *>(scope.source.model)[0x42]!=0;
            scope.canonical=local;
            scope.bound=cadence_script_shoot_dispatch_begin(&scope.source,local,&scope.canonical,&scope.binding);
            __asm__ volatile("cld" ::: "cc");
            if(scope.bound==1) {
                const int live=cadence_script_shoot_dispatch_validate(&scope.source,&scope.binding);
                __asm__ volatile("cld" ::: "cc");
                if(live<0 || (live>0 && (!native_script_shoot_dispatch_source_revalidate(&scope.source) || scope.canonical>1))) {
                    cadence_script_shoot_dispatch_invalid(&scope.source,&scope.binding,2);scope.bound=-1;
                }
            }
        }
        script_shoot_dispatch_call_original(machine);
    } __finally {current=scope.previous;}
}
}
extern "C" __attribute__((naked,used)) void native_script_shoot_dispatch_entry(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%edx\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %edx,516(%esp)\n\tfxsave (%esp)\n\tmovl %fs:0x34,%eax\n\tmovl %eax,512(%esp)\n\tcld\n\t"
        "movl %esp,%eax\n\tsubl $12,%esp\n\tpushl %eax\n\tcall _script_shoot_dispatch_run\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%eax\n\tmovl %eax,%fs:0x34\n\tmovl 516(%esp),%esp\n\t"
        "popal\n\tpopfl\n\tret $28\n\t");
}
extern "C" uint32_t native_script_shoot_dispatch_consume(void *actor,void *state,void *model,uintptr_t frame,uint32_t local) {
    const DWORD error=GetLastError();uint32_t result=local!=0;Scope *scope=current;
    if(!scope || !scope->bound) {
        const int active=cadence_script_shoot_dispatch_active();
        __asm__ volatile("cld" ::: "cc");
        if(active) {
            NativeScriptShootDispatchBinding probe{};uint32_t ignored=result;
            cadence_script_shoot_dispatch_begin(nullptr,result,&ignored,&probe);
            __asm__ volatile("cld" ::: "cc");result=0;
        }
        SetLastError(error);return result;
    }
    if(scope->bound<0){SetLastError(error);return 0;}
    if(scope->bound==1) {
        const int live=cadence_script_shoot_dispatch_validate(&scope->source,&scope->binding);
        __asm__ volatile("cld" ::: "cc");
        result=0;
        if(live>0) {
            if(scope->consumed || !native_script_shoot_dispatch_frame_matches(&scope->source,actor,state,model,frame))
                cadence_script_shoot_dispatch_invalid(&scope->source,&scope->binding,4);
            else {scope->consumed=true;result=scope->canonical;}
        } else if(live<0)cadence_script_shoot_dispatch_invalid(&scope->source,&scope->binding,5);
    }
    SetLastError(error);return result;
}
extern "C" int native_script_shoot_dispatch_install(void) {
    const DWORD error=GetLastError();int result=0;
    const unsigned char expected[]={0x8b,0xc1,0x8b,0x4c,0x24,0x08};
    auto *entry=reinterpret_cast<unsigned char *>(0x6f3fe0);
    if(installed)result=1;
    else if(!std::memcmp(entry,expected,sizeof expected)) {
        auto *code=static_cast<unsigned char *>(VirtualAlloc(nullptr,16,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE));
        if(code) {
            std::memcpy(code,expected,sizeof expected);code[6]=0xe9;
            const int32_t back=static_cast<int32_t>(0x6f3fe6-reinterpret_cast<uintptr_t>(code+11));
            std::memcpy(code+7,&back,4);DWORD prior=0,ignored=0;
            if(VirtualProtect(code,16,PAGE_EXECUTE_READ,&ignored) && !std::memcmp(entry,expected,sizeof expected) &&
               VirtualProtect(entry,sizeof expected,PAGE_EXECUTE_READWRITE,&prior)) {
                script_shoot_dispatch_original=reinterpret_cast<uintptr_t>(code);
                const int32_t relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(native_script_shoot_dispatch_entry)-0x6f3fe5);
                entry[0]=0xe9;std::memcpy(entry+1,&relative,4);entry[5]=0x90;
                FlushInstructionCache(GetCurrentProcess(),code,16);FlushInstructionCache(GetCurrentProcess(),entry,sizeof expected);
                VirtualProtect(entry,sizeof expected,prior,&ignored);installed=true;result=1;
            } else VirtualFree(code,0,MEM_RELEASE);
        }
    }
    SetLastError(error);return result;
}
