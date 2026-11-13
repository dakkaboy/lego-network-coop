#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "rts_generator_input_sync.h"
#include "physics_input_sync.h"
#include "../engine/native_rts_generator_source.h"
extern "C" {
#include "game_sync.h"
#include "../engine/constructor_lexical_seh.h"
__declspec(dllexport) volatile uint32_t clonewars_rts_generator_input_debug[8],clonewars_rts_generator_input_failure[16];
}
namespace {
struct Machine {alignas(16) unsigned char fx[512];DWORD error;
 void capture(){__asm__ volatile("fxsave %0":"=m"(fx)::"memory");error=GetLastError();}
 void restore()const{SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx):"memory");}};
struct Scope {CoherentFrameToken token;NativeRtsGeneratorSource source;void *object;uint32_t clock,delta;RtsGeneratorOriginal original;bool bound;Machine machine;};
bool live(const Scope &s){return coherent_frame_valid(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)) &&
 *reinterpret_cast<uint32_t *>(0xfb4b6c)==s.clock && native_rts_generator_source_live(&s.source);}
void reject(const Scope &s,unsigned reason){
 ++clonewars_rts_generator_input_debug[3];
 if(!clonewars_rts_generator_input_failure[0]){
  const uint32_t row[]={reason,s.token.epoch,s.token.sequence,s.clock,reinterpret_cast<uintptr_t>(s.object),
   s.source.team_slot,s.source.index,s.source.side,s.source.object_class};
  std::memcpy(const_cast<uint32_t *>(clonewars_rts_generator_input_failure),row,sizeof row);
 }
 game_sync_native_fault(15);
}
void *__cdecl invoke(void *raw){
 auto &s=*static_cast<Scope *>(raw);
 if(s.bound){
  if(!native_rts_generator_source(s.object,&s.source)){reject(s,1);return nullptr;}
  auto *p=static_cast<unsigned char *>(s.object);SyncPhysicsChoice c{};c.kind=SYNC_PHYSICS_RTS_GENERATOR;c.site=0x547d30;
  auto &v=c.rts_generator;v.clock=s.clock;v.team_slot=s.source.team_slot;v.index=s.source.index;v.side=s.source.side;
  v.object_class=s.source.object_class;std::memcpy(&v.state,p+0x264,4);std::memcpy(&v.delta,&s.delta,4);
  std::memcpy(&v.elapsed,p+0x26c,12);std::memcpy(&v.previous_state,p+0x268,4);
  std::memcpy(&v.timer_delta,static_cast<unsigned char *>(s.source.engine)+0xe0c,4);
  v.rng_game=*reinterpret_cast<uint32_t *>(0xe637b4);v.rng_engine=*reinterpret_cast<uint32_t *>(0xea178c);v.rng_effects=*reinterpret_cast<uint32_t *>(0xe5f498);
  const auto before=c;
  if(!live(s)){reject(s,2);return nullptr;}
  if(physics_world_input(&c,&s.token)!=1){reject(s,3);return nullptr;}
  if(!live(s)||!physics_choice_same_source(&before,&c)){reject(s,4);return nullptr;}
  ++clonewars_rts_generator_input_debug[0];
  if(std::memcmp(&before.rts_generator.delta,&v.delta,36))++clonewars_rts_generator_input_debug[1];
  if(std::memcmp(&before.rts_generator.delta,&v.delta,4)){
   ++clonewars_rts_generator_input_debug[2];
   if(!clonewars_rts_generator_input_debug[4]){
    clonewars_rts_generator_input_debug[4]=s.clock;
    std::memcpy(const_cast<uint32_t *>(clonewars_rts_generator_input_debug)+5,&before.rts_generator.delta,4);
    std::memcpy(const_cast<uint32_t *>(clonewars_rts_generator_input_debug)+6,&v.delta,4);
   }
  }
  std::memcpy(&s.delta,&v.delta,4);std::memcpy(p+0x26c,&v.elapsed,12);std::memcpy(p+0x268,&v.previous_state,4);
  std::memcpy(static_cast<unsigned char *>(s.source.engine)+0xe0c,&v.timer_delta,4);
  *reinterpret_cast<uint32_t *>(0xe637b4)=v.rng_game;*reinterpret_cast<uint32_t *>(0xea178c)=v.rng_engine;*reinterpret_cast<uint32_t *>(0xe5f498)=v.rng_effects;
 }
 s.machine.restore();s.original(s.object,s.delta);s.machine.capture();return nullptr;
}
void __cdecl abort(void *){}
}
void rts_generator_input_update(void *object,uint32_t delta,RtsGeneratorOriginal original){
 Scope s;s.machine.capture();s.token={};s.source={};s.object=object;s.delta=delta;s.original=original;
 s.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);s.bound=coherent_frame_get(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))!=0;
 constructor_lexical_seh(&s,invoke,abort);s.machine.restore();
}
