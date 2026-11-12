#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include "physics_input_sync.h"
#include "vehicle_rng_input_sync.h"
#include "../engine/vehicle_rng_thunk.h"
extern "C" {
#include "entity_sync.h"
#include "game_sync.h"
#include "../engine/rigid_body_binding.h"
__declspec(dllexport) volatile uint32_t clonewars_vehicle_rng_debug[4],clonewars_vehicle_rng_correction[12],clonewars_vehicle_rng_failure[12];
__attribute__((used)) static volatile uintptr_t vehicle_rng_float_native=0x573100,vehicle_rng_integer_native=0x573160;
}
namespace {
bool installed;
template<class T>T field(const void *p,size_t offset){T value;std::memcpy(&value,static_cast<const unsigned char *>(p)+offset,sizeof value);return value;}
bool readable(const void *p,size_t bytes){
    MEMORY_BASIC_INFORMATION m;const auto address=reinterpret_cast<uintptr_t>(p);
    return p && bytes && VirtualQuery(p,&m,sizeof m) && m.State==MEM_COMMIT && !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
        address+bytes>=address && address+bytes<=reinterpret_cast<uintptr_t>(m.BaseAddress)+m.RegionSize;
}
void reject(const CoherentFrameToken &token,const void *component,uint32_t site,uint32_t reason){
    if (!coherent_frame_valid(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))) return;
    ++clonewars_vehicle_rng_debug[3];
    if (!clonewars_vehicle_rng_failure[2]) {
        const uint32_t values[]={token.epoch,token.sequence,reason,*reinterpret_cast<uint32_t *>(0xfb4b6c),site,
            reinterpret_cast<uintptr_t>(component)};
        std::memcpy(const_cast<uint32_t *>(clonewars_vehicle_rng_failure),values,sizeof values);
    }
    game_sync_native_fault(15);
}
}
extern "C" void __cdecl physics_apply_vehicle_rng(void *component,uint32_t site){
    const DWORD error=GetLastError();
    CoherentFrameToken token{};
    if (!coherent_frame_get(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))) {SetLastError(error);return;}
    if (!physics_vehicle_rng_site(site) || !readable(component,0x2a0) || field<uint32_t>(component,0x60)!=4) {
        reject(token,component,site,1);SetLastError(error);return;
    }
    void *actor=field<void *>(component,0x29c);
    const uint32_t generation=entities_local_generation(actor);
    NativeRigidBodyBinding source{};
    // Native death motion can continue after activity clears, before the registered body retires.
    if (!entities_allocation_retained(actor,generation) || !native_actor_rigid_body(actor,&source) || source.component!=component) {
        if (!clonewars_vehicle_rng_failure[2]) {
            const auto *driver=field<unsigned char *>(component,0x294);
            const auto *body=readable(driver,0x264)?field<unsigned char *>(driver,0x260):nullptr;
            const auto *manager=*reinterpret_cast<unsigned char **>(0xfbdb3c);
            uint32_t registered=0;
            if (readable(manager,0x160)) {
                const auto count=field<uint32_t>(manager,0x15c);
                if (count<=SYNC_MAX_ACTORS && readable(manager+0x160,count*sizeof(void *)))
                    for (uint32_t i=0;i<count;++i) if (field<void *>(manager,0x160+i*sizeof(void *))==component) registered=1;
            }
            const uint32_t values[]={reinterpret_cast<uintptr_t>(actor),generation,readable(actor,0x54)?field<uint32_t>(actor,0x50):0,
                reinterpret_cast<uintptr_t>(driver),reinterpret_cast<uintptr_t>(body),registered};
            std::memcpy(const_cast<uint32_t *>(clonewars_vehicle_rng_failure)+6,values,sizeof values);
        }
        reject(token,component,site,2);SetLastError(error);return;
    }
    SyncActor identity{};entities_describe(&identity,actor);
    SyncPhysicsChoice input{};input.kind=SYNC_PHYSICS_VEHICLE_RNG;input.site=site;
    auto &v=input.vehicle_rng;v.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    v.value=*reinterpret_cast<uint32_t *>(0xea178c);v.slot=UINT32_MAX;
    entities_observed_identity(actor,&v.slot,&v.generation);
    v.character=field<int16_t>(actor,0xdc0);v.spawn_tag=identity.spawn_tag;v.spawn_source=identity.spawn_source;v.vehicle_type=4;
    const uint32_t seed=v.value;
    if (!coherent_frame_valid(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || physics_vehicle_rng_input(&input,actor,&token)!=1 ||
        !coherent_frame_valid(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)) || *reinterpret_cast<uint32_t *>(0xfb4b6c)!=v.clock ||
        !entities_allocation_retained(actor,generation) || !native_actor_rigid_body_same(actor,&source) ||
        *reinterpret_cast<uint32_t *>(0xea178c)!=seed) {
        reject(token,component,site,3);SetLastError(error);return;
    }
    *reinterpret_cast<uint32_t *>(0xea178c)=v.value;
    ++clonewars_vehicle_rng_debug[0];
    if (seed!=v.value) {
        ++clonewars_vehicle_rng_debug[1];
        if (!clonewars_vehicle_rng_correction[0]) {
            const uint32_t values[]={token.epoch,token.sequence,v.clock,site,v.slot,v.generation,
                static_cast<uint32_t>(v.character),v.spawn_tag,v.spawn_source.producer,v.spawn_source.serial,seed,v.value};
            std::memcpy(const_cast<uint32_t *>(clonewars_vehicle_rng_correction),values,sizeof values);
        }
    }
    SetLastError(error);
}
extern "C" {
__attribute__((naked,used)) void vehicle_rng_float_thunk(void){__asm__ volatile(VEHICLE_RNG_THUNK_ASM("_vehicle_rng_float_native"));}
__attribute__((naked,used)) void vehicle_rng_integer_thunk(void){__asm__ volatile(VEHICLE_RNG_THUNK_ASM("_vehicle_rng_integer_native"));}
}
int vehicle_rng_input_install(void){
    if (installed) return 1;
    const uintptr_t sites[]={0x997f03,0x997f14,0x997f25,0x99803e,0x998085,0x9980b4,0x99813e,0x9981cf,0x998288,0x9982b7,0x9982ee};
    for (const auto site:sites) {
        const auto *p=reinterpret_cast<const unsigned char *>(site);
        const auto target=site==0x9981cf?0x573160u:0x573100u;
        if (!readable(p,5) || p[0]!=0xe8 || site+5+field<int32_t>(p,1)!=target) return 0;
    }
    for (const auto site:sites) {
        auto *p=reinterpret_cast<unsigned char *>(site);DWORD old;
        if (!VirtualProtect(p,5,PAGE_EXECUTE_READWRITE,&old)) return 0;
        const auto target=reinterpret_cast<uintptr_t>(site==0x9981cf?vehicle_rng_integer_thunk:vehicle_rng_float_thunk);
        const int32_t offset=static_cast<int32_t>(target-site-5);std::memcpy(p+1,&offset,sizeof offset);
        const bool flushed=FlushInstructionCache(GetCurrentProcess(),p,5)!=0;DWORD ignored;
        if (!VirtualProtect(p,5,old,&ignored) || !flushed) return 0;
    }
    installed=true;clonewars_vehicle_rng_debug[2]=1;return 1;
}
