#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include "../src/engine/character_motion_thunk.h"

extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((aligned(16),used)) static unsigned char actor[0x1440],body[0x140];
__attribute__((aligned(16),used)) static float source_velocity[4],canonical_velocity[4];
__attribute__((used)) static uintptr_t entry,native_argument,native_body;
__attribute__((used)) static uint32_t native_calls,observed_regs[9],initial_flags,mxcsr_value;
__attribute__((used)) static unsigned short control_word;
__attribute__((used)) static uint32_t helper_mxcsr=0x5f80;
__attribute__((used)) static double live_fpu[2]={1.25,-2.5};
static unsigned helper_calls,projection_calls,fallback_calls,helper_mode;

__attribute__((noinline)) static void clobber_helper_fx(){
 __asm__ volatile(
  "fninit\n\tfldz\n\tfld1\n\tldmxcsr _helper_mxcsr\n\t"
  "pcmpeqd %%xmm0,%%xmm0\n\tpcmpeqd %%xmm1,%%xmm1\n\tpcmpeqd %%xmm2,%%xmm2\n\t"
  "pcmpeqd %%xmm3,%%xmm3\n\tpcmpeqd %%xmm4,%%xmm4\n\tpcmpeqd %%xmm5,%%xmm5\n\t"
  "pcmpeqd %%xmm6,%%xmm6\n\tpcmpeqd %%xmm7,%%xmm7\n\t"
  "movl $0x13579bdf,%%eax\n\tmovl $0x2468ace0,%%ecx\n\tmovl $0xabcdef01,%%edx\n\tstc"
  :::"eax","ecx","edx","cc","memory");
}

// These modes exercise the ASM/helper contract, not production journal or allocation validation.
void __cdecl cadence_character_motion_input(void *source_actor,void *character,float *velocity){
 const DWORD error=GetLastError();uint32_t flags,mxcsr;unsigned short cw,status;
 __asm__ volatile("pushfl\n\tpopl %0\n\tstmxcsr %1\n\tfnstcw %2\n\tfnstsw %3"
                  :"=r"(flags),"=m"(mxcsr),"=m"(cw),"=m"(status));
 assert(source_actor==actor && character==body && velocity!=source_velocity);
 assert(!(flags&0x400) && mxcsr==0x1f80 && cw==0x37f && !(status&0x3800));
 assert(!std::memcmp(velocity,source_velocity,sizeof source_velocity));++helper_calls;
 if(helper_mode==2 || helper_mode==3){std::memcpy(velocity,canonical_velocity,sizeof canonical_velocity);++projection_calls;}
 else if(helper_mode==0)++fallback_calls;
 clobber_helper_fx();SetLastError(error);
}

__attribute__((naked)) static void native_velocity(){
 __asm__ volatile(
  "pushfl\n\tincl _native_calls\n\tpopfl\n\t"
  "movl 4(%esp),%eax\n\tmovl %eax,_native_argument\n\tmovl %ecx,_native_body\n\t"
  "flds (%eax)\n\tfstps 0xb0(%ecx)\n\tflds 4(%eax)\n\tfstps 0xb4(%ecx)\n\t"
  "flds 8(%eax)\n\tfstps 0xb8(%ecx)\n\tflds 12(%eax)\n\tfstps 0xbc(%ecx)\n\tret $4");
}
__attribute__((used)) static uintptr_t character_velocity_native=reinterpret_cast<uintptr_t>(native_velocity);
__attribute__((naked)) static void motion_hook(){__asm__ volatile(CHARACTER_MOTION_INPUT_THUNK_ASM);}

