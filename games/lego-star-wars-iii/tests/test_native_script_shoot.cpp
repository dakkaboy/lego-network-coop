#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <initializer_list>
#include "engine/native_script_shoot_source.h"
#include "engine/script_shoot_thunk.h"
static unsigned checks;
static void check(bool condition){++checks;if(!condition){std::fprintf(stderr,"failed check %u\n",checks);std::fflush(stderr);}assert(condition);}
static unsigned char world[0x224],definition[0x96],model_data[0x50],brain[0x1a0],state_data[0xb0];
static uint32_t native_frame_data[8],wrapper[2],classes[4][4];
static unsigned char *actors;
static char arg0[]="TargetGizmo",arg1[]="synthetic\xc3\xa9",arg2[]="AvoidCamera";
static char *arguments[]={arg0,arg1,arg2};
template<class T>static void put(void *p,size_t off,T value){std::memcpy(static_cast<unsigned char *>(p)+off,&value,sizeof value);}
static void __cdecl code_caller(){}
static void setup(){
 std::memset(world,0,sizeof world);std::memset(definition,0,sizeof definition);std::memset(model_data,0,sizeof model_data);std::memset(brain,0,sizeof brain);std::memset(state_data,0,sizeof state_data);std::memset(actors,0,0x2880);
 put(reinterpret_cast<void *>(0xfb4a20),0,world);put(reinterpret_cast<void *>(0xfb2f60),0,actors);put<uint32_t>(reinterpret_cast<void *>(0xfb2e3c),0,2);put<uint32_t>(reinterpret_cast<void *>(0xfb4b6c),0,1627);
 put(world,0x220,definition);put<uint16_t>(definition,0x94,7);put(actors,8,model_data);put(model_data,0,classes[0]);put(model_data,0x34,brain);put(brain,0,classes[1]);put<uint32_t>(brain,0x198,1);put(state_data,0,classes[2]);put<uint16_t>(state_data,0xa6,1);model_data[0x42]=1;
 wrapper[0]=0;wrapper[1]=reinterpret_cast<uintptr_t>(actors);
 native_frame_data[0]=0x11223344;native_frame_data[1]=reinterpret_cast<uintptr_t>(code_caller);native_frame_data[2]=reinterpret_cast<uintptr_t>(world);native_frame_data[3]=reinterpret_cast<uintptr_t>(state_data);native_frame_data[4]=reinterpret_cast<uintptr_t>(wrapper);native_frame_data[5]=reinterpret_cast<uintptr_t>(arguments);native_frame_data[6]=3;native_frame_data[7]=0;
}
static NativeScriptShootSource resolved(){NativeScriptShootSource s{};SetLastError(0xaabbccdd);check(native_script_shoot_source_resolve(actors,state_data,model_data,reinterpret_cast<uintptr_t>(native_frame_data),&s)==1);check(GetLastError()==0xaabbccdd);return s;}
static void engine_tests(){
 check(sizeof(NativeScriptShootInput)==56);check(VirtualAlloc(reinterpret_cast<void *>(0xfb0000),0x10000,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE)==reinterpret_cast<void *>(0xfb0000));actors=static_cast<unsigned char *>(VirtualAlloc(nullptr,0x3000,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE));check(actors!=nullptr);setup();
 auto s=resolved();check(s.actor_ordinal==0 && s.input.argument_count==3 && s.input.initialize==0 && s.input.state_flags==1);
 for(unsigned i=0;i<3000;++i){arg1[0]=static_cast<char>('a'+i%26);auto a=resolved();check(native_script_shoot_source_revalidate(&a)==1);model_data[0x42]^=1;check(native_script_shoot_source_revalidate(&a)==1);auto b=resolved();check(!std::memcmp(&a.input,&b.input,sizeof a.input));arg1[0]^=1;check(native_script_shoot_source_revalidate(&a)==0);arg1[0]^=1;}
 setup();s=resolved();auto initial=s.input;arg0[0]='X';auto changed=resolved();check(std::memcmp(initial.argument_hash,changed.input.argument_hash,16)!=0);check(native_script_shoot_source_revalidate(&s)==0);arg0[0]='T';
 setup();s=resolved();native_frame_data[7]=0xffffffffu;auto initialized=resolved();check(initialized.input.initialize==1);check(native_script_shoot_source_revalidate(&s)==0);
 setup();put<uint32_t>(brain,0x198,2);s=resolved();check(s.input.brain_admission==1 && s.brain_admission_raw==2);put<uint32_t>(brain,0x198,3);check(!native_script_shoot_source_revalidate(&s));
 for(unsigned mutation=0;mutation<15;++mutation){setup();s=resolved();switch(mutation){
 case 0:wrapper[1]+=0x1440;break;case 1:put(model_data,0x34,state_data);break;case 2:put(actors,8,state_data);break;
 case 3:put(model_data,0,classes[3]);break;case 4:put(brain,0,classes[3]);break;case 5:put(state_data,0,classes[3]);break;
 case 6:put<uint16_t>(state_data,0xa6,9);break;case 7:put<uint32_t>(brain,0x198,0);break;
 case 8:native_frame_data[2]=0;break;case 9:native_frame_data[5]=0;break;case 10:native_frame_data[6]=2;break;
 case 11:put<uint32_t>(reinterpret_cast<void *>(0xfb4b6c),0,1628);break;
 case 12:put(reinterpret_cast<void *>(0xfb4a20),0,definition);break;case 13:put<uint32_t>(reinterpret_cast<void *>(0xfb2e3c),0,1);break;
 case 14:put(world,0x220,brain);break;}
 check(native_script_shoot_source_revalidate(&s)==0);
 }
 NativeScriptShootSource sentinel;std::memset(&sentinel,0x5a,sizeof sentinel);auto before=sentinel;
 for(unsigned invalid=0;invalid<9;++invalid){setup();void *a=actors,*m=model_data,*st=state_data;uintptr_t f=reinterpret_cast<uintptr_t>(native_frame_data);switch(invalid){
 case 0:a=actors+1;break;case 1:a=actors+0x2880;break;case 2:m=nullptr;break;case 3:st=reinterpret_cast<void *>(1);break;case 4:f=1;break;
 case 5:native_frame_data[6]=257;break;case 6:native_frame_data[1]=reinterpret_cast<uintptr_t>(actors);break;case 7:put(model_data,0,actors);break;case 8:put<uint32_t>(reinterpret_cast<void *>(0xfb2e3c),0,4097);break;}
 SetLastError(0x12345678);check(!native_script_shoot_source_resolve(a,st,m,f,&sentinel));check(!std::memcmp(&before,&sentinel,sizeof before));check(GetLastError()==0x12345678);
 }
 setup();native_frame_data[5]=0;native_frame_data[6]=0;s=resolved();check(s.input.argument_count==0);
 auto *guard=static_cast<unsigned char *>(VirtualAlloc(nullptr,0x2000,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE));DWORD old;check(guard!=nullptr);check(VirtualProtect(guard+0x1000,0x1000,PAGE_NOACCESS,&old)!=0);setup();native_frame_data[5]=reinterpret_cast<uintptr_t>(guard+0xffe);check(!native_script_shoot_source_resolve(actors,state_data,model_data,reinterpret_cast<uintptr_t>(native_frame_data),&sentinel));VirtualFree(guard,0,MEM_RELEASE);
 std::puts("actual engine resolver: source changes, class/backlink/clock/frame/pool/arguments, UTF8 bytes, malformed/guarded reads and LastError passed");
}
extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512],xmm_patterns[128];
__attribute__((used)) static uint32_t observed_regs[9],branch,helper_calls,continuation_calls;
__attribute__((used)) static unsigned char abi_model[0x50],abi_state[0xb0],native_operand;
__attribute__((used)) static uintptr_t entry;
__attribute__((used)) static double fpu_values[2]={1.25,2.5};
__attribute__((used)) static uint32_t mxcsr_value=0x3f80,cw=0x7f;
static int canonical=-1;
uint32_t __cdecl helper_body(void *a,void *s,void *m,uintptr_t frame,uint32_t local){
 check(a==reinterpret_cast<void *>(0x11112222) && s==abi_state && m==abi_model && frame==0x33334444 && local==abi_model[0x42]);++helper_calls;
 SetLastError(0xdeadbeef);return canonical<0?local:canonical;
}
__attribute__((naked)) uint32_t __cdecl cadence_script_shoot_visibility(void *,void *,void *,uintptr_t,uint32_t){__asm__ volatile(
 "pushl 20(%esp)\n\tpushl 20(%esp)\n\tpushl 20(%esp)\n\tpushl 20(%esp)\n\tpushl 20(%esp)\n\tcall _helper_body\n\taddl $20,%esp\n\t"
 "fninit\n\tpcmpeqd %xmm0,%xmm0\n\tpxor %xmm1,%xmm1\n\tpxor %xmm2,%xmm2\n\tpxor %xmm3,%xmm3\n\tpxor %xmm4,%xmm4\n\tpxor %xmm5,%xmm5\n\tpxor %xmm6,%xmm6\n\tpxor %xmm7,%xmm7\n\t"
 "movl $1,%ebx\n\tmovl $2,%ebp\n\tmovl $3,%esi\n\tmovl $4,%edi\n\tmovl $5,%ecx\n\tmovl $6,%edx\n\tstd\n\tret");}
