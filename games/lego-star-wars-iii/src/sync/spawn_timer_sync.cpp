#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <algorithm>
#include <cmath>
#include <cstring>

extern "C" {
#include "coherent_frame_fence.h"
}
#include "spawn_timer_sync.h"

namespace {

using RtsOrderUpdate = void (__attribute__((thiscall)) *)(void *,float);
using RtsTimerSet = void (__attribute__((thiscall)) *)(void *,uint32_t);
RtsOrderUpdate original_rts_order;
RtsTimerSet original_rts_timer_set;
struct RtsTimerFrame {
    SyncFrame *frame;
    char *teams[SYNC_MAX_RTS_TEAMS];
    uint32_t applied,choice_cursor;
    bool host,failed;
};
RtsTimerFrame rts_bootstrap;

extern "C" {
__declspec(dllexport) volatile uint32_t clonewars_rts_spawn_timer_debug[8];
}

struct ModuleEntry {
    uint32_t id, generation;
    char *object;
    uint32_t kind, flags;
};

struct LocalTimer {
    SyncSpawnTimer state;
    float *remaining;
};

static_assert(sizeof(ModuleEntry)==20);

bool accessible(const void *pointer, SIZE_T size, bool write = false) {
    MEMORY_BASIC_INFORMATION info;
    if (!pointer || !VirtualQuery(pointer,&info,sizeof(info)) || info.State!=MEM_COMMIT ||
        (info.Protect & (PAGE_GUARD | PAGE_NOACCESS))) return false;
    if (write && !(info.Protect & (PAGE_READWRITE | PAGE_WRITECOPY |
                                   PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY))) return false;
    const auto offset=reinterpret_cast<uintptr_t>(pointer)-reinterpret_cast<uintptr_t>(info.BaseAddress);
    return offset<info.RegionSize && size<=info.RegionSize-offset;
}

bool rts_team_slot(char *team,uint32_t &slot) {
    if (!accessible(team,0x1a34) || *reinterpret_cast<const uintptr_t *>(team)!=0xaef0fc) return false;
    const auto *descriptor=*reinterpret_cast<const char *const *>(team+0x1c);
    if (!accessible(descriptor,0x34)) return false;
    slot=*reinterpret_cast<const uint32_t *>(descriptor+0x30);
    return slot<SYNC_MAX_RTS_TEAMS;
}

bool synchronize_rts_order(const CoherentFrameToken &token,void *order) {
    auto *team=*reinterpret_cast<char **>(static_cast<char *>(order)+0x28);
    uint32_t slot;
    if (!rts_team_slot(team,slot)) return false;
    auto *&seen=rts_bootstrap.teams[slot];
    if (seen) return seen==team;
    auto *timers=reinterpret_cast<float *>(team+0x1a28);
    if (!accessible(timers,sizeof(SyncRtsTeamTimers::remaining),true) ||
        !coherent_frame_valid(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))) return false;

    auto &frame=*rts_bootstrap.frame;
    if (rts_bootstrap.host) {
        if (frame.rts_team_timer_count>=SYNC_MAX_RTS_TEAMS) return false;
        SyncRtsTeamTimers entry{.slot=slot};
        std::memcpy(entry.remaining,timers,sizeof(entry.remaining));
        for (float remaining : entry.remaining) if (!std::isfinite(remaining)) return false;
        frame.rts_team_timers[frame.rts_team_timer_count++]=entry;
        clonewars_rts_spawn_timer_debug[0]=clonewars_rts_spawn_timer_debug[0]+1;
    } else {
        const SyncRtsTeamTimers *begin=frame.rts_team_timers;
        const auto *end=begin+frame.rts_team_timer_count;
        const auto *entry=std::find_if(begin,end,[slot](const SyncRtsTeamTimers &state) {
            return state.slot==slot;
        });
        if (entry==end) return false;
        // Loading can draw different random delays before the first network frame is admitted.
        if (std::memcmp(timers,entry->remaining,sizeof(entry->remaining)))
            clonewars_rts_spawn_timer_debug[2]=clonewars_rts_spawn_timer_debug[2]+1;
        std::memcpy(timers,entry->remaining,sizeof(entry->remaining));
        ++rts_bootstrap.applied;
        clonewars_rts_spawn_timer_debug[1]=clonewars_rts_spawn_timer_debug[1]+1;
    }
    seen=team;
    return true;
}

