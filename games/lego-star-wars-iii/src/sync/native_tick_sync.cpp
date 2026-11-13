#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include "native_tick_sync.h"
#include "../engine/native_gizmo_source.h"
#include "../engine/native_global_pack_source.h"
extern "C" {
#include "game_sync.h"
#include "entity_sync.h"
#include "world_vars.h"
#include "../net/lan.h"
#include "../engine/native_tick_gate_thunk.h"
#include "../engine/native_world_admission_thunk.h"
#include "../engine/native_flow_request_thunk.h"
}

namespace {
SyncFrame *frame;
CoherentFrameToken token;
uint32_t cursor;
bool active,host,failed;
bool same(const CoherentFrameToken &a,const CoherentFrameToken &b) {
    return a.owner==b.owner && a.owner_nonce==b.owner_nonce && a.cohort_nonce==b.cohort_nonce &&
        a.thread==b.thread && a.release==b.release && a.epoch==b.epoch && a.sequence==b.sequence && a.frame==b.frame;
}
bool live(uint32_t phases) {
    return active && frame && token.frame==frame && world_vars_cohort_valid(&token,phases);
}
bool readable(const void *raw,size_t size) {
    MEMORY_BASIC_INFORMATION memory;
    const auto address=reinterpret_cast<uintptr_t>(raw);
    return raw && VirtualQuery(raw,&memory,sizeof memory) && memory.State==MEM_COMMIT &&
        !(memory.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && address+size>=address &&
        address+size<=reinterpret_cast<uintptr_t>(memory.BaseAddress)+memory.RegionSize;
}
uintptr_t pointer(const void *raw,size_t offset=0) {
    uintptr_t value;std::memcpy(&value,static_cast<const unsigned char *>(raw)+offset,sizeof value);return value;
}
void hash_byte(uint32_t hash[2],unsigned char value) {
    hash[0]=(hash[0]^value)*16777619u;hash[1]=(hash[1]^value)*0x85ebca6bu;
}
bool hash_text(uint32_t hash[2],const char *text) {
    if (!text) return false;
    for (unsigned i=0;i<512;++i) {
        if (!readable(text+i,1)) return false;
        const auto value=static_cast<unsigned char>(text[i]);hash_byte(hash,value);
        if (!value) return i!=0;
    }
    return false;
}
bool descriptor_witness(uint32_t hash[2],const unsigned char *descriptor) {
    if (!readable(descriptor,0xc0)) return false;
    int16_t level;uint16_t ordinal;
    std::memcpy(&level,descriptor+0x10,2);std::memcpy(&ordinal,descriptor+0x16,2);
    if (level < -1 || level>=4096) return false;
    if (!hash_text(hash,reinterpret_cast<const char *>(pointer(descriptor,0xc))) ||
        !hash_text(hash,reinterpret_cast<const char *>(pointer(descriptor,8)))) return false;
    for (unsigned i=0;i<2;++i) hash_byte(hash,static_cast<uint16_t>(level)>>(8*i));
    for (unsigned i=0;i<2;++i) hash_byte(hash,ordinal>>(8*i));
    return true;
}
bool clock_witness(void *track,uint32_t hash[2],int level) {
    auto *world=*reinterpret_cast<unsigned char **>(0xfb4a20);
    auto *manager=*reinterpret_cast<unsigned char **>(0xe901f4);
    auto *tracks=*reinterpret_cast<unsigned char **>(0xfa1c98);
    if (!readable(world,0x224) || !readable(manager,0x90) || !readable(tracks,0x34)) return false;
    auto *definition=reinterpret_cast<unsigned char *>(pointer(world,0x220));
    if (!readable(definition,0x96) || *reinterpret_cast<int16_t *>(definition+0x94)!=level) return false;
    auto *descriptor=reinterpret_cast<unsigned char *>(pointer(manager,0x84));
    auto *instance=reinterpret_cast<unsigned char *>(pointer(manager,0x88));
    if (!readable(instance,0x14)) return false;
    auto *request=reinterpret_cast<unsigned char *>(pointer(instance,0xc));
    if (!readable(request,0x18) || pointer(request,8)!=reinterpret_cast<uintptr_t>(descriptor)) return false;
    auto *provider=reinterpret_cast<unsigned char *>(pointer(request,0x14));
    if (!readable(provider,0xc)) return false;
    auto *owner=reinterpret_cast<unsigned char *>(pointer(provider));
    uint32_t limit;std::memcpy(&limit,manager+0x30,4);
    if (!limit || limit>4096) return false;
    auto *node=reinterpret_cast<unsigned char *>(pointer(manager,0x28));
    unsigned current_matches=0,owner_matches=0;
    for (unsigned i=0;node && i<limit;++i) {
        if (!readable(node,0xc0)) return false;
        current_matches+=node==descriptor;owner_matches+=node==owner;
        node=reinterpret_cast<unsigned char *>(pointer(node,4));
    }
    if (node || current_matches!=1 || owner_matches!=1) return false;
    auto *components=reinterpret_cast<unsigned char *>(pointer(owner,0xa0));
    if (!readable(components,0x24)) return false;
    const auto handle=pointer(components,0x20);
    if (!handle) return false;
    const void *matched=nullptr;
    for (unsigned i=0;i<3;++i) {
        auto *entry=reinterpret_cast<const void *>(pointer(tracks,0x28+4*i));
        if (!entry) continue;
        if (!readable(entry,0xc)) return false;
        if (pointer(entry,4)!=handle) continue;
        if (matched) return false;
        matched=entry;
    }
    if (matched!=track) return false;
    hash[0]=2166136261u;hash[1]=0x9e3779b9u;
    // A chained scene keeps its first provider; both authored descriptors identify this input.
    return descriptor_witness(hash,descriptor) && descriptor_witness(hash,owner);
}
}
extern "C" {
__declspec(dllexport) volatile uint32_t clonewars_native_tick_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_native_tick_failure[16];
__declspec(dllexport) volatile uint32_t clonewars_native_tick_correction[6];
__declspec(dllexport) volatile uint32_t clonewars_native_pack_pose_correction[16];
__declspec(dllexport) volatile uint32_t clonewars_native_pack_cell_correction[8];
__declspec(dllexport) volatile uint32_t clonewars_native_pack_hit_correction[8];
__declspec(dllexport) volatile uint32_t clonewars_native_pack_death_input_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_native_pack_avoidance_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_native_global_pack_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_native_weapon_command_correction[8];
__declspec(dllexport) volatile uint32_t clonewars_native_clock_debug[4],clonewars_native_clock_correction[10];
}
namespace {
void fail(unsigned reason,uint32_t site=0,uint32_t clock=0,const SyncTickGate *expected=nullptr) {
    if (!live(COHERENT_ALL_PHASES)) return;
    failed=true;
    if (!clonewars_native_tick_failure[0]) {
        const uint32_t values[]={frame->epoch,frame->sequence,cursor,reason,site,expected?expected->site:0,clock,expected?expected->clock:0};
        std::memcpy(const_cast<uint32_t *>(clonewars_native_tick_failure),values,sizeof(values));
    }
    ++clonewars_native_tick_debug[3];game_sync_native_fault(22);
}
}
extern "C" uint32_t native_tick_clock_input(const uint32_t witness[2],uint32_t sample) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return sample;
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    if (!witness || !native_track_time_valid(sample)) {fail(6,0x7b8b08,clock);return sample;}
    const SyncTickGate source[]={{0x7b8ae1,clock,witness[0]},{0x7b8afd,clock,witness[1]},{0x7b8b08,clock,sample}};
    if (host) {
        if (frame->tick_gate_count>SYNC_MAX_TICK_GATES-3) {fail(1,0x7b8b08,clock);return sample;}
        std::memcpy(frame->tick_gates+frame->tick_gate_count,source,sizeof source);
        frame->tick_gate_count+=3;clonewars_native_tick_debug[0]+=3;++clonewars_native_clock_debug[0];return sample;
    }
    if (cursor>frame->tick_gate_count || frame->tick_gate_count-cursor<3) {fail(5,0x7b8b08,clock);return sample;}
    const auto *expected=frame->tick_gates+cursor;
    for (unsigned i=0;i<3;++i) {
        if (!native_tick_gate_valid(expected+i) || expected[i].site!=source[i].site ||
            expected[i].clock!=clock || (i<2 && expected[i].value!=source[i].value)) {
            fail(5,source[i].site,clock,expected+i);return sample;
        }
    }
    const uint32_t result=expected[2].value;cursor+=3;clonewars_native_tick_debug[1]+=3;++clonewars_native_clock_debug[1];
    if (result!=sample) {
        ++clonewars_native_clock_debug[2];
        if (!clonewars_native_clock_correction[0]) {
            const uint32_t values[]={frame->epoch,frame->sequence,clock,witness[0],witness[1],sample,result,cursor-3,0x7b8b08,0};
            std::memcpy(const_cast<uint32_t *>(clonewars_native_clock_correction),values,sizeof values);
        }
    }
    return result;
}
extern "C" float __attribute__((thiscall,noinline)) native_track_clock(void *track) {
    using Getter=float (__attribute__((thiscall)) *)(void *);
    // Use the game's unavailable sample when its TrackManager lookup returns no receiver.
    float sample=track ? reinterpret_cast<Getter>(0x6c11d0)(track) : *reinterpret_cast<const float *>(0xad76dc);
    const DWORD error=GetLastError();
    const int preload_level=game_sync_preload_level();
    if (preload_level>=0) {
        uint32_t witness[2],bits;std::memcpy(&bits,&sample,4);
        bits=game_sync_preload_track_input(clock_witness(track,witness,preload_level)?witness:nullptr,bits);
        std::memcpy(&sample,&bits,4);
    } else if (live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) && !failed) {
        uint32_t witness[2],bits;std::memcpy(&bits,&sample,4);
        if (!clock_witness(track,witness,frame->level)) {++clonewars_native_clock_debug[3];fail(6,0x7b8b08,*reinterpret_cast<uint32_t *>(0xfb4b6c));}
        else {bits=native_tick_clock_input(witness,bits);std::memcpy(&sample,&bits,4);}
    }
    SetLastError(error);return sample;
}
extern "C" uint32_t __cdecl native_tick_decision(uint32_t site,uint32_t local) {
    const DWORD error=GetLastError();
    uint32_t result=local;
    if (live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) && !failed) {
        const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
        if (host) {
            if (frame->tick_gate_count>=SYNC_MAX_TICK_GATES) fail(1,site,clock);
            else {frame->tick_gates[frame->tick_gate_count++]={site,clock,local};++clonewars_native_tick_debug[0];}
        } else {
            const auto *expected=cursor<frame->tick_gate_count?frame->tick_gates+cursor:nullptr;
            if (!expected || !native_tick_gate_valid(expected) || expected->site!=site || expected->clock!=clock) fail(2,site,clock,expected);
            else {
                ++cursor;++clonewars_native_tick_debug[1];result=expected->value;
                if (result!=local) {
                    ++clonewars_native_tick_debug[2];
                    if (!clonewars_native_tick_correction[0]) {
                        const uint32_t values[]={frame->epoch,frame->sequence,site,clock,local,result};
                        std::memcpy(const_cast<uint32_t *>(clonewars_native_tick_correction),values,sizeof(values));
                    }
                }
            }
        }
    }
    SetLastError(error);return result;
}

