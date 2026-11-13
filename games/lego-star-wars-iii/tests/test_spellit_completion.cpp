#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdint>
#include <cstring>
#include <initializer_list>
#include "../src/engine/spellit_completion_thunk.h"
extern "C" {
alignas(16) __attribute__((used)) static unsigned char caller[512],before[512],after[512],receiver[0x184];
__attribute__((used)) static uint32_t regs[9],mxcsr=0x3f80,canonical,site_seen;
__attribute__((used)) static uintptr_t entry;
uint32_t __cdecl native_spellit_receiver_flags(void *object,uint32_t site) {
    assert(object==receiver);site_seen=site;
    uint32_t flags,control;__asm__ volatile("pushfl; popl %0; stmxcsr %1":"=r"(flags),"=m"(control));
    assert(!(flags&0x400) && control==0x1f80);
    __asm__ volatile("fninit; fld1; pcmpeqd %%xmm0,%%xmm0; stc":::"memory","cc");
    return canonical;
}
__attribute__((naked)) static void continuation(){__asm__ volatile("ret");}
__attribute__((used)) static uintptr_t resume=reinterpret_cast<uintptr_t>(continuation);
__attribute__((naked)) static void first(){__asm__ volatile(SPELLIT_RECEIVER_FLAGS_ASM(0x812d7a,resume));}
__attribute__((naked)) static void second(){__asm__ volatile(SPELLIT_RECEIVER_FLAGS_ASM(0x812df0,resume));}
__attribute__((naked)) static void invoke(){
 __asm__ volatile(
  "pushfl; pushal; fxsave _caller; fninit; fld1; fldz; ldmxcsr _mxcsr;"
  "pxor %xmm0,%xmm0; pcmpeqd %xmm7,%xmm7; fxsave _before;"
  "pushl $0xe97; popfl; movl $0x11111111,%eax; movl $_receiver,%ecx;"
  "movl $0x33333333,%edx; movl $0x44444444,%ebx; movl $0x55555555,%ebp;"
  "movl $0x66666666,%esi; movl $0x77777777,%edi; call *_entry;"
  "pushfl; pushal; movl %esp,%esi; movl $_regs,%edi; movl $9,%ecx; cld; rep movsl;"
  "fxsave _after; addl $36,%esp; fxrstor _caller; popal; popfl; ret");
}
}
int main(){
 for(unsigned branch=0;branch<2;++branch)for(unsigned local=0;local<256;++local)for(unsigned value:{0u,4u}){
  receiver[0x183]=static_cast<unsigned char>(local);canonical=value;entry=reinterpret_cast<uintptr_t>(branch?second:first);
  SetLastError(123);invoke();assert(GetLastError()==123 && receiver[0x183]==local);
  assert(site_seen==(branch?0x812df0u:0x812d7au));
  assert(regs[0]==0x77777777 && regs[1]==0x66666666 && regs[2]==0x55555555 && regs[4]==0x44444444);
  assert(regs[5]==0x33333333 && regs[6]==reinterpret_cast<uintptr_t>(receiver) && regs[7]==0x11111111);
  assert((regs[8]&0x8c5)==(value?0u:0x44u) && (regs[8]&0x400));
  assert(!std::memcmp(before,after,5) && !std::memcmp(before+24,after+24,8));
  for(unsigned i=0;i<8;++i)assert(!std::memcmp(before+32+i*16,after+32+i*16,10));
  assert(!std::memcmp(before+160,after+160,128));
 }
}
