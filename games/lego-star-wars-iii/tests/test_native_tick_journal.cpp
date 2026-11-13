#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <memory>
#include <cstring>
#include "../src/sync/native_tick_sync.h"
#include "../src/engine/native_global_pack_source.h"
extern "C" {
#include "../src/net/lan.h"
#include "../src/sync/entity_sync.h"
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
extern "C" void __cdecl native_rts_registry_rng(void *);
extern "C" void __cdecl native_rts_producer_rng(void *);
extern "C" uint32_t __cdecl native_rts_pack_admission(const void *,int32_t,int32_t,uint32_t);
extern "C" uint32_t __cdecl native_rts_turret_heading(const void *,uint32_t);
extern "C" void __cdecl native_rts_turret_aim(void *);
extern "C" uint32_t __cdecl native_fire_visibility(const void *,uint32_t);
extern "C" void __cdecl native_weapon_commands(unsigned char *);
extern "C" void __cdecl native_gizmo_turret_input(unsigned char *);
extern "C" void native_weapon_commands_input(void);
__attribute__((naked)) static uint32_t invoke_weapon_commands(unsigned char *) {
 __asm__ volatile("pushl %ebx\n\tmovl 8(%esp),%ebx\n\t"
  "movl $0xcafebabe,%eax\n\tmovl $0x12345678,%ecx\n\tmovl $0x87654321,%edx\n\t"
  "call _native_weapon_commands_input\n\tpushfl\n\t"
  "cmpl $0xcafebabe,%eax\n\tjne 1f\n\tcmpl $0x12345678,%ecx\n\tjne 1f\n\t"
  "cmpl $0x87654321,%edx\n\tjne 1f\n\tpopl %eax\n\tpopl %ebx\n\tret\n\t"
  "1: addl $4,%esp\n\tpopl %ebx\n\tmovl $-1,%eax\n\tret");
}
extern "C" void native_gizmo_turret_bridge(void);
__attribute__((naked)) static uint32_t invoke_gizmo_turret(unsigned char *) {
 __asm__ volatile("pushl %ebx\n\tmovl 8(%esp),%ebx\n\tmovl $0x12345678,%ecx\n\tmovl $0x87654321,%edx\n\t"
  "cmpl %ecx,%ecx\n\tstc\n\tcall _native_gizmo_turret_bridge\n\tpushfl\n\t"
  "cmpl $0x1234,%eax\n\tjne 1f\n\tcmpl $0x12345678,%ecx\n\tjne 1f\n\tcmpl $0x87654321,%edx\n\tjne 1f\n\t"
  "popl %eax\n\tpopl %ebx\n\tret\n\t1: addl $4,%esp\n\tpopl %ebx\n\tmovl $-1,%eax\n\tret");
}
extern "C" uint32_t __attribute__((thiscall)) native_fire_visibility_input(const void *);
extern "C" uint32_t __cdecl native_pack_attack(const unsigned char *,uint32_t);
extern "C" void __cdecl native_pack_attack_seed(const unsigned char *);
extern "C" void __cdecl native_pack_hit_seed(const unsigned char *,uint32_t);
extern "C" void __cdecl native_pack_rearm_seed(const unsigned char *);
extern "C" uint32_t __cdecl native_pack_formation(const unsigned char *,uint32_t);
extern "C" void __cdecl native_pack_mode(unsigned char *,unsigned char *);
extern "C" void __cdecl native_pack_animation(unsigned char *,uint32_t *);
extern "C" void __cdecl native_pack_move_timer_seed(const unsigned char *);
extern "C" void __cdecl native_pack_move_heading_seed(const unsigned char *);
extern "C" void __cdecl native_pack_move_choice_seed(const unsigned char *);
extern "C" void __cdecl native_pack_pose(unsigned char *,uint32_t);
extern "C" uint32_t __cdecl native_pack_cell_admission(const unsigned char *,uint32_t);
extern "C" uint32_t __cdecl native_perception_sweep(uint32_t);
extern "C" float __attribute__((thiscall)) native_track_clock(void *);
static volatile uint32_t getter_calls,getter_sample;
static const void *turret_pilot;
static uint32_t turret_pilot_generation=17;
extern "C" int entities_slot(const void *actor) { return actor==turret_pilot ? 12 : -1; }
extern "C" uint32_t entities_generation(const void *actor) { return actor==turret_pilot ? turret_pilot_generation : 0; }
extern "C" int entities_bind_native_actor(const SyncFrame *,const void *) {return 0;}
extern "C" volatile uint32_t clonewars_native_tick_failure[16],clonewars_native_tick_correction[6];
extern "C" uint32_t game_sync_preload_flow_input(void *,uint32_t request) { return request; }
extern "C" int game_sync_preload_level(void) { return -1; }
extern "C" uint32_t game_sync_preload_track_input(const uint32_t *,uint32_t time) { return time; }
static uint32_t word(const unsigned char *p,unsigned offset){uint32_t value;std::memcpy(&value,p+offset,4);return value;}
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
 unsigned char registry[4]{},battlefield[0x10d4]{},resource[0x10]{};
 put(registry,0,reinterpret_cast<uintptr_t>(battlefield));
 put(battlefield,0,0xaef0fc);
 put(battlefield,0xbc,reinterpret_cast<uintptr_t>(registry));
 put(battlefield,0x10d0,reinterpret_cast<uintptr_t>(resource));
 put(resource,0xc,*reinterpret_cast<uintptr_t *>(0xfb4a20));
 auto &game_rng=*reinterpret_cast<uint32_t *>(0xe637b4);
 auto &engine_rng=*reinterpret_cast<uint32_t *>(0xea178c);
 next(true);game_rng=0xabcd;engine_rng=0x91234567;
 native_rts_registry_rng(registry);
 assert(native_tick_finish() && frame->tick_gate_count==2 && native_tick_stream_valid(frame->tick_gates,2));
 assert(!native_tick_stream_valid(frame->tick_gates,1) && !native_tick_stream_valid(frame->tick_gates+1,1));
 begin(false);game_rng=1;engine_rng=2;SetLastError(654);
 native_rts_registry_rng(registry);
 assert(GetLastError()==654 && game_rng==0xabcd && engine_rng==0x91234567 && native_tick_finish());
 begin(false);game_rng=1;engine_rng=2;put(battlefield,0xbc,0);
 const auto wrong_rts=faults;
 native_rts_registry_rng(registry);
 assert(!native_tick_finish() && faults==wrong_rts+1 && game_rng==1 && engine_rng==2);
 put(battlefield,0xbc,reinterpret_cast<uintptr_t>(registry));
 next(true);game_rng=3;engine_rng=4;native_rts_producer_rng(battlefield);
 game_rng=5;engine_rng=6;native_rts_registry_rng(registry);
 assert(native_tick_finish() && native_tick_stream_valid(frame->tick_gates,4));
 begin(false);game_rng=1;engine_rng=2;native_rts_producer_rng(battlefield);
 assert(game_rng==3 && engine_rng==4);
 native_rts_registry_rng(registry);
 assert(game_rng==5 && engine_rng==6 && native_tick_finish());
 unsigned char producer[0x258]{};
 put(producer,0x28,reinterpret_cast<uintptr_t>(battlefield));put(producer,0x250,3);put(producer,0x254,1);
 next(true);assert(native_rts_pack_admission(producer,0,1,0) && native_tick_finish());
 assert(frame->tick_gate_count==1 && frame->tick_gates[0].value==23 && native_tick_stream_valid(frame->tick_gates,1));
 begin(false);assert(native_rts_pack_admission(producer,1,1,0) && native_tick_finish());
 next(true);assert(!native_rts_pack_admission(producer,0,1,1) && native_tick_finish());
 begin(false);assert(!native_rts_pack_admission(producer,0,1,0) && native_tick_finish());
 begin(false);put(producer,0x250,4);const auto wrong_producer=faults;
 assert(native_rts_pack_admission(producer,0,1,0) && !native_tick_finish() && faults==wrong_producer+1);
 unsigned char turret[0x900]{},pilot[0x10]{};
 turret_pilot=&pilot;
 next(true);assert(native_fire_visibility(turret_pilot,0xabcd0000)==0xabcd0000 && native_tick_finish());
 assert(frame->tick_gate_count==2 && native_tick_stream_valid(frame->tick_gates,2));
 assert(!native_tick_stream_valid(frame->tick_gates,1) && !native_tick_stream_valid(frame->tick_gates+1,1));
 begin(false);SetLastError(543);
 assert(native_fire_visibility(turret_pilot,0x12340001)==0x12340000 && GetLastError()==543 && native_tick_finish());
 ++turret_pilot_generation;begin(false);const auto stale_visibility=faults;
 assert(native_fire_visibility(turret_pilot,1)==1 && !native_tick_finish() && faults==stale_visibility+1);
 unsigned char visibility_model[0x44]{};
 put(&pilot,8,reinterpret_cast<uintptr_t>(visibility_model));
 auto visibility_query=native_fire_visibility_input;
 visibility_model[0x42]=5;
 next(true);const auto visible=visibility_query(&pilot);
 assert((visible&255)==5 && native_tick_finish());
 visibility_model[0x42]=0;
 begin(false);assert((visibility_query(&pilot)&255)==5 && visibility_model[0x42]==0 && native_tick_finish());
 native_tick_cancel(&bound);assert((visibility_query(&pilot)&255)==0);
 put(turret,0x2fc,reinterpret_cast<uintptr_t>(turret_pilot));
 auto *party=reinterpret_cast<void *>(0xfb4940);
 put(party,4,reinterpret_cast<uintptr_t>(turret_pilot));
 auto &turret_aim=*reinterpret_cast<uint16_t *>(turret+0x87e);
 next(true);turret_aim=0xd001;native_rts_turret_aim(turret);
 assert(turret_aim==0xd001 && native_tick_finish() && native_tick_stream_valid(frame->tick_gates,2));
 begin(false);turret_aim=0xcbdb;SetLastError(456);
 native_rts_turret_aim(turret);
 assert(turret_aim==0xd001 && GetLastError()==456 && native_tick_finish());
 begin(false);const auto wrong_heading_site=faults;
 native_rts_turret_heading(turret,0xcbdb);
 assert(!native_tick_finish() && faults==wrong_heading_site+1);
 next(true);assert(native_rts_turret_heading(turret,0x1234d001)==0x1234d001 && native_tick_finish());
 assert(frame->tick_gate_count==2 && native_tick_stream_valid(frame->tick_gates,2));
 assert(!native_tick_stream_valid(frame->tick_gates,1) && !native_tick_stream_valid(frame->tick_gates+1,1));
 begin(false);SetLastError(567);
 assert(native_rts_turret_heading(turret,0x5678cbdb)==0x5678d001 && GetLastError()==567 && native_tick_finish());
 ++turret_pilot_generation;
 begin(false);const auto stale_pilot=faults;
 assert(native_rts_turret_heading(turret,0xcbdb)==0xcbdb && !native_tick_finish() && faults==stale_pilot+1);
 put(party,4,0);
 next(true);assert(native_rts_turret_heading(turret,0xcbdb)==0xcbdb && native_tick_finish() && frame->tick_gate_count==0);
 unsigned char manager_list[4]{},krawly_manager[0x200]{},pack[0x148]{},pack_definition[0x34]{};
 unsigned char first_member[0xa0]{},second_member[0xa0]{};
 put(krawly_manager,0,0xaded84);
 put(krawly_manager,0x10c,reinterpret_cast<uintptr_t>(manager_list));
 put(manager_list,0,reinterpret_cast<uintptr_t>(pack));
 put(pack,0,0xadcef0);
 put(pack,0xb8,reinterpret_cast<uintptr_t>(krawly_manager));
 put(pack,0xb4,reinterpret_cast<uintptr_t>(pack_definition));
 put(pack,0xa0,reinterpret_cast<uintptr_t>(first_member));
 put(first_member,0x7c,reinterpret_cast<uintptr_t>(second_member));
 put(first_member,0x68,reinterpret_cast<uintptr_t>(pack));
 put(second_member,0x68,reinterpret_cast<uintptr_t>(pack));
 unsigned char clip_table[80]{};
 put(first_member,0x80,reinterpret_cast<uintptr_t>(clip_table));
 put(second_member,0x80,reinterpret_cast<uintptr_t>(clip_table));
 first_member[0x61]=1;first_member[0x62]=9;first_member[0x63]=6;
 put(first_member,0x84,0x3e000000);
 uint32_t animation_arguments[]={1,0x3d4ccccd};
 next(true);native_pack_animation(first_member,animation_arguments);
 assert(native_tick_finish() && frame->tick_gate_count==5 && native_tick_stream_valid(frame->tick_gates,5));
 for(unsigned count=1;count<5;++count) assert(!native_tick_stream_valid(frame->tick_gates,count));
 begin(false);first_member[0x61]=2;first_member[0x62]=7;first_member[0x63]=22;
 put(first_member,0x84,0x3f400000);animation_arguments[0]=2;animation_arguments[1]=0x3dcccccd;SetLastError(345);
 native_pack_animation(first_member,animation_arguments);
 assert(native_tick_finish() && GetLastError()==345 && animation_arguments[0]==1 && animation_arguments[1]==0x3d4ccccd);
 assert(first_member[0x61]==1 && first_member[0x62]==9 && first_member[0x63]==6);
 assert(*reinterpret_cast<uint32_t *>(first_member+0x84)==0x3e000000);
 assert(*reinterpret_cast<uintptr_t *>(first_member+0x10)==reinterpret_cast<uintptr_t>(clip_table+20));
 begin(false);const auto wrong_animation_member=faults;
 native_pack_animation(second_member,animation_arguments);
 assert(!native_tick_finish() && faults==wrong_animation_member+1);
 next(true);animation_arguments[0]=2;put(first_member,0x84,0x7fc00000);
 native_pack_animation(first_member,animation_arguments);
 assert(native_tick_finish() && frame->tick_gates[3].value==0);
 clip_table[40+0x12]=1;put(first_member,0x84,0x3f000000);
 next(true);native_pack_animation(first_member,animation_arguments);
 assert(native_tick_finish() && frame->tick_gates[3].value==0x3f000000 && native_tick_stream_valid(frame->tick_gates,5));
 begin(false);put(first_member,0x84,0x3e000000);
 native_pack_animation(first_member,animation_arguments);
 assert(native_tick_finish() && *reinterpret_cast<uint32_t *>(first_member+0x84)==0x3f000000);
 clip_table[40+0x12]=0;
 for(uint32_t site:{static_cast<uint32_t>(NATIVE_TICK_PACK_POSE_QUERY),static_cast<uint32_t>(NATIVE_TICK_PACK_POSE_COMMIT)}) {
  const uint32_t pose[]={0x3f800000,0x40000000,0x40400000,0x3f800000};
  std::memcpy(first_member+0x20,pose,sizeof pose);first_member[0x48]=0x34;first_member[0x49]=0x12;
  next(true);native_pack_pose(first_member,site);
  assert(native_tick_finish() && frame->tick_gate_count==6 && native_tick_stream_valid(frame->tick_gates,6));
  for(unsigned count=1;count<6;++count)assert(!native_tick_stream_valid(frame->tick_gates,count));
  assert(!native_tick_stream_valid(frame->tick_gates+1,5));
  begin(false);std::memset(first_member+0x20,0,16);first_member[0x48]=0;first_member[0x49]=0;
  first_member[0x4a]=0x56;first_member[0x4b]=0x78;SetLastError(654);
  native_pack_pose(first_member,site);
  assert(native_tick_finish() && GetLastError()==654 && !std::memcmp(first_member+0x20,pose,sizeof pose));
  assert(first_member[0x48]==0x34 && first_member[0x49]==0x12 && first_member[0x4a]==0x56 && first_member[0x4b]==0x78);
  begin(false);const auto wrong_pose_member=faults;native_pack_pose(second_member,site);
  assert(!native_tick_finish() && faults==wrong_pose_member+1);
  begin(false);const auto wrong_pose_site=faults;
  native_pack_pose(first_member,site==NATIVE_TICK_PACK_POSE_QUERY?NATIVE_TICK_PACK_POSE_COMMIT:NATIVE_TICK_PACK_POSE_QUERY);
  assert(!native_tick_finish() && faults==wrong_pose_site+1);
  frame->tick_gates[1].value=0x7fc00000;assert(!native_tick_stream_valid(frame->tick_gates,6));
 }
 {
  auto *constructor_bound=reinterpret_cast<unsigned char *>(0x47699b);const unsigned char code[]={0x83,0xfe,3};
  std::memcpy(constructor_bound,code,3);unsigned char native_pool[0x24]{};
  put(manager_list,0,0);put(krawly_manager,0x20,reinterpret_cast<uintptr_t>(native_pool));put(krawly_manager,0x28,1);
  put(native_pool,8,reinterpret_cast<uintptr_t>(krawly_manager));put(pack,0xb0,reinterpret_cast<uintptr_t>(native_pool));
  put(pack_definition,0,0xad7f74);put(pack_definition,4,reinterpret_cast<uintptr_t>(native_pool));
  put(pack_definition,0x10,reinterpret_cast<uintptr_t>(pack));put(pack_definition,0x18,1);put(pack_definition,0x1c,10);
  put(pack_definition,0x30,reinterpret_cast<uintptr_t>(krawly_manager));put(krawly_manager,0x184,reinterpret_cast<uintptr_t>(pack_definition));
  put(pack,0x13c,10);put(pack,0x140,1);
  NativeGlobalPackSource global{};assert(native_global_pack_source(pack,&global) && global.faction==1);
  unsigned char extra_pool[0x24]{};put(extra_pool,8,reinterpret_cast<uintptr_t>(krawly_manager));
  put(extra_pool,4,reinterpret_cast<uintptr_t>(native_pool));put(native_pool,0,reinterpret_cast<uintptr_t>(extra_pool));
  put(krawly_manager,0x20,reinterpret_cast<uintptr_t>(extra_pool));put(krawly_manager,0x24,reinterpret_cast<uintptr_t>(native_pool));put(krawly_manager,0x28,2);
  assert(native_global_pack_source(pack,&global));
  put(native_pool,0,0);put(native_pool,4,reinterpret_cast<uintptr_t>(extra_pool));put(extra_pool,0,reinterpret_cast<uintptr_t>(native_pool));put(extra_pool,4,0);
  put(krawly_manager,0x20,reinterpret_cast<uintptr_t>(native_pool));put(krawly_manager,0x24,reinterpret_cast<uintptr_t>(extra_pool));
  assert(native_global_pack_source(pack,&global));
  put(native_pool,4,0);put(krawly_manager,0x24,reinterpret_cast<uintptr_t>(native_pool));put(krawly_manager,0x28,1);

  for(unsigned mutation=0;mutation<8;++mutation){
   const auto manager_index=word(krawly_manager,0x184),pool_owner=word(native_pool,8),backlink=word(pack_definition,0x10);
   if(mutation==0)put(krawly_manager,0x184,0);
   if(mutation==1)put(native_pool,8,0);
   if(mutation==2)put(pack_definition,0x10,0);
   if(mutation==3)put(pack_definition,0x18,3);
   if(mutation==4)constructor_bound[1]=0xff;
   if(mutation==5)constructor_bound[2]=0;
   if(mutation==6)put(pack,0x140,0);
   if(mutation==7)put(native_pool,4,reinterpret_cast<uintptr_t>(native_pool));
   assert(!native_global_pack_source(pack,&global));
   put(krawly_manager,0x184,manager_index);put(native_pool,8,pool_owner);put(pack_definition,0x10,backlink);
   put(pack_definition,0x18,1);std::memcpy(constructor_bound,code,3);put(pack,0x140,1);put(native_pool,4,0);
  }
  put(first_member,0x20,0x3f800000);next(true);native_pack_pose(first_member,NATIVE_TICK_PACK_POSE_QUERY);
  assert(native_tick_finish() && frame->tick_gate_count==6 && native_tick_stream_valid(frame->tick_gates,6));
  begin(false);put(first_member,0x20,0);native_pack_pose(first_member,NATIVE_TICK_PACK_POSE_QUERY);
  assert(native_tick_finish() && word(first_member,0x20)==0x3f800000);
  begin(false);const auto wrong_global=faults;native_pack_pose(second_member,NATIVE_TICK_PACK_POSE_QUERY);
  assert(!native_tick_finish() && faults==wrong_global+1);
  first_member[0x60]=9;unsigned char entered=0;put(first_member,0x88,0x3f800000);put(first_member,0x8c,0x40000000);
  next(true);native_pack_mode(first_member,&entered);
  assert(native_tick_finish() && frame->tick_gates[0].value==0xfffe0000u && native_tick_stream_valid(frame->tick_gates,6));
  begin(false);put(first_member,0x88,0);put(first_member,0x8c,0);native_pack_mode(first_member,&entered);
  assert(native_tick_finish() && word(first_member,0x88)==0x3f800000 && word(first_member,0x8c)==0x40000000);
  put(manager_list,0,reinterpret_cast<uintptr_t>(pack));put(pack,0x13c,0);put(pack,0x140,0);put(pack_definition,0x1c,0);
 }
 next(true);assert(native_pack_cell_admission(first_member,0xe0)==0x60 && native_tick_finish());
 assert(native_tick_stream_valid(frame->tick_gates,2) && !native_tick_stream_valid(frame->tick_gates+1,1));
 begin(false);const auto unchanged_flags=first_member[0x63];SetLastError(321);
 assert(native_pack_cell_admission(first_member,0)==0x60 && native_tick_finish() && GetLastError()==321);
 assert(first_member[0x63]==unchanged_flags);
 begin(false);const auto wrong_cell_member=faults;
 assert(native_pack_cell_admission(second_member,0)==0 && !native_tick_finish() && faults==wrong_cell_member+1);
 next(true);assert(native_pack_attack(first_member,0)==0 && native_pack_attack(second_member,2)==2 && native_tick_finish());
 assert(frame->tick_gate_count==2 && native_tick_stream_valid(frame->tick_gates,2));
 assert(!native_tick_stream_valid(frame->tick_gates+1,1));
 begin(false);SetLastError(678);
 assert(native_pack_attack(first_member,2)==1 && native_pack_attack(second_member,0)==2 &&
        GetLastError()==678 && native_tick_finish());
 begin(false);put(second_member,0x6c,1);const auto wrong_member=faults;
 assert(native_pack_attack(second_member,0)==0 && !native_tick_finish() && faults==wrong_member+1);
 next(true);assert(native_pack_attack(first_member,1)==1 && native_tick_finish() && frame->tick_gate_count==0);
 begin(false);assert(native_pack_attack(first_member,2)==1 && native_tick_finish());
 next(true);engine_rng=0x8b66ea71u;
 native_pack_attack_seed(first_member);
 assert(native_tick_finish() && native_tick_stream_valid(frame->tick_gates,2));
 begin(false);engine_rng=0xb06c913du;SetLastError(789);
 native_pack_attack_seed(first_member);
 assert(engine_rng==0x8b66ea71u && GetLastError()==789 && native_tick_finish());
 begin(false);engine_rng=0xb06c913du;const auto wrong_seed_member=faults;
 native_pack_attack_seed(second_member);
 assert(engine_rng==0xb06c913du && !native_tick_finish() && faults==wrong_seed_member+1);
 next(true);engine_rng=0x12345678;
 native_pack_rearm_seed(first_member);
 assert(native_tick_finish() && native_tick_stream_valid(frame->tick_gates,2));
 begin(false);engine_rng=0x87654321;
 native_pack_rearm_seed(first_member);
 assert(engine_rng==0x12345678 && native_tick_finish());
 begin(false);engine_rng=0x87654321;const auto wrong_draw=faults;
 native_pack_attack_seed(first_member);
 assert(engine_rng==0x87654321 && !native_tick_finish() && faults==wrong_draw+1);
 for(auto draw:{native_pack_move_timer_seed,native_pack_move_heading_seed,native_pack_move_choice_seed}) {
  next(true);engine_rng=0x1234abcd;draw(first_member);
  assert(native_tick_finish() && native_tick_stream_valid(frame->tick_gates,2));
  assert(!native_tick_stream_valid(frame->tick_gates,1) && !native_tick_stream_valid(frame->tick_gates+1,1));
  begin(false);engine_rng=0xabcd1234;SetLastError(765);draw(first_member);
  assert(engine_rng==0x1234abcd && GetLastError()==765 && native_tick_finish());
  begin(false);engine_rng=0xabcd1234;const auto before_fault=faults;draw(second_member);
  assert(engine_rng==0xabcd1234 && !native_tick_finish() && faults==before_fault+1);
 }
 for(uint32_t site:{NATIVE_TICK_PACK_HIT_REACTION,NATIVE_TICK_PACK_HIT_AVOIDANCE,NATIVE_TICK_PACK_HIT_DEBRIS,
                   NATIVE_TICK_PACK_HIT_SHOCK,NATIVE_TICK_PACK_HIT_HEADING,
                   NATIVE_TICK_PACK_IMPULSE_TIMER,NATIVE_TICK_PACK_IMPULSE_SPEED,NATIVE_TICK_PACK_IMPULSE_HEADING,
                   NATIVE_TICK_PACK_DEATH_CLIP}) {
  next(true);engine_rng=0x1234abcd;native_pack_hit_seed(first_member,site);
  assert(native_tick_finish() && native_tick_stream_valid(frame->tick_gates,2));
  assert(!native_tick_stream_valid(frame->tick_gates,1) && !native_tick_stream_valid(frame->tick_gates+1,1));
  begin(false);engine_rng=0xabcd1234;SetLastError(765);native_pack_hit_seed(first_member,site);
  assert(engine_rng==0x1234abcd && GetLastError()==765 && native_tick_finish());
  begin(false);engine_rng=0xabcd1234;const auto before_fault=faults;native_pack_hit_seed(second_member,site);
  assert(engine_rng==0xabcd1234 && !native_tick_finish() && faults==before_fault+1);
 }
 next(true);
 assert(native_pack_formation(first_member,0)==0 && native_tick_finish());
 assert(native_tick_stream_valid(frame->tick_gates,2));
 begin(false);
 assert(native_pack_formation(first_member,1)==0 && native_tick_finish());
 begin(false);const auto wrong_formation_member=faults;
 assert(native_pack_formation(second_member,1)==1 && !native_tick_finish() && faults==wrong_formation_member+1);
 next(true);first_member[0x60]=5;unsigned char entry=1;
 native_pack_mode(first_member,&entry);
 assert(native_tick_finish() && frame->tick_gate_count==3 && native_tick_stream_valid(frame->tick_gates,3));
 assert(!native_tick_stream_valid(frame->tick_gates,2) && !native_tick_stream_valid(frame->tick_gates+1,2));
 begin(false);first_member[0x60]=2;first_member[0x63]=0x96;entry=0;SetLastError(890);
 native_pack_mode(first_member,&entry);
 assert(first_member[0x60]==5 && entry==1 && GetLastError()==890 && native_tick_finish());
 assert(first_member[0x63]==0x86);
 begin(false);second_member[0x60]=2;entry=0;const auto wrong_mode_member=faults;
 native_pack_mode(second_member,&entry);
 assert(second_member[0x60]==2 && entry==0 && !native_tick_finish() && faults==wrong_mode_member+1);
 next(true);first_member[0x60]=9;entry=0;
 put(first_member,0x88,0xbf000000);put(first_member,0x8c,0x3f800000);first_member[0x90]=1;first_member[0x91]=0;
 native_pack_mode(first_member,&entry);
 assert(native_tick_finish() && frame->tick_gate_count==6 && native_tick_stream_valid(frame->tick_gates,6));
 assert(!native_tick_stream_valid(frame->tick_gates,5) && !native_tick_stream_valid(frame->tick_gates+3,3));
 begin(false);put(first_member,0x88,0x3e000000);put(first_member,0x8c,0x3f000000);first_member[0x90]=0;first_member[0x91]=1;
 native_pack_mode(first_member,&entry);
 assert(native_tick_finish() && word(first_member,0x88)==0xbf000000 && word(first_member,0x8c)==0x3f800000);
 assert(first_member[0x90]==1 && first_member[0x91]==0);
 // The dispatcher can enter death with bytes from the previous state; stock code initializes them afterward.
 next(true);first_member[0x60]=9;entry=1;first_member[0x90]=12;first_member[0x91]=255;
 native_pack_mode(first_member,&entry);
 assert(native_tick_finish() && native_tick_stream_valid(frame->tick_gates,6));
 begin(false);first_member[0x90]=0;first_member[0x91]=0;entry=0;
 native_pack_mode(first_member,&entry);
 assert(native_tick_finish() && first_member[0x90]==12 && first_member[0x91]==255 && entry==1);
 for(uint32_t bytes=0;bytes<=UINT16_MAX;++bytes){
  const SyncTickGate gate={NATIVE_TICK_PACK_DEATH_FLAGS,clock,bytes};assert(native_tick_gate_valid(&gate));
 }
 const SyncTickGate oversized_flags={NATIVE_TICK_PACK_DEATH_FLAGS,clock,0x10000};
 assert(!native_tick_gate_valid(&oversized_flags));
 begin(false);put(second_member,0x88,0x3e000000);put(second_member,0x8c,0x3f000000);const auto wrong_death=faults;
 native_pack_mode(second_member,&entry);
 assert(!native_tick_finish() && faults==wrong_death+1 && word(second_member,0x88)==0x3e000000);
 begin(false);frame->tick_gate_count=5;put(first_member,0x88,0x3e000000);const auto incomplete_death=faults;
 native_pack_mode(first_member,&entry);
 assert(!native_tick_finish() && faults==incomplete_death+1 && word(first_member,0x88)==0x3e000000);
 next(true);first_member[0x60]=0xff;entry=1;
 native_pack_mode(first_member,&entry);
 native_pack_mode(second_member,&entry);
 assert(native_tick_finish() && frame->tick_gate_count==6 && native_tick_stream_valid(frame->tick_gates,6));
 begin(false);first_member[0x60]=5;entry=0;
 native_pack_mode(first_member,&entry);
 assert(first_member[0x60]==0xff && entry==1);
 native_pack_mode(second_member,&entry);
 assert(native_tick_finish());
 first_member[0x60]=5;entry=0;
 next(true);put(manager_list,0,0);
 const auto local_only_faults=faults;engine_rng=0x9876abcd;
 native_pack_hit_seed(first_member,NATIVE_TICK_PACK_HIT_REACTION);
 assert(engine_rng==0x9876abcd && faults==local_only_faults);
 native_pack_mode(first_member,&entry);
 assert(first_member[0x60]==5 && entry==0 && native_tick_finish() && frame->tick_gate_count==0);
 unsigned char weapon_actor[0x1440]{};
 turret_pilot=weapon_actor;
 weapon_actor[0x8ea]=3;weapon_actor[0x8fa]=41;weapon_actor[0x8fb]=254;weapon_actor[0x8fc]=255;
 weapon_actor[0x8f9]=0xa5;weapon_actor[0x8fd]=0x5a;
 next(true);native_weapon_commands(weapon_actor);
 assert(native_tick_finish() && frame->tick_gate_count==3 && native_tick_stream_valid(frame->tick_gates,3));
 assert(!native_tick_stream_valid(frame->tick_gates,2) && !native_tick_stream_valid(frame->tick_gates+1,2));
 begin(false);weapon_actor[0x8fa]=254;SetLastError(987);
 native_weapon_commands(weapon_actor);
 assert(native_tick_finish() && weapon_actor[0x8ea]==3 && weapon_actor[0x8fa]==41 && weapon_actor[0x8fb]==254 && weapon_actor[0x8fc]==255);
 assert(weapon_actor[0x8f9]==0xa5 && weapon_actor[0x8fd]==0x5a && GetLastError()==987);
 for(unsigned mutation=0;mutation<5;++mutation) {
  next(true);native_weapon_commands(weapon_actor);assert(native_tick_finish());
  if(mutation==0)frame->tick_gates[0].value++;
  if(mutation==1)frame->tick_gates[1].value++;
  if(mutation==2)frame->tick_gates[2].clock++;
  if(mutation==3)frame->tick_gate_count=2;
  if(mutation==4)frame->tick_gates[2].site=NATIVE_TICK_FIRE_VISIBILITY;
  begin(false);weapon_actor[0x8fa]=254;const auto before_reject=faults;
  native_weapon_commands(weapon_actor);
  assert(!native_tick_finish() && faults==before_reject+1 && weapon_actor[0x8fa]==254);
 }
 next(true);weapon_actor[0x8fa]=254;native_weapon_commands(weapon_actor);assert(native_tick_finish());
 begin(false);weapon_actor[0x8fa]=41;native_weapon_commands(weapon_actor);assert(native_tick_finish() && weapon_actor[0x8fa]==254);
 native_tick_cancel(&bound);weapon_actor[0x8fa]=41;native_weapon_commands(weapon_actor);assert(weapon_actor[0x8fa]==41);
 next(true);turret_pilot=nullptr;SetLastError(765);native_weapon_commands(weapon_actor);
 assert(native_tick_finish() && !frame->tick_gate_count && weapon_actor[0x8fa]==41 && GetLastError()==765);
 turret_pilot=weapon_actor;
 assert(VirtualProtect(reinterpret_cast<void *>(0x45a930),1,PAGE_EXECUTE_READWRITE,&old));
 *reinterpret_cast<unsigned char *>(0x45a930)=0xc3;
 assert(FlushInstructionCache(GetCurrentProcess(),reinterpret_cast<void *>(0x45a930),1));
 for(unsigned char command:{static_cast<unsigned char>(0xff),static_cast<unsigned char>(0xfe),static_cast<unsigned char>(41)}) {
  next(true);weapon_actor[0x8fb]=command;SetLastError(654);
  double retained;uint16_t cw_before,cw_after;uint32_t mx_before,mx_after;
  __asm__ volatile("fnstcw %0\n\tstmxcsr %1\n\tfld1":"=m"(cw_before),"=m"(mx_before));
  const uint32_t flags=invoke_weapon_commands(weapon_actor);
  __asm__ volatile("fstpl %0\n\tfnstcw %1\n\tstmxcsr %2":"=m"(retained),"=m"(cw_after),"=m"(mx_after));
  assert(flags!=UINT32_MAX && native_tick_finish() && retained==1 && cw_before==cw_after && mx_before==mx_after && GetLastError()==654);
  assert(((flags&0x40)!=0)==(command==0xff));
  assert((((flags&0x40)!=0) || (((flags&0x80)!=0)!=((flags&0x800)!=0)))==(static_cast<int8_t>(command)<=-1));
 }
 unsigned char gizmo_world[0x22e8]={},gizmo_container[16]={},gizmo_registry[0x2c]={},gizmo_manager[0x28]={},gizmo[0x1bc]={};
 void *gizmo_table[]={gizmo_manager};void *gizmo_handle=gizmo_table;
 auto put_gizmo=[](void *p,unsigned offset,uintptr_t value){std::memcpy(static_cast<unsigned char *>(p)+offset,&value,4);};
 put_gizmo(reinterpret_cast<void *>(0xfb4a20),0,reinterpret_cast<uintptr_t>(gizmo_world));
 put_gizmo(reinterpret_cast<void *>(0xe90184),0,reinterpret_cast<uintptr_t>(gizmo_registry));
 put_gizmo(gizmo_world,0x22e4,reinterpret_cast<uintptr_t>(gizmo_container));
 put_gizmo(gizmo_container,12,reinterpret_cast<uintptr_t>(gizmo_world));
 put_gizmo(gizmo_world,0x400,reinterpret_cast<uintptr_t>(&gizmo_handle));
 std::memcpy(gizmo_world+0x81,"EngineWorld",12);put_gizmo(gizmo_registry,0x28,1);
 put_gizmo(gizmo_manager,0,0xc4c1cc);put_gizmo(reinterpret_cast<void *>(0xc4c1cc),0x40,0x838260);
 put_gizmo(gizmo_manager,0x24,reinterpret_cast<uintptr_t>(gizmo));put_gizmo(gizmo,0,0xc47e9c);
 std::memcpy(gizmo+0x30,"AuthoredTurret",15);
 auto &gizmo_game_seed=*reinterpret_cast<uint16_t *>(0xe637b4);
 auto &gizmo_engine_seed=*reinterpret_cast<uint32_t *>(0xea178c);
 for(unsigned mutation=0;mutation<8;++mutation) {
  next(true);gizmo_game_seed=123;gizmo_engine_seed=456;put_gizmo(gizmo,0x154,0x3e800000);
  SetLastError(432);native_gizmo_turret_input(gizmo);
  assert(native_tick_finish() && frame->tick_gate_count==7 && native_tick_stream_valid(frame->tick_gates,7) && GetLastError()==432);
  if(mutation==1)frame->tick_gates[0].value++;
  if(mutation==2)frame->tick_gates[4].clock++;
  if(mutation==3)frame->tick_gate_count=6;
  if(mutation==4)frame->tick_gates[4].value=0x10000;
  if(mutation==5)frame->tick_gates[6].value=0x7fc00000;
  if(mutation==6)frame->tick_gates[2].site++;
  if(mutation==7)gizmo[0x30]='X';
  begin(false);gizmo_game_seed=321;gizmo_engine_seed=654;put_gizmo(gizmo,0x154,0x3f000000);
  const auto previous_faults=faults;SetLastError(432);native_gizmo_turret_input(gizmo);
  if(!mutation) {
   assert(native_tick_finish() && faults==previous_faults && gizmo_game_seed==123 && gizmo_engine_seed==456);
   uint32_t timer;std::memcpy(&timer,gizmo+0x154,4);assert(timer==0x3e800000);
  } else {
   assert(!native_tick_finish() && faults==previous_faults+1 && gizmo_game_seed==321 && gizmo_engine_seed==654);
   uint32_t timer;std::memcpy(&timer,gizmo+0x154,4);assert(timer==0x3f000000);
  }
  assert(GetLastError()==432);gizmo[0x30]='A';
 }
 assert(VirtualProtect(reinterpret_cast<void *>(0x838281),1,PAGE_EXECUTE_READWRITE,&old));
 *reinterpret_cast<unsigned char *>(0x838281)=0xc3;
 assert(FlushInstructionCache(GetCurrentProcess(),reinterpret_cast<void *>(0x838281),1));
 gizmo[0x1ba]=0x34;gizmo[0x1bb]=0x12;next(true);SetLastError(876);
 double gizmo_retained;uint16_t gizmo_cw_before,gizmo_cw_after;uint32_t gizmo_mx_before,gizmo_mx_after;
 __asm__ volatile("fnstcw %0\n\tstmxcsr %1\n\tfld1":"=m"(gizmo_cw_before),"=m"(gizmo_mx_before));
 const uint32_t gizmo_flags=invoke_gizmo_turret(gizmo);
 __asm__ volatile("fstpl %0\n\tfnstcw %1\n\tstmxcsr %2":"=m"(gizmo_retained),"=m"(gizmo_cw_after),"=m"(gizmo_mx_after));
 assert(gizmo_flags!=UINT32_MAX && (gizmo_flags&0x41)==0x41 && native_tick_finish() && GetLastError()==876);
 assert(gizmo_retained==1 && gizmo_cw_before==gizmo_cw_after && gizmo_mx_before==gizmo_mx_after);
 auto &elapsed=*reinterpret_cast<uint32_t *>(0xfb4ad4);
 next(true);elapsed=0x3f800000;SetLastError(321);assert(native_tick_elapsed_input() && GetLastError()==321 && native_tick_finish());
 assert(frame->tick_gate_count==1 && frame->tick_gates[0].site==NATIVE_TICK_GAME_TIME && native_tick_stream_valid(frame->tick_gates,1));
 begin(false);elapsed=0x40000000;SetLastError(654);assert(native_tick_elapsed_input() && elapsed==0x3f800000 && GetLastError()==654 && native_tick_finish());
 native_tick_cancel(&bound);elapsed=0x40400000;assert(!native_tick_elapsed_input() && elapsed==0x40400000);
 ++frame->epoch;++bound.epoch;frame->tick_gates[0].clock++;begin(false);elapsed=0x40800000;
 assert(!native_tick_elapsed_input() && elapsed==0x40800000 && !native_tick_finish());
 next(true);elapsed=0x7fc00000;assert(!native_tick_elapsed_input() && !native_tick_finish());
 puts("Native world journal host/client correction, order, clock, count, retired lease and LastError checks passed.");
}