extern "C" int native_tick_elapsed_input(void) {
    const DWORD error=GetLastError();int result=0;
    if(live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) && !failed) {
        const uint32_t local=*reinterpret_cast<uint32_t *>(NATIVE_TICK_GAME_TIME);
        if(!native_track_time_valid(local))fail(6,NATIVE_TICK_GAME_TIME,*reinterpret_cast<uint32_t *>(0xfb4b6c));
        else {
            const uint32_t canonical=native_tick_decision(NATIVE_TICK_GAME_TIME,local);
            if(!failed && live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) {
                *reinterpret_cast<uint32_t *>(NATIVE_TICK_GAME_TIME)=canonical;result=1;
            }
        }
    }
    SetLastError(error);return result;
}
extern "C" void __cdecl native_weapon_commands(unsigned char *actor) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return;
    const DWORD error=GetLastError();
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    int slot=entities_slot(actor);
    uint32_t generation=entities_generation(actor);
    constexpr uint32_t site=NATIVE_TICK_WEAPON_COMMAND_ACTOR;
    if(!host && (slot<0 || !generation) && entities_bind_native_actor(frame,actor)) {
        slot=entities_slot(actor);generation=entities_generation(actor);
    }
    if (slot<0 || !generation) {SetLastError(error);return;}
    if (static_cast<uint32_t>(slot)>=SYNC_MAX_ACTORS || !readable(actor,0x1440)) {
        fail(4,site,clock);SetLastError(error);return;
    }
    const uint32_t local=static_cast<uint32_t>(actor[0x8ea]) | static_cast<uint32_t>(actor[0x8fa])<<8 |
        static_cast<uint32_t>(actor[0x8fb])<<16 | static_cast<uint32_t>(actor[0x8fc])<<24;
    const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
    if (host && frame->tick_gate_count>SYNC_MAX_TICK_GATES-3) fail(1,site,clock);
    else if (!host && (!expected || frame->tick_gate_count-cursor<3 ||
             expected[0].site!=site || expected[0].clock!=clock || expected[0].value!=static_cast<uint32_t>(slot) ||
             expected[1].site!=NATIVE_TICK_WEAPON_COMMAND_GENERATION || expected[1].clock!=clock || expected[1].value!=generation ||
             expected[2].site!=NATIVE_TICK_WEAPON_COMMAND_VALUE || expected[2].clock!=clock)) {
        fail(2,site,clock,expected);
        const uint32_t values[]={static_cast<uint32_t>(slot),generation,
            expected?expected[0].value:UINT32_MAX,
            expected && frame->tick_gate_count-cursor>=2?expected[1].value:0,
            reinterpret_cast<uintptr_t>(actor),local,
            *reinterpret_cast<uint32_t *>(actor+0x4c),*reinterpret_cast<uint32_t *>(actor+0x50)};
        std::memcpy(const_cast<uint32_t *>(clonewars_native_tick_failure)+8,values,sizeof values);
    }
    else {
        native_tick_decision(site,static_cast<uint32_t>(slot));
        native_tick_decision(NATIVE_TICK_WEAPON_COMMAND_GENERATION,generation);
        const uint32_t result=native_tick_decision(NATIVE_TICK_WEAPON_COMMAND_VALUE,local);
        if (!host && !failed && live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) {
            if (result!=local && !clonewars_native_weapon_command_correction[0]) {
                const uint32_t values[]={frame->epoch,frame->sequence,clock,static_cast<uint32_t>(slot),generation,local,result,cursor-3};
                std::memcpy(const_cast<uint32_t *>(clonewars_native_weapon_command_correction),values,sizeof values);
            }
            // 7E6CD0 queues these bytes; 45A929 consumes them before invoking stock Fire.
            actor[0x8ea]=result;actor[0x8fa]=result>>8;actor[0x8fb]=result>>16;actor[0x8fc]=result>>24;
        }
    }
    SetLastError(error);
}

extern "C" void __cdecl native_gizmo_turret_input(unsigned char *gizmo) {
    if(!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed)return;
    const DWORD error=GetLastError();
    constexpr uint32_t site=NATIVE_TICK_GIZMO_TURRET_SOURCE;
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    NativeGizmoSource source;
    if(!readable(gizmo,0x158) || !native_gizmo_source_find(gizmo,0x838260,source)) {
        fail(4,site,clock);
        const uint32_t values[]={reinterpret_cast<uintptr_t>(gizmo),readable(gizmo,4)?static_cast<uint32_t>(pointer(gizmo)):0,
            *reinterpret_cast<uint32_t *>(0xfb4a20),*reinterpret_cast<uint32_t *>(0xe90184),0,0,0,0};
        std::memcpy(const_cast<uint32_t *>(clonewars_native_tick_failure)+8,values,sizeof values);
        SetLastError(error);return;
    }
    uint32_t local[7];std::memcpy(local,source.key,sizeof source.key);
    local[4]=*reinterpret_cast<uint16_t *>(0xe637b4);
    local[5]=*reinterpret_cast<uint32_t *>(0xea178c);
    std::memcpy(local+6,gizmo+0x154,4);
    const auto *expected=cursor<frame->tick_gate_count?frame->tick_gates+cursor:nullptr;
    bool valid=native_track_time_valid(local[6]);
    if(host)valid=valid && frame->tick_gate_count<=SYNC_MAX_TICK_GATES-7;
    else {
        valid=valid && expected && frame->tick_gate_count-cursor>=7;
        for(unsigned i=0;valid && i<7;++i)
            valid=expected[i].site==site+i && expected[i].clock==clock && native_tick_gate_valid(expected+i) &&
                (i>=4 || expected[i].value==local[i]);
    }
    if(!valid)fail(2,site,clock,expected);
    else {
        uint32_t result[7];
        for(unsigned i=0;i<7;++i)result[i]=native_tick_decision(site+i,local[i]);
        if(!host && !failed && live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) {
            if(!native_gizmo_source_revalidate(source))fail(4,site,clock,expected);
            else {
                *reinterpret_cast<uint16_t *>(0xe637b4)=static_cast<uint16_t>(result[4]);
                *reinterpret_cast<uint32_t *>(0xea178c)=result[5];
                std::memcpy(gizmo+0x154,result+6,4);
            }
        }
    }
    SetLastError(error);
}

extern "C" uint32_t __cdecl native_fire_visibility(const void *actor,uint32_t local) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return local;
    const DWORD error=GetLastError();
    const int slot=entities_slot(actor);
    const uint32_t generation=entities_generation(actor);
    constexpr uint32_t site=NATIVE_TICK_FIRE_VISIBILITY;
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
    uint32_t result=local;
    if (slot<0 || static_cast<uint32_t>(slot)>=SYNC_MAX_ACTORS || !generation) {
        fail(4,site,clock);
    } else if (host && frame->tick_gate_count>SYNC_MAX_TICK_GATES-2) {
        fail(1,site,clock);
    } else if (!host && (!expected || frame->tick_gate_count-cursor<2 ||
               expected[0].site!=site || expected[0].clock!=clock ||
               expected[0].value>>8!=static_cast<uint32_t>(slot) ||
               expected[1].site!=NATIVE_TICK_FIRE_VISIBILITY_ACTOR ||
               expected[1].clock!=clock || expected[1].value!=generation)) {
        fail(2,site,clock,expected);
    } else {
        const uint32_t packed=static_cast<uint32_t>(slot)<<8 | (local&UINT8_MAX);
        const uint32_t source=native_tick_decision(site,packed);
        native_tick_decision(NATIVE_TICK_FIRE_VISIBILITY_ACTOR,generation);
        result=(local&~static_cast<uint32_t>(UINT8_MAX)) | (source&UINT8_MAX);
    }
    SetLastError(error);
    return result;
}