__attribute__((naked)) static void invoke(){
 __asm__ volatile(
  "pushfl\n\tpushal\n\tfxsave _caller_fx\n\t"
  "fninit\n\tfldz\n\tfldz\n\tfldz\n\tfldz\n\tfldz\n\tfldz\n\tfldz\n\tfldz\n\t"
  "fninit\n\tfldcw _control_word\n\tfldl _live_fpu\n\tfldl _live_fpu+8\n\tldmxcsr _mxcsr_value\n\t"
  "pxor %xmm0,%xmm0\n\tpxor %xmm1,%xmm1\n\tpxor %xmm2,%xmm2\n\tpxor %xmm3,%xmm3\n\t"
  "pxor %xmm4,%xmm4\n\tpxor %xmm5,%xmm5\n\tpxor %xmm6,%xmm6\n\tpxor %xmm7,%xmm7\n\t"
  "pcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
  "pushl _initial_flags\n\tpopfl\n\tmovl $0x11111111,%eax\n\tmovl $_body,%ecx\n\t"
  "movl $0x33333333,%edx\n\tmovl $_actor,%ebx\n\tmovl $0x55555555,%ebp\n\t"
  "movl $0x66666666,%esi\n\tmovl $0x77777777,%edi\n\tpushl $_source_velocity\n\tcall *_entry\n\t"
  "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\t"
  "fxsave _observed_fx\n\tleal 36(%esp),%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}
}

static void same_fx(const unsigned char *expected){
 assert(!std::memcmp(expected,observed_fx,5));
 assert(!std::memcmp(expected+24,observed_fx+24,8));
 for(unsigned i=0;i<8;++i)assert(!std::memcmp(expected+32+16*i,observed_fx+32+16*i,10));
 assert(!std::memcmp(expected+160,observed_fx+160,128));
}
static void from_words(float *destination,const uint32_t *source){std::memcpy(destination,source,16);}

int main(){
 const uint32_t boundary[]={0,0x80000000u,0x3f800000u,0xbf800000u,0x7f7fffffu,0xff7fffffu,
  0x00800000u,0x80800000u,1,0x80000001u,0x3f000001u,0xbf000001u};
 for(unsigned i=0;i<5000;++i){
  helper_mode=i%4;
  initial_flags=(i&1)?0x646u:0x297u;
  control_word=static_cast<unsigned short>(0x37f|((i%4)<<10));mxcsr_value=0x1f80|((i%4)<<13);
  for(unsigned j=0;j<sizeof actor;++j)actor[j]=static_cast<unsigned char>(i*17+j*29);
  for(unsigned j=0;j<sizeof body;++j)body[j]=static_cast<unsigned char>(i*43+j*13);
  uint32_t local_words[4],canonical_words[4];
  for(unsigned j=0;j<4;++j){local_words[j]=boundary[(i+j*3)%12];canonical_words[j]=boundary[(i+j*5+7)%12];}
  if(helper_mode==3)std::memcpy(canonical_words,local_words,16);
  from_words(canonical_velocity,canonical_words);
  unsigned char body_before[sizeof body],actor_before[sizeof actor];
  std::memcpy(body_before,body,sizeof body);std::memcpy(actor_before,actor,sizeof actor);
  const uint32_t *expected_words=(helper_mode==2||helper_mode==3)?canonical_words:local_words;
  from_words(source_velocity,expected_words);
  const unsigned before=native_calls;
  entry=reinterpret_cast<uintptr_t>(native_velocity);SetLastError(123);invoke();
  assert(GetLastError()==123 && native_calls==before+1 && native_body==reinterpret_cast<uintptr_t>(body));
  assert(native_argument==reinterpret_cast<uintptr_t>(source_velocity));
  assert(observed_regs[7]==native_argument);
  unsigned char expected_body[sizeof body],expected_fx[512];uint32_t expected_regs[9];
  std::memcpy(expected_body,body,sizeof body);std::memcpy(expected_fx,observed_fx,512);std::memcpy(expected_regs,observed_regs,sizeof observed_regs);
  std::memcpy(body,body_before,sizeof body);from_words(source_velocity,local_words);
  entry=reinterpret_cast<uintptr_t>(motion_hook);SetLastError(123);invoke();
  assert(GetLastError()==123 && helper_calls==i+1 && native_calls==before+2);
  assert(native_body==reinterpret_cast<uintptr_t>(body) && native_argument!=reinterpret_cast<uintptr_t>(source_velocity));
  assert(!std::memcmp(body,expected_body,sizeof body) && !std::memcmp(body+0xb0,expected_words,16));
  assert(!std::memcmp(body,body_before,0xb0) && !std::memcmp(body+0xc0,body_before+0xc0,sizeof body-0xc0));
  assert(!std::memcmp(actor,actor_before,sizeof actor) && !std::memcmp(source_velocity,local_words,16));
  assert(!std::memcmp(observed_regs,expected_regs,sizeof observed_regs));
  assert(observed_regs[7]==reinterpret_cast<uintptr_t>(source_velocity));
  assert(observed_regs[0]==0x77777777 && observed_regs[1]==0x66666666 && observed_regs[2]==0x55555555);
  assert(observed_regs[4]==reinterpret_cast<uintptr_t>(actor) && observed_regs[5]==0x33333333 && observed_regs[6]==reinterpret_cast<uintptr_t>(body));
  assert((observed_regs[8]&0x400)==(initial_flags&0x400));same_fx(expected_fx);
 }
 assert(helper_calls==5000 && native_calls==10000 && projection_calls==2500 && fallback_calls==1250);
 puts("5000 Character motion ASM cases passed: native setter once, scratch canonical/no-op/fallback inputs, source and non-velocity state unchanged, native GPR/ESP/flags/DF/FX/LastError behavior (mock helper contract).");
}
