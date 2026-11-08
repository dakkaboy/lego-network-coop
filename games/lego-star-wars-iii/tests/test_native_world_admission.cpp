#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <initializer_list>
#include "../src/engine/native_world_admission_thunk.h"
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((used)) static uint32_t observed_regs[9],branch,native_calls,transition_arg;
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static double fpu_values[2]={1.25,2.5};
__attribute__((used)) static uint32_t mxcsr_value=0x3f80;
static unsigned input_calls,expected_local,selected;
uint32_t __cdecl native_tick_decision(uint32_t site,uint32_t local) {
 const DWORD error=GetLastError();assert(site==0x888889&&local==expected_local);++input_calls;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");SetLastError(error);return selected;
}
__attribute__((naked)) static void transition_stub(void){__asm__ volatile("movl $1,_branch\n\tpushfl\n\tincl _native_calls\n\tpopfl\n\tpushl %eax\n\tmovl 8(%esp),%eax\n\tmovl %eax,_transition_arg\n\tpopl %eax\n\tret $4");}
__attribute__((naked)) static void continue_stub(void){__asm__ volatile("movl $2,_branch\n\tpushfl\n\tincl _native_calls\n\tpopfl\n\tret");}
__attribute__((naked)) static void resume_stub(void){__asm__ volatile("ret");}
__attribute__((used)) static uintptr_t world_transition=reinterpret_cast<uintptr_t>(transition_stub),world_continue=reinterpret_cast<uintptr_t>(continue_stub);
__attribute__((used)) static uintptr_t world_exit_resume=reinterpret_cast<uintptr_t>(resume_stub),world_continue_resume=reinterpret_cast<uintptr_t>(resume_stub);
__attribute__((naked)) static void exit_hook(void){__asm__ volatile(NATIVE_WORLD_ADMISSION_ASM(1));}
__attribute__((naked)) static void continue_hook(void){__asm__ volatile(NATIVE_WORLD_ADMISSION_ASM(0));}
__attribute__((naked)) static void original_exit(void){__asm__ volatile("pushl $0xf\n\tmovl %edi,%ecx\n\tcall *_world_transition\n\tjmp *_world_exit_resume");}
__attribute__((naked)) static void original_continue(void){__asm__ volatile("call *_world_continue\n\tjmp *_world_continue_resume");}
__attribute__((naked)) static void invoke(void) {
 __asm__ volatile(
 "pushfl\n\tpushal\n\tfxsave _caller_fx\n\tfninit\n\t"
 "fldl _fpu_values\n\tfldl _fpu_values+8\n\tldmxcsr _mxcsr_value\n\t"
 "pcmpeqd %xmm0,%xmm0\n\tpcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
 "pushl $0x646\n\tpopfl\n\tmovl $0x11111111,%eax\n\tmovl $0x22222222,%ecx\n\t"
 "movl $0x33333333,%edx\n\tmovl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\t"
 "movl $0x66666666,%esi\n\tmovl $0x77777777,%edi\n\tcall *_entry\n\t"
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\t"
 "fxsave _observed_fx\n\taddl $36,%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}
}
int main(){
 for(unsigned i=0;i<1000;++i)for(expected_local=0;expected_local<2;++expected_local)for(selected=0;selected<2;++selected){
  entry=reinterpret_cast<uintptr_t>(selected?original_exit:original_continue);branch=native_calls=transition_arg=0;invoke();
  assert(branch==(selected?1u:2u)&&native_calls==1&&transition_arg==(selected?15u:0u));
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  entry=reinterpret_cast<uintptr_t>(expected_local?exit_hook:continue_hook);branch=native_calls=transition_arg=0;SetLastError(123);invoke();
  assert(branch==(selected?1u:2u)&&native_calls==1&&transition_arg==(selected?15u:0u)&&GetLastError()==123&&!std::memcmp(regs,observed_regs,sizeof regs)&&!std::memcmp(fx,observed_fx,sizeof fx));
 }
 assert(input_calls==4000);
 puts("4000 native world admission bridge comparisons passed across both local paths and host decisions, preserving native call, GPR/EFLAGS/ESP/DF/x87/XMM/LastError.");
}
