#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <limits>
#include "../src/engine/character_support_input.h"
#include "../src/engine/effect_birth_thunk.h"
#include "../src/engine/native_effect_binding.hpp"
#include "../src/sync/physics_input_sync.h"
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((used)) static uint32_t observed_regs[9],argument,expected_argument,calls;
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static double fpu_values[2]={1.25,2.5};
__attribute__((used)) static uint32_t mxcsr_value=0x3f80;
void __cdecl physics_effect_birth(void *node) {
 const DWORD error=GetLastError();assert(reinterpret_cast<uintptr_t>(node)==expected_argument);++calls;
 __asm__ volatile("fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm7,%xmm7");SetLastError(error);
}
__attribute__((naked)) static void native_exit(){__asm__ volatile("movl 0x208(%esp),%ecx\n\tret");}
__attribute__((naked)) static void resume_exit(){__asm__ volatile("ret");}
__attribute__((used)) static uintptr_t effect_birth_resume=reinterpret_cast<uintptr_t>(resume_exit);
__attribute__((naked)) static void hook(){__asm__ volatile(EFFECT_BIRTH_THUNK_ASM);}
__attribute__((naked)) static void invoke(){__asm__ volatile(
 "pushfl\n\tpushal\n\tsubl $0x220,%esp\n\tfxsave _caller_fx\n\tfninit\n\t"
 "fldl _fpu_values\n\tfldl _fpu_values+8\n\tldmxcsr _mxcsr_value\n\t"
 "pcmpeqd %xmm0,%xmm0\n\tpcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
 "movl $0x87654321,0x204(%esp)\n\tpushl $0x646\n\tpopfl\n\t"
 "movl _expected_argument,%eax\n\tmovl $0x22222222,%ecx\n\tmovl $0x33333333,%edx\n\t"
 "movl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\tmovl $0x66666666,%esi\n\tmovl $0x77777777,%edi\n\tcall *_entry\n\t"
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\t"
 "fxsave _observed_fx\n\taddl $36,%esp\n\tfxrstor _caller_fx\n\taddl $0x220,%esp\n\tpopal\n\tpopfl\n\tret");}
}
int main(){
 using clonewars::engine::NativeEffectBodyBinding;
 using clonewars::engine::resolve_effect_body;
 const auto *object=reinterpret_cast<const unsigned char *>(0x1234);
 NativeEffectBodyBinding bindings[4]={};bool live[4]={false,true,false,false};uint32_t source[2]={99,99},revoked=0;
 bindings[0].body=bindings[1].body=object;bindings[0].epoch=bindings[1].epoch=7;
 bindings[0].sequence=10;bindings[0].event=55;bindings[1].sequence=22;bindings[1].event=20;
 auto validate=[&](size_t i,const NativeEffectBodyBinding &){return live[i];};
 assert(resolve_effect_body(bindings,4,object,7,0,validate,source,revoked)==1&&source[0]==22&&source[1]==20&&revoked==1&&!bindings[0].body);
 live[1]=false;live[2]=true;bindings[2]=bindings[1];bindings[2].sequence=23;bindings[2].event=30;
 assert(resolve_effect_body(bindings,4,object,7,0,validate,source,revoked)==1&&source[0]==23&&revoked==1&&!bindings[1].body);
 live[3]=true;bindings[3]=bindings[2];bindings[3].event=31;source[0]=source[1]=99;
 assert(resolve_effect_body(bindings,4,object,7,0,validate,source,revoked)==-1&&source[0]==99&&source[1]==99);
 assert(resolve_effect_body(bindings,4,object,8,0,validate,source,revoked)==0&&source[0]==99&&source[1]==99);
 assert(resolve_effect_body(bindings,4,object,7,1,validate,source,revoked)==0&&source[0]==99&&source[1]==99);
 for(unsigned i=0;i<3000;++i){
  expected_argument=i%2?0:0x12345678;entry=reinterpret_cast<uintptr_t>(native_exit);invoke();
  unsigned char fx[512];uint32_t regs[9];memcpy(fx,observed_fx,512);memcpy(regs,observed_regs,sizeof regs);
  entry=reinterpret_cast<uintptr_t>(hook);SetLastError(123);const auto before=calls;invoke();
  assert(calls==before+1&&GetLastError()==123);assert(!memcmp(fx,observed_fx,512));assert(!memcmp(regs,observed_regs,sizeof regs));
 }
 unsigned char body[0x140],before[0x140];memset(body,0xa4,sizeof body);memcpy(before,body,sizeof body);
 SyncCharacterMotionState local={},host={};local.support_frame=host.support_frame=7;local.support_event=host.support_event=3;
 host.support_anchor[0]=2;host.support_anchor[3]=1;host.support_normal[1]=1;host.support_material_flags=0x10400;
 assert(character_support_replay(body,&local,&host));assert(!memcmp(body+0x110,host.support_anchor,16));
 uint32_t flags;memcpy(&flags,body+0xc0,4);assert(flags==0xa4a4a4a5);uint16_t material;memcpy(&material,body+0x102,2);assert(material==0x400);
 for(unsigned i=0;i<sizeof body;i++)if(!(i>=0x110&&i<0x120)&&!(i>=0xf0&&i<0xfc)&&!(i>=0x102&&i<0x104)&&!(i>=0xc0&&i<0xc4))assert(body[i]==before[i]);
 memcpy(before,body,sizeof body);host.support_event++;assert(!character_support_replay(body,&local,&host));assert(!memcmp(body,before,sizeof body));host.support_event--;
 host.support_anchor[2]=std::numeric_limits<float>::quiet_NaN();assert(!character_support_replay(body,&local,&host));assert(!memcmp(body,before,sizeof body));
 host=local={};assert(character_support_replay(nullptr,&local,&host));host.support_event=1;assert(!character_support_input_valid(&host));
 SyncPhysicsChoice birth={};birth.kind=SYNC_PHYSICS_EFFECT_BIRTH;birth.site=0x7427d8;birth.flags=0x40000000;birth.model=4;birth.clock=12;birth.name_hash[0]=1;
 assert(physics_choice_valid(&birth));auto other=birth;other.name_hash[0]++;assert(!physics_choice_same_source(&birth,&other));other=birth;other.clock++;assert(!physics_choice_same_source(&birth,&other));birth.recipe[0]=1;assert(!physics_choice_valid(&birth));
 puts("3000 native effect exits preserve ABI; support replay checks birth identity, finite inputs, atomic rejection and unrelated contact fields.");
}
