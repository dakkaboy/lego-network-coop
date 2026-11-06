#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <algorithm>
#include <cmath>

extern "C" {
#include "coherent_frame_fence.h"
}
#include "spawn_timer_sync.h"

namespace {

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
    if (frame->sequence!=1) return 1;
    constexpr auto prepare=COHERENT_PHASE_BIT(COHERENT_PREPARE);
    if (token->frame!=frame || !coherent_frame_valid(token,prepare)) return 0;
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
