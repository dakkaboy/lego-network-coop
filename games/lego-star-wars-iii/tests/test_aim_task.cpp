#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <initializer_list>
#include "../src/engine/aim_task_input.h"
#include "../src/engine/aim_task_thunk.h"
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((used)) static uint32_t observed_regs[9],branch;
__attribute__((used)) static unsigned char model[0x50],task[0x30];
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static double fpu_values[2]={1.25,2.5};
__attribute__((used)) static uint32_t mxcsr_value=0x3f80;
static int authoritative=-1,input_calls,visibility_calls;
void __cdecl cadence_prepare_aim_task(void *actor,unsigned char *native_task) {
 const DWORD error=GetLastError();
 assert(actor==reinterpret_cast<void *>(0x66666666) && native_task==task);++input_calls;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");
 SetLastError(error);
}
int __cdecl cadence_aim_task_visibility(void *actor,void *native_task,int visible) {
 const DWORD error=GetLastError();
 assert(actor==reinterpret_cast<void *>(0x66666666) && native_task==task && visible==model[0x42]);++visibility_calls;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");
 SetLastError(error);return authoritative<0?visible:authoritative;
}
__attribute__((naked)) static void input_cont(void){__asm__ volatile("setnz _branch\n\tret");}
__attribute__((naked)) static void visible_cont(void){__asm__ volatile("movl $1,_branch\n\tret");}
__attribute__((naked)) static void hidden_cont(void){__asm__ volatile("movl $0,_branch\n\tret");}
__attribute__((used)) static uintptr_t aim_task_input_resume=reinterpret_cast<uintptr_t>(input_cont);
__attribute__((used)) static uintptr_t aim_task_visible_resume=reinterpret_cast<uintptr_t>(visible_cont),aim_task_hidden_resume=reinterpret_cast<uintptr_t>(hidden_cont);
__attribute__((naked)) static void input_hook(void){__asm__ volatile(AIM_TASK_INPUT_THUNK_ASM);}
__attribute__((naked)) static void visibility_hook(void){__asm__ volatile(AIM_TASK_VISIBILITY_THUNK_ASM);}
__attribute__((naked)) static void original_input(void){__asm__ volatile("movl 0x10(%edi),%ecx\n\ttestl %ecx,%ecx\n\tjmp *_aim_task_input_resume");}
__attribute__((naked)) static void original_visibility(void){__asm__ volatile("cmpb $0,0x42(%eax)\n\tje 1f\n\tjmp *_aim_task_visible_resume\n\t1: jmp *_aim_task_hidden_resume");}
__attribute__((naked)) static void invoke(void) {
 __asm__ volatile(
 "pushfl\n\tpushal\n\tfxsave _caller_fx\n\tfninit\n\t"
 "fldl _fpu_values\n\tfldl _fpu_values+8\n\tldmxcsr _mxcsr_value\n\t"
 "pcmpeqd %xmm0,%xmm0\n\tpcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
 "pushl $0x646\n\tpopfl\n\tmovl $_model,%eax\n\tmovl $0x22222222,%ecx\n\t"
 "movl $0x33333333,%edx\n\tmovl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\t"
 "movl $0x66666666,%esi\n\tmovl $_task,%edi\n\tcall *_entry\n\t"
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\t"
 "fxsave _observed_fx\n\taddl $36,%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}
}
int main(){
 for(unsigned i=0;i<1000;++i)for(uint32_t target:{0u,0x12345678u}){
  std::memcpy(task+0x10,&target,4);entry=reinterpret_cast<uintptr_t>(original_input);invoke();
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  entry=reinterpret_cast<uintptr_t>(input_hook);SetLastError(123);invoke();
  assert(GetLastError()==123 && branch==!!target && !std::memcmp(regs,observed_regs,sizeof regs) && !std::memcmp(fx,observed_fx,sizeof fx));
 }
 const unsigned char values[]={0,1,255};
 for(unsigned i=0;i<1000;++i)for(auto visible:values)for(int forced=-1;forced<2;++forced){
  model[0x42]=visible;authoritative=forced;
  entry=reinterpret_cast<uintptr_t>(original_visibility);invoke();
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  entry=reinterpret_cast<uintptr_t>(visibility_hook);SetLastError(123);invoke();
  assert(GetLastError()==123 && branch==static_cast<uint32_t>(forced<0?!!visible:forced) && model[0x42]==visible);
  assert(!std::memcmp(regs,observed_regs,sizeof regs) && !std::memcmp(fx,observed_fx,sizeof fx));
 }
 assert(input_calls==2000 && visibility_calls==9000);
 const SyncAimTaskState a={1,8,123,200,-.1f,.5f,1.5f,0x721234,0};auto b=a;
 b.rng_engine=456;b.remaining=.25f;assert(aim_task_context_equal(&a,&b));
 b=a;++b.target_slot;assert(!aim_task_context_equal(&a,&b));
 b=a;++b.target_generation;assert(!aim_task_context_equal(&a,&b));
 b=a;++b.clock;assert(!aim_task_context_equal(&a,&b));
 b=a;++b.task_class;assert(!aim_task_context_equal(&a,&b));
 b=a;b.minimum+=.1f;assert(!aim_task_context_equal(&a,&b));
 b=a;b.maximum+=.1f;assert(!aim_task_context_equal(&a,&b));
 puts("11000 native aim bridge comparisons passed; target/recipe/class/clock remain strict.");
}
