#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "rts_order_input_sync.h"
#include "physics_input_sync.h"
#include "../engine/native_rts_order_source.h"
#include "../engine/rts_order_ready_thunk.h"
extern "C" {
#include "game_sync.h"
#include "../engine/constructor_lexical_seh.h"
}
extern "C" {
__declspec(dllexport) volatile uint32_t clonewars_rts_order_input_debug[8],clonewars_rts_order_input_failure[16];
__attribute__((used)) static volatile uintptr_t rts_order_ready_resume=0x55e661;
}
namespace {
struct Machine {alignas(16) unsigned char fx[512];DWORD error;
 void capture(){__asm__ volatile("fxsave %0":"=m"(fx)::"memory");error=GetLastError();}
 void restore()const{SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx):"memory");}};
struct Scope {Scope *previous;CoherentFrameToken token;NativeRtsOrderSource source;void *order;uint32_t clock,delta;RtsOrderOriginal original;bool bound;Machine machine;};
thread_local Scope *current;
bool live(const Scope &s){return coherent_frame_valid(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)) &&
    *reinterpret_cast<uint32_t *>(0xfb4b6c)==s.clock && native_rts_order_source_live(&s.source);}
void reject(const Scope &s,unsigned reason){
    ++clonewars_rts_order_input_debug[3];
    if(!clonewars_rts_order_input_failure[0]){
        const uint32_t row[]={reason,s.token.epoch,s.token.sequence,s.clock,reinterpret_cast<uintptr_t>(s.order),
            s.source.team_slot,s.source.building_id,s.source.order_class};
        std::memcpy(const_cast<uint32_t *>(clonewars_rts_order_input_failure),row,sizeof row);
    }
    game_sync_native_fault(15);
}
SyncPhysicsChoice input(const Scope &s,uint32_t site){
    SyncPhysicsChoice c{};c.kind=SYNC_PHYSICS_RTS_ORDER;c.site=site;
    c.rts_order.clock=s.clock;c.rts_order.team_slot=s.source.team_slot;
    c.rts_order.building_id=s.source.building_id;c.rts_order.order_class=s.source.order_class;return c;
}
bool exchange(Scope &s,SyncPhysicsChoice &c){
    const auto before=c;
    if(!live(s)){reject(s,2);return false;}
    if(physics_world_input(&c,&s.token)!=1){reject(s,3);return false;}
    if(!live(s)||!physics_choice_same_source(&before,&c)){reject(s,4);return false;}
    ++clonewars_rts_order_input_debug[0];
    if(std::memcmp(&before.rts_order.state,&c.rts_order.state,20))++clonewars_rts_order_input_debug[c.site==0x55e65c?2:1];
    return true;
}
void *__cdecl invoke(void *raw){
    auto &s=*static_cast<Scope *>(raw);
    if(s.bound){
        if(!native_rts_order_source(s.order,&s.source)){reject(s,1);return nullptr;}
        auto c=input(s,0x55e2c0);auto &v=c.rts_order;auto *o=static_cast<unsigned char *>(s.order);
        std::memcpy(&v.state,o+0x2e8,12);std::memcpy(&v.progress,o+0x2d4,4);
        if(!exchange(s,c))return nullptr;
        std::memcpy(o+0x2e8,&v.state,12);std::memcpy(o+0x2d4,&v.progress,4);
    }
    s.machine.restore();s.original(s.order,s.delta);s.machine.capture();return nullptr;
}
void __cdecl abort(void *raw){current=static_cast<Scope *>(raw)->previous;}
}
extern "C" uint32_t __cdecl native_rts_order_ready(void *order,uint32_t local){
    const DWORD error=GetLastError();uint32_t result=local;Scope *s=current;
    if(s && s->bound){
        if(s->order!=order || !live(*s))reject(*s,5);
        else {auto c=input(*s,0x55e65c);c.rts_order.ready=local&2;
            if(exchange(*s,c))result=(local&~2u)|c.rts_order.ready;
            ++clonewars_rts_order_input_debug[4];}
    }
    SetLastError(error);return result;
}
extern "C" __attribute__((naked)) void native_rts_order_ready_bridge(){
    __asm__ volatile(RTS_ORDER_READY_ASM);
}
void rts_order_input_update(void *order,uint32_t delta,RtsOrderOriginal original){
    Scope s;s.machine.capture();s.token={};s.source={};s.previous=current;s.order=order;s.delta=delta;s.original=original;
    s.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);s.bound=coherent_frame_get(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))!=0;
    current=&s;constructor_lexical_seh(&s,invoke,abort);current=s.previous;s.machine.restore();
}
int rts_order_input_install(){
    static bool installed;if(installed)return 1;
    auto *p=reinterpret_cast<unsigned char *>(0x55e65c);const unsigned char expected[]={0x8a,0x48,0x62,0xd0,0xe9};
    if(std::memcmp(p,expected,5))return 0;
    DWORD old;if(!VirtualProtect(p,5,PAGE_EXECUTE_READWRITE,&old))return 0;
    const int32_t relative=reinterpret_cast<uintptr_t>(native_rts_order_ready_bridge)-reinterpret_cast<uintptr_t>(p)-5;
    p[0]=0xe9;std::memcpy(p+1,&relative,4);FlushInstructionCache(GetCurrentProcess(),p,5);VirtualProtect(p,5,old,&old);installed=true;return 1;
}
