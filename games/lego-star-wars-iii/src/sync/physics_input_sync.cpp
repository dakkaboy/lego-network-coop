#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstddef>
#include <cstring>
#include "physics_input_sync.h"
#include "../engine/breakup_launch_thunk.h"
#include "spellit_input_sync.h"
#include "module_rng_input_sync.h"
extern "C" {
#include "geometry_sync.h"
#include "game_sync.h"
#include "../engine/module_cohort_binding.h"
#include "../engine/constructor_lexical_seh.h"
}

namespace {
static_assert(sizeof(SyncPhysicsWorldInput)==sizeof(SyncPhysicsModuleInput) &&
    offsetof(SyncPhysicsWorldInput,value)==offsetof(SyncPhysicsModuleInput,value));
using NativeSpin = uint32_t (__cdecl *)(void *);
NativeSpin originals[2];
SyncFrame *frame;
GeometryFrameLease lease;
uint32_t cursor,last_epoch;
bool active,host,failed;

bool readable(const void *p,size_t size) {
    MEMORY_BASIC_INFORMATION m;
    const auto address=reinterpret_cast<uintptr_t>(p);
    return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && address+size>=address &&
        address+size<=reinterpret_cast<uintptr_t>(m.BaseAddress)+m.RegionSize;
}
bool live() {
    GeometryFrameLease current;
    return active && frame && geometry_frame_lease_get(&current) && lease.serial==current.serial &&
        module_cohort_same(&lease.cohort,&current.cohort) && !geometry_frame_cancelled(&lease) &&
        coherent_frame_valid(&lease.cohort,MODULE_COHORT_PHASES) && lease.cohort.frame==frame;
}
uint32_t word(const void *p) {uint32_t value;std::memcpy(&value,p,4);return value;}
uint32_t &rng() {return *reinterpret_cast<uint32_t *>(0xe5f498);}
uint32_t &game_rng() {return *reinterpret_cast<uint32_t *>(0xe637b4);}
}

extern "C" {
__declspec(dllexport) volatile uint32_t clonewars_physics_input_debug[8];
__declspec(dllexport) volatile uint32_t clonewars_physics_input_failure[12];
__declspec(dllexport) SyncPhysicsChoice clonewars_physics_failure_local,clonewars_physics_failure_expected;
__declspec(dllexport) volatile uint32_t clonewars_breakup_launch_debug[4],clonewars_breakup_launch_correction[8];
__attribute__((used)) static volatile uintptr_t breakup_launch_native=0x966af0;
}

