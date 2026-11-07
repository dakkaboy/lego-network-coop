#pragma once
#include "../net/sync_wire.h"

#ifdef __cplusplus
extern "C" {
#endif
int physics_input_install(void);
int physics_input_begin(SyncFrame *,int);
int physics_input_finish(void);
void physics_input_cancel(void);
static inline int physics_choice_valid(const SyncPhysicsChoice *choice) {
    if (!choice || !(choice->flags&0x40000000u) || choice->model>UINT16_MAX ||
        (!choice->name_hash[0] && !choice->name_hash[1]) || choice->site<0x400000 || choice->site>=0xb00000) return 0;
    return (choice->kind==SYNC_PHYSICS_AXIS_SPIN && (choice->flags&0x80u)) ||
           (choice->kind==SYNC_PHYSICS_ROTATION_SPIN && (choice->flags&0x100000u));
}
static inline int physics_choice_same_source(const SyncPhysicsChoice *a,const SyncPhysicsChoice *b) {
    if (!physics_choice_valid(a) || !physics_choice_valid(b) || a->kind!=b->kind || a->site!=b->site ||
        a->flags!=b->flags || a->model!=b->model || a->clock!=b->clock ||
        a->name_hash[0]!=b->name_hash[0] || a->name_hash[1]!=b->name_hash[1]) return 0;
    for (unsigned i=0;i<6;++i) if (a->recipe[i]!=b->recipe[i]) return 0;
    return 1;
}
#ifdef __cplusplus
}
#endif
