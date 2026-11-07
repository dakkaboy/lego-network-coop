#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdint>
#include <cstring>
#include <cstdio>
#include "../src/engine/rigid_body_binding.hpp"
#include "../src/net/sync_wire.h"
static unsigned char manager[0x164],actor[0x1440],component[0x2a0],replacement[0x2a0],driver[0x264],body[0xb0],other_body[0xb0],dynamics[0xa0];
static void *selected=component;
static unsigned lookups,transforms;
static void *__attribute__((thiscall)) lookup(void *self,const void *requested) {
    assert(self==manager && requested==actor);++lookups;return selected;
}
static void __attribute__((thiscall)) transform(void *self,const float *matrix) {
    assert(self==body);++transforms;std::memcpy(body+0x40,matrix,64);
}
int main() {
    const clonewars::engine::RigidBodySource source(manager,lookup,transform),empty(nullptr,lookup,transform);
    *reinterpret_cast<uint32_t *>(manager+0x15c)=1;
    *reinterpret_cast<void **>(manager+0x160)=component;
    *reinterpret_cast<void **>(component+0x29c)=actor;
    *reinterpret_cast<void **>(component+0x294)=driver;
    *reinterpret_cast<void **>(driver+0x260)=body;
    NativeRigidBodyBinding binding;
    assert(source.resolve(actor,binding) && binding.component==component && binding.driver==driver && binding.body==body);
    assert(source.matches(actor,binding));
    *reinterpret_cast<void **>(body+0x98)=dynamics;
    assert(!source.matches(actor,binding));
    assert(source.resolve(actor,binding) && binding.dynamics==dynamics);
    *reinterpret_cast<void **>(body+0x98)=reinterpret_cast<void *>(1);
    assert(!source.resolve(actor,binding));
    *reinterpret_cast<void **>(body+0x98)=nullptr;
    assert(source.resolve(actor,binding));
    *reinterpret_cast<void **>(driver+0x260)=other_body;
    assert(!source.matches(actor,binding));
    *reinterpret_cast<void **>(driver+0x260)=body;
    std::memcpy(replacement,component,sizeof(component));selected=replacement;
    assert(!source.matches(actor,binding));selected=component;
    *reinterpret_cast<void **>(component+0x29c)=other_body;
    assert(!source.resolve(actor,binding) && !binding.body);
    *reinterpret_cast<void **>(component+0x29c)=actor;
    *reinterpret_cast<void **>(driver+0x260)=nullptr;
    assert(!source.resolve(actor,binding) && !binding.body);
    *reinterpret_cast<void **>(driver+0x260)=body;
    *reinterpret_cast<uint32_t *>(manager+0x15c)=SYNC_MAX_ACTORS+1;
    const auto before=lookups;assert(!source.resolve(actor,binding) && lookups==before);
    *reinterpret_cast<uint32_t *>(manager+0x15c)=1;
    assert(!empty.resolve(actor,binding));
    assert(source.resolve(actor,binding));
    const float matrix[16]={0,0,1,0,0,1,0,0,-1,0,0,0,12,3,-5,1};
    source.transform(binding.body,matrix);
    assert(transforms==1 && !std::memcmp(body+0x40,matrix,sizeof(matrix)));
    puts("Native physical-owner binding preserves actor/component/driver/body ownership, rejects stale links and forwards one native transform call.");
}
