#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <algorithm>
#include <cmath>
#include <cstring>

extern "C" {
#include "coherent_frame_fence.h"
}
#include "spawn_timer_sync.h"
#include "rts_order_input_sync.h"
#include "rts_generator_input_sync.h"
#include "rts_body_input_sync.h"

namespace {

using RtsOrderUpdate = void (__attribute__((thiscall)) *)(void *,float);
using RtsTimerSet = void (__attribute__((thiscall)) *)(void *,uint32_t);
using ModuleTimerChoose = float (__attribute__((thiscall)) *)(char *);
RtsOrderUpdate original_rts_order,original_rts_generator;
RtsTimerSet original_rts_timer_set;
RtsBodyUpdate original_rts_body;
RtsVisibilityUpdate original_rts_visibility;
void __attribute__((thiscall)) rts_visibility_hook(void *object,uint32_t delta){rts_visibility_input_update(object,delta,original_rts_visibility);}
void __attribute__((thiscall)) rts_body_hook(void *object,uint32_t state,uint32_t flag){rts_body_input_update(object,state,flag,original_rts_body);}
ModuleTimerChoose original_module_timer_choose;
__attribute__((used)) const uintptr_t rts_spawn_ground_query asm("rts_spawn_ground_query")=0x52a580;

__attribute__((naked)) void rts_spawn_ground_query_hook() {
    // The stock query only supplies XYZ. Both producer callers copy XYZW on
    // success, so seed the query's W from their already initialized transform.
    __asm__ volatile(
        "pushl %edx\n\t"
        "movl 0xa8(%esp), %edx\n\t"
        "movl %edx, 0xc(%eax)\n\t"
        "popl %edx\n\t"
        "jmpl *rts_spawn_ground_query");
}
struct SpawnTimerFrame {
    SyncFrame *frame;
    char *teams[SYNC_MAX_RTS_TEAMS];
    uint32_t applied,choice_cursor;
    bool host,failed;
};
SpawnTimerFrame timer_frame;

extern "C" {
__declspec(dllexport) volatile uint32_t clonewars_rts_spawn_timer_debug[8];
__declspec(dllexport) volatile uint32_t clonewars_module_spawn_timer_debug[8];
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

bool registered_module(const char *object,const ModuleEntry &entry) {
    return accessible(object,0x70) && entry.kind==4 && entry.id && entry.object==object &&
        *reinterpret_cast<const uint32_t *>(object+8)==entry.id &&
        *reinterpret_cast<const ModuleEntry *const *>(object+0x68)==&entry &&
        *reinterpret_cast<const uint32_t *>(object+0x6c)==entry.generation;
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
    auto *&seen=timer_frame.teams[slot];
    if (seen) return seen==team;
    auto *timers=reinterpret_cast<float *>(team+0x1a28);
    if (!accessible(timers,sizeof(SyncRtsTeamTimers::remaining),true) ||
        !coherent_frame_valid(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))) return false;

    auto &frame=*timer_frame.frame;
    if (timer_frame.host) {
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
        ++timer_frame.applied;
        clonewars_rts_spawn_timer_debug[1]=clonewars_rts_spawn_timer_debug[1]+1;
    }
    seen=team;
    return true;
}

bool synchronize_timer_choice(const CoherentFrameToken &token,SyncSpawnTimerChoice local,
                              float &remaining,volatile uint32_t *debug) {
    if (!std::isfinite(remaining) || !coherent_frame_valid(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))) return false;
    auto &frame=*timer_frame.frame;
    if (timer_frame.host) {
        if (frame.spawn_timer_choice_count>=SYNC_MAX_SPAWN_TIMER_CHOICES) return false;
        local.remaining=remaining;
        frame.spawn_timer_choices[frame.spawn_timer_choice_count++]=local;
        debug[0]=debug[0]+1;
    } else {
        if (timer_frame.choice_cursor>=frame.spawn_timer_choice_count) return false;
        const auto &choice=frame.spawn_timer_choices[timer_frame.choice_cursor];
        if (choice.kind!=local.kind || choice.owner!=local.owner ||
            choice.selector!=local.selector || choice.serial!=local.serial) return false;
        if (std::memcmp(&remaining,&choice.remaining,sizeof(remaining))) {
            debug[2]=debug[2]+1;
            if (local.kind==SYNC_SPAWN_TIMER_MODULE) {
                debug[4]=token.sequence;
                debug[5]=local.owner;
                uint32_t bits;
                std::memcpy(&bits,&remaining,sizeof(bits));
                debug[6]=bits;
                std::memcpy(&bits,&choice.remaining,sizeof(bits));
                debug[7]=bits;
            }
        }
        remaining=choice.remaining;
        ++timer_frame.choice_cursor;
        debug[1]=debug[1]+1;
    }
    return true;
}

