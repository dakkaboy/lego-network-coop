#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include <cmath>
#include "object_progress_sync.h"
extern "C" {
#include "game_sync.h"
#include "../net/lan.h"
__declspec(dllexport) extern volatile uint32_t clonewars_object_progress_debug[4];
__declspec(dllexport) extern volatile uint32_t clonewars_object_progress_failure[12];
}

namespace {
using NativeUpdate=void (__attribute__((thiscall)) *)(void *,uint32_t);
using NativeRegen=uint8_t (__attribute__((thiscall)) *)(void *,uint8_t,uint8_t,uint32_t,int);
const auto update=reinterpret_cast<NativeUpdate>(0x87c930);
const auto regenerate=reinterpret_cast<NativeRegen>(0x859240);
struct Source {
    CoherentFrameToken token;
    unsigned char *world,*container,*handle,*table,*provider,*manager;
    uint32_t index,count;
    float delta;
    bool pending;
};
thread_local Source source;
bool installed;

bool readable(const void *p,size_t size) {
    MEMORY_BASIC_INFORMATION m;
    const auto address=reinterpret_cast<uintptr_t>(p);
    return p && size && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && address+size>=address &&
        address+size<=reinterpret_cast<uintptr_t>(m.BaseAddress)+m.RegionSize;
}
template<class T> T field(const unsigned char *p,size_t offset) {
    T value;std::memcpy(&value,p+offset,sizeof(value));return value;
}
bool networked() {return lan_status()==LAN_CONNECTED && game_sync_epoch()!=0;}
bool live(const CoherentFrameToken &token) {
    return coherent_frame_valid(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))!=0;
}
bool witness(Source &s) {
    if (!readable(s.world,0x22e8)) return false;
    s.container=field<unsigned char *>(s.world,0x22e4);
    s.handle=field<unsigned char *>(s.world,0x400);
    s.provider=*reinterpret_cast<unsigned char **>(0xe901dc);
    const auto registry=*reinterpret_cast<unsigned char **>(0xe90184);
    if (!readable(s.container,0x10) || field<void *>(s.container,0xc)!=s.world ||
        !readable(s.handle,4) || !readable(s.provider,0x3c) || !readable(registry,0x2c)) return false;
    s.index=field<uint32_t>(s.provider,0x38);s.count=field<uint32_t>(registry,0x28);
    s.table=field<unsigned char *>(s.handle,0);
    if (!s.count || s.count>4096 || s.index>=s.count || !readable(s.table,s.count*4)) return false;
    s.manager=field<unsigned char *>(s.table,s.index*4);
    return readable(s.manager,0x28) && field<uintptr_t>(s.manager,0)==0xc4c8ec;
}
bool same_witness(const Source &s) {
    Source current{};current.world=s.world;
    return witness(current) && current.container==s.container && current.handle==s.handle &&
        current.table==s.table && current.provider==s.provider && current.manager==s.manager &&
        current.index==s.index && current.count==s.count;
}
bool member(const Source &s,const unsigned char *object) {
    auto *current=field<unsigned char *>(s.manager,0x24);
    for (unsigned n=0;current && n<65536;++n) {
        if (!readable(current,0x28)) return false;
        if (current==object) return true;
        current=field<unsigned char *>(current,0x24);
    }
    return false;
}
void reject(uint32_t reason,const Source &s) {
    ++clonewars_object_progress_debug[3];
    if (!clonewars_object_progress_failure[2]) {
        uint32_t delta;std::memcpy(&delta,&s.delta,4);
        const uint32_t values[]={s.token.epoch,s.token.sequence,reason,
            *reinterpret_cast<uint32_t *>(0xfb4b6c),reinterpret_cast<uintptr_t>(s.world),
            *reinterpret_cast<uint32_t *>(0xfb4a20),reinterpret_cast<uintptr_t>(s.manager),
            reinterpret_cast<uintptr_t>(s.provider),s.index,s.count,delta,s.pending?1u:0u};
        std::memcpy(const_cast<uint32_t *>(clonewars_object_progress_failure),values,sizeof(values));
    }
    game_sync_native_fault(15);
}
struct MachineState {
    alignas(16) unsigned char fx[512];DWORD error;
    void capture(){__asm__ volatile("fxsave %0":"=m"(fx)::"memory");error=GetLastError();}
    void restore()const{SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx):"memory");}
};
void __attribute__((fastcall)) update_hook(void *manager,void *,uint32_t delta_bits) {
    MachineState machine;machine.capture();
    volatile uint32_t native_delta=delta_bits;
    float delta;std::memcpy(&delta,&delta_bits,4);
    CoherentFrameToken token{};
    const bool bound=networked() && coherent_frame_get(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH));
    Source next{};next.token=token;next.delta=delta;
    if (bound) {
        next.world=*reinterpret_cast<unsigned char **>(0xfb4a20);
        if (!std::isfinite(delta) || delta<0 || delta>.1f || !witness(next) || next.manager!=manager ||
            (source.pending && live(source.token))) reject(1,next);
        else next.pending=true;
    }
    machine.restore();update(manager,native_delta);machine.capture();
    if (next.pending && live(next.token)) {
        if (same_witness(next)) source=next;
        else reject(2,next);
    }
    machine.restore();
}
uint8_t __attribute__((fastcall)) render_regen(void *provider,void *,uint8_t current,uint8_t maximum,float delta,int enabled) {
    MachineState machine;machine.capture();
    const bool separate=networked();
    if (separate) ++clonewars_object_progress_debug[1];
    uint32_t delta_bits=0;if (!separate) std::memcpy(&delta_bits,&delta,4);
    machine.restore();
    // Rendering can repeat while a peer waits for a simulation step.
    return regenerate(provider,current,maximum,delta_bits,separate?0:enabled);
}
}

