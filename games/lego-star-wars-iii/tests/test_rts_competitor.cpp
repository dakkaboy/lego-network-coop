#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <initializer_list>
#include "../src/engine/rts_competitor_input.h"
#include "../src/engine/rts_competitor_thunk.h"
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((used)) static uint32_t observed_regs[9],branch;
__attribute__((used)) static unsigned char model[0x50],task[0x30];
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static double fpu_values[2]={1.25,2.5};
__attribute__((used)) static uint32_t mxcsr_value=0x3f80;
static int input_calls;
static float initial_delta=.05f;
__attribute__((used)) static uint32_t observed_delta;
void __cdecl cadence_prepare_rts_competitor(void *competitor,float *delta) {
 const DWORD error=GetLastError();assert(competitor==task&&*delta==initial_delta);++input_calls;*delta=.017f;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");SetLastError(error);
}
__attribute__((naked)) static void native_cont(void){__asm__ volatile("movl %ebp,%esp\n\tpopl %ebp\n\tret");}
__attribute__((used)) static uintptr_t rts_competitor_input_resume=reinterpret_cast<uintptr_t>(native_cont);
__attribute__((naked)) static void input_hook(void){__asm__ volatile(RTS_COMPETITOR_INPUT_THUNK_ASM);}
__attribute__((naked)) static void original_input(void){__asm__ volatile("pushl %ebp\n\tmovl %esp,%ebp\n\tandl $-16,%esp\n\tjmp *_rts_competitor_input_resume");}
__attribute__((naked)) static void invoke(void) {
 __asm__ volatile(
 "pushfl\n\tpushal\n\tfxsave _caller_fx\n\tfninit\n\t"
 "fldl _fpu_values\n\tfldl _fpu_values+8\n\tldmxcsr _mxcsr_value\n\t"
 "pcmpeqd %xmm0,%xmm0\n\tpcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
 "pushl $0x646\n\tpopfl\n\tmovl $_model,%eax\n\tmovl $0x22222222,%ecx\n\t"
 "movl $0x33333333,%edx\n\tmovl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\t"
 "movl $0x66666666,%esi\n\tmovl $_task,%edi\n\tmovl $_task,%ecx\n\tpushl $0x3d4ccccd\n\tcall *_entry\n\t"
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\t"
 "fxsave _observed_fx\n\taddl $36,%esp\n\tpopl _observed_delta\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}
}
int main(){
 for(unsigned i=0;i<3000;++i){
  entry=reinterpret_cast<uintptr_t>(original_input);invoke();
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  entry=reinterpret_cast<uintptr_t>(input_hook);SetLastError(123);invoke();
  float delta;std::memcpy(&delta,&observed_delta,4);
  assert(GetLastError()==123&&delta==.017f&&!std::memcmp(regs,observed_regs,sizeof regs)&&!std::memcmp(fx,observed_fx,sizeof fx));
 }
 assert(input_calls==3000);
 const SyncRtsCompetitorState a={123,456,200,0x6ee004,.017f,{}};auto b=a;
 b.rng_game=789;b.rng_engine=333;b.delta=.02f;b.timers[11]=1;assert(rts_competitor_context_equal(&a,&b));
 b=a;++b.clock;assert(!rts_competitor_context_equal(&a,&b));
 b=a;++b.competitor_class;assert(!rts_competitor_context_equal(&a,&b));
 puts("3000 native RTS entry bridge comparisons passed; original aligned prologue, delta argument, GPR/EFLAGS/ESP/DF/x87/XMM/LastError.");
}
