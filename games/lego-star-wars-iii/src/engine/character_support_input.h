#pragma once
#include <math.h>
#include <stddef.h>
#include <string.h>
#include "../net/sync_wire.h"
static inline int character_support_input_valid(const SyncCharacterMotionState *p) {
    if (!p || (!!p->support_frame != !!p->support_event) || (p->support_material_flags&~0x1ffffu)) return 0;
    for (unsigned i=0;i<4;++i) if (!isfinite(p->support_anchor[i])) return 0;
    for (unsigned i=0;i<3;++i) if (!isfinite(p->support_normal[i])) return 0;
    if (!p->support_frame) {
        const unsigned char *start=(const unsigned char *)&p->support_frame;
        for (unsigned i=0;i<sizeof(*p)-offsetof(SyncCharacterMotionState,support_frame);++i) if(start[i])return 0;
    }
    return 1;
}
static inline int character_support_same_source(const SyncCharacterMotionState *a,const SyncCharacterMotionState *b) {
    return character_support_input_valid(a) && character_support_input_valid(b) &&
        a->support_frame==b->support_frame && a->support_event==b->support_event;
}
static inline int character_support_replay(void *body,const SyncCharacterMotionState *local,const SyncCharacterMotionState *expected) {
    if (!character_support_same_source(local,expected)) return 0;
    if (!expected->support_frame) return 1;
    if (!body) return 0;
    unsigned char *p=(unsigned char *)body;
    memcpy(p+0x110,expected->support_anchor,sizeof expected->support_anchor);
    memcpy(p+0xf0,expected->support_normal,sizeof expected->support_normal);
    const uint16_t material=(uint16_t)expected->support_material_flags;
    memcpy(p+0x102,&material,sizeof material);
    uint32_t flags;memcpy(&flags,p+0xc0,sizeof flags);
    flags=(flags&~1u)|(expected->support_material_flags>>16);
    memcpy(p+0xc0,&flags,sizeof flags);return 1;
}
