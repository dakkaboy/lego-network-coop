#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdint>
#include <cstring>
#include "../src/engine/rts_order_ready_thunk.h"
extern "C" {
alignas(16) __attribute__((used)) static unsigned char caller[512],before[512],after[512],receiver[0x64];
__attribute__((used)) static uint32_t regs[9],mxcsr=0x3f80,canonical;
__attribute__((used)) static uintptr_t entry;
uint32_t __cdecl native_rts_order_ready(void *object,uint32_t local){
    assert(object==reinterpret_cast<void *>(0x66666666) && local==receiver[0x62]);
    uint32_t flags,control;__asm__ volatile("pushfl; popl %0; stmxcsr %1":"=r"(flags),"=m"(control));
    assert(!(flags&0x400) && control==0x1f80);
    __asm__ volatile("fninit; fld1; pcmpeqd %%xmm0,%%xmm0; stc":::"memory","cc");
    return (local&~2u)|canonical;
}
__attribute__((naked)) static void continuation(){__asm__ volatile("ret");}
__attribute__((used)) static uintptr_t rts_order_ready_resume=reinterpret_cast<uintptr_t>(continuation);
__attribute__((naked)) static void hook(){__asm__ volatile(RTS_ORDER_READY_ASM);}
__attribute__((naked)) static void original(){__asm__ volatile("movb 0x62(%eax),%cl; shrb %cl; jmp *_rts_order_ready_resume");}
__attribute__((naked)) static void invoke(){
 __asm__ volatile(
  "pushfl; pushal; fxsave _caller; fninit; fld1; fldz; ldmxcsr _mxcsr;"
  "pxor %xmm0,%xmm0; pcmpeqd %xmm7,%xmm7; fxsave _before;"
  "pushl $0xe97; popfl; movl $_receiver,%eax; movl $0x22222222,%ecx;"
  "movl $0x33333333,%edx; movl $0x44444444,%ebx; movl $0x55555555,%ebp;"
  "movl $0x66666666,%esi; movl $0x77777777,%edi; call *_entry;"
  "pushfl; pushal; movl %esp,%esi; movl $_regs,%edi; movl $9,%ecx; cld; rep movsl;"
  "fxsave _after; addl $36,%esp; fxrstor _caller; popal; popfl; ret");
}
}
int main(){
 for(unsigned local=0;local<256;++local)for(unsigned bit=0;bit<2;++bit){
  canonical=bit*2;receiver[0x62]=(local&~2u)|canonical;entry=reinterpret_cast<uintptr_t>(original);invoke();
  uint32_t expected[9];std::memcpy(expected,regs,sizeof expected);
  receiver[0x62]=local;entry=reinterpret_cast<uintptr_t>(hook);SetLastError(123);invoke();
  assert(GetLastError()==123 && receiver[0x62]==local);
  for(unsigned i=0;i<8;++i)if(i!=3)assert(regs[i]==expected[i]);
  assert((regs[8]&0xcc5)==(expected[8]&0xcc5));
  assert(!std::memcmp(before,after,5) && !std::memcmp(before+24,after+24,8));
  for(unsigned i=0;i<8;++i)assert(!std::memcmp(before+32+i*16,after+32+i*16,10));
  assert(!std::memcmp(before+160,after+160,128));
 }
}
