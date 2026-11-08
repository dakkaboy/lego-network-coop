#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include "../src/engine/force_geometry_thunk.h"
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((used)) static float caster[3],candidate[3],authoritative[6],output[3],distance_value;
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static uint32_t mode,observed_regs[4],distance_calls;
static bool project;
static unsigned input_calls;
void __cdecl cadence_force_geometry_input(void *target,void *source,uint32_t native_mode,float *points) {
 assert(target==reinterpret_cast<void *>(0x77777777) && source==reinterpret_cast<void *>(0x55555555) && native_mode==mode);
 assert(!std::memcmp(points,caster,12) && !std::memcmp(points+3,candidate,12));
 ++input_calls;
 if(project)std::memcpy(points,authoritative,24);
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");
}
__attribute__((naked)) static void native_distance(void) {
 __asm__ volatile(
 "incl _distance_calls\n\tmovl 12(%esp),%eax\n\tsubl $12,%esp\n\t"
 "movl 16(%esp),%ecx\n\tmovl 20(%esp),%edx\n\t"
 "flds (%ecx)\n\tfsubs (%edx)\n\tfstps (%eax)\n\t"
 "flds 4(%ecx)\n\tfsubs 4(%edx)\n\tfstps 4(%eax)\n\t"
 "flds 8(%ecx)\n\tfsubs 8(%edx)\n\tfstps 24(%esp)\n\tflds 24(%esp)\n\tfsts 8(%eax)\n\t"
 "flds 4(%eax)\n\tflds (%eax)\n\tfmul %st,%st\n\tfld %st(1)\n\tfmulp %st,%st(2)\n\t"
 "faddp %st,%st(1)\n\tfld %st(1)\n\tfmulp %st,%st(2)\n\tfaddp %st,%st(1)\n\t"
 "fstps 24(%esp)\n\tflds 24(%esp)\n\taddl $12,%esp\n\tret");
}
__attribute__((used)) static uintptr_t force_distance_native=reinterpret_cast<uintptr_t>(native_distance);
__attribute__((naked)) static void geometry_hook(void){__asm__ volatile(FORCE_GEOMETRY_INPUT_THUNK_ASM);}
__attribute__((naked)) static void invoke(void){
 __asm__ volatile(
 "pushfl\n\tpushal\n\tfxsave _caller_fx\n\tfninit\n\tfld1\n\tfldpi\n\t"
 "pxor %xmm0,%xmm0\n\tpcmpeqd %xmm7,%xmm7\n\tsubl $0x48,%esp\n\t"
 "movl _mode,%eax\n\tmovl %eax,0x44(%esp)\n\t"
 "movl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\tmovl $0x66666666,%esi\n\tmovl $0x77777777,%edi\n\t"
 "pushl $_output\n\tpushl $_candidate\n\tpushl $_caster\n\tcall *_entry\n\t"
 "fstps _distance_value\n\tfxsave _observed_fx\n\tmovl %ebx,_observed_regs\n\tmovl %ebp,_observed_regs+4\n\t"
 "movl %esi,_observed_regs+8\n\tmovl %edi,_observed_regs+12\n\t"
 "addl $0x54,%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}
}
int main(){
 for(unsigned i=0;i<5000;++i){
  mode=i%3;project=i%2;
  for(unsigned j=0;j<6;++j)authoritative[j]=static_cast<float>(static_cast<int>((i*31+j*97)%173)-86)/37.0f;
  std::memcpy(caster,authoritative,12);std::memcpy(candidate,authoritative+3,12);
  entry=reinterpret_cast<uintptr_t>(native_distance);invoke();
  unsigned char fx[512];std::memcpy(fx,observed_fx,512);float expected[3],distance=distance_value;std::memcpy(expected,output,12);
  if(project){caster[0]+=.0001f;caster[2]-=.02f;candidate[0]-=.0001f;candidate[2]+=.02f;}
  float local[6];std::memcpy(local,caster,12);std::memcpy(local+3,candidate,12);
  entry=reinterpret_cast<uintptr_t>(geometry_hook);SetLastError(123);invoke();
  assert(GetLastError()==123 && distance_value==distance && !std::memcmp(expected,output,12));
  assert(!std::memcmp(fx,observed_fx,512));
  assert(observed_regs[0]==0x44444444 && observed_regs[1]==0x55555555 && observed_regs[2]==0x66666666 && observed_regs[3]==0x77777777);
  assert(!std::memcmp(local,caster,12) && !std::memcmp(local+3,candidate,12));
 }
 assert(input_calls==5000 && distance_calls==10000);
 puts("5000 Force distance source cases passed: native calculation once, authoritative points, local objects unchanged, callee registers/ESP/FX/LastError preserved.");
}
