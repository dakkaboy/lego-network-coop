#pragma once
#include <math.h>
#include <string.h>
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
int physics_vehicle_rng_input(SyncPhysicsChoice *,const void *,const CoherentFrameToken *);
int physics_effect_body_source(const void *,uint32_t source[2]);
static inline int physics_vehicle_rng_site(uint32_t site) {
    switch (site) {
    case 0x997f03:case 0x997f14:case 0x997f25:case 0x99803e:case 0x998085:case 0x9980b4:
    case 0x99813e:case 0x9981cf:case 0x998288:case 0x9982b7:case 0x9982ee:return 1;
    default:return 0;
    }
}
static inline int physics_choice_valid(const SyncPhysicsChoice *choice) {
    if (!choice) return 0;
    if (choice->kind==SYNC_PHYSICS_EFFECT_BIRTH) {
        if (choice->site!=0x7427d8 || !(choice->flags&0x40000000u) || choice->model>UINT16_MAX ||
            !(choice->name_hash[0]|choice->name_hash[1]) || choice->rng) return 0;
        for (unsigned i=0;i<6;++i) if (choice->recipe[i]) return 0;
        for (unsigned i=56;i<sizeof(*choice);++i) if (((const unsigned char *)choice)[i]) return 0;
        return 1;
    }
    if (choice->kind==SYNC_PHYSICS_BREAKUP_BASIS) {
        const SyncPhysicsBreakupBasisInput *p=&choice->breakup_basis;
        if (choice->site!=0x905f38 || p->model>UINT16_MAX || !(p->name_hash[0]|p->name_hash[1])) return 0;
        for (unsigned i=0;i<16;++i) if (!isfinite(p->matrix[i])) return 0;
        return 1;
    }
    if (choice->kind==SYNC_PHYSICS_BREAKUP_SCALE) {
        if (choice->site!=0x905f38 || !(choice->flags&0x40000000u) || choice->model>UINT16_MAX ||
            !(choice->name_hash[0]|choice->name_hash[1]) || choice->rng) return 0;
        for (unsigned i=0;i<3;++i) { float v;memcpy(&v,choice->recipe+i,4);if (!isfinite(v)) return 0; }
        for (unsigned i=3;i<6;++i) if (choice->recipe[i]) return 0;
        for (unsigned i=56;i<sizeof(*choice);++i) if (((const unsigned char *)choice)[i]) return 0;
        return 1;
    }
    if (choice->kind==SYNC_PHYSICS_VEHICLE_RNG) {
        const SyncPhysicsVehicleRngInput *v=&choice->vehicle_rng;
        if (!physics_vehicle_rng_site(choice->site) || v->slot>=SYNC_MAX_ACTORS || !v->generation ||
            v->character<0 || v->character>=4096 || v->vehicle_type!=4) return 0;
        for (unsigned i=0;i<11;++i) if (v->reserved[i]) return 0;
        return 1;
    }
    if(choice->kind==SYNC_PHYSICS_SPELLIT_BODY_BASIS||choice->kind==SYNC_PHYSICS_SPELLIT_BODY_MOTION){
        const SyncPhysicsSpellItBodyInput *body=&choice->spellit_body;
        if(choice->site!=0x840660||!body->body_class||body->body_class>=0x1000000||body->piece_ordinal>=65536||body->reserved||
           !(body->key[0]|body->key[1]|body->key[2]|body->key[3]))return 0;
        for(unsigned i=0;i<12;++i)if(!isfinite(body->values[i]))return 0;
        return 1;
    }
    if(choice->kind==SYNC_PHYSICS_SPELLIT_SELECTION) {
        const SyncPhysicsSpellItSelectionInput *s=&choice->spellit_selection;
        if((choice->site!=0x8406a7 && choice->site!=0x840790 && choice->site!=0x840b93) || !s->gizmo_class || s->gizmo_ordinal>=65536 ||
           s->piece_count>65536 || s->candidate_count>s->piece_count ||
           !(s->source_name[0]|s->source_name[1]|s->source_name[2]|s->source_name[3]) ||
           !(s->eligibility[0]|s->eligibility[1]|s->eligibility[2]|s->eligibility[3]))return 0;
        for(unsigned i=0;i<6;++i)if(s->reserved[i])return 0;
        return 1;
    }
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
    if ((choice->kind>=SYNC_PHYSICS_SPELLIT_SEED && choice->kind<=SYNC_PHYSICS_SPELLIT_ENABLED) ||
        choice->kind==SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS) {
        const SyncPhysicsWorldInput *w=&choice->world;
        if (!w->gizmo_class || w->gizmo_ordinal>=65536 ||
            !(w->source_name[0]|w->source_name[1]|w->source_name[2]|w->source_name[3])) return 0;
        if (choice->kind==SYNC_PHYSICS_SPELLIT_SEED) {
            if (choice->site!=0x86101e || w->poi_ordinal || w->poi_count || w->receiver_class || w->piece_ordinal) return 0;
            for (unsigned i=0;i<4;++i) if (w->resource_name[i] || w->poi_name[i]) return 0;
            return 1;
        }
        const int site_valid=choice->kind==SYNC_PHYSICS_SPELLIT_ENTITY?choice->site==0x8407d4u:
            choice->kind==SYNC_PHYSICS_SPELLIT_ENABLED?
                (choice->site==0x84085bu || choice->site==0x812d8cu || choice->site==0x812e02u):
                (choice->site==0x812d7au || choice->site==0x812df0u);
        const int value_valid=choice->kind==SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS?!(w->value&~4u):w->value<=1;
        return site_valid && value_valid && w->receiver_class && w->piece_ordinal<65536 &&
            w->poi_count && w->poi_count<=65536 && w->poi_ordinal<w->poi_count &&
            (w->resource_name[0]|w->resource_name[1]|w->resource_name[2]|w->resource_name[3]) &&
            (w->poi_name[0]|w->poi_name[1]|w->poi_name[2]|w->poi_name[3]);
    }
    const unsigned char *tail=(const unsigned char *)choice+56;
    for (unsigned i=56;i<sizeof(*choice);++i) if (tail[i-56]) return 0;
    if (!(choice->flags&0x40000000u) || choice->model>UINT16_MAX ||
        (!choice->name_hash[0] && !choice->name_hash[1]) || choice->site<0x400000 || choice->site>=0xb00000) return 0;
    if (choice->kind==SYNC_PHYSICS_BREAKUP_LAUNCH) {
        for (unsigned i=2;i<6;++i) {
            float value;memcpy(&value,choice->recipe+i,sizeof value);
            if (!isfinite(value)) return 0;
        }
    }
    return (choice->kind==SYNC_PHYSICS_AXIS_SPIN && (choice->flags&0x80u)) ||
           (choice->kind==SYNC_PHYSICS_ROTATION_SPIN && (choice->flags&0x100000u)) ||
           (choice->kind==SYNC_PHYSICS_BREAKUP_LAUNCH && choice->site==0x905f38);
}
static inline int physics_choice_same_source(const SyncPhysicsChoice *a,const SyncPhysicsChoice *b) {
    if (!physics_choice_valid(a) || !physics_choice_valid(b) || a->kind!=b->kind || a->site!=b->site) return 0;
    if (a->kind==SYNC_PHYSICS_BREAKUP_BASIS) return !memcmp(&a->breakup_basis,&b->breakup_basis,16);
    if (a->kind==SYNC_PHYSICS_BREAKUP_SCALE || a->kind==SYNC_PHYSICS_EFFECT_BIRTH) return a->flags==b->flags && a->model==b->model &&
        a->clock==b->clock && !memcmp(a->name_hash,b->name_hash,sizeof(a->name_hash));
    if(a->kind==SYNC_PHYSICS_SPELLIT_BODY_BASIS||a->kind==SYNC_PHYSICS_SPELLIT_BODY_MOTION)
        return !memcmp(&a->spellit_body,&b->spellit_body,32);
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
    const unsigned identity_words=a->kind==SYNC_PHYSICS_BREAKUP_LAUNCH?2:6;
    for (unsigned i=0;i<identity_words;++i) if (a->recipe[i]!=b->recipe[i]) return 0;
    return 1;
}
static inline int physics_breakup_geometry_replay(float *matrix,float *scale,const SyncPhysicsChoice *local_basis,
    const SyncPhysicsChoice *local_scale,const SyncPhysicsChoice *basis,const SyncPhysicsChoice *size) {
    if (!matrix || !scale || !local_basis || !local_scale ||
        local_basis->kind!=SYNC_PHYSICS_BREAKUP_BASIS || local_scale->kind!=SYNC_PHYSICS_BREAKUP_SCALE ||
        !physics_choice_same_source(local_basis,basis) || !physics_choice_same_source(local_scale,size) ||
        basis->breakup_basis.clock!=size->clock || basis->breakup_basis.model!=size->model ||
        memcmp(basis->breakup_basis.name_hash,size->name_hash,sizeof size->name_hash)) return 0;
    memcpy(matrix,basis->breakup_basis.matrix,sizeof basis->breakup_basis.matrix);
    memcpy(scale,size->recipe,3*sizeof(float));return 1;
}
static inline int physics_breakup_launch_replay(void *descriptor,const SyncPhysicsChoice *local,const SyncPhysicsChoice *expected) {
    if (!descriptor || !local || local->kind!=SYNC_PHYSICS_BREAKUP_LAUNCH ||
        !physics_choice_same_source(local,expected)) return 0;
    // Native 9689A0 supplies part masks followed by launch spread and inherited velocity.
    memcpy((unsigned char *)descriptor+0x10,expected->recipe+2,4*sizeof(uint32_t));
    return 1;
}
#ifdef __cplusplus
}
#endif
