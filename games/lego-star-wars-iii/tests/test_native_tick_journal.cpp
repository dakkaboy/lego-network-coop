#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <memory>
#include <cstring>
#include "../src/sync/native_tick_sync.h"
extern "C" {
#include "../src/net/lan.h"
void __cdecl reset_native_visibility_cache(unsigned char *);
}
__attribute__((used)) static unsigned char native_image[0x1200000];
static CoherentFrameToken bound;
static unsigned phase,faults;
static bool alive;
static long lan_state;
extern "C" long lan_status(void) { return lan_state; }
extern "C" int world_vars_cohort_valid(const CoherentFrameToken *token,uint32_t phases) {
 return alive && token && token->frame==bound.frame && token->epoch==bound.epoch &&
  token->sequence==bound.sequence && token->cohort_nonce==bound.cohort_nonce && (phases&COHERENT_PHASE_BIT(phase));
}
extern "C" void game_sync_native_fault(int code){assert(code==22);++faults;}
extern "C" uint32_t __cdecl native_tick_decision(uint32_t,uint32_t);
extern "C" void __cdecl native_flow_request(unsigned char *);
extern "C" uint32_t __cdecl native_perception_sweep(uint32_t);
extern "C" float __attribute__((thiscall)) native_track_clock(void *);
static volatile uint32_t getter_calls,getter_sample;
extern "C" volatile uint32_t clonewars_native_tick_failure[8],clonewars_native_tick_correction[6];
int main(){
 assert(reinterpret_cast<uintptr_t>(native_image)<0xfb0000 && reinterpret_cast<uintptr_t>(native_image)+sizeof(native_image)>0xfc0000);
 auto &clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);clock=100;
 auto frame=std::make_unique<SyncFrame>();frame->epoch=1;frame->sequence=1;
 bound={};bound.frame=frame.get();bound.epoch=1;bound.sequence=1;bound.cohort_nonce=7;alive=true;
 auto begin=[&](bool host){phase=COHERENT_PREPARE;assert(native_tick_begin(frame.get(),host,&bound));phase=COHERENT_DISPATCH;};
 begin(true);assert(native_tick_decision(0x888889,0)==0);assert(native_tick_decision(0x8888cd,1)==1);assert(native_tick_finish());
 assert(frame->tick_gate_count==2 && frame->tick_gates[0].site==0x888889);
 begin(false);SetLastError(123);assert(native_tick_decision(0x888889,1)==0 && GetLastError()==123);
 assert(native_tick_decision(0x8888cd,0)==1);assert(native_tick_finish()&&!faults);
 assert(clonewars_native_tick_correction[2]==0x888889 && clonewars_native_tick_correction[4]==1 && !clonewars_native_tick_correction[5]);
 begin(false);native_tick_decision(0x8888cd,0);assert(faults==1&&!native_tick_finish()&&clonewars_native_tick_failure[3]==2);
 ++frame->epoch;++bound.epoch;begin(false);++clock;native_tick_decision(0x888889,1);assert(faults==2&&!native_tick_finish());--clock;
 ++frame->epoch;++bound.epoch;begin(false);assert(!native_tick_finish()&&faults==3&&clonewars_native_tick_failure[3]==3);
 ++frame->epoch;++bound.epoch;begin(true);frame->tick_gate_count=SYNC_MAX_TICK_GATES;native_tick_decision(0x888889,1);assert(faults==4&&!native_tick_finish()&&clonewars_native_tick_failure[3]==1);
 begin(false);alive=false;assert(native_tick_decision(0x888889,1)==1&&faults==4);assert(!native_tick_finish());alive=true;
 native_tick_cancel(&bound);assert(native_tick_decision(0x888889,1)==1&&faults==4);
 unsigned char root[0x1c00]={};auto *flow=root+0x1b44;*reinterpret_cast<void **>(0xfb2e60)=root;
 auto &pending=*reinterpret_cast<uint32_t *>(flow+0x60);auto &current=*reinterpret_cast<uint32_t *>(flow+0x34);current=14;
 ++frame->epoch;++bound.epoch;begin(true);pending=11;native_flow_request(flow);assert(native_tick_finish()&&frame->tick_gate_count==1&&frame->tick_gates[0].site==0x889edc);
 begin(false);pending=UINT32_MAX;SetLastError(456);native_flow_request(flow);assert(pending==11&&current==14&&GetLastError()==456&&native_tick_finish());
 ++frame->epoch;++bound.epoch;begin(true);pending=UINT32_MAX;native_flow_request(flow);assert(native_tick_finish());
 begin(false);pending=11;native_flow_request(flow);assert(pending==UINT32_MAX&&current==14&&native_tick_finish());
 ++frame->epoch;++bound.epoch;begin(true);pending=11;native_flow_request(root);assert(!native_tick_finish()&&faults==5&&pending==11);
 native_tick_cancel(&bound);native_flow_request(nullptr);
 const uint32_t witness[]={0x12345678,0x87654321};
 auto next=[&](bool host){++frame->epoch;++bound.epoch;begin(host);};
 next(true);assert(native_tick_clock_input(witness,0x3c23d70a)==0x3c23d70a);
 assert(frame->tick_gate_count==3 && native_tick_stream_valid(frame->tick_gates,3) && native_tick_finish());
 begin(false);assert(native_tick_clock_input(witness,0x3ca40698)==0x3c23d70a && native_tick_finish());
 for(unsigned mutation=0;mutation<6;++mutation){
  next(true);native_tick_clock_input(witness,0x3c23d70a);assert(native_tick_finish());
  if(mutation==0)frame->tick_gates[0].value++;
  if(mutation==1)frame->tick_gates[1].value++;
  if(mutation==2)frame->tick_gates[2].value=0x7fc00000;
  if(mutation==3)frame->tick_gates[2].clock++;
  if(mutation==4)frame->tick_gate_count=2;
  if(mutation==5)frame->tick_gates[1].site=0x7b8b08;
  const auto old=faults;begin(false);assert(native_tick_clock_input(witness,0x3ca40698)==0x3ca40698);
  assert(faults==old+1 && !native_tick_finish());
 }
 for(uint32_t sample:{0u,0x80000000u,0xbf800000u,0x7f7fffffu,0xbf000000u,0xc0000000u})assert(native_track_time_valid(sample));
 for(uint32_t sample:{0x7f800000u,0xff800000u,0x7fc00000u})assert(!native_track_time_valid(sample));
 next(true);frame->tick_gate_count=SYNC_MAX_TICK_GATES-2;const auto full=faults;
 native_tick_clock_input(witness,0x3c23d70a);assert(faults==full+1 && frame->tick_gate_count==SYNC_MAX_TICK_GATES-2 && !native_tick_finish());
 unsigned char world[0x224]={},definition[0x96]={},manager[0x90]={},instance[0x14]={},request[0x18]={},provider[12]={},first[0xc0]={},second[0xc0]={},tracks[0x34]={},track[12]={},components[0x24]={},handle[4]={};
 auto put=[](void *p,unsigned offset,uintptr_t value){std::memcpy(static_cast<unsigned char *>(p)+offset,&value,4);};
 auto shortput=[](void *p,unsigned offset,int16_t value){std::memcpy(static_cast<unsigned char *>(p)+offset,&value,2);};
 frame->level=6;shortput(definition,0x94,6);put(world,0x220,reinterpret_cast<uintptr_t>(definition));
 *reinterpret_cast<void **>(0xfb4a20)=world;*reinterpret_cast<void **>(0xe901f4)=manager;*reinterpret_cast<void **>(0xfa1c98)=tracks;
 put(manager,0x28,reinterpret_cast<uintptr_t>(first));put(manager,0x30,2);put(first,4,reinterpret_cast<uintptr_t>(second));
 put(manager,0x84,reinterpret_cast<uintptr_t>(second));put(manager,0x88,reinterpret_cast<uintptr_t>(instance));
 put(instance,0xc,reinterpret_cast<uintptr_t>(request));put(request,8,reinterpret_cast<uintptr_t>(second));put(request,0x14,reinterpret_cast<uintptr_t>(provider));
 put(provider,0,reinterpret_cast<uintptr_t>(first));put(tracks,0x28,reinterpret_cast<uintptr_t>(track));
 put(first,0xa0,reinterpret_cast<uintptr_t>(components));put(second,0xa0,reinterpret_cast<uintptr_t>(components));
 put(components,0x20,reinterpret_cast<uintptr_t>(handle));put(track,4,reinterpret_cast<uintptr_t>(handle));
 put(first,8,reinterpret_cast<uintptr_t>("SceneA"));put(second,8,reinterpret_cast<uintptr_t>("SceneB"));
 for(auto *descriptor:{first,second}){put(descriptor,0xc,reinterpret_cast<uintptr_t>("Mission"));shortput(descriptor,0x10,6);}
 shortput(second,0x16,1);
 unsigned char stub[]={0xff,0x05,0,0,0,0,0xd9,0x05,0,0,0,0,0xc3};
 put(stub,2,reinterpret_cast<uintptr_t>(&getter_calls));put(stub,8,reinterpret_cast<uintptr_t>(&getter_sample));
 DWORD old;assert(VirtualProtect(reinterpret_cast<void *>(0x6c11d0),sizeof stub,PAGE_EXECUTE_READWRITE,&old));
 std::memcpy(reinterpret_cast<void *>(0x6c11d0),stub,sizeof stub);assert(FlushInstructionCache(GetCurrentProcess(),reinterpret_cast<void *>(0x6c11d0),sizeof stub));
 auto invoke=[&](uint32_t input){getter_sample=input;const auto calls=getter_calls;uint16_t before,after;uint32_t mx_before,mx_after;
  __asm__ volatile("fnstcw %0;stmxcsr %1":"=m"(before),"=m"(mx_before));SetLastError(789);
  volatile float value=native_track_clock(track);assert(GetLastError()==789 && getter_calls==calls+1);
  __asm__ volatile("fnstcw %0;stmxcsr %1":"=m"(after),"=m"(mx_after));assert(before==after && (mx_before&~63u)==(mx_after&~63u));
  uint32_t bits;std::memcpy(&bits,const_cast<const float *>(&value),4);return bits;};
 next(true);const auto initial_faults=faults;assert(invoke(0x3c23d70a)==0x3c23d70a && native_tick_finish() && faults==initial_faults);
 const auto a=frame->tick_gates[0].value,b=frame->tick_gates[1].value;
 begin(false);assert(invoke(0x3ca40698)==0x3c23d70a && native_tick_finish() && faults==initial_faults);
 put(provider,0,reinterpret_cast<uintptr_t>(second));begin(false);assert(invoke(0x3ca40698)==0x3ca40698 && !native_tick_finish() && faults==initial_faults+1);
 put(provider,0,reinterpret_cast<uintptr_t>(first));
 next(true);put(track,4,0);const auto wrong_track=faults;invoke(0x3c23d70a);assert(faults==wrong_track+1 && !native_tick_finish());put(track,4,reinterpret_cast<uintptr_t>(handle));
 next(true);put(first,4,reinterpret_cast<uintptr_t>(first));const auto cyclic=faults;invoke(0x3c23d70a);assert(faults==cyclic+1 && !native_tick_finish());put(first,4,reinterpret_cast<uintptr_t>(second));
 next(true);shortput(definition,0x94,7);const auto wrong_world=faults;invoke(0x3c23d70a);assert(faults==wrong_world+1 && !native_tick_finish());shortput(definition,0x94,6);
 next(true);assert(invoke(0xbf800000u)==0xbf800000u && native_tick_finish());
 assert(frame->tick_gates[0].value==a && frame->tick_gates[1].value==b);
 *reinterpret_cast<float *>(0xad76dc)=-1.f;
 next(true);assert(invoke(0x42308f61u)==0x42308f61u && native_tick_finish());
 put(tracks,0x28,0);
 begin(false);const auto before_missing=getter_calls;SetLastError(789);
 assert(native_track_clock(nullptr)>44.f && GetLastError()==789 && getter_calls==before_missing && native_tick_finish());
 next(true);assert(native_track_clock(nullptr)==-1.f && native_tick_finish());
 put(tracks,0x28,reinterpret_cast<uintptr_t>(track));
 begin(false);assert(invoke(0x42308f61u)==0xbf800000u && native_tick_finish());
 const auto wrong_lookup=faults;
 begin(false);assert(native_track_clock(nullptr)==-1.f && !native_tick_finish() && faults==wrong_lookup+1);
 native_tick_cancel(&bound);const auto offline_faults=faults;assert(invoke(0x3ca40698)==0x3ca40698 && faults==offline_faults);
 auto &sweep_cursor=*reinterpret_cast<uint32_t *>(0xfbea24);
 next(true);sweep_cursor=17;assert(!native_perception_sweep(0) && native_tick_finish());
 assert(frame->tick_gate_count==1 && frame->tick_gates[0].site==0x9dda14 && frame->tick_gates[0].value==34);
 begin(false);sweep_cursor=0;SetLastError(456);
 assert(!native_perception_sweep(1) && sweep_cursor==17 && GetLastError()==456 && native_tick_finish());
 next(true);assert(native_perception_sweep(1) && native_tick_finish());
 begin(false);sweep_cursor=11;assert(native_perception_sweep(0) && sweep_cursor==11 && native_tick_finish());
 next(true);sweep_cursor=SYNC_MAX_ACTORS+1;const auto invalid_cursor=faults;
 assert(!native_perception_sweep(0) && !native_tick_finish() && faults==invalid_cursor+1);
 native_tick_cancel(&bound);assert(native_perception_sweep(1) && sweep_cursor==SYNC_MAX_ACTORS+1);
 unsigned char actor_manager[0x220];std::memset(actor_manager,0x5a,sizeof actor_manager);
 put(actor_manager,0,0xc4f730);put(actor_manager,8,reinterpret_cast<uintptr_t>(handle));
 put(reinterpret_cast<void *>(0xfb2f60),0,reinterpret_cast<uintptr_t>(handle));
 const unsigned char actor_reset[]={0xff,0x05,0,0,0,0,0xc3};
 unsigned char reset_stub[sizeof actor_reset];std::memcpy(reset_stub,actor_reset,sizeof actor_reset);
 uint32_t resets=0;put(reset_stub,2,reinterpret_cast<uintptr_t>(&resets));
 auto *native_reset=reinterpret_cast<void *>(0x8a6560);
 assert(VirtualProtect(native_reset,sizeof reset_stub,PAGE_EXECUTE_READWRITE,&old));
 std::memcpy(native_reset,reset_stub,sizeof reset_stub);
 assert(FlushInstructionCache(GetCurrentProcess(),native_reset,sizeof reset_stub));
 reset_native_visibility_cache(actor_manager);
 assert(resets==1 && actor_manager[0x10]==0x5a && actor_manager[0x214]==0x5a);
 lan_state=LAN_CONNECTED;SetLastError(321);
 reset_native_visibility_cache(actor_manager);
 assert(resets==2 && GetLastError()==321);
 for(unsigned i=0x10;i<0x218;++i) assert(actor_manager[i]==0);
 assert(actor_manager[0xf]==0x5a && actor_manager[0x218]==0x5a);
 puts("Native world journal host/client correction, order, clock, count, retired lease and LastError checks passed.");
}