extern "C" {
__declspec(dllexport) volatile uint32_t clonewars_object_progress_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_object_progress_failure[12];
}

int object_progress_world_complete(void *world,const CoherentFrameToken *token) {
    if (!token || !live(*token)) return 0;
    if (source.pending && !live(source.token)) source={};
    if (!source.pending) return 1;
    const Source s=source;source={};
    if (s.world!=world || s.token.frame!=token->frame || s.token.owner!=token->owner ||
        s.token.owner_nonce!=token->owner_nonce || s.token.release!=token->release ||
        s.token.cohort_nonce!=token->cohort_nonce || s.token.thread!=token->thread ||
        s.token.epoch!=token->epoch || s.token.sequence!=token->sequence || !same_witness(s)) {
        reject(3,s);return 0;
    }
    auto *g=field<unsigned char *>(s.manager,0x24);
    unsigned count=0;
    while (g) {
        if (++count>65536 || !live(s.token) || !same_witness(s) || !readable(g,0xf4)) {reject(4,s);return 0;}
        auto *next=field<unsigned char *>(g,0x24);
        auto *provider=field<unsigned char *>(g,0xf0);
        if (!g[0x73] && field<void *>(g,0x88) && (field<uint16_t>(g,0x62)&3)==3 && provider) {
            auto *recipe=field<unsigned char *>(g,0x84);
            if (!readable(provider,0x18) || !readable(recipe,0x6c)) {reject(5,s);return 0;}
            const auto type=field<uintptr_t>(g,0);
            auto *model=field<void *>(g,0x88);
            uint32_t provider_binding[4];std::memcpy(provider_binding,provider+8,sizeof(provider_binding));
            const uint8_t current=g[0xec],maximum=recipe[0x6b];
            uint32_t delta_bits;std::memcpy(&delta_bits,&s.delta,4);
            const uint8_t result=regenerate(provider,current,maximum,delta_bits,1);
            if (!live(s.token) || !same_witness(s) || !readable(g,0xf4) ||
                !readable(provider,0x18) || !readable(recipe,0x6c) || recipe[0x6b]!=maximum ||
                std::memcmp(provider_binding,provider+8,sizeof(provider_binding)) ||
                field<uintptr_t>(g,0)!=type || field<void *>(g,0x88)!=model ||
                g[0x73] || (field<uint16_t>(g,0x62)&3)!=3 ||
                field<void *>(g,0xf0)!=provider || field<void *>(g,0x84)!=recipe ||
                field<void *>(g,0x24)!=next || g[0xec]!=current) {reject(6,s);return 0;}
            if (result!=current) {
                if (!member(s,g) || !live(s.token)) {reject(7,s);return 0;}
                g[0xec]=result;
            }
            ++clonewars_object_progress_debug[0];
        }
        g=next;
    }
    ++clonewars_object_progress_debug[2];return live(s.token);
}

int object_progress_install(void) {
    if (installed) return 1;
    auto *slot=reinterpret_cast<uintptr_t *>(0xc4c92c);
    auto *call=reinterpret_cast<unsigned char *>(0x85cacb);
    int32_t relative;
    if (!readable(slot,4) || *slot!=0x87c930 || !readable(call,5) || call[0]!=0xe8) return 0;
    std::memcpy(&relative,call+1,4);
    if (reinterpret_cast<uintptr_t>(call)+5+relative!=0x859240) return 0;
    DWORD call_protection,slot_protection,ignored;
    if (!VirtualProtect(call,5,PAGE_EXECUTE_READWRITE,&call_protection)) return 0;
    if (!VirtualProtect(slot,4,PAGE_READWRITE,&slot_protection)) {
        VirtualProtect(call,5,call_protection,&ignored);return 0;
    }
    relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(render_regen)-reinterpret_cast<uintptr_t>(call)-5);
    std::memcpy(call+1,&relative,4);FlushInstructionCache(GetCurrentProcess(),call,5);
    *slot=reinterpret_cast<uintptr_t>(update_hook);
    VirtualProtect(call,5,call_protection,&ignored);VirtualProtect(slot,4,slot_protection,&ignored);
    installed=true;return 1;
}
