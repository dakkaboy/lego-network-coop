#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <initializer_list>
#include "../src/engine/native_flow_request_thunk.h"
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512],flow[0x80];
__attribute__((used)) static uint32_t observed_regs[9],native_calls;
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static double fpu_values[2]={1.25,2.5};
__attribute__((used)) static uint32_t mxcsr_value=0x3f80;
static unsigned input_calls,expected_local,selected;
void __cdecl native_flow_request(unsigned char *p) {
 const DWORD error=GetLastError();assert(p==flow&&*reinterpret_cast<uint32_t *>(p+0x60)==expected_local);++input_calls;
 *reinterpret_cast<uint32_t *>(p+0x60)=selected;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");SetLastError(error);
}
__attribute__((naked,used)) static void transition_stub(void){__asm__ volatile("movl 4(%esp),%eax\n\tmovl %eax,0x34(%ecx)\n\tpushfl\n\tincl _native_calls\n\tpopfl\n\tret $4");}
__attribute__((naked)) static void native_cont(void){__asm__ volatile("je 1f\n\tpushl %eax\n\tmovl %esi,%ecx\n\tcall _transition_stub\n\tmovl $-1,0x60(%esi)\n\t1: ret");}
__attribute__((used)) static uintptr_t flow_request_resume=reinterpret_cast<uintptr_t>(native_cont);
__attribute__((naked)) static void input_hook(void){__asm__ volatile(NATIVE_FLOW_REQUEST_ASM);}
__attribute__((naked)) static void original_input(void){__asm__ volatile("movl 0x60(%esi),%eax\n\tcmpl %edi,%eax\n\tjmp *_flow_request_resume");}
__attribute__((naked)) static void invoke(void) {
 __asm__ volatile(
 "pushfl\n\tpushal\n\tfxsave _caller_fx\n\tfninit\n\t"
 "fldl _fpu_values\n\tfldl _fpu_values+8\n\tldmxcsr _mxcsr_value\n\t"
 "pcmpeqd %xmm0,%xmm0\n\tpcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
 "pushl $0x646\n\tpopfl\n\tmovl $0x11111111,%eax\n\tmovl $0x22222222,%ecx\n\t"
 "movl $0x33333333,%edx\n\tmovl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\t"
 "movl $_flow,%esi\n\tmovl $-1,%edi\n\tcall *_entry\n\t"
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\t"
 "fxsave _observed_fx\n\taddl $36,%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}
}
int main(){
 const uint32_t locals[]={UINT32_MAX,11,14},requests[]={UINT32_MAX,0,11,13,14,20};
 for(unsigned i=0;i<200;++i)for(uint32_t local:locals)for(uint32_t request:requests){
  selected=request;expected_local=local;*reinterpret_cast<uint32_t *>(flow+0x60)=selected;*reinterpret_cast<uint32_t *>(flow+0x34)=14;native_calls=0;
  entry=reinterpret_cast<uintptr_t>(original_input);invoke();
  assert(native_calls==(selected==UINT32_MAX?0u:1u));
  const uint32_t state=*reinterpret_cast<uint32_t *>(flow+0x34);
  unsigned char fx[512];uint32_t regs[9];std::memcpy(fx,observed_fx,sizeof fx);std::memcpy(regs,observed_regs,sizeof regs);
  *reinterpret_cast<uint32_t *>(flow+0x60)=expected_local;*reinterpret_cast<uint32_t *>(flow+0x34)=14;native_calls=0;
  entry=reinterpret_cast<uintptr_t>(input_hook);SetLastError(123);invoke();
  assert(native_calls==(selected==UINT32_MAX?0u:1u)&&*reinterpret_cast<uint32_t *>(flow+0x34)==state&&*reinterpret_cast<uint32_t *>(flow+0x60)==UINT32_MAX);
  assert(GetLastError()==123&&!std::memcmp(regs,observed_regs,sizeof regs)&&!std::memcmp(fx,observed_fx,sizeof fx));
 }
 assert(input_calls==3600);
 puts("3600 native pending-request bridge comparisons passed; original transition/clear or no-request path, GPR/EFLAGS/ESP/DF/x87/XMM/LastError preserved.");
}
