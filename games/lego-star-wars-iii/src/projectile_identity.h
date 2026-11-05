#pragma once
#include <stdint.h>
enum ProjectileIdentityStatus { SHOT_NULL,SHOT_LIVE,SHOT_UNTRACKED,SHOT_RESOURCE_MISMATCH,SHOT_AMBIGUOUS,SHOT_INVALID,SHOT_REMOVED,SHOT_REPLACED };
typedef struct ProjectileIdentityCandidate { uintptr_t object,resource; uint32_t id; } ProjectileIdentityCandidate;
static inline int projectile_identity_select(const ProjectileIdentityCandidate *entries,unsigned count,
                                             uintptr_t object,uintptr_t resource,uint32_t *identity) {
    *identity=0;
    if (!object) return SHOT_NULL;
    if (!resource) return SHOT_INVALID;
    int mismatch=0;
    for (unsigned i=0;i<count;++i) {
        if (!entries[i].id || entries[i].object!=object) continue;
        if (entries[i].resource!=resource) { mismatch=1; continue; }
        if (*identity) { *identity=0; return SHOT_AMBIGUOUS; }
        *identity=entries[i].id;
    }
    return *identity ? SHOT_LIVE : mismatch ? SHOT_RESOURCE_MISMATCH : SHOT_UNTRACKED;
}
