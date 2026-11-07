#pragma once
#include "rigid_body_binding.h"
namespace clonewars::engine {
using RigidOwnerLookup=void *(__thiscall *)(void *,const void *);
using RigidTransform=void (__thiscall *)(void *,const float *);
class RigidBodySource {
public:
    RigidBodySource(void *manager,RigidOwnerLookup owner,RigidTransform transform):manager_(manager),owner_(owner),transform_(transform) {}
    bool resolve(const void *actor,NativeRigidBodyBinding &out) const;
    bool matches(const void *actor,const NativeRigidBodyBinding &binding) const;
    void transform(void *body,const float *matrix) const;
private:
    void *manager_;
    RigidOwnerLookup owner_;
    RigidTransform transform_;
};
}
