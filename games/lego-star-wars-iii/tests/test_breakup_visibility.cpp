#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include "../src/engine/cadence_thunk.h"
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((used)) static uint32_t observed_regs[9],branch,initial_ebx;
__attribute__((used)) static uint32_t initial_breakup,observed_breakup;
__attribute__((used)) static uintptr_t initial_edx=0x33333333;
static unsigned char model[0x50];
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static double fpu_values[2]={1.25,2.5};
__attribute__((used)) static uint32_t mxcsr_value=0x3f80;
static int authoritative=-1,calls;
static int death_calls;
static int fall_calls;
int __cdecl cadence_apply_fall_visibility(void *actor,int visible) {
 const DWORD error=GetLastError();
 assert(actor==reinterpret_cast<void *>(0x44444444) && visible==!!model[0x42]);++fall_calls;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");
 SetLastError(error);return authoritative<0?visible:authoritative;
}
void __cdecl cadence_apply_death_breakup(void *actor,uint32_t *argument) {
 const DWORD error=GetLastError();
 assert(actor==reinterpret_cast<void *>(0x55555555) && *argument==initial_breakup);
 if(authoritative>=0)*argument=static_cast<uint32_t>(authoritative);
 ++death_calls;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");
 SetLastError(error);
}
int __cdecl cadence_apply_breakup_visibility(void *actor,int hidden) {
 const DWORD error=GetLastError();
 assert(actor==reinterpret_cast<void *>(0x66666666));
 assert(hidden==static_cast<int>(initial_ebx&255));++calls;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");
 SetLastError(error);return authoritative<0?hidden:authoritative;
}
__attribute__((naked)) static void visible_cont(void){__asm__ volatile("movl $0,_branch\n\tret");}
__attribute__((naked)) static void hidden_cont(void){__asm__ volatile("movl $1,_branch\n\tret");}
__attribute__((used)) static uintptr_t breakup_visible_resume=reinterpret_cast<uintptr_t>(visible_cont),breakup_hidden_resume=reinterpret_cast<uintptr_t>(hidden_cont);
__attribute__((naked)) static void gate_hook(void){__asm__ volatile(BREAKUP_VISIBILITY_THUNK_ASM);}
__attribute__((naked)) static void death_cont(void){__asm__ volatile("setnz _branch\n\tret");}
__attribute__((used)) static uintptr_t death_breakup_resume=reinterpret_cast<uintptr_t>(death_cont);
__attribute__((naked)) static void death_hook(void){__asm__ volatile(DEATH_BREAKUP_THUNK_ASM);}
__attribute__((naked)) static void original_death(void){__asm__ volatile("cmpl $0,0xa0(%esp)\n\tjmp *_death_breakup_resume");}
__attribute__((used)) static uintptr_t fall_visible_resume=reinterpret_cast<uintptr_t>(hidden_cont),fall_hidden_resume=reinterpret_cast<uintptr_t>(visible_cont);
__attribute__((naked)) static void fall_hook(void){__asm__ volatile(FALL_VISIBILITY_THUNK_ASM);}
__attribute__((naked)) static void original_fall(void){__asm__ volatile("cmpb $0,0x42(%edx)\n\tjz 1f\n\tjmp *_fall_visible_resume\n\t1: jmp *_fall_hidden_resume");}
__attribute__((naked)) static void original_gate(void){__asm__ volatile("testb %bl,%bl\n\tjnz 1f\n\tjmp *_breakup_visible_resume\n\t1: jmp *_breakup_hidden_resume");}
__attribute__((naked)) static void invoke_thunk(void) {
 __asm__ volatile(
 "pushfl\n\tpushal\n\tsubl $256,%esp\n\tfxsave _caller_fx\n\tfninit\n\t"
 "fldl _fpu_values\n\tfldl _fpu_values+8\n\tldmxcsr _mxcsr_value\n\t"
 "pcmpeqd %xmm0,%xmm0\n\tpcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
 "movl _initial_breakup,%eax\n\tmovl %eax,0x9c(%esp)\n\t"
 "pushl $0x646\n\tpopfl\n\tmovl $0x11111111,%eax\n\tmovl $0x22222222,%ecx\n\t"
 "movl _initial_edx,%edx\n\tmovl _initial_ebx,%ebx\n\tmovl $0x55555555,%ebp\n\t"
 "movl $0x66666666,%esi\n\tmovl $0x77777777,%edi\n\tcall *_entry\n\t"
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\t"
 "movl 0xc0(%esp),%eax\n\tmovl %eax,_observed_breakup\n\t"
 "fxsave _observed_fx\n\taddl $36,%esp\n\tfxrstor _caller_fx\n\taddl $256,%esp\n\tpopal\n\tpopfl\n\tret");
}
}
int main(){
 for(unsigned i=0;i<1000;i++)for(int hidden=0;hidden<2;hidden++){
  initial_ebx=0x44444400u|hidden;entry=reinterpret_cast<uintptr_t>(original_gate);invoke_thunk();
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  for(int forced=-1;forced<2;forced++){
   authoritative=forced;entry=reinterpret_cast<uintptr_t>(gate_hook);SetLastError(123);invoke_thunk();
   assert(GetLastError()==123 && branch==static_cast<uint32_t>(forced<0?hidden:forced));
   assert(!std::memcmp(regs,observed_regs,sizeof regs));assert(!std::memcmp(fx,observed_fx,sizeof fx));
  }
 }
 assert(calls==6000);
 for(unsigned i=0;i<1000;i++)for(int local=0;local<2;local++)for(int forced=-1;forced<2;forced++){
  authoritative=forced;const uint32_t expected=forced<0?local:forced;
  initial_breakup=expected;entry=reinterpret_cast<uintptr_t>(original_death);invoke_thunk();
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  initial_breakup=local;entry=reinterpret_cast<uintptr_t>(death_hook);SetLastError(123);invoke_thunk();
  assert(GetLastError()==123 && branch==expected && observed_breakup==expected);
  assert(!std::memcmp(regs,observed_regs,sizeof regs));assert(!std::memcmp(fx,observed_fx,sizeof fx));
 }
 assert(death_calls==6000);
 initial_edx=reinterpret_cast<uintptr_t>(model);initial_ebx=0x44444444;const unsigned char values[]={0,1,255};
 for(unsigned i=0;i<1000;i++)for(auto value:values)for(int forced=-1;forced<2;forced++){
  model[0x42]=value;authoritative=forced;
  entry=reinterpret_cast<uintptr_t>(original_fall);invoke_thunk();
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  entry=reinterpret_cast<uintptr_t>(fall_hook);SetLastError(123);invoke_thunk();
  assert(GetLastError()==123 && branch==static_cast<uint32_t>(forced<0?!!value:forced) && model[0x42]==value);
  assert(!std::memcmp(regs,observed_regs,sizeof regs));assert(!std::memcmp(fx,observed_fx,sizeof fx));
 }
 assert(fall_calls==9000);
 puts("21000 breakup/death/fall-gate comparisons passed: native/authoritative branches, GPR/EFLAGS/ESP/DF/x87/XMM/LastError, local visibility unchanged.");
}