static uint32_t rts_turret_heading(const void *turret,uint32_t local,uint32_t site) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return local;
    const auto *pilot=reinterpret_cast<const void *>(pointer(turret,0x2fc));
    if (!pilot || (pilot!=*reinterpret_cast<const void **>(0xfb4940) &&
                   pilot!=*reinterpret_cast<const void **>(0xfb4944))) return local;

    const DWORD error=GetLastError();
    const int slot=entities_slot(pilot);
    const uint32_t generation=entities_generation(pilot);
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
    uint32_t result=local;
    if (slot<0 || static_cast<uint32_t>(slot)>=SYNC_MAX_ACTORS || !generation) {
        fail(4,site,clock);
    } else if (host && frame->tick_gate_count>SYNC_MAX_TICK_GATES-2) {
        fail(1,site,clock);
    } else if (!host && (!expected || frame->tick_gate_count-cursor<2 ||
               expected[0].site!=site || expected[0].clock!=clock ||
               expected[0].value>>16!=static_cast<uint32_t>(slot) ||
               expected[1].site!=NATIVE_TICK_RTS_TURRET_PILOT || expected[1].clock!=clock ||
               expected[1].value!=generation)) {
        fail(2,site,clock,expected);
    } else {
        // The stock angle feeds the turret state machine even when the local turret pose differs.
        const uint32_t packed=static_cast<uint32_t>(slot)<<16 | (local&UINT16_MAX);
        const uint32_t heading=native_tick_decision(site,packed);
        native_tick_decision(NATIVE_TICK_RTS_TURRET_PILOT,generation);
        result=(local&0xffff0000u) | (heading&UINT16_MAX);
    }
    SetLastError(error);
    return result;
}

extern "C" uint32_t __cdecl native_rts_turret_heading(const void *turret,uint32_t local) {
    return rts_turret_heading(turret,local,NATIVE_TICK_RTS_TURRET_HEADING);
}
extern "C" void __cdecl native_rts_turret_aim(void *turret) {
    auto &heading=*reinterpret_cast<uint16_t *>(static_cast<unsigned char *>(turret)+0x87e);
    heading=static_cast<uint16_t>(rts_turret_heading(turret,heading,NATIVE_TICK_RTS_TURRET_AIM));
}

namespace {
struct NativeListMemory {
    uintptr_t begin=0,end=0;
    bool contains(const void *raw,size_t size) {
        const auto address=reinterpret_cast<uintptr_t>(raw);
        if(!raw)return false;
        if(address>=begin && address<end && size<=end-address)return true;
        MEMORY_BASIC_INFORMATION memory;
        if(!VirtualQuery(raw,&memory,sizeof memory) || memory.State!=MEM_COMMIT ||
           (memory.Protect&(PAGE_GUARD|PAGE_NOACCESS)))return false;
        begin=reinterpret_cast<uintptr_t>(memory.BaseAddress);
        if(memory.RegionSize>UINTPTR_MAX-begin){begin=end=0;return false;}
        end=begin+memory.RegionSize;
        return address>=begin && address<end && size<=end-address;
    }
};
bool pack_attack_identity(const unsigned char *member,uint32_t &index,uint32_t &witness,bool with_target=true) {
    const auto *pack=reinterpret_cast<const unsigned char *>(pointer(member,0x68));
    if (!readable(pack,0x144) || pointer(pack)!=0xadcef0) return false;
    const auto *manager=reinterpret_cast<const unsigned char *>(pointer(pack,0xb8));
    const auto *list=readable(manager,0x110) && pointer(manager)==0xaded84 ?
        reinterpret_cast<const unsigned char *>(pointer(manager,0x10c)) : nullptr;
    const auto *definition=reinterpret_cast<const unsigned char *>(pointer(pack,0xb4));
    if (!readable(list,4) || (with_target && !readable(definition,0x20))) return false;

    auto *current=reinterpret_cast<const unsigned char *>(pointer(list));
    uint32_t pack_index=0;
    // No engine calls occur during either traversal, so region checks stay local to this lookup.
    NativeListMemory packs,members;
    while (current && current!=pack) {
        if (pack_index>=UINT16_MAX-UINT8_MAX || !packs.contains(current,0x18) || pointer(current)!=0xadcef0) return false;
        current=reinterpret_cast<const unsigned char *>(pointer(current,0x14));
        ++pack_index;
    }
    if (current!=pack) {
        NativeGlobalPackSource source{};
        if(!native_global_pack_source(pack,&source))return false;
        pack_index=UINT16_MAX-source.faction;
        ++clonewars_native_global_pack_debug[host?0:1];
    }
    current=reinterpret_cast<const unsigned char *>(pointer(pack,0xa0));
    uint32_t member_index=0;
    while (current!=member) {
        if (member_index==UINT16_MAX || !members.contains(current,0x80) || pointer(current,0x68)!=reinterpret_cast<uintptr_t>(pack)) return false;
        current=reinterpret_cast<const unsigned char *>(pointer(current,0x7c));
        ++member_index;
    }
    index=pack_index<<16 | member_index;
    const uint32_t fields[]={*reinterpret_cast<const uint32_t *>(pack+0x13c),
        *reinterpret_cast<const uint32_t *>(pack+0x140),with_target ? *reinterpret_cast<const uint32_t *>(definition+0x1c) : 0,
        *reinterpret_cast<const uint32_t *>(pack+0xf8),*reinterpret_cast<const uint32_t *>(pack+0xfc),
        *reinterpret_cast<const uint32_t *>(member+0x6c),*reinterpret_cast<const uint32_t *>(member+0x70)};
    witness=2166136261u;
    for (uint32_t field:fields) witness=(witness^field)*16777619u;
    return true;
}
}

extern "C" void __cdecl native_pack_pose(unsigned char *member,uint32_t site) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return;
    const DWORD error=GetLastError();
    uint32_t index,witness;
    if(!readable(member,0x80) || !pack_attack_identity(member,index,witness,false)){SetLastError(error);return;}
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
    uint32_t source[6]={((witness^index)*16777619u)};
    std::memcpy(source+1,member+0x20,16);
    uint16_t heading;std::memcpy(&heading,member+0x48,2);source[5]=heading;
    uint32_t local[6];std::memcpy(local,source,sizeof local);
    if(native_pack_pose_field(site)!=1 || (host && frame->tick_gate_count>SYNC_MAX_TICK_GATES-6)) {
        fail(1,site,clock,expected);SetLastError(error);return;
    }
    if(!host) {
        if(!expected || frame->tick_gate_count-cursor<6 || expected[0].value!=source[0]) {
            fail(2,site,clock,expected);SetLastError(error);return;
        }
        for(unsigned i=0;i<6;++i) {
            if(expected[i].site!=site+i*5 || expected[i].clock!=clock || !native_tick_gate_valid(expected+i)) {
                fail(2,site,clock,expected);SetLastError(error);return;
            }
            source[i]=expected[i].value;
        }
    }
    for(unsigned i=1;i<6;++i) {
        const SyncTickGate gate={site+i*5,clock,source[i]};
        if(!native_tick_gate_valid(&gate)){fail(4,site,clock,expected);SetLastError(error);return;}
    }
    for(unsigned i=0;i<6;++i)native_tick_decision(site+i*5,local[i]);
    if(!host && !failed && live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) {
        if(std::memcmp(source+1,local+1,20) && !clonewars_native_pack_pose_correction[0]) {
            const uint32_t values[]={frame->epoch,frame->sequence,site,clock,index,
                local[1],local[2],local[3],local[4],local[5],source[1],source[2],source[3],source[4],source[5],witness};
            std::memcpy(const_cast<uint32_t *>(clonewars_native_pack_pose_correction),values,sizeof values);
        }
        // Keep native spatial queries and their linked collision lists on the same game pose.
        std::memcpy(member+0x20,source+1,16);
        heading=static_cast<uint16_t>(source[5]);std::memcpy(member+0x48,&heading,2);
    }
    SetLastError(error);
}
extern "C" void __cdecl native_pack_pose_query(unsigned char *member) {native_pack_pose(member,NATIVE_TICK_PACK_POSE_QUERY);}
extern "C" void __cdecl native_pack_pose_commit(unsigned char *member) {native_pack_pose(member,NATIVE_TICK_PACK_POSE_COMMIT);}
extern "C" uint32_t __cdecl native_pack_cell_admission(const unsigned char *member,uint32_t flags) {
    const uint32_t local=flags&0x60u;
    if(!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed)return local;
    const DWORD error=GetLastError();uint32_t index,witness;
    if(!pack_attack_identity(member,index,witness,false)){SetLastError(error);return local;}
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c),key=(witness^index)*16777619u;
    const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
    uint32_t result=local;
    if(host && frame->tick_gate_count>SYNC_MAX_TICK_GATES-2) fail(1,NATIVE_TICK_PACK_CELL_MEMBER,clock);
    else if(!host && (!expected || frame->tick_gate_count-cursor<2 ||
            expected[0].site!=NATIVE_TICK_PACK_CELL_MEMBER || expected[0].clock!=clock || expected[0].value!=key ||
            expected[1].site!=NATIVE_TICK_PACK_CELL_FLAGS || expected[1].clock!=clock || !native_tick_gate_valid(expected+1)))
        fail(2,NATIVE_TICK_PACK_CELL_MEMBER,clock,expected);
    else {
        native_tick_decision(NATIVE_TICK_PACK_CELL_MEMBER,key);
        result=native_tick_decision(NATIVE_TICK_PACK_CELL_FLAGS,local);
        if(!host && result!=local && !failed && !clonewars_native_pack_cell_correction[0]) {
            const uint32_t values[]={frame->epoch,frame->sequence,clock,index,local,result,witness,0};
            std::memcpy(const_cast<uint32_t *>(clonewars_native_pack_cell_correction),values,sizeof values);
        }
    }
    SetLastError(error);return result;
}