bool synchronize_rts_timer_choice(const CoherentFrameToken &token,char *team,uint32_t index) {
    uint32_t slot;
    if (index>=3 || !rts_team_slot(team,slot)) return false;
    auto *remaining=reinterpret_cast<float *>(team+0x1a28)+index;
    if (!accessible(remaining,sizeof(*remaining),true) || *remaining<2.0f || *remaining>4.0f) return false;
    return synchronize_timer_choice(token,{.kind=SYNC_SPAWN_TIMER_RTS,.owner=slot,.selector=index},
                                    *remaining,clonewars_rts_spawn_timer_debug+4);
}

bool synchronize_module_timer_choice(const CoherentFrameToken &token,const char *object,float &remaining) {
    if (!accessible(object,0x378)) return false;
    const auto *registry=*reinterpret_cast<char *volatile *>(0xe906b0);
    const auto *entry=*reinterpret_cast<const ModuleEntry *const *>(object+0x68);
    if (!registry || !entry) return false;
    const auto base=reinterpret_cast<uintptr_t>(registry)+8;
    const auto offset=reinterpret_cast<uintptr_t>(entry)-base;
    if (offset%sizeof(*entry) || offset/sizeof(*entry)>=SYNC_MAX_SPAWN_TIMERS ||
        !accessible(entry,sizeof(*entry)) || !registered_module(object,*entry)) return false;
    const auto type=*reinterpret_cast<const uint32_t *>(object+4);
    const auto serial=*reinterpret_cast<const uint32_t *>(object+0x374);
    return type && synchronize_timer_choice(token,{.kind=SYNC_SPAWN_TIMER_MODULE,.owner=entry->id,
        .selector=type,.serial=serial},remaining,clonewars_module_spawn_timer_debug);
}

float __attribute__((thiscall)) module_timer_choose_hook(char *object) {
    CoherentFrameToken token;
    constexpr auto phase=COHERENT_PHASE_BIT(COHERENT_DISPATCH);
    const bool synchronized=coherent_frame_get(&token,phase) && token.frame==timer_frame.frame;
    float remaining=original_module_timer_choose(object);
    const DWORD error=GetLastError();
    if (synchronized && coherent_frame_valid(&token,phase) && !timer_frame.failed &&
        !synchronize_module_timer_choice(token,object,remaining)) {
        timer_frame.failed=true;
        clonewars_module_spawn_timer_debug[3]=clonewars_module_spawn_timer_debug[3]+1;
    }
    SetLastError(error);
    return remaining;
}

void __attribute__((thiscall)) rts_timer_set_hook(void *team,uint32_t index) {
    CoherentFrameToken token;
    constexpr auto phase=COHERENT_PHASE_BIT(COHERENT_DISPATCH);
    const bool synchronized=coherent_frame_get(&token,phase) && token.frame==timer_frame.frame;
    // Both peers consume the native random draw even when the resulting cooldown differs.
    original_rts_timer_set(team,index);
    if (synchronized && coherent_frame_valid(&token,phase) && !timer_frame.failed &&
        !synchronize_rts_timer_choice(token,static_cast<char *>(team),index)) {
        timer_frame.failed=true;
        clonewars_rts_spawn_timer_debug[7]=clonewars_rts_spawn_timer_debug[7]+1;
    }
}

void __attribute__((thiscall)) rts_order_hook(void *order,float delta) {
    alignas(16) unsigned char fx[512];__asm__ volatile("fxsave %0":"=m"(fx)::"memory");
    const DWORD error=GetLastError();
    CoherentFrameToken token;
    if (coherent_frame_get(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)) &&
        token.sequence==1 && token.frame==timer_frame.frame) {
        if (timer_frame.failed){SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx):"memory");return;}
        if (!synchronize_rts_order(token,order)) {
            timer_frame.failed=true;
            clonewars_rts_spawn_timer_debug[3]=clonewars_rts_spawn_timer_debug[3]+1;
            SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx):"memory");
            return;
        }
    }
    uint32_t delta_bits;std::memcpy(&delta_bits,&delta,4);
    SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx):"memory");
    rts_order_input_update(order,delta_bits,reinterpret_cast<RtsOrderOriginal>(original_rts_order));
}

