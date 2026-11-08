#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cfloat>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include "../src/engine/spellit_query_thunk.h"

extern "C" {
__attribute__((aligned(16),used)) static unsigned char caller_fx[512],observed_fx[512];
__attribute__((used)) static unsigned char actor[0x40],model[0x48],manager[0x30];
__attribute__((used)) static uintptr_t entry,test_eax,test_esi;
__attribute__((used)) static uint32_t observed_regs[9],mxcsr_value=0x3f80,helper_mxcsr=0x5f80;
__attribute__((used)) static float initial_limit,observed_limit,candidate[3],output[3],distance_value;
__attribute__((used)) static uint32_t observed_height_store,distance_calls;
__attribute__((used)) static uintptr_t native_candidate,native_caster,native_output;
__attribute__((used)) static float native_caster_values[3];
__attribute__((used)) static double live_fpu[2]={1.25,-2.5};
static bool project;
static uint32_t expected_local,canonical_operand,expected_kind;
static float canonical_limit,canonical_position[3];
static unsigned prepare_calls,operand_calls,position_calls;
static unsigned node_calls;
__attribute__((used)) static uint32_t node_stack[36],observed_node_stack[36];
static float node_local[3],node_canonical[3];
static constexpr uintptr_t query_frame=0x55555555;

static uint32_t bits(float value){uint32_t result;std::memcpy(&result,&value,4);return result;}
static float from_bits(uint32_t value){float result;std::memcpy(&result,&value,4);return result;}

static void check_helper_environment(){
 uint32_t flags,mxcsr;unsigned short control,status;
 __asm__ volatile("pushfl\n\tpopl %0\n\tstmxcsr %1\n\tfnstcw %2\n\tfnstsw %3"
                  :"=r"(flags),"=m"(mxcsr),"=m"(control),"=m"(status));
 assert(!(flags&0x400) && mxcsr==0x1f80 && control==0x37f && !(status&0x3800));
}
__attribute__((noinline)) static void clobber_helper_fx(){
 __asm__ volatile(
  "fninit\n\tfldz\n\tfld1\n\tldmxcsr _helper_mxcsr\n\t"
  "pcmpeqd %%xmm0,%%xmm0\n\tpcmpeqd %%xmm1,%%xmm1\n\tpcmpeqd %%xmm2,%%xmm2\n\t"
  "pcmpeqd %%xmm3,%%xmm3\n\tpcmpeqd %%xmm4,%%xmm4\n\tpcmpeqd %%xmm5,%%xmm5\n\t"
  "pcmpeqd %%xmm6,%%xmm6\n\tpcmpeqd %%xmm7,%%xmm7\n\t"
  "movl $0x12345678,%%eax\n\tmovl $0x87654321,%%ecx\n\tmovl $0xabcdef01,%%edx\n\tstc"
  :::"eax","ecx","edx","cc","memory");
}

// These helpers model only the bridge contract; production scope/journal validation is tested separately.
void __cdecl cadence_spellit_prepare(void *source,void *owner,uintptr_t frame,float *limit){
 const DWORD error=GetLastError();check_helper_environment();
 assert(source==actor && owner==manager && frame==query_frame && bits(*limit)==bits(initial_limit));
 ++prepare_calls;if(project)*limit=canonical_limit;
 clobber_helper_fx();SetLastError(error);
}
uint32_t __cdecl cadence_spellit_operand(uintptr_t frame,uint32_t kind,uint32_t local){
 const DWORD error=GetLastError();check_helper_environment();
 assert(frame==query_frame && kind==expected_kind && local==expected_local);++operand_calls;
 const uint32_t result=project?canonical_operand:local;
 clobber_helper_fx();SetLastError(error);return result;
}
void __cdecl cadence_spellit_position(uintptr_t frame,float *point){
 const DWORD error=GetLastError();check_helper_environment();
 assert(frame==query_frame && point!=reinterpret_cast<float *>(actor+0x24));
 assert(!std::memcmp(point,actor+0x24,12));++position_calls;
 if(project)std::memcpy(point,canonical_position,12);
 clobber_helper_fx();SetLastError(error);
}
void __cdecl cadence_spellit_node(uintptr_t frame,void *gizmo,void *node,float *point){
 const DWORD error=GetLastError();check_helper_environment();
 assert(frame==query_frame && gizmo==manager && node==reinterpret_cast<void *>(0x77777777));
 assert(!std::memcmp(point,node_local,12));++node_calls;
 if(project)std::memcpy(point,node_canonical,12);
 clobber_helper_fx();SetLastError(error);
}

__attribute__((naked)) static void prepare_cont(){__asm__ volatile("ret");}
__attribute__((naked)) static void first_heading_cont(){__asm__ volatile("ret");}
__attribute__((naked)) static void second_heading_cont(){__asm__ volatile("ret");}
__attribute__((naked)) static void height_cont(){__asm__ volatile("ret");}
__attribute__((used)) static uintptr_t spellit_prepare_resume=reinterpret_cast<uintptr_t>(prepare_cont);
__attribute__((used)) static uintptr_t spellit_first_heading_resume=reinterpret_cast<uintptr_t>(first_heading_cont);
__attribute__((used)) static uintptr_t spellit_second_heading_resume=reinterpret_cast<uintptr_t>(second_heading_cont);
__attribute__((used)) static uintptr_t spellit_height_resume=reinterpret_cast<uintptr_t>(height_cont);
__attribute__((naked)) static void prepare_hook(){__asm__ volatile(SPELLIT_PREPARE_THUNK_ASM);}
__attribute__((naked)) static void first_heading_hook(){__asm__ volatile(SPELLIT_HEADING_THUNK_ASM("%eax",spellit_first_heading_resume));}
__attribute__((naked)) static void second_heading_hook(){__asm__ volatile(SPELLIT_HEADING_THUNK_ASM("%esi",spellit_second_heading_resume));}
__attribute__((naked)) static void height_hook(){__asm__ volatile(SPELLIT_HEIGHT_THUNK_ASM);}
__attribute__((naked)) static void original_prepare(){__asm__ volatile("movl 8(%esi),%eax\n\ttestl %eax,%eax\n\tjmp *_spellit_prepare_resume");}
__attribute__((naked)) static void original_first_heading(){__asm__ volatile("movzwl 0x40(%eax),%eax\n\tjmp *_spellit_first_heading_resume");}
__attribute__((naked)) static void original_second_heading(){__asm__ volatile("movzwl 0x40(%esi),%eax\n\tjmp *_spellit_second_heading_resume");}
__attribute__((naked)) static void original_height(){__asm__ volatile("flds 0x28(%eax)\n\tmovl %ecx,0x2c(%esp)\n\tjmp *_spellit_height_resume");}
__attribute__((used)) static uintptr_t spellit_node_resume=reinterpret_cast<uintptr_t>(prepare_cont);
__attribute__((naked)) static void node_hook(){__asm__ volatile(SPELLIT_NODE_THUNK_ASM);}
__attribute__((naked)) static void original_node(){__asm__ volatile("movl 0x70(%esp),%eax\n\tmovl 0x74(%esp),%ecx\n\tjmp *_spellit_node_resume");}

#define INIT_NATIVE_FX_ASM \
 "fninit\n\tfldz\n\tfldz\n\tfldz\n\tfldz\n\tfldz\n\tfldz\n\tfldz\n\tfldz\n\t" \
 "fninit\n\tfldl _live_fpu\n\tfldl _live_fpu+8\n\tldmxcsr _mxcsr_value\n\t" \
 "pxor %xmm0,%xmm0\n\tpxor %xmm1,%xmm1\n\tpxor %xmm2,%xmm2\n\tpxor %xmm3,%xmm3\n\t" \
 "pxor %xmm4,%xmm4\n\tpxor %xmm5,%xmm5\n\tpxor %xmm6,%xmm6\n\tpxor %xmm7,%xmm7\n\t" \
 "pcmpeqd %xmm7,%xmm7\n\tpslld $7,%xmm7\n\t"
#define CAPTURE_NATIVE_ASM \
 "pushfl\n\tpushal\n\tmovl %esp,%esi\n\tmovl $_observed_regs,%edi\n\tmovl $9,%ecx\n\tcld\n\trep movsl\n\tfxsave _observed_fx\n\t"
__attribute__((naked)) static void invoke_node(){
 __asm__ volatile(
  "pushfl\n\tpushal\n\tfxsave _caller_fx\n\tsubl $0x90,%esp\n\t"
  "movl $_node_stack,%esi\n\tmovl %esp,%edi\n\tmovl $36,%ecx\n\tcld\n\trep movsl\n\t" INIT_NATIVE_FX_ASM
  "pushl $0x646\n\tpopfl\n\tmovl $0x11111111,%eax\n\tmovl $0x22222222,%ecx\n\t"
  "movl $0x33333333,%edx\n\tmovl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\t"
  "movl $_manager,%esi\n\tmovl $0x77777777,%edi\n\tcall *_entry\n\t" CAPTURE_NATIVE_ASM
  "leal 36(%esp),%esi\n\tmovl $_observed_node_stack,%edi\n\tmovl $36,%ecx\n\trep movsl\n\t"
  "leal 180(%esp),%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}
__attribute__((naked)) static void invoke_operand(){
 __asm__ volatile(
  "pushfl\n\tpushal\n\tfxsave _caller_fx\n\t" INIT_NATIVE_FX_ASM
  "subl $0x60,%esp\n\tmovl _initial_limit,%eax\n\tmovl %eax,0xc(%esp)\n\t"
  "movl $0xcafebabe,0x28(%esp)\n\tpushl $0x646\n\tpopfl\n\t"
  "movl _test_eax,%eax\n\tmovl $0x22222222,%ecx\n\tmovl $0x33333333,%edx\n\t"
  "movl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\tmovl _test_esi,%esi\n\tmovl $_manager,%edi\n\t"
  "call *_entry\n\t" CAPTURE_NATIVE_ASM
  "movl 48(%esp),%eax\n\tmovl %eax,_observed_limit\n\tmovl 76(%esp),%eax\n\tmovl %eax,_observed_height_store\n\t"
  "leal 0x84(%esp),%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}

__attribute__((naked)) static void native_distance(){
 __asm__ volatile(
  "incl _distance_calls\n\tmovl 4(%esp),%eax\n\tmovl %eax,_native_candidate\n\t"
  "movl 8(%esp),%eax\n\tmovl %eax,_native_caster\n\tmovl 12(%esp),%edx\n\tmovl %edx,_native_output\n\t"
  "movl (%eax),%edx\n\tmovl %edx,_native_caster_values\n\tmovl 4(%eax),%edx\n\tmovl %edx,_native_caster_values+4\n\t"
  "movl 8(%eax),%edx\n\tmovl %edx,_native_caster_values+8\n\t"
  "movl 12(%esp),%eax\n\tsubl $12,%esp\n\tmovl 16(%esp),%ecx\n\tmovl 20(%esp),%edx\n\t"
  "flds (%ecx)\n\tfsubs (%edx)\n\tfstps (%eax)\n\tfldz\n\tfstps 4(%eax)\n\t"
  "flds 8(%ecx)\n\tfsubs 8(%edx)\n\tfstps 24(%esp)\n\tflds 24(%esp)\n\tfsts 8(%eax)\n\t"
  "flds (%eax)\n\tfmul %st,%st\n\tfldz\n\tfmul %st,%st\n\tfaddp %st,%st(1)\n\t"
  "fld %st(1)\n\tfmulp %st,%st(2)\n\tfaddp %st,%st(1)\n\tfstps 24(%esp)\n\tflds 24(%esp)\n\taddl $12,%esp\n\tret");
}
__attribute__((used)) static uintptr_t spellit_distance_native=reinterpret_cast<uintptr_t>(native_distance);
__attribute__((naked)) static void position_hook(){__asm__ volatile(SPELLIT_POSITION_THUNK_ASM);}
__attribute__((naked)) static void invoke_distance(){
 __asm__ volatile(
  "pushfl\n\tpushal\n\tfxsave _caller_fx\n\t" INIT_NATIVE_FX_ASM
  "pushl $0x646\n\tpopfl\n\tmovl $0x44444444,%ebx\n\tmovl $0x55555555,%ebp\n\t"
  "movl $0x66666666,%esi\n\tmovl $0x77777777,%edi\n\t"
  "pushl $_output\n\tpushl $_actor+0x24\n\tpushl $_candidate\n\tcall *_entry\n\t"
  "fstps _distance_value\n\tleal 12(%esp),%esp\n\t" CAPTURE_NATIVE_ASM
  "leal 36(%esp),%esp\n\tfxrstor _caller_fx\n\tpopal\n\tpopfl\n\tret");
}
}

struct Observation{uint32_t regs[9];unsigned char fx[512];float limit;uint32_t height_store;};
static Observation observation(){
 Observation result;std::memcpy(result.regs,observed_regs,sizeof result.regs);
 std::memcpy(result.fx,observed_fx,sizeof result.fx);result.limit=observed_limit;result.height_store=observed_height_store;return result;
}
static void same_fx(const unsigned char *a,const unsigned char *b){
 assert(!std::memcmp(a,b,5));
 assert(!std::memcmp(a+24,b+24,8));
 for(unsigned i=0;i<8;++i)assert(!std::memcmp(a+32+16*i,b+32+16*i,10));
 assert(!std::memcmp(a+160,b+160,128));
}
static void same_operand_result(const Observation &expected){
 assert(!std::memcmp(expected.regs,observed_regs,sizeof observed_regs));same_fx(expected.fx,observed_fx);
 assert(bits(expected.limit)==bits(observed_limit) && expected.height_store==observed_height_store);
 assert(observed_regs[8]&0x400);
}
static void put_heading(uint16_t value){std::memcpy(model+0x40,&value,2);}
static void put_y(uint32_t value){std::memcpy(actor+0x28,&value,4);}

int main(){
 const float limits[]={-FLT_MAX,-1.0f,-FLT_MIN,-0.0f,0.0f,FLT_MIN,.5f,1.0f,FLT_MAX};
 const uint16_t headings[]={0,1,0x3fff,0x4000,0x7fff,0x8000,0xffff};
 const float heights[]={-FLT_MAX,-1.0f,-FLT_MIN,-0.0f,0.0f,FLT_MIN,1.0f,FLT_MAX};
 model[0x42]=0xa5;model[0x43]=0x5a;
 for(unsigned i=0;i<6000;++i){
  project=(i&1)!=0;canonical_limit=limits[(i+3)%9];
  const float local_limit=limits[i%9];
  uintptr_t model_pointer=(i%3)?reinterpret_cast<uintptr_t>(model):0;
  std::memcpy(actor+8,&model_pointer,4);test_esi=reinterpret_cast<uintptr_t>(actor);test_eax=0x11111111;
  initial_limit=project?canonical_limit:local_limit;entry=reinterpret_cast<uintptr_t>(original_prepare);invoke_operand();
  Observation expected=observation();initial_limit=local_limit;
  unsigned char actor_before[sizeof actor],model_before[sizeof model];
  std::memcpy(actor_before,actor,sizeof actor);std::memcpy(model_before,model,sizeof model);
  entry=reinterpret_cast<uintptr_t>(prepare_hook);SetLastError(123);invoke_operand();
  assert(GetLastError()==123);same_operand_result(expected);
  assert(observed_regs[7]==model_pointer && bool(observed_regs[8]&0x40)==!model_pointer);
  assert(!std::memcmp(actor_before,actor,sizeof actor) && !std::memcmp(model_before,model,sizeof model));

  expected_kind=0;expected_local=headings[i%7];canonical_operand=headings[(i+2)%7];
  for(unsigned second=0;second<2;++second){
   test_eax=second?0x11111111:reinterpret_cast<uintptr_t>(model);
   test_esi=second?reinterpret_cast<uintptr_t>(model):0x66666666;
   put_heading(static_cast<uint16_t>(project?canonical_operand:expected_local));
   entry=second?reinterpret_cast<uintptr_t>(original_second_heading):reinterpret_cast<uintptr_t>(original_first_heading);
   invoke_operand();expected=observation();put_heading(static_cast<uint16_t>(expected_local));
   std::memcpy(model_before,model,sizeof model);
   entry=second?reinterpret_cast<uintptr_t>(second_heading_hook):reinterpret_cast<uintptr_t>(first_heading_hook);
   SetLastError(123);invoke_operand();assert(GetLastError()==123);same_operand_result(expected);
   assert(observed_regs[7]==(project?canonical_operand:expected_local));
   assert(!std::memcmp(model_before,model,sizeof model));
  }

  expected_kind=1;expected_local=bits(heights[i%8]);canonical_operand=bits(heights[(i+3)%8]);
  test_eax=reinterpret_cast<uintptr_t>(actor);test_esi=0x66666666;
  put_y(project?canonical_operand:expected_local);entry=reinterpret_cast<uintptr_t>(original_height);invoke_operand();expected=observation();
  put_y(expected_local);std::memcpy(actor_before,actor,sizeof actor);
  entry=reinterpret_cast<uintptr_t>(height_hook);SetLastError(123);invoke_operand();
  assert(GetLastError()==123);same_operand_result(expected);assert(observed_height_store==0x22222222);
  assert(!std::memcmp(actor_before,actor,sizeof actor));

  float local_position[3];
  for(unsigned j=0;j<3;++j){
   local_position[j]=static_cast<float>(static_cast<int>((i*31+j*97)%173)-86)/37.0f;
   canonical_position[j]=local_position[j]+static_cast<float>(j+1)*.03125f;
   candidate[j]=static_cast<float>(static_cast<int>((i*43+j*59)%191)-95)/19.0f;
  }
  std::memcpy(actor+0x24,project?canonical_position:local_position,12);
  entry=reinterpret_cast<uintptr_t>(native_distance);const unsigned before=distance_calls;invoke_distance();
  expected=observation();const float expected_distance=distance_value;float expected_output[3];std::memcpy(expected_output,output,12);
  std::memcpy(actor+0x24,local_position,12);std::memcpy(actor_before,actor,sizeof actor);std::memcpy(model_before,model,sizeof model);
  float candidate_before[3];std::memcpy(candidate_before,candidate,12);
  entry=reinterpret_cast<uintptr_t>(position_hook);SetLastError(123);invoke_distance();
  assert(GetLastError()==123 && distance_calls==before+2 && bits(distance_value)==bits(expected_distance));
  assert(!std::memcmp(expected_output,output,12) && bits(output[1])==0);
  const float *used_position=project?canonical_position:local_position;
  const float dx=candidate[0]-used_position[0],dz=candidate[2]-used_position[2];
  const float squared=static_cast<float>(static_cast<double>(dx)*dx+static_cast<double>(dz)*dz);
  assert(bits(output[0])==bits(dx) && bits(output[2])==bits(dz) && bits(distance_value)==bits(squared));
  assert(native_candidate==reinterpret_cast<uintptr_t>(candidate) && native_output==reinterpret_cast<uintptr_t>(output));
  assert(native_caster!=reinterpret_cast<uintptr_t>(actor+0x24));
  assert(!std::memcmp(native_caster_values,project?canonical_position:local_position,12));
  assert(observed_regs[0]==0x77777777 && observed_regs[1]==0x66666666 && observed_regs[2]==query_frame && observed_regs[4]==0x44444444);
  assert(observed_regs[3]==expected.regs[3] && (observed_regs[8]&0x400));same_fx(expected.fx,observed_fx);
  assert(!std::memcmp(actor_before,actor,sizeof actor) && !std::memcmp(model_before,model,sizeof model) && !std::memcmp(candidate_before,candidate,12));

  for(unsigned j=0;j<36;++j)node_stack[j]=i*311u+j*57u;
  for(unsigned j=0;j<3;++j){node_local[j]=heights[(i+j)%8];node_canonical[j]=heights[(i+j+3)%8];}
  std::memcpy(node_stack+27,project?node_canonical:node_local,12);
  entry=reinterpret_cast<uintptr_t>(original_node);invoke_node();expected=observation();
  uint32_t expected_stack[36];std::memcpy(expected_stack,observed_node_stack,sizeof expected_stack);
  std::memcpy(node_stack+27,node_local,12);entry=reinterpret_cast<uintptr_t>(node_hook);
  SetLastError(123);invoke_node();assert(GetLastError()==123);same_operand_result(expected);
  assert(!std::memcmp(expected_stack,observed_node_stack,sizeof expected_stack));
  assert(!std::memcmp(node_stack+27,node_local,12));
 }
 assert(prepare_calls==6000 && operand_calls==18000 && position_calls==6000 && distance_calls==12000 && node_calls==6000);
 puts("36000 SpellIt ASM hook cases passed: canonical operands, native distance once, query-local node translation, ABI and live FX state preserved (mock helper contracts).");
}