extern "C" void __cdecl native_pack_animation(unsigned char *member,uint32_t *arguments) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return;
    const DWORD error=GetLastError();
    uint32_t index,witness;
    if (!readable(member,0x88) || !pack_attack_identity(member,index,witness,false)) {SetLastError(error);return;}
    constexpr uint32_t sites[]={NATIVE_TICK_PACK_ANIMATION_MEMBER,NATIVE_TICK_PACK_ANIMATION_REQUEST,
        NATIVE_TICK_PACK_ANIMATION_STATE,NATIVE_TICK_PACK_ANIMATION_CLOCK,NATIVE_TICK_PACK_ANIMATION_DELTA};
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
    uint32_t source[]={((witness^index)*16777619u),arguments[0],
        member[0x61] | (static_cast<uint32_t>(member[0x62])<<8) | (static_cast<uint32_t>(!!(member[0x63]&0x10))<<16),
        0,arguments[1]};
    std::memcpy(source+3,member+0x84,4);
    uint32_t local[5];std::memcpy(local,source,sizeof local);
    if (host && frame->tick_gate_count>SYNC_MAX_TICK_GATES-5) {
        fail(1,sites[0],clock);
    } else {
        if (!host) {
            if (!expected || frame->tick_gate_count-cursor<5 || expected[0].value!=source[0]) {
                fail(2,sites[0],clock,expected);SetLastError(error);return;
            }
            for (unsigned i=0;i<5;++i) {
                if (expected[i].site!=sites[i] || expected[i].clock!=clock || !native_tick_gate_valid(expected+i)) {
                    fail(2,sites[0],clock,expected);SetLastError(error);return;
                }
                source[i]=expected[i].value;
            }
        }
        const auto table=pointer(member,0x80);
        const uint32_t requested=source[1],playing=source[2]&UINT8_MAX;
        if (requested>UINTPTR_MAX/20 || table>UINTPTR_MAX-requested*20 ||
            !readable(reinterpret_cast<const void *>(table+requested*20),20)) {
            fail(4,sites[0],clock,expected);SetLastError(error);return;
        }
        const auto *descriptor=reinterpret_cast<const unsigned char *>(table+requested*20);
        // Stock clip transitions retain their phase when the asset requests it.
        if (host && requested!=playing && !descriptor[0x12]) source[3]=0;
        if (!native_track_time_valid(source[3]) || !native_track_time_valid(source[4])) {
            fail(4,sites[0],clock,expected);SetLastError(error);return;
        }
        for (unsigned i=0;i<5;++i) native_tick_decision(sites[i],host ? source[i] : local[i]);
        if (!host && !failed && live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) {
            arguments[0]=requested;arguments[1]=source[4];
            member[0x61]=static_cast<unsigned char>(playing);
            member[0x62]=static_cast<unsigned char>(source[2]>>8);
            member[0x63]=static_cast<unsigned char>((member[0x63]&~0x10u) | ((source[2]>>12)&0x10u));
            std::memcpy(member+0x84,source+3,4);
            if (requested==playing) {
                // The continuing clip uses the local asset table, never the peer's descriptor pointer.
                *reinterpret_cast<uintptr_t *>(member+0x10)=table+requested*20;
            }
        }
    }
    SetLastError(error);
}

extern "C" uint32_t __cdecl native_pack_attack(const unsigned char *member,uint32_t local) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return local;
    constexpr uint32_t site=NATIVE_TICK_PACK_ATTACK;
    const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
    const bool has_attack=!host && expected && expected->site==site;
    if (local!=2 && !has_attack) return local;

    const DWORD error=GetLastError();
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    uint32_t index,witness,result=local;
    if (!pack_attack_identity(member,index,witness)) {
        fail(4,site,clock,expected);
    } else if (host && frame->tick_gate_count>SYNC_MAX_TICK_GATES-2) {
        fail(1,site,clock);
    } else if (host) {
        native_tick_decision(site,index);
        native_tick_decision(NATIVE_TICK_PACK_ATTACK_WITNESS,witness);
    } else if (has_attack && expected->value==index) {
        if (frame->tick_gate_count-cursor<2 || expected[0].clock!=clock ||
            expected[1].site!=NATIVE_TICK_PACK_ATTACK_WITNESS ||
            expected[1].clock!=clock || expected[1].value!=witness) {
            fail(2,site,clock,expected);
        } else {
            native_tick_decision(site,index);
            native_tick_decision(NATIVE_TICK_PACK_ATTACK_WITNESS,witness);
            result=2;
        }
    } else if (local==2) {
        result=1;
    }
    SetLastError(error);
    return result;
}

static void pack_attack_seed(const unsigned char *member,uint32_t site,uint32_t seed_site,bool with_target=true,bool require_identity=true,volatile uint32_t *correction=nullptr) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return;
    const DWORD error=GetLastError();
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
    uint32_t index,witness;
    if (!pack_attack_identity(member,index,witness,with_target)) {
        if(require_identity)fail(4,site,clock,expected);
    } else {
        const uint32_t key=(witness^index)*16777619u;
        if (host && frame->tick_gate_count>SYNC_MAX_TICK_GATES-2) {
            fail(1,site,clock);
        } else if (!host && (!expected || frame->tick_gate_count-cursor<2 ||
                   expected[0].site!=site || expected[0].clock!=clock || expected[0].value!=key ||
                   expected[1].site!=seed_site || expected[1].clock!=clock)) {
            fail(2,site,clock,expected);
        } else {
            auto &seed=*reinterpret_cast<uint32_t *>(0xea178c);
            native_tick_decision(site,key);
            const uint32_t local=seed,source=native_tick_decision(seed_site,seed);
            if(site==NATIVE_TICK_PACK_HIT_AVOIDANCE && !failed && live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) {
                ++clonewars_native_pack_avoidance_debug[host?0:1];
                if(local!=source)++clonewars_native_pack_avoidance_debug[2];
            }
            if (!host && !failed && live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) {
                if(correction && !correction[0] && local!=source) {
                    const uint32_t values[]={frame->epoch,frame->sequence,site,clock,index,local,source,witness};
                    std::memcpy(const_cast<uint32_t *>(correction),values,sizeof values);
                }
                seed=source;
            }
        }
    }
    SetLastError(error);
}

extern "C" void __cdecl native_pack_attack_seed(const unsigned char *member) {
    pack_attack_seed(member,NATIVE_TICK_PACK_TIMER_MEMBER,NATIVE_TICK_PACK_TIMER_SEED);
}
extern "C" void __cdecl native_pack_hit_seed(const unsigned char *member,uint32_t site) {
    if(native_pack_hit_rng_site(site))pack_attack_seed(member,site,site+5,false,false,clonewars_native_pack_hit_correction);
}

extern "C" void __cdecl native_pack_rearm_seed(const unsigned char *member) {
    pack_attack_seed(member,NATIVE_TICK_PACK_REARM_MEMBER,NATIVE_TICK_PACK_REARM_SEED);
}
extern "C" void __cdecl native_pack_move_timer_seed(const unsigned char *member) {
    pack_attack_seed(member,NATIVE_TICK_PACK_MOVE_TIMER,NATIVE_TICK_PACK_MOVE_TIMER_SEED,false);
}
extern "C" void __cdecl native_pack_move_heading_seed(const unsigned char *member) {
    pack_attack_seed(member,NATIVE_TICK_PACK_MOVE_HEADING,NATIVE_TICK_PACK_MOVE_HEADING_SEED,false);
}
extern "C" void __cdecl native_pack_move_choice_seed(const unsigned char *member) {
    pack_attack_seed(member,NATIVE_TICK_PACK_MOVE_CHOICE,NATIVE_TICK_PACK_MOVE_CHOICE_SEED,false);
}

