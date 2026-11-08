#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <initializer_list>

#include "../src/engine/force_target_thunk.h"
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((used)) static uint32_t observed_regs[9],branch;
__attribute__((used)) static unsigned char model[0x50],task[0x30];
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static double fpu_values[2]={1.25,2.5};
__attribute__((used)) static uint32_t mxcsr_value=0x3f80;
static int authoritative=-1,visibility_calls;
__attribute__((used)) static uint32_t test_mode;
int __cdecl cadence_force_target_visibility(void *candidate,void *caster,uint32_t mode,int visible) {
 const DWORD error=GetLastError();
 assert(candidate==task && caster==reinterpret_cast<void *>(0x33333333) && mode==test_mode && visible==model[0x42]);++visibility_calls;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");
 SetLastError(error);return authoritative<0?visible:authoritative;
}
__attribute__((naked)) static void visible_cont(void){__asm__ volatile("movl $1,_branch\n\tret");}
__attribute__((naked)) static void hidden_cont(void){__asm__ volatile("movl $0,_branch\n\tret");}
__attribute__((used)) static uintptr_t force_target_visible_resume=reinterpret_cast<uintptr_t>(visible_cont),force_target_hidden_resume=reinterpret_cast<uintptr_t>(hidden_cont);
__attribute__((naked)) static void visibility_hook(void){__asm__ volatile(FORCE_TARGET_VISIBILITY_THUNK_ASM);}
__attribute__((naked)) static void original_visibility(void){__asm__ volatile("cmpb $0,0x42(%eax)\n\tje 1f\n\tjmp *_force_target_visible_resume\n\t1: jmp *_force_target_hidden_resume");}
__attribute__((naked)) static void invoke(void) {
 __asm__ volatile(
 "pushfl\n\tpushal\n\tfxsave _caller_fx\n\tfninit\n\t"
 "fldl _fpu_values\n\tfldl _fpu_values+8\n\tldmxcsr _mxcsr_value\n\t"
 "pcmpeqd %xmm0,%xmm0\n\tpcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
 "pushl $0x646\n\tpopfl\n\tmovl $_model,%eax\n\tmovl $0x22222222,%ecx\n\t"
 "movl $0x33333333,%edx\n\tmovl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\t"
 "movl $0x66666666,%esi\n\tmovl $_task,%edi\n\tsubl $0x44,%esp\n\tmovl _test_mode,%ecx\n\tmovl %ecx,0x40(%esp)\n\tmovl $0x22222222,%ecx\n\tcall *_entry\n\tleal 0x44(%esp),%esp\n\t"
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\t"
 "fxsave _observed_fx\n\taddl $36,%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}
}
int main(){
 const unsigned char values[]={0,1,255};
 for(unsigned i=0;i<100;++i)for(uint32_t mode:{0u,1u,2u,0x12345678u,UINT32_MAX})for(unsigned char visible:values)for(int forced=-1;forced<2;++forced){
  model[0x42]=visible;authoritative=forced;test_mode=mode;
  entry=reinterpret_cast<uintptr_t>(original_visibility);invoke();
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  entry=reinterpret_cast<uintptr_t>(visibility_hook);SetLastError(123);invoke();
  assert(GetLastError()==123 && branch==static_cast<uint32_t>(forced<0?!!visible:forced) && model[0x42]==visible);
  assert(!std::memcmp(regs,observed_regs,sizeof regs) && !std::memcmp(fx,observed_fx,sizeof fx));
 }
 assert(visibility_calls==4500);
 puts("4500 native Force candidate comparisons passed; candidate/caster/mode, GPR/EFLAGS/ESP/DF/x87/XMM/LastError and local model visibility preserved.");
}