namespace {
uint32_t failure_source_word(const SyncPhysicsChoice *choice) {
    if (!choice) return 0;
    if (choice->kind==SYNC_PHYSICS_SPELLIT_BODY_BASIS || choice->kind==SYNC_PHYSICS_SPELLIT_BODY_MOTION)
        return choice->spellit_body.key[0];
    return choice->kind>=SYNC_PHYSICS_SPELLIT_SEED?choice->world.source_name[0]:choice->name_hash[0];
}
int fail(unsigned reason,const SyncPhysicsChoice *local=nullptr,const SyncPhysicsChoice *expected=nullptr) {
    if (!live()) return 0;
    failed=true;
    if (!clonewars_physics_input_failure[0]) {
        clonewars_physics_failure_local=local?*local:SyncPhysicsChoice{};
        clonewars_physics_failure_expected=expected?*expected:SyncPhysicsChoice{};
        const uint32_t values[]={frame->epoch,frame->sequence,cursor,reason,
            local?local->kind:0,expected?expected->kind:0,
            failure_source_word(local),failure_source_word(expected),
            local?(local->kind>=SYNC_PHYSICS_SPELLIT_SEED?local->world.clock:local->clock):0,
            expected?(expected->kind>=SYNC_PHYSICS_SPELLIT_SEED?expected->world.clock:expected->clock):0,
            local?local->site:0,expected?expected->site:0};
        std::memcpy(const_cast<uint32_t *>(clonewars_physics_input_failure),values,sizeof(values));
    }
    ++clonewars_physics_input_debug[2];game_sync_native_fault(15);return 0;
}
bool describe_name(const unsigned char *source,SyncPhysicsChoice &choice) {
    if (!readable(source,0xb8)) return false;
    auto *name=reinterpret_cast<const unsigned char *>(word(source+0xb4));
    uint32_t hash=2166136261u,second=0x9e3779b9u;
    bool terminated=false;
    for (unsigned i=0;i<128;++i) {
        if (!readable(name+i,1)) return false;
        const unsigned value=name[i];
        if (!value || value==255) {terminated=i!=0;break;}
        hash=(hash^value)*16777619u;second=(second^value)*0x85ebca6bu;
    }
    if (!terminated) return false;
    choice.name_hash[0]=hash;choice.name_hash[1]=second;
    return true;
}
bool describe(void *raw,unsigned kind,uint32_t site,SyncPhysicsChoice &choice) {
    auto *p=static_cast<unsigned char *>(raw);
    if (!readable(p,0x168)) return false;
    choice={};choice.kind=kind;choice.site=site;choice.flags=word(p+0x11c);
    if (!describe_name(reinterpret_cast<const unsigned char *>(word(p+0x164)),choice)) return false;
    uint16_t model;std::memcpy(&model,p+0x156,2);choice.model=model;
    choice.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    std::memcpy(choice.recipe,p+0x124,sizeof(choice.recipe));choice.rng=rng();
    return physics_choice_valid(&choice)!=0;
}

void apply_launch(const unsigned char *descriptor,const unsigned char *handle) {
    if (!active || !readable(descriptor,0x30) || !descriptor[0x2c]) return;
    if (!live() || failed) return;
    SyncPhysicsChoice local={};
    local.kind=SYNC_PHYSICS_BREAKUP_LAUNCH;local.site=0x905f38;
    local.flags=0x40000000u|(descriptor[0x2d]?0x10u:0);
    local.model=static_cast<uint16_t>(word(descriptor+4));local.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    std::memcpy(local.recipe,descriptor+8,sizeof(local.recipe));local.rng=game_rng();
    if (!readable(handle,8) || !describe_name(reinterpret_cast<const unsigned char *>(word(handle+4)),local) ||
        !physics_choice_valid(&local)) {fail(1,&local);++clonewars_breakup_launch_debug[3];return;}
    if (!live()) return;
    if (host) {
        if (frame->physics_choice_count>=SYNC_MAX_PHYSICS_CHOICES) {fail(2,&local);++clonewars_breakup_launch_debug[3];return;}
        frame->physics_choices[frame->physics_choice_count++]=local;
        ++clonewars_physics_input_debug[0];++clonewars_breakup_launch_debug[0];
    } else {
        const auto *entry=cursor<frame->physics_choice_count?frame->physics_choices+cursor:nullptr;
        if (!entry || !physics_choice_same_source(entry,&local)) {fail(3,&local,entry);++clonewars_breakup_launch_debug[3];return;}
        if (local.rng!=entry->rng) {
            ++clonewars_breakup_launch_debug[2];
            if (!clonewars_breakup_launch_correction[0]) {
                const uint32_t values[]={frame->epoch,frame->sequence,local.clock,local.model,
                    local.name_hash[0],local.rng,entry->rng,local.site};
                std::memcpy(const_cast<uint32_t *>(clonewars_breakup_launch_correction),values,sizeof(values));
            }
        }
        // This is the shared game stream: retain the advances of the original 966AF0 call.
        game_rng()=entry->rng;++cursor;++clonewars_physics_input_debug[1];++clonewars_breakup_launch_debug[1];
    }
}
struct SpinScope {
    void *effect;
    unsigned kind;
    uint32_t site,result,saved_rng;
    bool seeded;
    GeometryFrameLease seeded_lease;
    alignas(16) unsigned char fx[512];
    DWORD error;
};
void capture(SpinScope &s) {__asm__ volatile("fxsave %0":"=m"(s.fx)::"memory");s.error=GetLastError();}
void restore(const SpinScope &s) {SetLastError(s.error);__asm__ volatile("fxrstor %0"::"m"(s.fx):"memory");}
void restore_seed(SpinScope &s) {
    if (s.seeded && live() && s.seeded_lease.serial==lease.serial &&
        module_cohort_same(&s.seeded_lease.cohort,&lease.cohort)) rng()=s.saved_rng;
    s.seeded=false;
}

extern "C" void __cdecl physics_apply_breakup_launch(const unsigned char *descriptor,const unsigned char *handle) {
    const DWORD error=GetLastError();apply_launch(descriptor,handle);SetLastError(error);
}
extern "C" __attribute__((naked)) void physics_breakup_launch_thunk(void) {__asm__ volatile(BREAKUP_LAUNCH_THUNK_ASM);}
void *__cdecl invoke(void *raw) {
    auto &s=*static_cast<SpinScope *>(raw);
    const auto *p=static_cast<const unsigned char *>(s.effect);
    // Visual particles share this RNG; only physical sources enter the network journal.
    if (active && readable(p,0x168) && (word(p+0x11c)&0x40000000u) && word(p+0x164)) {
        if (!live() || failed) return nullptr;
        SyncPhysicsChoice local;
        if (!describe(s.effect,s.kind,s.site,local)) {fail(1);return nullptr;}
        if (!live()) return nullptr;
        if (host) {
            if (frame->physics_choice_count>=SYNC_MAX_PHYSICS_CHOICES) {fail(2,&local);return nullptr;}
            frame->physics_choices[frame->physics_choice_count++]=local;
            ++clonewars_physics_input_debug[0];
        } else {
            const auto *entry=cursor<frame->physics_choice_count?frame->physics_choices+cursor:nullptr;
            if (!entry || !physics_choice_same_source(entry,&local)) {fail(3,&local,entry);return nullptr;}
            s.saved_rng=local.rng;s.seeded_lease=lease;s.seeded=true;rng()=entry->rng;++cursor;
            clonewars_physics_input_debug[3]+=local.rng!=entry->rng;
            ++clonewars_physics_input_debug[1];
        }
    }
    restore(s);
    s.result=originals[s.kind-1](s.effect);
    capture(s);
    restore_seed(s);
    return nullptr;
}
void __cdecl abort_spin(void *raw) {restore_seed(*static_cast<SpinScope *>(raw));}
uint32_t spin(void *effect,unsigned kind,uint32_t site) {
    SpinScope scope;capture(scope);scope.seeded=false;scope.result=0;scope.effect=effect;scope.kind=kind;scope.site=site;
    constructor_lexical_seh(&scope,invoke,abort_spin);restore(scope);return scope.result;
}
uint32_t __cdecl axis_hook(void *effect) {return spin(effect,SYNC_PHYSICS_AXIS_SPIN,reinterpret_cast<uintptr_t>(__builtin_return_address(0)));}
uint32_t __cdecl rotation_hook(void *effect) {return spin(effect,SYNC_PHYSICS_ROTATION_SPIN,reinterpret_cast<uintptr_t>(__builtin_return_address(0)));}
}