__attribute__((naked)) static void visible_cont(){__asm__ volatile("movl $1,_branch\n\tpushfl\n\tincl _continuation_calls\n\tpopfl\n\tret");}
__attribute__((naked)) static void hidden_cont(){__asm__ volatile("testb $8,_abi_state+0xa6\n\tjnz 1f\n\tmovl $0,_branch\n\tpushfl\n\tincl _continuation_calls\n\tpopfl\n\tret\n\t1: jmp *_script_shoot_visible_resume");}
__attribute__((used)) static uintptr_t script_shoot_visible_resume=reinterpret_cast<uintptr_t>(visible_cont),script_shoot_hidden_resume=reinterpret_cast<uintptr_t>(hidden_cont);
__attribute__((naked)) static void hook(){__asm__ volatile(SCRIPT_SHOOT_VISIBILITY_THUNK_ASM);}
__attribute__((naked)) static void original(){__asm__ volatile("cmpb $0,_native_operand\n\tjne 1f\n\tjmp *_script_shoot_hidden_resume\n\t1: jmp *_script_shoot_visible_resume");}
__attribute__((naked)) static void invoke(){__asm__ volatile(
 "pushfl\n\tpushal\n\tfxsave _caller_fx\n\tfninit\n\tfldcw _cw\n\tfldl _fpu_values\n\tfldl _fpu_values+8\n\tldmxcsr _mxcsr_value\n\t"
 "movdqa _xmm_patterns,%xmm0\n\tmovdqa _xmm_patterns+16,%xmm1\n\tmovdqa _xmm_patterns+32,%xmm2\n\tmovdqa _xmm_patterns+48,%xmm3\n\tmovdqa _xmm_patterns+64,%xmm4\n\tmovdqa _xmm_patterns+80,%xmm5\n\tmovdqa _xmm_patterns+96,%xmm6\n\tmovdqa _xmm_patterns+112,%xmm7\n\t"
 "pushl $0x646\n\tpopfl\n\tmovl $_abi_model,%eax\n\tmovl $0x22222222,%ecx\n\tmovl $0x33333333,%edx\n\tmovl $0x44444444,%ebx\n\tmovl $0x33334444,%ebp\n\tmovl $_abi_state,%esi\n\tmovl $0x11112222,%edi\n\tcall *_entry\n\t"
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\tfxsave _observed_fx\n\taddl $36,%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");}
}
static void abi_tests(){std::fprintf(stderr,"engine done %u\n",checks);
 for(unsigned i=0;i<sizeof xmm_patterns;++i)xmm_patterns[i]=static_cast<unsigned char>(i*13+7);
 unsigned cases=0;
 for(unsigned repeat=0;repeat<1000;++repeat)for(unsigned char local:{0,1,255})for(int host:{-1,0,1})for(unsigned char fallback:{0,8}){
  abi_model[0x42]=local;abi_state[0xa6]=fallback;canonical=host;native_operand=host<0?local:host;entry=reinterpret_cast<uintptr_t>(original);invoke();
  uint32_t regs[9];unsigned char fx[512];std::memcpy(regs,observed_regs,sizeof regs);std::memcpy(fx,observed_fx,sizeof fx);const uint32_t expected_branch=branch;
  entry=reinterpret_cast<uintptr_t>(hook);SetLastError(0x98765432);invoke();check(GetLastError()==0x98765432);check(branch==expected_branch && abi_model[0x42]==local && abi_state[0xa6]==fallback);if(std::memcmp(regs,observed_regs,sizeof regs)){for(unsigned q=0;q<9;++q)std::fprintf(stderr,"reg%u %08x %08x\n",q,regs[q],observed_regs[q]);}check(!std::memcmp(regs,observed_regs,sizeof regs));if(std::memcmp(fx,observed_fx,sizeof fx)){for(unsigned q=0;q<512;++q)if(fx[q]!=observed_fx[q])std::fprintf(stderr,"fx%u %02x %02x\n",q,fx[q],observed_fx[q]);}check(!std::memcmp(fx,observed_fx,sizeof fx));++cases;
 }
 check(helper_calls==cases && continuation_calls==2*cases);std::printf("%u actual macro ABI cases passed: GPR/ESP/EFLAGS/DF/x87/all8XMM/LastError and native fallback unchanged\n",cases);
}
int main(){engine_tests();abi_tests();std::printf("PASS %u checks\n",checks);}
