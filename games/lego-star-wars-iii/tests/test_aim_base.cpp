#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <initializer_list>

#include "../src/engine/aim_base_thunk.h"
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((used)) static uint32_t observed_regs[9],branch;
__attribute__((used)) static unsigned char model[0x50],task[0x30];
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static double fpu_values[2]={1.25,2.5};
__attribute__((used)) static uint32_t mxcsr_value=0x3f80;
static int input_calls;
__attribute__((used)) static float input_delta,selected_delta,observed_delta;
__attribute__((used)) static unsigned char wrapper[8];
__attribute__((used)) static uint32_t observed_argument;
void __cdecl cadence_prepare_aim_base(void *native_task,void *native_wrapper,float *delta) {
 const DWORD error=GetLastError();
 assert(native_task==task && native_wrapper==wrapper && *delta==input_delta);++input_calls;
 *delta=selected_delta;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");
 SetLastError(error);
}
__attribute__((naked)) static void input_cont(void){__asm__ volatile("fstps _observed_delta\n\tmovl %eax,_observed_argument\n\tret");}
__attribute__((used)) static uintptr_t aim_base_input_resume=reinterpret_cast<uintptr_t>(input_cont);
__attribute__((naked)) static void input_hook(void){__asm__ volatile(AIM_BASE_INPUT_THUNK_ASM);}
__attribute__((naked)) static void original_input(void){__asm__ volatile("flds 0x14(%esp)\n\tmovl 0xc(%esp),%eax\n\tjmp *_aim_base_input_resume");}
__attribute__((naked)) static void invoke(void) {
 __asm__ volatile(
 "pushfl\n\tpushal\n\tfxsave _caller_fx\n\tfninit\n\t"
 "fldl _fpu_values\n\tfldl _fpu_values+8\n\tldmxcsr _mxcsr_value\n\t"
 "pcmpeqd %xmm0,%xmm0\n\tpcmpeqd %xmm1,%xmm1\n\tpslld $1,%xmm1\n\tpcmpeqd %xmm2,%xmm2\n\tpslld $2,%xmm2\n\t"
 "pcmpeqd %xmm3,%xmm3\n\tpslld $3,%xmm3\n\tpcmpeqd %xmm4,%xmm4\n\tpslld $4,%xmm4\n\t"
 "pcmpeqd %xmm5,%xmm5\n\tpslld $5,%xmm5\n\tpcmpeqd %xmm6,%xmm6\n\tpslld $6,%xmm6\n\tpcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
 "pushl $0x646\n\tpopfl\n\tmovl $_model,%eax\n\tmovl $0x22222222,%ecx\n\t"
 "movl $0x33333333,%edx\n\tmovl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\t"
 "movl $0x66666666,%esi\n\tmovl $0x77777777,%edi\n\tsubl $0x20,%esp\n\t"
 "movl $0xaabbccdd,8(%esp)\n\tmovl $_wrapper,12(%esp)\n\tmovl _input_delta,%eax\n\tmovl %eax,16(%esp)\n\t"
 "movl $_model,%eax\n\tmovl $_task,%ecx\n\tcall *_entry\n\tleal 0x20(%esp),%esp\n\t"
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\t"
 "fxsave _observed_fx\n\taddl $36,%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}
}
int main(){
 for(unsigned i=0;i<500;++i)for(float local:{0.f,.017f,1.25f})for(float selected:{0.f,.025f,2.5f}){
  selected_delta=selected;input_delta=selected;
  entry=reinterpret_cast<uintptr_t>(original_input);invoke();
  assert(observed_delta==selected && observed_argument==0xaabbccdd);
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  input_delta=local;entry=reinterpret_cast<uintptr_t>(input_hook);SetLastError(123);invoke();
  assert(GetLastError()==123 && observed_delta==selected && observed_argument==0xaabbccdd);
  if(std::memcmp(regs,observed_regs,sizeof regs) || std::memcmp(fx,observed_fx,sizeof fx)) {
   for(unsigned j=0;j<9;++j)if(regs[j]!=observed_regs[j])std::printf("reg%u %08x %08x\n",j,regs[j],observed_regs[j]);
   for(unsigned j=0;j<512;++j)if(fx[j]!=observed_fx[j])std::printf("fx%u %02x %02x\n",j,fx[j],observed_fx[j]);
   std::fflush(stdout);return 1;
  }
 }
 assert(input_calls==4500);
 puts("4500 native Attack-entry comparisons passed; task/wrapper/delta projected before original FLD/MOV, GPR/EFLAGS/ESP/DF/x87/XMM/LastError preserved.");
}
