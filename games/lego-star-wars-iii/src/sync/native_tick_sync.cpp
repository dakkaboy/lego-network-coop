#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include "native_tick_sync.h"
extern "C" {
#include "game_sync.h"
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
bool clock_witness(void *track,uint32_t hash[2]) {
    auto *world=*reinterpret_cast<unsigned char **>(0xfb4a20);
    auto *manager=*reinterpret_cast<unsigned char **>(0xe901f4);
    auto *tracks=*reinterpret_cast<unsigned char **>(0xfa1c98);
    if (!readable(world,0x224) || !readable(manager,0x90) || !readable(tracks,0x34)) return false;
    auto *definition=reinterpret_cast<unsigned char *>(pointer(world,0x220));
    if (!readable(definition,0x96) || *reinterpret_cast<int16_t *>(definition+0x94)!=frame->level) return false;
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
__declspec(dllexport) volatile uint32_t clonewars_native_tick_failure[8];
__declspec(dllexport) volatile uint32_t clonewars_native_tick_correction[6];
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
    if (live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) && !failed) {
        uint32_t witness[2],bits;std::memcpy(&bits,&sample,4);
        if (!clock_witness(track,witness)) {++clonewars_native_clock_debug[3];fail(6,0x7b8b08,*reinterpret_cast<uint32_t *>(0xfb4b6c));}
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

extern "C" void __cdecl native_flow_request(unsigned char *flow) {
    const DWORD error=GetLastError();
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
    const uintptr_t reset_actors_call=0x791777;
    const uintptr_t sites[]={0x8888cd,0x888889,0x888897,0x889edc,0x7b8b02,0x9dda14,0x9dd0f4,reset_actors_call};
    void *hooks[]={reinterpret_cast<void *>(native_tick_first),reinterpret_cast<void *>(native_world_exit),reinterpret_cast<void *>(native_world_continue),reinterpret_cast<void *>(native_flow_request_input),reinterpret_cast<void *>(native_track_clock_input),reinterpret_cast<void *>(native_perception_sweep_input),reinterpret_cast<void *>(native_perception_sweep_early),reinterpret_cast<void *>(reset_native_visibility_cache)};
    const unsigned char bytes[][11]={{0x80,0x3d,0x61,0xc1,0xfb,0,0},{0x6a,0x0f,0x8b,0xcf,0xe8,0x6e,0xbf,0xf5,0xff},{0xe8,0x84,0x4b,0xcf,0xff},{0x8b,0x46,0x60,0x3b,0xc7},{0x85,0xc0,0x74,0x1e,0x8b,0xc8,0xe8,0xc3,0x86,0xf0,0xff},
        {0x83,0x7c,0x24,0x18,0,0x0f,0x84,0xd3,4,0,0},{0x83,0x7c,0x24,0x18,0,0x0f,0x85,0x20,9,0,0},{0xe8,0xe4,0x4d,0x11,0}};
    const unsigned sizes[]={7,9,5,5,11,11,11,5};
    const auto count=sizeof(sites)/sizeof(sites[0]);
    for (unsigned i=0;i<count;++i) if (std::memcmp(reinterpret_cast<void *>(sites[i]),bytes[i],sizes[i])) return 0;
    // 8889EA only controls the local preload indicator timer; its outer guard is asynchronous.
    for (unsigned i=0;i<count;++i) {
        auto *p=reinterpret_cast<unsigned char *>(sites[i]);DWORD old;
        if (!VirtualProtect(p,sizes[i],PAGE_EXECUTE_READWRITE,&old)) return 0;
        const auto relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(hooks[i])-sites[i]-5);
        p[0]=sites[i]==reset_actors_call?0xe8:0xe9;std::memcpy(p+1,&relative,4);std::memset(p+5,0x90,sizes[i]-5);
        const bool flushed=FlushInstructionCache(GetCurrentProcess(),p,sizes[i])!=0;DWORD ignored;
        if (!VirtualProtect(p,sizes[i],old,&ignored) || !flushed) return 0;
    }
    return 1;
}
