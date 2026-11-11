#pragma once
#include <math.h>
#include "../net/sync_wire.h"

#ifdef __cplusplus
extern "C" {
#endif
#include "coherent_frame_fence.h"
int physics_input_install(void);
int physics_input_begin(SyncFrame *,int);
int physics_input_finish(void);
void physics_input_cancel(void);
int physics_world_input(SyncPhysicsChoice *,const CoherentFrameToken *);
int physics_module_input(SyncPhysicsChoice *,const CoherentFrameToken *);
static inline int physics_choice_valid(const SyncPhysicsChoice *choice) {
    if (!choice) return 0;
    if(choice->kind==SYNC_PHYSICS_SPELLIT_STEP) {
        const SyncPhysicsSpellItStepInput *s=&choice->spellit_step;
        if(choice->site!=0x86101e || s->game_seed>UINT16_MAX || !isfinite(s->delta) || s->delta<0 || s->delta>.1f ||
           !isfinite(s->timer) || !s->gizmo_class || s->gizmo_ordinal>=65536 ||
           !(s->source_name[0]|s->source_name[1]|s->source_name[2]|s->source_name[3]))return 0;
        for(unsigned i=0;i<9;++i)if(s->reserved[i])return 0;
        return 1;
    }
    if(choice->kind==SYNC_PHYSICS_SPELLIT_POSE) {
        const SyncPhysicsSpellItPoseInput *p=&choice->spellit_pose;
        if(choice->site!=0x8406b2 || !p->gizmo_class || p->gizmo_ordinal>=65536 ||
           !isfinite(p->last_time) ||
           !(p->source_name[0]|p->source_name[1]|p->source_name[2]|p->source_name[3]) ||
           !(p->resource_name[0]|p->resource_name[1]|p->resource_name[2]|p->resource_name[3]) ||
           !(p->poi_name[0]|p->poi_name[1]|p->poi_name[2]|p->poi_name[3]))return 0;
        for(unsigned i=0;i<3;++i)if(!isfinite(p->position[i]))return 0;
        return 1;
    }
    if (choice->kind==SYNC_PHYSICS_MODULE_SEED) {
        const SyncPhysicsModuleInput *m=&choice->module;
        if (choice->site!=0x4da6d0 || !m->module_id || !m->module_type || m->module_class!=0x6e6b3c ||
            m->burst_min>UINT8_MAX || m->burst_max>UINT8_MAX || m->burst_min>=m->burst_max ||
            m->channel_count>3 || m->weapon<INT8_MIN || m->weapon>INT8_MAX) return 0;
        for (unsigned i=0;i<3;++i) if (!isfinite(m->intervals[i])) return 0;
        for (unsigned i=0;i<7;++i) if (m->reserved[i]) return 0;
        return 1;
    }
    if (choice->kind==SYNC_PHYSICS_GUN_JAM_SEED) {
        const SyncPhysicsGunJamInput *jam=&choice->gun_jam;
        if (choice->site!=0x4acb53 || !jam->module_id || !jam->module_type ||
            jam->member_count>12 || jam->candidate_count>INT32_MAX ||
            jam->clip<INT16_MIN || jam->clip>INT16_MAX ||
            !isfinite(jam->remaining) || !isfinite(jam->minimum) || !isfinite(jam->maximum)) return 0;
        for (unsigned i=0;i<9;++i) if (jam->reserved[i]) return 0;
        return 1;
    }
    if (choice->kind>=SYNC_PHYSICS_SPELLIT_SEED && choice->kind<=SYNC_PHYSICS_SPELLIT_ENABLED) {
        const SyncPhysicsWorldInput *w=&choice->world;
        if (!w->gizmo_class || w->gizmo_ordinal>=65536 ||
            !(w->source_name[0]|w->source_name[1]|w->source_name[2]|w->source_name[3])) return 0;
        if (choice->kind==SYNC_PHYSICS_SPELLIT_SEED) {
            if (choice->site!=0x86101e || w->poi_ordinal || w->poi_count || w->receiver_class || w->piece_ordinal) return 0;
            for (unsigned i=0;i<4;++i) if (w->resource_name[i] || w->poi_name[i]) return 0;
            return 1;
        }
        return choice->site==(choice->kind==SYNC_PHYSICS_SPELLIT_ENTITY?0x8407d4u:0x84085bu) &&
            w->value<=1 && w->receiver_class && w->piece_ordinal<65536 &&
            w->poi_count && w->poi_count<=65536 && w->poi_ordinal<w->poi_count &&
            (w->resource_name[0]|w->resource_name[1]|w->resource_name[2]|w->resource_name[3]) &&
            (w->poi_name[0]|w->poi_name[1]|w->poi_name[2]|w->poi_name[3]);
    }
    const unsigned char *tail=(const unsigned char *)choice+56;
    for (unsigned i=56;i<sizeof(*choice);++i) if (tail[i-56]) return 0;
    if (!(choice->flags&0x40000000u) || choice->model>UINT16_MAX ||
        (!choice->name_hash[0] && !choice->name_hash[1]) || choice->site<0x400000 || choice->site>=0xb00000) return 0;
    return (choice->kind==SYNC_PHYSICS_AXIS_SPIN && (choice->flags&0x80u)) ||
           (choice->kind==SYNC_PHYSICS_ROTATION_SPIN && (choice->flags&0x100000u)) ||
           (choice->kind==SYNC_PHYSICS_BREAKUP_LAUNCH && choice->site==0x905f38);
}
static inline int physics_choice_same_source(const SyncPhysicsChoice *a,const SyncPhysicsChoice *b) {
    if (!physics_choice_valid(a) || !physics_choice_valid(b) || a->kind!=b->kind || a->site!=b->site) return 0;
    if(a->kind==SYNC_PHYSICS_SPELLIT_STEP) {
        if(a->spellit_step.clock!=b->spellit_step.clock)return 0;
        const unsigned char *first=(const unsigned char *)&a->spellit_step,*second=(const unsigned char *)&b->spellit_step;
        for(unsigned i=20;i<sizeof(a->spellit_step);++i)if(first[i]!=second[i])return 0;
        return 1;
    }
    if(a->kind==SYNC_PHYSICS_SPELLIT_POSE) {
        if(a->spellit_pose.clock!=b->spellit_pose.clock)return 0;
        const unsigned char *first=(const unsigned char *)&a->spellit_pose,*second=(const unsigned char *)&b->spellit_pose;
        for(unsigned i=16;i<76;++i)if(first[i]!=second[i])return 0;
        return 1;
    }
    if (a->kind>=SYNC_PHYSICS_SPELLIT_SEED) {
        if (a->world.clock!=b->world.clock) return 0;
        const unsigned char *first=(const unsigned char *)&a->world,*second=(const unsigned char *)&b->world;
        for (unsigned i=8;i<sizeof(a->world);++i) {
            // Native pool generations guard local allocation reuse; authored IDs identify peers.
            if((a->kind==SYNC_PHYSICS_MODULE_SEED || a->kind==SYNC_PHYSICS_GUN_JAM_SEED) && i>=16 && i<20)continue;
            if (first[i]!=second[i]) return 0;
        }
        return 1;
    }
    if (
        a->flags!=b->flags || a->model!=b->model || a->clock!=b->clock ||
        a->name_hash[0]!=b->name_hash[0] || a->name_hash[1]!=b->name_hash[1]) return 0;
    for (unsigned i=0;i<6;++i) if (a->recipe[i]!=b->recipe[i]) return 0;
    return 1;
}
#ifdef __cplusplus
}
#endif