extern "C" uint32_t __cdecl native_pack_formation(const unsigned char *member,uint32_t leave) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return leave;
    const DWORD error=GetLastError();
    constexpr uint32_t site=NATIVE_TICK_PACK_FORMATION_MEMBER;
    constexpr uint32_t choice=NATIVE_TICK_PACK_FORMATION_LEAVE;
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
    uint32_t index,witness;
    if (pack_attack_identity(member,index,witness,false)) {
        const uint32_t key=(witness^index)*16777619u;
        if (host && frame->tick_gate_count>SYNC_MAX_TICK_GATES-2) fail(1,site,clock);
        else if (!host && (!expected || frame->tick_gate_count-cursor<2 || expected[0].site!=site ||
                 expected[0].value!=key || expected[0].clock!=clock || expected[1].site!=choice ||
                 expected[1].clock!=clock || !native_tick_gate_valid(expected+1))) fail(2,site,clock,expected);
        else {
            native_tick_decision(site,key);
            leave=native_tick_decision(choice,leave);
        }
    }
    SetLastError(error);
    return leave;
}

extern "C" void __cdecl native_pack_mode(unsigned char *member,unsigned char *entry) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return;
    const DWORD error=GetLastError();
    const auto *pack=reinterpret_cast<const void *>(pointer(member,0x68));
    // States outside the jump table still execute the stock default handler.
    if (readable(pack,4) && pointer(pack)==0xadcef0) {
        constexpr uint32_t site=NATIVE_TICK_PACK_MODE_MEMBER;
        const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
        const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
        const uint32_t local=member[0x60] | (static_cast<uint32_t>(*entry&1)<<8) |
            (static_cast<uint32_t>(member[0x63]&0x10)<<5);
        uint32_t index,witness;
        if (!pack_attack_identity(member,index,witness,false)) {
            // The stock dispatcher can run during construction, before the pack joins its manager.
            SetLastError(error);return;
        }
        const uint32_t mode=host?local:(expected && frame->tick_gate_count-cursor>=3?expected[2].value:local);
        const bool dying=(mode&0xffu)==9;
        constexpr uint32_t death_sites[]={NATIVE_TICK_PACK_DEATH_VERTICAL,NATIVE_TICK_PACK_DEATH_SPEED,NATIVE_TICK_PACK_DEATH_FLAGS};
        uint32_t death_local[3]={},death_source[3]={};
        if(dying){
            if(!readable(member,0x92)){fail(4,site,clock,expected);SetLastError(error);return;}
            std::memcpy(death_local,member+0x88,8);
            death_local[2]=member[0x90] | (static_cast<uint32_t>(member[0x91])<<8);
            for(unsigned i=0;i<3;++i){
                const SyncTickGate gate={death_sites[i],clock,death_local[i]};
                if(!native_tick_gate_valid(&gate)){fail(4,death_sites[i],clock,expected);SetLastError(error);return;}
                death_source[i]=death_local[i];
            }
            if(!host){
                if(!expected || frame->tick_gate_count-cursor<6){fail(2,site,clock,expected);SetLastError(error);return;}
                for(unsigned i=0;i<3;++i){
                    if(expected[3+i].site!=death_sites[i] || expected[3+i].clock!=clock || !native_tick_gate_valid(expected+3+i)){
                        fail(2,death_sites[i],clock,expected);SetLastError(error);return;
                    }
                    death_source[i]=expected[3+i].value;
                }
            }
        }
        if (host && frame->tick_gate_count>SYNC_MAX_TICK_GATES-(dying?6:3)) {
            fail(1,site,clock);
        } else if (!host && (!expected || frame->tick_gate_count-cursor<3 ||
                   expected[0].site!=site || expected[0].clock!=clock || expected[0].value!=index ||
                   expected[1].site!=NATIVE_TICK_PACK_MODE_WITNESS || expected[1].clock!=clock || expected[1].value!=witness ||
                   expected[2].site!=NATIVE_TICK_PACK_MODE_VALUE || expected[2].clock!=clock || !native_tick_gate_valid(expected+2))) {
            if (!clonewars_native_tick_failure[0]) {
                const uint32_t context[]={index,witness,expected?expected[0].value:UINT32_MAX,
                    expected && frame->tick_gate_count-cursor>1?expected[1].value:0,
                    *reinterpret_cast<const uint32_t *>(member+0x6c),*reinterpret_cast<const uint32_t *>(member+0x70),
                    *reinterpret_cast<const uint32_t *>(static_cast<const unsigned char *>(pack)+0xf8),
                    *reinterpret_cast<const uint32_t *>(static_cast<const unsigned char *>(pack)+0xfc)};
                std::memcpy(const_cast<uint32_t *>(clonewars_native_tick_failure+8),context,sizeof context);
            }
            fail(2,site,clock,expected);
        } else {
            native_tick_decision(site,index);
            native_tick_decision(NATIVE_TICK_PACK_MODE_WITNESS,witness);
            const uint32_t source=native_tick_decision(NATIVE_TICK_PACK_MODE_VALUE,local);
            if (!host && !failed && source!=local) {
                member[0x60]=static_cast<unsigned char>(source);
                *entry=static_cast<unsigned char>((source>>8)&1);
                member[0x63]=static_cast<unsigned char>((member[0x63]&~0x10u) | ((source>>5)&0x10u));
            }
            if(dying && !failed){
                for(unsigned i=0;i<3;++i)native_tick_decision(death_sites[i],death_local[i]);
                if(!failed && live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))){
                    ++clonewars_native_pack_death_input_debug[host?0:1];
                    if(!host){
                        // The stock death integrator reads these independently of the spatial-query pose.
                        if(std::memcmp(death_local,death_source,sizeof death_local))++clonewars_native_pack_death_input_debug[2];
                        std::memcpy(member+0x88,death_source,8);
                        member[0x90]=static_cast<unsigned char>(death_source[2]);
                        member[0x91]=static_cast<unsigned char>(death_source[2]>>8);
                    }
                }
            }
        }
    }
    SetLastError(error);
}

extern "C" void __cdecl native_flow_request(unsigned char *flow) {
    const DWORD error=GetLastError();
    if (readable(flow,0x64)) {
        auto &pending=*reinterpret_cast<uint32_t *>(flow+0x60);
        pending=game_sync_preload_flow_input(flow,pending);
    }
    if (live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) && !failed) {
        const auto root=*reinterpret_cast<uintptr_t *>(0xfb2e60);
        MEMORY_BASIC_INFORMATION memory;
        const auto address=reinterpret_cast<uintptr_t>(flow);
        if (!root || address!=root+0x1b44 || !VirtualQuery(flow,&memory,sizeof(memory)) ||
            memory.State!=MEM_COMMIT || (memory.Protect&(PAGE_NOACCESS|PAGE_GUARD)) ||
            address+0x64<address || address+0x64>reinterpret_cast<uintptr_t>(memory.BaseAddress)+memory.RegionSize) {
            fail(4,0x889edc);SetLastError(error);return;
        }
        const uint32_t local=*reinterpret_cast<uint32_t *>(flow+0x60);
        const SyncTickGate source={0x889edc,*reinterpret_cast<uint32_t *>(0xfb4b6c),local};
        if (!native_tick_gate_valid(&source)) {fail(4,source.site,source.clock);SetLastError(error);return;}
        const uint32_t result=native_tick_decision(source.site,local);
        // This is the pending request. The original consumer still performs the native state transition.
        if (!host && !failed && live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) *reinterpret_cast<uint32_t *>(flow+0x60)=result;
    }
    SetLastError(error);
}

extern "C" uint32_t __cdecl native_tick_gate(uint32_t site) {
    return native_tick_decision(site,*reinterpret_cast<uint8_t *>(0xfbc161));
}

static void rts_rng(const void *battlefield,const void *registry,uint32_t game_site,uint32_t engine_site) {
    const auto *resource=readable(battlefield,0x10d4) ? reinterpret_cast<const void *>(pointer(battlefield,0x10d0)) : nullptr;
    auto &game=*reinterpret_cast<uint32_t *>(0xe637b4);
    auto &engine=*reinterpret_cast<uint32_t *>(0xea178c);
    if (!readable(resource,0x10) || pointer(battlefield)!=0xaef0fc ||
        !readable(registry,4) || pointer(registry)!=reinterpret_cast<uintptr_t>(battlefield) ||
        pointer(battlefield,0xbc)!=reinterpret_cast<uintptr_t>(registry) ||
        !pointer(resource,0xc) || pointer(resource,0xc)!=*reinterpret_cast<uintptr_t *>(0xfb4a20) ||
        game>UINT16_MAX) {
        fail(7,game_site,*reinterpret_cast<uint32_t *>(0xfb4b6c));
    } else {
        const uint32_t game_source=native_tick_decision(game_site,game);
        const uint32_t engine_source=native_tick_decision(engine_site,engine);
        // Earlier world updates can consume a different number of draws before entering RTS.
        if (!host && !failed && live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) {
            game=game_source;
            engine=engine_source;
        }
    }
}

extern "C" void __cdecl native_rts_registry_rng(void *registry) {
    const DWORD error=GetLastError();
    if (live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) && !failed) {
        const auto *battlefield=readable(registry,4) ? reinterpret_cast<const void *>(pointer(registry)) : nullptr;
        rts_rng(battlefield,registry,NATIVE_TICK_RTS_GAME_RNG,NATIVE_TICK_RTS_ENGINE_RNG);
    }
    SetLastError(error);
}

