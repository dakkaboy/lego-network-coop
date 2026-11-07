#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include "../src/engine/breakup_launch_thunk.h"
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((used)) static uint32_t observed_regs[9],iterator,argument,projected,native_calls;
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static double fpu_values[2]={1.25,2.5};
__attribute__((used)) static uint32_t mxcsr_value=0x3f80;
static unsigned projections;
void __cdecl physics_apply_breakup_launch(void *descriptor,void *handle) {
 const DWORD error=GetLastError();
 assert(descriptor==reinterpret_cast<void *>(0x66666666));
 assert(handle==reinterpret_cast<void *>(iterator<40?0x11223344:0));
 ++projections;projected=1;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");
 SetLastError(error);
}
__attribute__((naked)) static void native_launch(void) {
 __asm__ volatile("pushfl\n\tincl _native_calls\n\tpopfl\n\tpushl %eax\n\tmovl 8(%esp),%eax\n\tmovl %eax,_argument\n\tpopl %eax\n\tret");
}
__attribute__((used)) static uintptr_t breakup_launch_native=reinterpret_cast<uintptr_t>(native_launch);
__attribute__((naked)) static void launch_hook(void){__asm__ volatile(BREAKUP_LAUNCH_THUNK_ASM);}
__attribute__((naked)) static void invoke_thunk(void) {
 __asm__ volatile(
 "pushfl\n\tpushal\n\tsubl $1280,%esp\n\tfxsave _caller_fx\n\tfninit\n\t"
 "fldl _fpu_values\n\tfldl _fpu_values+8\n\tldmxcsr _mxcsr_value\n\t"
 "pcmpeqd %xmm0,%xmm0\n\tpcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
 "movl _iterator,%ecx\n\tmovl %ecx,0x3c(%esp)\n\tmovl $0x11223344,0x398(%esp,%ecx,4)\n\t"
 "movl $0x12345678,(%esp)\n\t"
 "pushl $0x646\n\tpopfl\n\tmovl $0x11111111,%eax\n\tmovl $0x22222222,%ecx\n\t"
 "movl $0x33333333,%edx\n\tmovl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\t"
 "movl $0x66666666,%esi\n\tmovl $0x77777777,%edi\n\tcall *_entry\n\t"
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\t"
 "fxsave _observed_fx\n\taddl $36,%esp\n\tfxrstor _caller_fx\n\taddl $1280,%esp\n\tpopal\n\tpopfl\n\tret");
}
}
int main(){
 const uint32_t indices[]={0,39,40};
 for(unsigned i=0;i<1000;i++)for(auto index:indices){
  iterator=index;entry=reinterpret_cast<uintptr_t>(native_launch);invoke_thunk();
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  projected=0;entry=reinterpret_cast<uintptr_t>(launch_hook);SetLastError(123);const auto before=native_calls;invoke_thunk();
  assert(projected==1 && native_calls==before+1 && argument==0x12345678 && GetLastError()==123);
  assert(!std::memcmp(regs,observed_regs,sizeof regs));assert(!std::memcmp(fx,observed_fx,sizeof fx));
 }
 assert(projections==3000);
 puts("3000 native launch bridges passed: native part lookup, invalid iterator, one original call, unchanged argument/GPR/EFLAGS/ESP/DF/x87/XMM/LastError.");
}