void __attribute__((thiscall)) rts_generator_hook(void *object,float delta) {
    uint32_t bits;std::memcpy(&bits,&delta,4);
    rts_generator_input_update(object,bits,reinterpret_cast<RtsGeneratorOriginal>(original_rts_generator));
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
        if (!registered_module(object,entry) || !accessible(remaining,sizeof(float),true)) return false;
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
    timer_frame={.frame=frame,.host=host!=0};
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
    return timer_frame.frame==frame && !timer_frame.failed &&
        (timer_frame.host || (timer_frame.applied==frame->rts_team_timer_count &&
            timer_frame.choice_cursor==frame->spawn_timer_choice_count));
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

static bool install_module_timer_hook() {
    constexpr uintptr_t call=0x504a20;
    constexpr uintptr_t target=0x483a90;
    constexpr unsigned char expected[]={0xe8,0x6b,0xf0,0xf7,0xff};
    auto *site=reinterpret_cast<unsigned char *>(call);
    DWORD protection;
    if (!accessible(site,sizeof(expected)) || std::memcmp(site,expected,sizeof(expected)) ||
        !VirtualProtect(site,sizeof(expected),PAGE_EXECUTE_READWRITE,&protection)) return false;
    original_module_timer_choose=reinterpret_cast<ModuleTimerChoose>(target);
    const auto relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(&module_timer_choose_hook)-call-5);
    std::memcpy(site+1,&relative,sizeof(relative));
    const bool flushed=FlushInstructionCache(GetCurrentProcess(),site,sizeof(expected));
    return VirtualProtect(site,sizeof(expected),protection,&protection) && flushed;
}

static bool install_pack_ground_query_hooks() {
    constexpr unsigned char first_native[]={0x8d,0x44,0x24,0x40,0x50,0xe8,0x12,0x25,0xfe,0xff};
    constexpr unsigned char second_native[]={0x8d,0x84,0x24,0xa0,0,0,0,0x50,0xe8,0xa0,0x1b,0xfe,0xff};
    auto *first=reinterpret_cast<unsigned char *>(0x548064);
    auto *second=reinterpret_cast<unsigned char *>(0x5489d3);
    const auto span=reinterpret_cast<uintptr_t>(second)-reinterpret_cast<uintptr_t>(first)+sizeof(second_native);
    DWORD protection;
    if (!accessible(first,span) || std::memcmp(first,first_native,sizeof(first_native)) ||
        std::memcmp(second,second_native,sizeof(second_native)) ||
        !VirtualProtect(first,span,PAGE_EXECUTE_READWRITE,&protection)) return false;
    for (auto *relative : {first+6,second+9}) {
        const auto displacement=static_cast<int32_t>(
            reinterpret_cast<uintptr_t>(&rts_spawn_ground_query_hook)-reinterpret_cast<uintptr_t>(relative+4));
        std::memcpy(relative,&displacement,sizeof(displacement));
    }
    const bool flushed=FlushInstructionCache(GetCurrentProcess(),first,span);
    return VirtualProtect(first,span,protection,&protection) && flushed;
}

int rts_spawn_timers_install(void) {
    constexpr unsigned char visibility_native[]={0x8b,0x91,0x38,0x02,0,0};
    constexpr unsigned char order_native[]={0x55,0x8b,0xec,0x83,0xe4,0xf0};
    constexpr unsigned char timer_native[]={0xd9,0x05,0x40,0x14,0xae,0x00};
    return install_rts_hook(0x5525e0,visibility_native,&rts_visibility_hook,original_rts_visibility) && install_rts_hook(0x544b10,order_native,&rts_body_hook,original_rts_body) && install_rts_hook(0x547d30,order_native,&rts_generator_hook,original_rts_generator) && rts_order_input_install() && install_rts_hook(0x55e2c0,order_native,&rts_order_hook,original_rts_order) &&
        install_rts_hook(0x50afc0,timer_native,&rts_timer_set_hook,original_rts_timer_set) &&
        install_module_timer_hook() && install_pack_ground_query_hooks();
}