extern "C" void __cdecl native_rts_producer_rng(void *battlefield) {
    const DWORD error=GetLastError();
    if (live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) && !failed) {
        const auto *registry=readable(battlefield,0xc0) ? reinterpret_cast<const void *>(pointer(battlefield,0xbc)) : nullptr;
        rts_rng(battlefield,registry,NATIVE_TICK_RTS_PRODUCER_GAME_RNG,NATIVE_TICK_RTS_PRODUCER_ENGINE_RNG);
    }
    SetLastError(error);
}

extern "C" uint32_t __cdecl native_rts_pack_admission(const void *producer,int32_t count,int32_t limit,uint32_t blocked) {
    const uint32_t local=count<limit && !(blocked&0xff);
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || failed) return local;
    const DWORD error=GetLastError();
    constexpr uint32_t site=NATIVE_TICK_RTS_PACK_ADMISSION;
    const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    uint32_t result=local;
    if (!readable(producer,0x258)) fail(7,site,clock);
    else {
        const uint32_t index=pointer(producer,0x250),side=pointer(producer,0x254);
        const auto *battlefield=reinterpret_cast<const void *>(pointer(producer,0x28));
        const auto *resource=readable(battlefield,0x10d4) ?
            reinterpret_cast<const void *>(pointer(battlefield,0x10d0)) : nullptr;
        if (index>=8 || side>=2 || !readable(resource,0x10) ||
            pointer(battlefield)!=0xaef0fc || pointer(resource,0xc)!=*reinterpret_cast<uintptr_t *>(0xfb4a20)) {
            fail(7,site,clock);
        } else {
            // The native count is indexed by side and slot. Keep the stock producer state machine on the host's admission decision.
            const uint32_t key=(side*8+index)*2;
            const auto *expected=cursor<frame->tick_gate_count ? frame->tick_gates+cursor : nullptr;
            if (!host && (!expected || expected->site!=site || (expected->value&~1u)!=key))
                fail(7,site,clock,expected);
            else result=native_tick_decision(site,key|local)&1;
        }
    }
    SetLastError(error);
    return result;
}

extern "C" uint32_t __cdecl native_perception_sweep(uint32_t completed) {
    const DWORD error=GetLastError();
    uint32_t publish=completed!=0;
    constexpr uint32_t dispatch=COHERENT_PHASE_BIT(COHERENT_DISPATCH);
    if (live(dispatch) && !failed) {
        auto &next=*reinterpret_cast<uint32_t *>(0xfbea24);
        // A completed sweep resets the cursor in the native publisher.
        if (!publish && next>SYNC_MAX_ACTORS) fail(4,0x9dda14,*reinterpret_cast<uint32_t *>(0xfb4b6c));
        else {
            const uint32_t decision=native_tick_decision(0x9dda14,publish ? 1 : next*2);
            publish=decision&1;
            if (!host && !failed && live(dispatch) && !publish) next=decision/2;
        }
    }
    SetLastError(error);return publish;
}

extern "C" void __cdecl reset_native_visibility_cache(unsigned char *actor_manager) {
    using ResetActors=void (__cdecl *)(unsigned char *);
    reinterpret_cast<ResetActors>(0x8a6560)(actor_manager);
    const DWORD error=GetLastError();
    constexpr size_t cache_offset=0x10;
    constexpr size_t cache_end=0x218;
    if (lan_status()!=LAN_CONNECTED || !readable(actor_manager,cache_end) ||
        pointer(actor_manager)!=0xc4f730 || pointer(actor_manager,8)!=pointer(reinterpret_cast<void *>(0xfb2f60))) {
        SetLastError(error);
        return;
    }
    // The manager survives level loads. Its cached sight pairs and sweep cursor still refer to the retired actors.
    std::memset(actor_manager+cache_offset,0,cache_end-cache_offset);
    SetLastError(error);
}

extern "C" {
__attribute__((used)) static volatile uintptr_t world_transition=0x7e4800, world_continue=0x57d420;
__attribute__((used)) static volatile uintptr_t world_exit_resume=0x888892, world_continue_resume=0x88889c;
__attribute__((naked)) void native_world_exit(void) {__asm__ volatile(NATIVE_WORLD_ADMISSION_ASM(1));}
__attribute__((naked)) void native_world_continue(void) {__asm__ volatile(NATIVE_WORLD_ADMISSION_ASM(0));}
__attribute__((used)) static volatile uintptr_t first_resume=0x8888d4,flow_request_resume=0x889ee1;
__attribute__((used)) static volatile uintptr_t track_clock_resume=0x7b8b0d;
__attribute__((used)) static volatile uintptr_t rts_registry_update=0x5198b0;
__attribute__((used)) static volatile uintptr_t rts_producer_resume=0x562da1;
__attribute__((used)) static volatile uintptr_t pack_attack_random=0x6d60d0;
__attribute__((used)) static volatile uintptr_t rts_turret_heading_resume=0x561a6c;
__attribute__((used)) static volatile uintptr_t pack_attack_arrived=0x45ff79,pack_attack_continue=0x45ff92;
__attribute__((naked)) void native_pack_attack_input(void) {
    // Both native paths consume the distance from the x87 stack before the next instruction.
    __asm__ volatile(
        "testb $2,%dl\n\tjz 1f\n\tfcomps 0xadae44\n\tfnstsw %ax\n\ttestb $5,%ah\n\tjp 2f\n\t"
        "leal 0x16c(%edi),%eax\n\tmovl $0x2d8,%ecx\n\tcmpw %cx,%ax\n\tja 2f\n\t"
        "pushfl\n\tpushal\n\txorl %ecx,%ecx\n\ttestb $8,%dl\n\tsetne %cl\n\tincl %ecx\n\tjmp 3f\n\t"
        "1: fstp %st(0)\n\t"
        "2: pushfl\n\tpushal\n\txorl %ecx,%ecx\n\t"
        "3: movl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $8,%esp\n\tpushl %ecx\n\tpushl 4(%eax)\n\t"
        "call _native_pack_attack\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\t"
        "testl %eax,%eax\n\tjz 4f\n\tcmpl $2,%eax\n\tje 5f\n\t"
        "andl $-9,20(%esp)\n\tjmp 6f\n\t"
        "5: orl $8,20(%esp)\n\t"
        "6: movl (%esp),%eax\n\taddl $0x16c,%eax\n\tmovl %eax,28(%esp)\n\t"
        "movl $0x2d8,24(%esp)\n\tpopal\n\tpopfl\n\tjmp *_pack_attack_arrived\n\t"
        "4: popal\n\tpopfl\n\tjmp *_pack_attack_continue");
}
__attribute__((naked)) void native_rts_turret_heading_input(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $8,%esp\n\tpushl 28(%eax)\n\tpushl 4(%eax)\n\t"
        "call _native_rts_turret_heading\n\taddl $16,%esp\n\t"
        "movl 512(%esp),%edx\n\tmovl %eax,28(%edx)\n\tfxrstor (%esp)\n\tmovl %edx,%esp\n\t"
        "popal\n\tpopfl\n\tmovw %ax,0x880(%esi)\n\tjmp *_rts_turret_heading_resume");
}
#define RTS_RNG_INPUT_ASM(saved_register, callback) \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t" \
    "subl $12,%esp\n\tpushl " #saved_register "(%eax)\n\tcall _" #callback "\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"
#define PACK_HIT_RNG_INPUT_ASM \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t" \
    "movl 36(%eax),%edx\n\tsubl $5,%edx\n\tsubl $8,%esp\n\tpushl %edx\n\tpushl 4(%eax)\n\t" \
    "call _native_pack_hit_seed\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"
