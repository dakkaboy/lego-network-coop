#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "rts_body_input_sync.h"
#include "physics_input_sync.h"
#include "../engine/native_rts_body_source.h"
extern "C" {
#include "game_sync.h"
#include "../engine/constructor_lexical_seh.h"
__declspec(dllexport) volatile uint32_t clonewars_rts_body_input_debug[4],clonewars_rts_body_input_failure[12];
__declspec(dllexport) volatile uint32_t clonewars_rts_visibility_input_debug[4],clonewars_rts_visibility_input_failure[12];
}
namespace {
using Byte=unsigned char;
struct Machine {alignas(16) Byte fx[512];DWORD error;void capture(){__asm__ volatile("fxsave %0":"=m"(fx)::"memory");error=GetLastError();}void restore()const{SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx):"memory");}};
struct Scope {CoherentFrameToken token;NativeRtsBodySource source;void *object;uint32_t state,flag,clock;RtsBodyUpdate original;bool bound;Machine machine;};
bool live(const Scope &s){return coherent_frame_valid(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))&&s.clock==*reinterpret_cast<uint32_t *>(0xfb4b6c);}
bool same(const Scope &s){NativeRtsBodySource now{};return live(s)&&native_rts_body_source(s.object,s.state,now)==1&&!std::memcmp(&s.source,&now,sizeof now);}
void reject(const Scope &s,unsigned reason){if(!live(s))return;++clonewars_rts_body_input_debug[3];if(!clonewars_rts_body_input_failure[0]){const uint32_t v[]={reason,s.token.epoch,s.token.sequence,s.clock,reinterpret_cast<uintptr_t>(s.object),s.source.ordinal,s.state};std::memcpy(const_cast<uint32_t *>(clonewars_rts_body_input_failure),v,sizeof v);}game_sync_native_fault(15);}
void *__cdecl invoke(void *raw){
 auto &s=*static_cast<Scope *>(raw);
 s.machine.restore();s.original(s.object,s.state,s.flag);s.machine.capture();
 if(s.bound && live(s)){
  const int found=native_rts_body_source(s.object,s.state,s.source);if(found<0){reject(s,1);return nullptr;}
  if(found){
   float local[24],canonical[24];std::memcpy(local,static_cast<Byte *>(s.source.body)+0x40,64);std::memcpy(local+16,static_cast<Byte *>(s.source.dynamics)+0x20,32);std::memcpy(canonical,local,sizeof local);
   for(unsigned part=0;part<2;++part){
    SyncPhysicsChoice c{};c.kind=part?SYNC_PHYSICS_RTS_BODY_MOTION:SYNC_PHYSICS_RTS_BODY_BASIS;c.site=0x544b10;
    auto &v=c.spellit_body;v.clock=s.clock;v.body_class=s.source.body_class;v.piece_ordinal=s.source.ordinal;std::memcpy(v.key,s.source.key,sizeof v.key);std::memcpy(v.values,local+12*part,48);const auto before=c;
    if(!same(s)||physics_world_input(&c,&s.token)!=1||!same(s)||!physics_choice_same_source(&before,&c)){reject(s,2);return nullptr;}
    std::memcpy(canonical+12*part,v.values,48);
   }
   if(!same(s)){reject(s,3);return nullptr;}
   Machine helper;helper.capture();using Apply=void (__attribute__((thiscall)) *)(void *,const float *);
   s.machine.restore();reinterpret_cast<Apply>(0xa29570)(s.source.body,canonical);helper.restore();if(!same(s)){reject(s,4);return nullptr;}
   s.machine.restore();reinterpret_cast<Apply>(0x8b5cd0)(s.source.model,canonical+16);helper.restore();if(!same(s)){reject(s,5);return nullptr;}
   s.machine.restore();reinterpret_cast<Apply>(0x8b5e00)(s.source.model,canonical+20);helper.restore();if(!same(s)){reject(s,6);return nullptr;}
   ++clonewars_rts_body_input_debug[0];if(std::memcmp(local,canonical,sizeof local))++clonewars_rts_body_input_debug[1];
  }
 }
 return nullptr;
}
void __cdecl abort(void *){}
}
void rts_body_input_update(void *object,uint32_t state,uint32_t flag,RtsBodyUpdate original){Scope s{};s.machine.capture();s.object=object;s.state=state;s.flag=flag;s.original=original;s.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);s.bound=coherent_frame_get(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))!=0;constructor_lexical_seh(&s,invoke,abort);s.machine.restore();}

namespace {
struct VisibilityScope {CoherentFrameToken token;NativeRtsObjectSource source;void *object;uint32_t clock,delta;RtsVisibilityUpdate original;bool bound;Machine machine;};
bool visibility_live(const VisibilityScope &s){return coherent_frame_valid(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))&&s.clock==*reinterpret_cast<uint32_t *>(0xfb4b6c);}
void visibility_reject(const VisibilityScope &s,unsigned reason){if(!visibility_live(s))return;++clonewars_rts_visibility_input_debug[3];if(!clonewars_rts_visibility_input_failure[0]){const uint32_t v[]={reason,s.token.epoch,s.token.sequence,s.clock,reinterpret_cast<uintptr_t>(s.object),s.source.ordinal};std::memcpy(const_cast<uint32_t *>(clonewars_rts_visibility_input_failure),v,sizeof v);}game_sync_native_fault(15);}
void *__cdecl visibility_invoke(void *raw){
 auto &s=*static_cast<VisibilityScope *>(raw);
 if(s.bound && visibility_live(s)){
 if(!native_rts_object_source(s.object,s.source)){visibility_reject(s,1);return nullptr;}
 SyncPhysicsChoice c{};c.kind=SYNC_PHYSICS_RTS_VISIBILITY;c.site=0x5525e0;auto &v=c.world;v.clock=s.clock;v.value=static_cast<Byte *>(s.source.pad)[0x27d];std::memcpy(v.source_name,s.source.key,sizeof v.source_name);v.gizmo_class=s.source.object_class;v.gizmo_ordinal=s.source.ordinal;const auto before=c;
 if(physics_world_input(&c,&s.token)!=1||!visibility_live(s)){visibility_reject(s,2);return nullptr;}
 NativeRtsObjectSource now{};
 if(!native_rts_object_source(s.object,now)||std::memcmp(&s.source,&now,sizeof now)||!physics_choice_same_source(&before,&c)){visibility_reject(s,3);return nullptr;}
 static_cast<Byte *>(s.source.pad)[0x27d]=static_cast<Byte>(v.value);++clonewars_rts_visibility_input_debug[0];if(v.value!=before.world.value)++clonewars_rts_visibility_input_debug[1];
 }
 s.machine.restore();s.original(s.object,s.delta);s.machine.capture();return nullptr;
}
}
void rts_visibility_input_update(void *object,uint32_t delta,RtsVisibilityUpdate original){VisibilityScope s{};s.machine.capture();s.object=object;s.delta=delta;s.original=original;s.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);s.bound=coherent_frame_get(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))!=0;constructor_lexical_seh(&s,visibility_invoke,abort);s.machine.restore();}
