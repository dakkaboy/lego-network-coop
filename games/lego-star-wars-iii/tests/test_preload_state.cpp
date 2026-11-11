#include "../src/sync/preload_state.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <initializer_list>
#include <limits>

static void require(bool result){if(!result)std::abort();}
static SyncPreloadInput source(uint32_t serial=1){
 return SyncPreloadInput{.epoch=5,.level=7,.serial=serial,.root_phase=0xd,.clock=19,
  .rng_game=0xffffffffu,.rng_engine=0x87654321u,.rng_effects=0x92345678u,.delta=.08f,.engine_delta=.1f,.engine_mode=3};
}
static NativePreloadState bound(){
 NativePreloadState state{};preload_state_bind(&state,11,5,7,0x12340000);return state;
}
static void reject_input(NativePreloadState &state,const SyncPreloadInput &input){
 const auto before=state;require(!preload_state_accept(&state,&input));
 require(!std::memcmp(&before,&state,sizeof state));
}
static void reject_finish(NativePreloadState &state,const SyncPreloadReceipt &receipt){
 const auto before=state;require(!preload_state_finish(&state,&receipt));
 require(!std::memcmp(&before,&state,sizeof state));
}
int main(){
 static_assert(sizeof(SyncPreloadInput)==44);
 static_assert(sizeof(SyncPreloadReceipt)==1044);
 static_assert(sizeof(SyncWorldReady)==24);
 require(native_jobs_idle(0,0,0,0));
 require(!native_jobs_idle(1,0,0,0));require(!native_jobs_idle(0,1,0,0));
 require(!native_jobs_idle(0,0,1,0));require(!native_jobs_idle(0,0,0,1));
 const SyncWorldReady absent_ready{.level=-1},zero_world{};
 require(preload_world_ready_valid(&absent_ready)&&!preload_world_ready_valid(&zero_world));
 require(!preload_world_ready_valid(nullptr)&&!preload_world_ready_matches(&absent_ready,&absent_ready));
 SyncWorldReady prepared{5,7,0xd,0};require(preload_world_ready_valid(&prepared));
 require(preload_world_ready_matches(&prepared,&prepared));
 auto fewer=prepared;
 fewer.collider_count=1;
 fewer.collider_roster=42;
 require(preload_world_ready_matches(&prepared,&fewer));
 require(!preload_world_roster_matches(&prepared,&fewer));
 require(preload_world_roster_matches(&fewer,&fewer));
 for(unsigned field=0;field<4;++field){auto stale=prepared;
  if(field==0)stale.epoch++;if(field==1)stale.level++;if(field==2)stale.root_phase=0xe;if(field==3)stale.completed_serial++;
  require(!preload_world_ready_matches(&prepared,&stale));
 }
 auto invalid=prepared;invalid.root_phase=0xb;require(!preload_world_ready_valid(&invalid));
 invalid.completed_serial=1;require(preload_world_ready_valid(&invalid));
 for(uint32_t serial=0;serial<5000;++serial){
  SyncWorldReady local{5,7,serial?0xeu:0xdu,serial},peer=local;
  require(preload_world_ready_matches(&local,&peer));
  ++peer.completed_serial;require(!preload_world_ready_matches(&local,&peer));
  peer=local;if(serial)--peer.completed_serial;else peer=absent_ready;
  require(!preload_world_ready_matches(&local,&peer));
 }
 require(!preload_stage_eligible(0xd,12,-1,0,0));
 require(!preload_stage_eligible(0xe,6,7,1,1));
 require(!preload_stage_eligible(0xd,6,7,1,1));
 require(preload_stage_eligible(0xd,7,-1,1,0));
 require(preload_stage_eligible(0xe,7,-1,1,1));
 require(!preload_initial_seal_ready(nullptr,0xd));
 {
  SyncPreloadReceipt receipt{3,1,14,2,{UINT32_MAX,14}};
  uint32_t request=99;
  require(preload_receipt_valid(&receipt));
  require(preload_flow_request_read(&receipt,3,0,&request)==1 && request==UINT32_MAX);
  require(preload_flow_request_read(&receipt,3,1,&request)==1 && request==14);
  require(preload_flow_request_read(&receipt,4,0,&request)==0 && request==14);
  require(preload_flow_request_read(&receipt,2,0,&request)==-1 && request==14);
  require(preload_flow_request_read(&receipt,3,2,&request)==-1);
  require(preload_flow_request_read(&receipt,3,SYNC_MAX_PRELOAD_FLOW_REQUESTS,&request)==-1);
  auto invalid=receipt;invalid.flow_requests[1]=21;require(!preload_receipt_valid(&invalid));
  invalid=receipt;invalid.flow_requests[2]=1;require(!preload_receipt_valid(&invalid));
  invalid=receipt;invalid.flow_count=SYNC_MAX_PRELOAD_FLOW_REQUESTS+1;require(!preload_receipt_valid(&invalid));
  auto state=bound();auto input=source();require(preload_state_accept(&state,&input));
  receipt.serial=1;require(preload_state_finish(&state,&receipt));
  require(preload_state_peer_receipt(&state,&receipt)==1);
  receipt.flow_requests[1]=13;require(preload_state_peer_receipt(&state,&receipt)==-1);
 }
 {
  SyncPreloadReceipt receipt{.serial=3,.world_calls=1,.end_phase=13,.track_count=1};
  receipt.tracks[0]={{0x1234,0x5678},0x3f800000};
  uint32_t witness[2]={0x1234,0x5678},time=0;
  require(preload_receipt_valid(&receipt));
  require(preload_track_read(&receipt,3,0,witness,&time)==1 && time==0x3f800000);
  require(preload_track_read(&receipt,4,0,witness,&time)==0 && time==0x3f800000);
  require(preload_track_read(&receipt,2,0,witness,&time)==-1);
  witness[1]^=1;require(preload_track_read(&receipt,3,0,witness,&time)==-1);witness[1]^=1;
  require(preload_track_read(&receipt,3,1,witness,&time)==-1);
  auto invalid=receipt;invalid.tracks[0].time=0x7fc00000;require(!preload_receipt_valid(&invalid));
  invalid=receipt;invalid.tracks[1].witness[0]=1;require(!preload_receipt_valid(&invalid));
  invalid=receipt;invalid.track_count=SYNC_MAX_PRELOAD_FLOW_REQUESTS+1;require(!preload_receipt_valid(&invalid));
  auto state=bound();auto input=source();require(preload_state_accept(&state,&input));
  receipt.serial=1;require(preload_state_finish(&state,&receipt));
  require(preload_state_peer_receipt(&state,&receipt)==1);
  receipt.tracks[0].time++;require(preload_state_peer_receipt(&state,&receipt)==-1);
 }
 {
  auto entering=bound();auto input=source();input.root_phase=0xb;
  require(preload_state_accept(&entering,&input));
  const SyncPreloadReceipt entered{1,1,0xd};
  require(preload_state_finish(&entering,&entered));
  require(!preload_initial_seal_ready(&entering,0xd));
  input=source(2);require(preload_state_accept(&entering,&input));
  const SyncPreloadReceipt without_world{2,0,0xd};
  require(preload_state_finish(&entering,&without_world));
  require(!preload_initial_seal_ready(&entering,0xd));
  input=source(3);require(preload_state_accept(&entering,&input));
  const SyncPreloadReceipt updated{3,1,0xd};
  require(preload_state_finish(&entering,&updated));
  require(!preload_initial_seal_ready(&entering,0xd));
  input=source(4);input.root_phase=0xe;require(preload_state_accept(&entering,&input));
  const SyncPreloadReceipt playable{4,1,0xe};
  require(preload_state_finish(&entering,&playable));
  require(preload_initial_seal_ready(&entering,0xe));
 }
 for(uint32_t phase:{0xdu,0xeu}){
  auto early=bound();auto initial=source();initial.root_phase=phase;
  require(!preload_initial_seal_ready(&early,phase));
  require(preload_state_accept(&early,&initial));
  const SyncPreloadReceipt zero{1,0,phase};
  require(preload_state_finish(&early,&zero));require(!preload_initial_seal_ready(&early,phase));
  early=bound();require(preload_state_accept(&early,&initial));
  const SyncPreloadReceipt first_world{1,1,phase};
  require(preload_state_finish(&early,&first_world));
  require(preload_initial_seal_ready(&early,phase)==(phase==0xe));
  auto wrong=first_world;wrong.end_phase=phase==0xd?0xe:0xd;
  require(preload_state_peer_receipt(&early,&wrong)==-1);
  require(!preload_initial_seal_ready(&early,wrong.end_phase));
  require(!preload_initial_seal_ready(&early,0xa));require(!preload_initial_seal_ready(&early,0xb));
  require(preload_state_peer_receipt(&early,&first_world)==1);
  require(preload_state_seal(&early,1));require(!preload_initial_seal_ready(&early,phase));
  reject_input(early,source(2));
 }
 require(!preload_stage_eligible(0xb,7,-1,1,0));
 require(preload_stage_eligible(0xb,7,-1,1,1));
 require(preload_stage_eligible(0xa,7,-1,1,1));
 require(!preload_stage_eligible(0xc,7,-1,1,1));
 require(!preload_stage_eligible(0xd,-1,-1,1,0));
 require(!preload_stage_eligible(0xd,4096,-1,1,0));
 require(!preload_stage_eligible(0xd,7,7,1,0));
 require(!preload_stage_eligible(0xd,7,7,1,1));
 const auto host=source();const SyncPreloadInput empty{.level=-1},zero{};
 require(preload_input_valid(&host)&&preload_input_valid(&empty));
 require(!preload_input_valid(nullptr)&&!preload_input_valid(&zero));
 for(uint32_t phase:{0xau,0xbu,0xdu,0xeu}){auto input=host;input.root_phase=phase;require(preload_input_valid(&input));}
 for(unsigned field=0;field<14;++field){
  auto bad=host;
  switch(field){
   case 0:bad.epoch=0;break;
   case 1:bad.level=-1;break;
   case 2:bad.level=4096;break;
   case 3:bad.serial=0;break;
   case 4:bad.root_phase=0xc;break;
   case 5:bad.root_phase=0xf;break;
   case 6:bad.delta=std::numeric_limits<float>::quiet_NaN();break;
   case 7:bad.engine_delta=std::numeric_limits<float>::infinity();break;
   case 8:bad.delta=-.001f;break;
   case 9:bad.engine_delta=-.001f;break;
   case 10:bad.delta=.1001f;break;
   case 11:bad.engine_delta=.1001f;break;
   case 12:bad.engine_mode=17;break;
   case 13:bad.engine_mode=UINT32_MAX;break;
  }
  require(!preload_input_valid(&bad));
 }
 auto boundary=host;boundary.root_phase=0xe;boundary.delta=boundary.engine_delta=0;
 boundary.engine_mode=16;require(preload_input_valid(&boundary));
 auto empty_bad=empty;empty_bad.serial=1;require(!preload_input_valid(&empty_bad));
 empty_bad=empty;empty_bad.delta=-0.0f;require(!preload_input_valid(&empty_bad));
 const SyncPreloadReceipt no_receipt{},no_world{1,0,0},many_worlds{1,64,20};
 require(preload_receipt_valid(&no_receipt)&&preload_receipt_valid(&no_world)&&preload_receipt_valid(&many_worlds));
 require(!preload_receipt_valid(nullptr));
 for(const auto bad:{SyncPreloadReceipt{0,1,0},SyncPreloadReceipt{0,0,1},
  SyncPreloadReceipt{1,65,0},SyncPreloadReceipt{1,0,21}})require(!preload_receipt_valid(&bad));
 NativePreloadState state=bound();
 require(!preload_state_accept(nullptr,&host));require(!preload_state_finish(nullptr,&no_world));
 require(!preload_state_seal(nullptr,1));preload_state_bind(nullptr,1,1,1,1);
 require(!preload_state_accept(&state,nullptr));require(!preload_state_finish(&state,nullptr));
 reject_input(state,source(2));reject_finish(state,no_world);
 auto stale=host;stale.epoch=4;reject_input(state,stale);
 stale=host;stale.level=6;reject_input(state,stale);
 require(preload_state_accept(&state,&host));require(preload_state_accept(&state,&host));
 for(unsigned field=0;field<8;++field){
  auto changed=host;
  switch(field){
   case 0:changed.clock++;break;
   case 1:changed.rng_game++;break;
   case 2:changed.rng_engine++;break;
   case 3:changed.delta=.07f;break;
   case 4:changed.engine_delta=.09f;break;
   case 5:changed.engine_mode++;break;
   case 6:changed.root_phase=0xe;break;
   case 7:changed.rng_effects++;break;
  }
  reject_input(state,changed);
 }
 reject_input(state,source(2));reject_input(state,source(3));
 reject_finish(state,no_receipt);reject_finish(state,{2,1,14});
 require(!preload_state_seal(&state,1));
 require(preload_state_finish(&state,&no_world));require(!state.completed);
 require(preload_state_peer_receipt(&state,&no_world)==1);
 require(preload_state_peer_receipt(&state,&no_receipt)==0);
 auto wrong_phase=no_world;wrong_phase.end_phase=0xd;
 require(preload_state_peer_receipt(&state,&wrong_phase)==-1);
 auto wrong_calls=no_world;wrong_calls.world_calls=1;
 require(preload_state_peer_receipt(&state,&wrong_calls)==-1);
 const SyncPreloadReceipt future_receipt{2,0,0};require(preload_state_peer_receipt(&state,&future_receipt)==-1);
 require(preload_state_finish(&state,&no_world));reject_finish(state,{1,1,0});
 require(!preload_state_seal(&state,1));require(preload_state_accept(&state,&host));
 auto next=source(2);next.root_phase=0xe;next.clock++;
 require(preload_state_accept(&state,&next));reject_input(state,host);reject_input(state,source(4));
 reject_finish(state,no_world);require(!preload_state_seal(&state,1));
 const SyncPreloadReceipt second{2,2,14};require(preload_state_finish(&state,&second));
 require(state.completed&&state.applied.world_calls==2);
 require(preload_state_finish(&state,&second));reject_finish(state,{2,1,14});reject_finish(state,{2,2,13});
 auto third=source(3);require(preload_state_accept(&state,&third));
 const SyncPreloadReceipt third_done{3,0,15};require(preload_state_finish(&state,&third_done));
 require(state.completed);require(!preload_state_seal(&state,2));
 require(preload_state_seal(&state,3));require(preload_state_seal(&state,3));
 require(!preload_state_seal(&state,2));reject_input(state,third);reject_input(state,source(4));
 require(preload_state_finish(&state,&third_done));
 preload_state_bind(&state,11,5,7,0x12340000);require(state.sealed_serial==3&&state.completed);
 for(unsigned context=0;context<4;++context){
  state=bound();require(preload_state_accept(&state,&host));
  const SyncPreloadReceipt done{1,1,14};require(preload_state_finish(&state,&done));
  require(preload_state_seal(&state,1));
  preload_state_bind(&state,context==0?12:11,context==1?6:5,context==2?8:7,context==3?0x12350000:0x12340000);
  require(!state.input.epoch&&!state.applied.serial&&!state.completed&&!state.sealed_serial);
  auto fresh=host;fresh.epoch=state.epoch;fresh.level=state.level;
  require(preload_state_accept(&state,&fresh));
  require(preload_state_finish(&state,&done));require(preload_state_seal(&state,1));
 }
 for(unsigned invalid=0;invalid<4;++invalid){
  NativePreloadState unbound{};preload_state_bind(&unbound,invalid==0?0:11,invalid==1?0:5,invalid==2?-1:7,invalid==3?0:0x12340000);
  reject_input(unbound,host);
 }
 state=bound();auto plus=host;plus.delta=0;require(preload_state_accept(&state,&plus));
 auto minus=plus;minus.delta=-0.0f;reject_input(state,minus);
 state=bound();state.input=source(UINT32_MAX);state.applied={UINT32_MAX,1,14};state.completed=1;
 reject_input(state,source(0));reject_input(state,source(1));reject_input(state,source(UINT32_MAX-1));
 require(preload_state_accept(&state,&state.input));require(preload_state_seal(&state,UINT32_MAX));
 state=bound();require(preload_state_accept(&state,&host));
 require(preload_state_finish(&state,&many_worlds));require(preload_state_seal(&state,1));
 state=bound();
 for(uint32_t serial=1;serial<=5000;++serial){
  const auto current=source(serial);require(preload_state_accept(&state,&current));
  require(preload_state_accept(&state,&current));
  const SyncPreloadReceipt done{serial,serial%3,serial%21};
  require(preload_state_finish(&state,&done));require(preload_state_finish(&state,&done));
 }
 require(state.completed&&preload_state_seal(&state,5000));
 std::puts("preload stream state: passed");
}
