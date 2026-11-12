#undef NDEBUG
#include <cassert>
#include <cstdint>
#include <cstring>
#include <initializer_list>
#include "../src/engine/native_numeric_input.h"
static_assert(sizeof(NativeNumericScope)==12);
int main(){
 alignas(16) unsigned char original[512],fx[512],before[512],after[512];
 __asm__ volatile("fxsave %0":"=m"(original));
 const uint16_t modes[]={0x7f,0x27f,0x37f};
 for(auto local:modes)for(auto remote:modes){
  __asm__ volatile("fninit;fldcw %0;fld1"::"m"(local));
  __asm__ volatile("fxsave %0":"=m"(fx));
  std::memcpy(before,fx,sizeof fx);
  auto input=native_numeric_read(fx);auto desired=input;desired.cw=remote&0x1f3f;
  desired.mxcsr^=0xe040;
  assert(native_numeric_valid(desired));assert(native_numeric_apply(fx,desired));
  for(unsigned i=0;i<512;++i)if(i>=2&&(i<24||i>=28))assert(fx[i]==before[i]);
  NativeNumericScope scope{};native_numeric_borrow(&scope,input,fx);
  assert(scope.active);
  __asm__ volatile("fxrstor %0"::"m"(fx));
  uint16_t effective;double value;
  __asm__ volatile("fnstcw %0;fstpl %1":"=m"(effective),"=m"(value));
  assert((effective&0x1f3f)==desired.cw);assert(value==1.);
  __asm__ volatile("fxsave %0":"=m"(after));
  std::memcpy(before,after,sizeof after);
  native_numeric_restore(&scope,after);assert(!scope.active);
  assert(native_numeric_read(after).cw==input.cw);
  assert(native_numeric_read(after).mxcsr==input.mxcsr);
  for(unsigned i=0;i<512;++i)if(i>=2&&(i<24||i>=28))assert(after[i]==before[i]);
  std::memcpy(before,after,sizeof after);native_numeric_restore(&scope,after);
  assert(!std::memcmp(before,after,sizeof after));
 }
 __asm__ volatile("fxrstor %0"::"m"(original));
 std::memcpy(fx,original,sizeof fx);std::memcpy(before,fx,sizeof fx);
 for(auto invalid:{NativeNumericInput{0x100,0},NativeNumericInput{0x4000,0},NativeNumericInput{0,0x10000}}){
  assert(!native_numeric_apply(fx,invalid));assert(!std::memcmp(fx,before,sizeof fx));
 }
 auto local=native_numeric_read(fx);NativeNumericScope unchanged{};
 native_numeric_borrow(&unchanged,local,fx);assert(!unchanged.active);
 assert(native_numeric_apply(fx,NativeNumericInput{831,local.mxcsr}));
 native_numeric_restore(&unchanged,fx);assert(native_numeric_read(fx).cw==831);
 NativeNumericScope captured{};local.cw=63;native_numeric_borrow(&captured,local,fx);
 assert(captured.active);native_numeric_restore(&captured,fx);assert(native_numeric_read(fx).cw==63);
 return 0;
}