int physics_input_begin(SyncFrame *next,int authority) {
    GeometryFrameLease current;
    if (!next || !geometry_frame_lease_get(&current) || current.cohort.frame!=next ||
        !coherent_frame_valid(&current.cohort,COHERENT_PHASE_BIT(COHERENT_PREPARE))) return 0;
    frame=next;lease=current;cursor=0;host=authority!=0;failed=false;active=true;
    clonewars_physics_input_debug[5]=reinterpret_cast<uintptr_t>(frame);
    if (host) frame->physics_choice_count=0;
    if (last_epoch!=frame->epoch) {
        std::memset(const_cast<uint32_t *>(clonewars_physics_input_failure),0,sizeof(clonewars_physics_input_failure));
        std::memset(const_cast<uint32_t *>(clonewars_breakup_launch_correction),0,sizeof(clonewars_breakup_launch_correction));
        last_epoch=frame->epoch;
    }
    return live();
}
int physics_input_finish(void) {
    if (!live()) return 0;
    if (!failed && !host && cursor!=frame->physics_choice_count) fail(4);
    const bool ok=!failed;active=false;return ok;
}
void physics_input_cancel(void) {active=false;frame=nullptr;}
static int physics_source_input(SyncPhysicsChoice *choice,const CoherentFrameToken *token) {
    if (!active) return 0;
    if (!token || !live() || failed || !module_cohort_same(token,&lease.cohort) ||
        !coherent_frame_valid(token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))) return -1;
    if (!choice || !physics_choice_valid(choice)) {fail(5,choice);return -1;}
    if (host) {
        if (frame->physics_choice_count>=SYNC_MAX_PHYSICS_CHOICES) {fail(2,choice);return -1;}
        frame->physics_choices[frame->physics_choice_count++]=*choice;++clonewars_physics_input_debug[0];
    } else {
        const auto *expected=cursor<frame->physics_choice_count?frame->physics_choices+cursor:nullptr;
        if (!expected || !physics_choice_same_source(expected,choice)) {fail(6,choice,expected);return -1;}
        if(choice->kind==SYNC_PHYSICS_SPELLIT_BODY_BASIS||choice->kind==SYNC_PHYSICS_SPELLIT_BODY_MOTION){
            std::memcpy(choice->spellit_body.values,expected->spellit_body.values,sizeof choice->spellit_body.values);
        } else if(choice->kind==SYNC_PHYSICS_SPELLIT_STEP) {
            choice->spellit_step.engine_seed=expected->spellit_step.engine_seed;
            choice->spellit_step.game_seed=expected->spellit_step.game_seed;
            choice->spellit_step.delta=expected->spellit_step.delta;
            choice->spellit_step.timer=expected->spellit_step.timer;
        } else if(choice->kind==SYNC_PHYSICS_SPELLIT_POSE) {
            std::memcpy(choice->spellit_pose.position,expected->spellit_pose.position,sizeof choice->spellit_pose.position);
            choice->spellit_pose.last_time=expected->spellit_pose.last_time;
        }
        else if (choice->kind==SYNC_PHYSICS_MODULE_SEED) choice->module.value=expected->module.value;
        else if (choice->kind==SYNC_PHYSICS_GUN_JAM_SEED) choice->gun_jam.value=expected->gun_jam.value;
        else choice->world.value=expected->world.value;
        ++cursor;++clonewars_physics_input_debug[1];
    }
    return live()?1:-1;
}
int physics_world_input(SyncPhysicsChoice *choice,const CoherentFrameToken *token) {
    if (!active) return 0;
    if (!choice || ((choice->kind<SYNC_PHYSICS_SPELLIT_SEED || choice->kind>SYNC_PHYSICS_SPELLIT_ENABLED) &&
                   choice->kind!=SYNC_PHYSICS_SPELLIT_POSE && choice->kind!=SYNC_PHYSICS_SPELLIT_STEP &&
                   choice->kind!=SYNC_PHYSICS_SPELLIT_SELECTION && choice->kind!=SYNC_PHYSICS_SPELLIT_BODY_BASIS &&
                   choice->kind!=SYNC_PHYSICS_SPELLIT_BODY_MOTION)) {
        if (live()) fail(5,choice);
        return -1;
    }
    return physics_source_input(choice,token);
}
int physics_module_input(SyncPhysicsChoice *choice,const CoherentFrameToken *token) {
    if (!active) return 0;
    if (!choice || (choice->kind!=SYNC_PHYSICS_MODULE_SEED && choice->kind!=SYNC_PHYSICS_GUN_JAM_SEED)) {
        if (live()) fail(5,choice);
        return -1;
    }
    return physics_source_input(choice,token);
}
int physics_input_install(void) {
    auto *launch=reinterpret_cast<unsigned char *>(0x905f33);
    const unsigned char launch_bytes[]={0xe8,0xb8,0x0b,0x06,0x00};
    if (std::memcmp(launch,launch_bytes,sizeof(launch_bytes))) return 0;
    const uintptr_t addresses[]={0x71ab90,0x71ac10};
    const unsigned char bytes[2][6]={{0x56,0x57,0x8b,0x7c,0x24,0x0c},{0x56,0x68,0x98,0xf4,0xe5,0x00}};
    void *hooks[]={reinterpret_cast<void *>(axis_hook),reinterpret_cast<void *>(rotation_hook)};
    for (unsigned i=0;i<2;++i)
        if (!readable(reinterpret_cast<void *>(addresses[i]),6) || std::memcmp(reinterpret_cast<void *>(addresses[i]),bytes[i],6)) return 0;
    if (!spellit_input_install()) return 0;
    if (!module_rng_input_install()) return 0;
    for (unsigned i=0;i<2;++i) {
        auto *bridge=static_cast<unsigned char *>(VirtualAlloc(nullptr,11,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE));
        if (!bridge) return 0;
        std::memcpy(bridge,bytes[i],6);bridge[6]=0xe9;
        const auto back=static_cast<int32_t>(addresses[i]+6-reinterpret_cast<uintptr_t>(bridge)-11);
        std::memcpy(bridge+7,&back,4);DWORD old;
        if (!VirtualProtect(bridge,11,PAGE_EXECUTE_READ,&old)) return 0;
        FlushInstructionCache(GetCurrentProcess(),bridge,11);originals[i]=reinterpret_cast<NativeSpin>(bridge);
        auto *entry=reinterpret_cast<unsigned char *>(addresses[i]);
        if (!VirtualProtect(entry,6,PAGE_EXECUTE_READWRITE,&old)) return 0;
        const auto jump=static_cast<int32_t>(reinterpret_cast<uintptr_t>(hooks[i])-addresses[i]-5);
        entry[0]=0xe9;std::memcpy(entry+1,&jump,4);entry[5]=0x90;
        FlushInstructionCache(GetCurrentProcess(),entry,6);DWORD unused;VirtualProtect(entry,6,old,&unused);
    }
    DWORD old;
    if (!VirtualProtect(launch,5,PAGE_EXECUTE_READWRITE,&old)) return 0;
    const auto relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(physics_breakup_launch_thunk)-0x905f38);
    std::memcpy(launch+1,&relative,4);
    const bool flushed=FlushInstructionCache(GetCurrentProcess(),launch,5)!=0;DWORD ignored;
    if (!VirtualProtect(launch,5,old,&ignored) || !flushed) return 0;
    clonewars_physics_input_debug[4]=3;return 1;
}