__attribute__((naked)) void native_pack_hit_int_input(void) {
    __asm__ volatile(PACK_HIT_RNG_INPUT_ASM "jmp *_pack_move_random_integer");
}
__attribute__((naked)) void native_pack_hit_float_input(void) {
    __asm__ volatile(PACK_HIT_RNG_INPUT_ASM "jmp *_pack_attack_random");
}
__attribute__((naked)) void native_rts_registry_input(void) {
    __asm__ volatile(RTS_RNG_INPUT_ASM(24,native_rts_registry_rng) "jmp *_rts_registry_update");
}
__attribute__((naked)) void native_rts_producer_input(void) {
    __asm__ volatile(RTS_RNG_INPUT_ASM(4,native_rts_producer_rng)
        "movl 0xb8(%esi),%edi\n\tjmp *_rts_producer_resume");
}
__attribute__((naked)) void native_pack_attack_seed_input(void) {
    __asm__ volatile(RTS_RNG_INPUT_ASM(4,native_pack_attack_seed) "jmp *_pack_attack_random");
}
__attribute__((naked)) void native_pack_rearm_seed_input(void) {
    __asm__ volatile(RTS_RNG_INPUT_ASM(4,native_pack_rearm_seed) "jmp *_pack_attack_random");
}
__attribute__((used)) static volatile uintptr_t pack_move_random_integer=0x6d6140;
__attribute__((naked)) void native_pack_move_timer_seed_input(void) {
    __asm__ volatile(RTS_RNG_INPUT_ASM(4,native_pack_move_timer_seed) "jmp *_pack_attack_random");
}
__attribute__((naked)) void native_pack_move_heading_seed_input(void) {
    __asm__ volatile(RTS_RNG_INPUT_ASM(4,native_pack_move_heading_seed) "jmp *_pack_move_random_integer");
}
__attribute__((naked)) void native_pack_move_choice_seed_input(void) {
    __asm__ volatile(RTS_RNG_INPUT_ASM(4,native_pack_move_choice_seed) "jmp *_pack_move_random_integer");
}
__attribute__((used)) static volatile uintptr_t pack_cell_query=0x42a670,pack_cell_commit_resume=0x6d7677;
__attribute__((naked)) void native_pack_pose_query_input(void) {
    __asm__ volatile(RTS_RNG_INPUT_ASM(4,native_pack_pose_query) "jmp *_pack_cell_query");
}
__attribute__((naked)) void native_pack_pose_commit_input(void) {
    __asm__ volatile(RTS_RNG_INPUT_ASM(24,native_pack_pose_commit)
        "movl 0x38(%ecx),%eax\n\tmovl 4(%esp),%edx\n\tjmp *_pack_cell_commit_resume");
}
__attribute__((used)) static volatile uintptr_t pack_cell_callbacks=0x47571b,pack_cell_skip=0x47573b;
__attribute__((naked)) void native_pack_cell_admission_input(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $8,%esp\n\tpushl 16(%eax)\n\tpushl 4(%eax)\n\tcall _native_pack_cell_admission\n\taddl $16,%esp\n\t"
        "movl 512(%esp),%edx\n\tandl $-97,16(%edx)\n\torl %eax,16(%edx)\n\t"
        "fxrstor (%esp)\n\tmovl %edx,%esp\n\tpopal\n\tpopfl\n\t"
        "testb $0x60,%bl\n\tjnz 1f\n\tjmp *_pack_cell_callbacks\n\t1: jmp *_pack_cell_skip");
}
#undef RTS_RNG_INPUT_ASM
__attribute__((used)) static volatile uintptr_t pack_formation_keep=0x460508,pack_formation_leave=0x4604f4;
__attribute__((naked)) void native_pack_formation_input(void) {
    __asm__ volatile(
        "jz 1f\n\tflds 0x20(%esp)\n\tflds 0x28(%esp)\n\tfld %st(1)\n\tfmulp %st,%st(2)\n\t"
        "fldz\n\t.byte 0xdc,0xc8\n\tfaddp %st,%st(2)\n\t.byte 0xdc,0xc8\n\tfaddp %st,%st(1)\n\t"
        "fstps 0x14(%esp)\n\tflds 0x14(%esp)\n\tfcomps 0xadae44\n\tfnstsw %ax\n\ttestb $1,%ah\n\tjz 1f\n\t"
        "movl $0x2d8,%edx\n\tcmpw %dx,%cx\n\tjg 1f\n\tmovl $-0x2d8,%eax\n\tcmpw %ax,%cx\n\tjl 1f\n\t"
        "pushfl\n\tpushal\n\txorl %ecx,%ecx\n\tjmp 2f\n\t"
        "1: pushfl\n\tpushal\n\tmovl $1,%ecx\n\t"
        "2: movl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\t"
        "fxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $8,%esp\n\tpushl %ecx\n\tpushl 4(%eax)\n\tcall _native_pack_formation\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\ttestl %eax,%eax\n\tjz 3f\n\t"
        "popal\n\tpopfl\n\tjmp *_pack_formation_leave\n\t3: popal\n\tpopfl\n\tjmp *_pack_formation_keep");
}
__attribute__((used)) static volatile uintptr_t pack_animation_resume=0x4087a6;
__attribute__((naked)) void native_pack_animation_input(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "leal 44(%eax),%edx\n\tsubl $8,%esp\n\tpushl %edx\n\tpushl 24(%eax)\n\t"
        "call _native_pack_animation\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"
        "pushl %ecx\n\tmovl 12(%esp),%eax\n\tpushl %esi\n\tjmp *_pack_animation_resume");
}
__attribute__((used)) static volatile uintptr_t rts_turret_aim_resume=0x561b88;
__attribute__((naked)) void native_rts_turret_aim_input(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $12,%esp\n\tpushl 4(%eax)\n\tcall _native_rts_turret_aim\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"
        "leal 0x8a0(%esi),%eax\n\tjmp *_rts_turret_aim_resume");
}
__attribute__((used)) static volatile uintptr_t gizmo_turret_resume=0x838281;
__attribute__((naked)) void native_gizmo_turret_bridge(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $12,%esp\n\tpushl 16(%eax)\n\tcall _native_gizmo_turret_input\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"
        "movzwl 0x1ba(%ebx),%eax\n\tjmp *_gizmo_turret_resume");
}
__attribute__((used)) static volatile uintptr_t weapon_commands_resume=0x45a930;
__attribute__((naked)) void native_weapon_commands_input(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $12,%esp\n\tpushl 16(%eax)\n\tcall _native_weapon_commands\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"
        "cmpb $0xff,0x8fb(%ebx)\n\tjmp *_weapon_commands_resume");
}
__attribute__((naked,thiscall)) uint32_t native_fire_visibility_input(const void *actor) {
    __asm__ volatile(
        "movl 8(%ecx),%eax\n\ttestl %eax,%eax\n\tjz 1f\n\tmovb 0x42(%eax),%al\n\t"
        "1: pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $8,%esp\n\tpushl 28(%eax)\n\tpushl 24(%eax)\n\t"
        "call _native_fire_visibility\n\taddl $16,%esp\n\t"
        "movl 512(%esp),%edx\n\tmovl %eax,28(%edx)\n\t"
        "fxrstor (%esp)\n\tmovl %edx,%esp\n\tpopal\n\tpopfl\n\tret");
}
__attribute__((used)) static volatile uintptr_t pack_mode_resume=0x47575a;
__attribute__((naked)) void native_pack_mode_input(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "leal 52(%eax),%edx\n\tsubl $8,%esp\n\tpushl %edx\n\tpushl 4(%eax)\n\t"
        "call _native_pack_mode\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"
        "movzbl 0x60(%esi),%eax\n\tcmpl $0x1d,%eax\n\tjmp *_pack_mode_resume");
}
__attribute__((used)) static volatile uintptr_t rts_pack_admitted=0x547eca,rts_pack_waiting=0x547eec;
__attribute__((naked)) void native_rts_pack_gate(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "pushl 28(%eax)\n\tpushl 0(%eax)\n\tpushl 16(%eax)\n\tpushl 4(%eax)\n\t"
        "call _native_rts_pack_admission\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\ttestl %eax,%eax\n\tjz 1f\n\t"
        "popal\n\tpopfl\n\tjmp *_rts_pack_admitted\n\t"
        "1: popal\n\tpopfl\n\tjmp *_rts_pack_waiting\n\t");
}
__attribute__((naked)) void native_flow_request_input(void) {__asm__ volatile(NATIVE_FLOW_REQUEST_ASM);}
__attribute__((naked)) void native_track_clock_input(void) {
    __asm__ volatile("movl %eax,%ecx\n\tcall _native_track_clock\n\tjmp *_track_clock_resume\n\t");
}
__attribute__((used)) static volatile uintptr_t perception_continue=0x9dd0ff;
__attribute__((used)) static volatile uintptr_t perception_publish=0x9dda1f,perception_exit=0x9ddef2;
__attribute__((naked)) void native_perception_sweep_input(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $12,%esp\n\tpushl 60(%eax)\n\tcall _native_perception_sweep\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\ttestl %eax,%eax\n\tjz 1f\n\t"
        "popal\n\tpopfl\n\tcmpl $0,0x18(%esp)\n\tjmp *_perception_publish\n\t"
        "1: popal\n\tpopfl\n\tcmpl $0,0x18(%esp)\n\tjmp *_perception_exit\n\t");
}
__attribute__((naked)) void native_perception_sweep_early(void) {
    __asm__ volatile("cmpl $0,0x18(%esp)\n\tjne _native_perception_sweep_input\n\tjmp *_perception_continue\n\t");
}
// The saved x87 stack is restored before the original FSTP between CMP and JNE.
__attribute__((naked)) void native_tick_first(void) {__asm__ volatile(NATIVE_TICK_GATE_ASM(0x8888cd,first_resume));}
}
int native_tick_begin(SyncFrame *next,int authority,const CoherentFrameToken *original) {
    if (!next || !original || original->frame!=next || !world_vars_cohort_valid(original,COHERENT_PHASE_BIT(COHERENT_PREPARE))) return 0;
    if (token.epoch!=original->epoch) {
        std::memset(const_cast<uint32_t *>(clonewars_native_tick_failure),0,sizeof(clonewars_native_tick_failure));
        std::memset(const_cast<uint32_t *>(clonewars_native_tick_correction),0,sizeof(clonewars_native_tick_correction));
        std::memset(const_cast<uint32_t *>(clonewars_native_pack_pose_correction),0,sizeof(clonewars_native_pack_pose_correction));
        std::memset(const_cast<uint32_t *>(clonewars_native_pack_cell_correction),0,sizeof(clonewars_native_pack_cell_correction));
        std::memset(const_cast<uint32_t *>(clonewars_native_pack_hit_correction),0,sizeof(clonewars_native_pack_hit_correction));
        std::memset(const_cast<uint32_t *>(clonewars_native_weapon_command_correction),0,sizeof(clonewars_native_weapon_command_correction));
    }
    frame=next;token=*original;cursor=0;host=authority!=0;failed=false;active=true;
    if (host) frame->tick_gate_count=frame->tick_gate_reserved=0;
    return live(COHERENT_PHASE_BIT(COHERENT_PREPARE));
}
int native_tick_finish(void) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) return 0;
    if (!host && cursor!=frame->tick_gate_count && !failed) fail(3);
    const bool result=!failed;active=false;return result;
}
void native_tick_cancel(const CoherentFrameToken *original) {
    if (original && same(token,*original)) {active=false;frame=nullptr;}
}
int native_tick_install(void) {
    if(!native_global_pack_registry_count())return 0;
    const uintptr_t hit_rng[][2]={
        {NATIVE_TICK_PACK_HIT_REACTION,0x6d6140},{NATIVE_TICK_PACK_HIT_AVOIDANCE,0x6d6140},{NATIVE_TICK_PACK_HIT_DEBRIS,0x6d6140},
        {NATIVE_TICK_PACK_HIT_SHOCK,0x6d6140},{NATIVE_TICK_PACK_HIT_HEADING,0x6d6140},
        {NATIVE_TICK_PACK_IMPULSE_TIMER,0x6d60d0},{NATIVE_TICK_PACK_IMPULSE_SPEED,0x6d60d0},
        {NATIVE_TICK_PACK_IMPULSE_HEADING,0x6d6140},{NATIVE_TICK_PACK_DEATH_CLIP,0x6d60d0}};
    for(const auto &source:hit_rng) {
        const auto *code=reinterpret_cast<const unsigned char *>(source[0]);
        int32_t relative;std::memcpy(&relative,code+1,4);
        if(code[0]!=0xe8 || source[0]+5+relative!=source[1])return 0;
    }
    const uintptr_t reset_actors_call=0x791777;
    const uintptr_t sites[]={NATIVE_TICK_GIZMO_TURRET_SOURCE,NATIVE_TICK_WEAPON_COMMAND_ACTOR,0x8888cd,0x888889,0x888897,0x889edc,0x7b8b02,0x9dda14,0x9dd0f4,reset_actors_call,NATIVE_TICK_RTS_GAME_RNG,NATIVE_TICK_RTS_PRODUCER_GAME_RNG,NATIVE_TICK_RTS_PACK_ADMISSION,NATIVE_TICK_RTS_TURRET_HEADING,NATIVE_TICK_PACK_ATTACK,NATIVE_TICK_PACK_TIMER_MEMBER,NATIVE_TICK_PACK_MODE_MEMBER,NATIVE_TICK_PACK_REARM_MEMBER,0x4604b3,NATIVE_TICK_FIRE_VISIBILITY,NATIVE_TICK_RTS_TURRET_AIM,NATIVE_TICK_PACK_ANIMATION_MEMBER,NATIVE_TICK_PACK_MOVE_TIMER,NATIVE_TICK_PACK_MOVE_HEADING,NATIVE_TICK_PACK_MOVE_CHOICE,NATIVE_TICK_PACK_POSE_QUERY,NATIVE_TICK_PACK_POSE_COMMIT,NATIVE_TICK_PACK_CELL_MEMBER};
    void *hooks[]={reinterpret_cast<void *>(native_gizmo_turret_bridge),reinterpret_cast<void *>(native_weapon_commands_input),reinterpret_cast<void *>(native_tick_first),reinterpret_cast<void *>(native_world_exit),reinterpret_cast<void *>(native_world_continue),reinterpret_cast<void *>(native_flow_request_input),reinterpret_cast<void *>(native_track_clock_input),reinterpret_cast<void *>(native_perception_sweep_input),reinterpret_cast<void *>(native_perception_sweep_early),reinterpret_cast<void *>(reset_native_visibility_cache),reinterpret_cast<void *>(native_rts_registry_input),reinterpret_cast<void *>(native_rts_producer_input),reinterpret_cast<void *>(native_rts_pack_gate),reinterpret_cast<void *>(native_rts_turret_heading_input),reinterpret_cast<void *>(native_pack_attack_input),reinterpret_cast<void *>(native_pack_attack_seed_input),reinterpret_cast<void *>(native_pack_mode_input),reinterpret_cast<void *>(native_pack_rearm_seed_input),reinterpret_cast<void *>(native_pack_formation_input),reinterpret_cast<void *>(native_fire_visibility_input),reinterpret_cast<void *>(native_rts_turret_aim_input),reinterpret_cast<void *>(native_pack_animation_input),reinterpret_cast<void *>(native_pack_move_timer_seed_input),reinterpret_cast<void *>(native_pack_move_heading_seed_input),reinterpret_cast<void *>(native_pack_move_choice_seed_input),reinterpret_cast<void *>(native_pack_pose_query_input),reinterpret_cast<void *>(native_pack_pose_commit_input),reinterpret_cast<void *>(native_pack_cell_admission_input)};
    const unsigned char bytes[][11]={{0x0f,0xb7,0x83,0xba,1,0,0},{0x80,0xbb,0xfb,8,0,0,0xff},{0x80,0x3d,0x61,0xc1,0xfb,0,0},{0x6a,0x0f,0x8b,0xcf,0xe8,0x6e,0xbf,0xf5,0xff},{0xe8,0x84,0x4b,0xcf,0xff},{0x8b,0x46,0x60,0x3b,0xc7},{0x85,0xc0,0x74,0x1e,0x8b,0xc8,0xe8,0xc3,0x86,0xf0,0xff},
        {0x83,0x7c,0x24,0x18,0,0x0f,0x84,0xd3,4,0,0},{0x83,0x7c,0x24,0x18,0,0x0f,0x85,0x20,9,0,0},{0xe8,0xe4,0x4d,0x11,0},{0xe8,0xd2,0x6a,0xfb,0xff},{0x8b,0xbe,0xb8,0,0,0},{0x3b,0xdf,0x7d,0x26,0x84,0xc0,0x75,0x22},{0x66,0x89,0x86,0x80,8,0,0},{0xf6,0xc2,2,0x74,0x34,0xd8,0x1d,0x44,0xae,0xad,0},{0xe8,0xa7,0x5c,0x27,0},{0x0f,0xb6,0x46,0x60,0x83,0xf8,0x1d},{0xe8,0xc6,0x59,0x27,0},{0x74,0x3f,0xd9,0x44,0x24,0x20},{0xe8,0x78,0x8a,0xb8,0xff},{0x8d,0x86,0xa0,8,0,0},{0x51,0x8b,0x44,0x24,0x0c,0x56},{0xe8,0xbe,0x63,0x27,0},{0xe8,0xb1,0x63,0x27,0},{0xe8,0x23,0x5f,0x27,0},{0xe8,0x5c,0x4f,0xfb,0xff},{0x8b,0x41,0x38,0x8b,0x54,0x24,0x04},{0xf6,0xc3,0x60,0x75,0x20}};
    const unsigned sizes[]={7,7,7,9,5,5,11,11,11,5,5,6,8,7,11,5,7,5,6,5,6,6,5,5,5,5,7,5};
    const auto count=sizeof(sites)/sizeof(sites[0]);
    for (unsigned i=0;i<count;++i) if (std::memcmp(reinterpret_cast<void *>(sites[i]),bytes[i],sizes[i])) return 0;
    // 8889EA only controls the local preload indicator timer; its outer guard is asynchronous.
    for (unsigned i=0;i<count;++i) {
        auto *p=reinterpret_cast<unsigned char *>(sites[i]);DWORD old;
        if (!VirtualProtect(p,sizes[i],PAGE_EXECUTE_READWRITE,&old)) return 0;
        const auto relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(hooks[i])-sites[i]-5);
        p[0]=(sites[i]==reset_actors_call || sites[i]==NATIVE_TICK_RTS_GAME_RNG || sites[i]==NATIVE_TICK_PACK_TIMER_MEMBER || sites[i]==NATIVE_TICK_PACK_REARM_MEMBER || sites[i]==NATIVE_TICK_FIRE_VISIBILITY || sites[i]==NATIVE_TICK_PACK_MOVE_TIMER || sites[i]==NATIVE_TICK_PACK_MOVE_HEADING || sites[i]==NATIVE_TICK_PACK_MOVE_CHOICE || sites[i]==NATIVE_TICK_PACK_POSE_QUERY)?0xe8:0xe9;std::memcpy(p+1,&relative,4);std::memset(p+5,0x90,sizes[i]-5);
        const bool flushed=FlushInstructionCache(GetCurrentProcess(),p,sizes[i])!=0;DWORD ignored;
        if (!VirtualProtect(p,sizes[i],old,&ignored) || !flushed) return 0;
    }
    for(const auto &source:hit_rng) {
        auto *code=reinterpret_cast<unsigned char *>(source[0]);DWORD old;
        if(!VirtualProtect(code,5,PAGE_EXECUTE_READWRITE,&old))return 0;
        const auto hook=source[1]==0x6d6140 ? native_pack_hit_int_input : native_pack_hit_float_input;
        const int32_t relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(hook)-source[0]-5);
        std::memcpy(code+1,&relative,4);
        const bool flushed=FlushInstructionCache(GetCurrentProcess(),code,5)!=0;DWORD ignored;
        if(!VirtualProtect(code,5,old,&ignored)||!flushed)return 0;
    }
    return 1;
}