bool synchronize_rts_timer_choice(const CoherentFrameToken &token,char *team,uint32_t index) {
    uint32_t slot;
    if (index>=3 || !rts_team_slot(team,slot)) return false;
    auto *remaining=reinterpret_cast<float *>(team+0x1a28)+index;
    if (!accessible(remaining,sizeof(*remaining),true) ||
        !coherent_frame_valid(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))) return false;
    auto &frame=*rts_bootstrap.frame;
    if (rts_bootstrap.host) {
        if (frame.rts_timer_choice_count>=SYNC_MAX_RTS_TIMER_CHOICES ||
            !std::isfinite(*remaining) || *remaining<2.0f || *remaining>4.0f) return false;
        frame.rts_timer_choices[frame.rts_timer_choice_count++]={slot,index,*remaining};
        clonewars_rts_spawn_timer_debug[4]=clonewars_rts_spawn_timer_debug[4]+1;
    } else {
        if (rts_bootstrap.choice_cursor>=frame.rts_timer_choice_count) return false;
        const auto &choice=frame.rts_timer_choices[rts_bootstrap.choice_cursor];
        if (choice.slot!=slot || choice.index!=index) return false;
        if (*remaining!=choice.remaining)
            clonewars_rts_spawn_timer_debug[6]=clonewars_rts_spawn_timer_debug[6]+1;
        *remaining=choice.remaining;
        ++rts_bootstrap.choice_cursor;
        clonewars_rts_spawn_timer_debug[5]=clonewars_rts_spawn_timer_debug[5]+1;
    }
    return true;
}

void __attribute__((thiscall)) rts_timer_set_hook(void *team,uint32_t index) {
    CoherentFrameToken token;
    constexpr auto phase=COHERENT_PHASE_BIT(COHERENT_DISPATCH);
    const bool synchronized=coherent_frame_get(&token,phase) && token.frame==rts_bootstrap.frame;
    // Both peers consume the native random draw even when the resulting cooldown differs.
    original_rts_timer_set(team,index);
    if (synchronized && coherent_frame_valid(&token,phase) && !rts_bootstrap.failed &&
        !synchronize_rts_timer_choice(token,static_cast<char *>(team),index)) {
        rts_bootstrap.failed=true;
        clonewars_rts_spawn_timer_debug[7]=clonewars_rts_spawn_timer_debug[7]+1;
    }
}

void __attribute__((thiscall)) rts_order_hook(void *order,float delta) {
    CoherentFrameToken token;
    if (coherent_frame_get(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)) &&
        token.sequence==1 && token.frame==rts_bootstrap.frame) {
        if (rts_bootstrap.failed) return;
        if (!synchronize_rts_order(token,order)) {
            rts_bootstrap.failed=true;
            clonewars_rts_spawn_timer_debug[3]=clonewars_rts_spawn_timer_debug[3]+1;
            return;
        }
    }
    original_rts_order(order,delta);
}

bool collect(ModuleEntry *entries, LocalTimer *timers, uint32_t &count) {
    if (!entries) return true;
    if (!accessible(entries,sizeof(ModuleEntry)*SYNC_MAX_SPAWN_TIMERS)) return false;
    for (uint32_t i=0;i<SYNC_MAX_SPAWN_TIMERS;++i) {
        const auto &entry=entries[i];
        if (entry.kind!=4 || !entry.id || !entry.object) continue;
        const char *object=entry.object;
        if (!accessible(object,sizeof(uintptr_t))) return false;
        const auto vtable=*reinterpret_cast<const uintptr_t *>(object);
        // These native classes share the randomized timer checked by their spawn gates.
        if (vtable!=0xae60c4 && vtable!=0xae62a4 && vtable!=0xae6a94) continue;
        auto *remaining=reinterpret_cast<float *>(entry.object+0x348);
        if (!accessible(object,0x70) || !accessible(remaining,sizeof(float),true) ||
            *reinterpret_cast<const uint32_t *>(object+8)!=entry.id ||
            *reinterpret_cast<ModuleEntry *const *>(object+0x68)!=&entry ||
            *reinterpret_cast<const uint32_t *>(object+0x6c)!=entry.generation) return false;
        const auto type=*reinterpret_cast<const uint32_t *>(object+4);
        if (!type || !std::isfinite(*remaining)) return false;
        timers[count++]={{entry.id,type,*remaining},remaining};
    }
    std::sort(timers,timers+count,[](const LocalTimer &a,const LocalTimer &b) {
        return a.state.id<b.state.id;
    });
    for (uint32_t i=1;i<count;++i) if (timers[i-1].state.id==timers[i].state.id) return false;
    return true;
}

}

