#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include "rigid_body_binding.hpp"
#include "../net/sync_wire.h"
namespace {
bool readable(const void *p,size_t size) {
    MEMORY_BASIC_INFORMATION m;const auto address=reinterpret_cast<uintptr_t>(p);
    return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT && !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
        address+size>=address && address+size<=reinterpret_cast<uintptr_t>(m.BaseAddress)+m.RegionSize;
}
clonewars::engine::RigidBodySource current_source() {
    return {*reinterpret_cast<void **>(0xfbdb3c),
        reinterpret_cast<clonewars::engine::RigidOwnerLookup>(0x9736c0),
        reinterpret_cast<clonewars::engine::RigidTransform>(0xa29570)};
}
}
namespace clonewars::engine {
bool RigidBodySource::resolve(const void *actor,NativeRigidBodyBinding &out) const {
    out={};
    const auto *manager=static_cast<const unsigned char *>(manager_);
    if (!readable(actor,0x1440) || !readable(manager,0x160)) return 0;
    const auto count=*reinterpret_cast<const uint32_t *>(manager+0x15c);
    if (count>SYNC_MAX_ACTORS || !readable(manager+0x160,count*sizeof(void *))) return 0;
    auto *component=static_cast<unsigned char *>(owner_(manager_,actor));
    if (!readable(component,0x2a0) || *reinterpret_cast<void **>(component+0x29c)!=actor) return 0;
    auto *driver=*reinterpret_cast<unsigned char **>(component+0x294);
    if (!readable(driver,0x264)) return 0;
    auto *body=*reinterpret_cast<unsigned char **>(driver+0x260);
    if (!readable(body,0xa0)) return 0;
    auto *dynamics=*reinterpret_cast<void **>(body+0x98);
    if (dynamics && !readable(dynamics,0x50)) return 0;
    out={component,driver,body,dynamics};return true;
}
bool RigidBodySource::matches(const void *actor,const NativeRigidBodyBinding &binding) const {
    NativeRigidBodyBinding current;
    return resolve(actor,current) && current.component==binding.component &&
        current.driver==binding.driver && current.body==binding.body && current.dynamics==binding.dynamics;
}
void RigidBodySource::transform(void *body,const float *matrix) const {transform_(body,matrix);}
}
int native_actor_rigid_body(const void *actor,NativeRigidBodyBinding *out) {return current_source().resolve(actor,*out);}
int native_actor_rigid_body_same(const void *actor,const NativeRigidBodyBinding *binding) {return current_source().matches(actor,*binding);}
void native_rigid_body_transform(void *body,const float *transform) {current_source().transform(body,transform);}
