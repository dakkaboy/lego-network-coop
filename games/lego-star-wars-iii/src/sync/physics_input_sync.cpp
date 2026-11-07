#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include "physics_input_sync.h"
extern "C" {
#include "geometry_sync.h"
#include "game_sync.h"
#include "../engine/module_cohort_binding.h"
#include "../engine/constructor_lexical_seh.h"
}

namespace {
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
}

extern "C" {
__declspec(dllexport) volatile uint32_t clonewars_physics_input_debug[8];
__declspec(dllexport) volatile uint32_t clonewars_physics_input_failure[12];
}

namespace {
int fail(unsigned reason,const SyncPhysicsChoice *local=nullptr,const SyncPhysicsChoice *expected=nullptr) {
    if (!live()) return 0;
    failed=true;
    if (!clonewars_physics_input_failure[0]) {
        const uint32_t values[]={frame->epoch,frame->sequence,cursor,reason,
            local?local->kind:0,expected?expected->kind:0,
            local?local->name_hash[0]:0,expected?expected->name_hash[0]:0,
            local?local->clock:0,expected?expected->clock:0,
            local?local->site:0,expected?expected->site:0};
        std::memcpy(const_cast<uint32_t *>(clonewars_physics_input_failure),values,sizeof(values));
    }
    ++clonewars_physics_input_debug[2];game_sync_native_fault(15);return 0;
}
bool describe(void *raw,unsigned kind,uint32_t site,SyncPhysicsChoice &choice) {
    auto *p=static_cast<unsigned char *>(raw);
    if (!readable(p,0x168)) return false;
    auto *source=reinterpret_cast<const unsigned char *>(word(p+0x164));
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
    choice={};choice.kind=kind;choice.site=site;choice.flags=word(p+0x11c);
    uint16_t model;std::memcpy(&model,p+0x156,2);choice.model=model;
    choice.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    choice.name_hash[0]=hash;choice.name_hash[1]=second;
    std::memcpy(choice.recipe,p+0x124,sizeof(choice.recipe));choice.rng=rng();
    return physics_choice_valid(&choice)!=0;
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
    if (host) frame->physics_choice_count=frame->physics_choice_reserved=0;
    if (last_epoch!=frame->epoch) {
        std::memset(const_cast<uint32_t *>(clonewars_physics_input_failure),0,sizeof(clonewars_physics_input_failure));
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
int physics_input_install(void) {
    const uintptr_t addresses[]={0x71ab90,0x71ac10};
    const unsigned char bytes[2][6]={{0x56,0x57,0x8b,0x7c,0x24,0x0c},{0x56,0x68,0x98,0xf4,0xe5,0x00}};
    void *hooks[]={reinterpret_cast<void *>(axis_hook),reinterpret_cast<void *>(rotation_hook)};
    for (unsigned i=0;i<2;++i)
        if (!readable(reinterpret_cast<void *>(addresses[i]),6) || std::memcmp(reinterpret_cast<void *>(addresses[i]),bytes[i],6)) return 0;
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
    clonewars_physics_input_debug[4]=3;return 1;
}