int spawn_timers_prepare(const CoherentFrameToken *token, SyncFrame *frame, int host) {
    constexpr auto prepare=COHERENT_PHASE_BIT(COHERENT_PREPARE);
    if (token->frame!=frame || !coherent_frame_valid(token,prepare)) return 0;
    rts_bootstrap={.frame=frame,.host=host!=0};
    if (frame->sequence!=1) return 1;
    const auto registry=*reinterpret_cast<char *volatile *>(0xe906b0);
    auto *entries=registry ? reinterpret_cast<ModuleEntry *>(registry+8) : nullptr;
    LocalTimer timers[SYNC_MAX_SPAWN_TIMERS];
    uint32_t count=0;
    if (!collect(entries,timers,count) || !coherent_frame_valid(token,prepare)) return 0;
    if (host) {
        for (uint32_t i=0;i<count;++i) frame->spawn_timers[i]=timers[i].state;
        frame->spawn_timer_count=count;
        return 1;
    }
    if (count!=frame->spawn_timer_count) return 0;
    for (uint32_t i=0;i<count;++i) {
        const auto &remote=frame->spawn_timers[i];
        const auto &local=timers[i].state;
        if (remote.id!=local.id || remote.type!=local.type) return 0;
    }
    if (registry!=*reinterpret_cast<char *volatile *>(0xe906b0) ||
        !coherent_frame_valid(token,prepare)) return 0;
    for (uint32_t i=0;i<count;++i) *timers[i].remaining=frame->spawn_timers[i].remaining;
    return 1;
}

int rts_spawn_timers_finish(const SyncFrame *frame) {
    return rts_bootstrap.frame==frame && !rts_bootstrap.failed &&
        (rts_bootstrap.host || (rts_bootstrap.applied==frame->rts_team_timer_count &&
            rts_bootstrap.choice_cursor==frame->rts_timer_choice_count));
}

template<typename Function,size_t size>
bool install_rts_hook(uintptr_t address,const unsigned char (&native)[size],Function hook,Function &original) {
    auto *entry=reinterpret_cast<unsigned char *>(address);
    if (!accessible(entry,size) || std::memcmp(entry,native,size)) return 0;
    auto *bridge=static_cast<unsigned char *>(VirtualAlloc(nullptr,size+5,MEM_RESERVE|MEM_COMMIT,PAGE_EXECUTE_READWRITE));
    if (!bridge) return 0;
    DWORD protection;
    if (!VirtualProtect(entry,size,PAGE_EXECUTE_READWRITE,&protection)) {
        VirtualFree(bridge,0,MEM_RELEASE);
        return 0;
    }
    std::memcpy(bridge,native,size);
    bridge[size]=0xe9;
    const auto back=static_cast<int32_t>(reinterpret_cast<uintptr_t>(entry)-reinterpret_cast<uintptr_t>(bridge)-5);
    std::memcpy(bridge+size+1,&back,sizeof(back));
    FlushInstructionCache(GetCurrentProcess(),bridge,size+5);
    original=reinterpret_cast<Function>(bridge);
    const auto forward=static_cast<int32_t>(reinterpret_cast<uintptr_t>(hook)-reinterpret_cast<uintptr_t>(entry)-5);
    entry[0]=0xe9;
    std::memcpy(entry+1,&forward,sizeof(forward));
    entry[5]=0x90;
    FlushInstructionCache(GetCurrentProcess(),entry,size);
    VirtualProtect(entry,size,protection,&protection);
    return 1;
}

int rts_spawn_timers_install(void) {
    constexpr unsigned char order_native[]={0x55,0x8b,0xec,0x83,0xe4,0xf0};
    constexpr unsigned char timer_native[]={0xd9,0x05,0x40,0x14,0xae,0x00};
    return install_rts_hook(0x55e2c0,order_native,&rts_order_hook,original_rts_order) &&
        install_rts_hook(0x50afc0,timer_native,&rts_timer_set_hook,original_rts_timer_set);
}
