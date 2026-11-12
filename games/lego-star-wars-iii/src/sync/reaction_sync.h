#pragma once
#include <math.h>
#include "../net/sync_wire.h"
#include "../engine/cohort_module_lease.h"
typedef struct ReactionJournal { SyncFrame *frame;uint32_t cursor;int host,failed; } ReactionJournal;
#define REACTION_ARENA_NO_CLIP (-2)
static inline int reaction_hit_outcome_empty(const SyncReactionHitOutcome *hit) {
    const unsigned char *unused=(const unsigned char *)hit;
    for (unsigned i=0;i<sizeof(*hit);++i) if (unused[i]) return 0;
    return 1;
}
static inline int reaction_hit_outcome_valid(const SyncReactionHitOutcome *hit) {
    return hit && hit->completed==1 && hit->health_before>=INT8_MIN && hit->health_before<=INT8_MAX &&
        hit->health_after>=INT8_MIN && hit->health_after<=INT8_MAX && !(hit->life_before&~0xff03u) && !(hit->life_after&~0xff03u) &&
        ((hit->life_before&3)==1 || (hit->life_before&3)==3) &&
        (hit->life_after==0 || (hit->life_after&3)==1 || (hit->life_after&3)==3) &&
        hit->action_before>=INT16_MIN && hit->action_before<=INT16_MAX && hit->action_after>=INT16_MIN && hit->action_after<=INT16_MAX &&
        isfinite(hit->timer_before) && isfinite(hit->timer_after) &&
        (hit->life_after || (!hit->health_after && !hit->action_after && hit->timer_after==0));
}
static inline int reaction_hit_outcome_same(const SyncReactionHitOutcome *a,const SyncReactionHitOutcome *b) {
    return reaction_hit_outcome_valid(a) && reaction_hit_outcome_valid(b) &&
        a->health_before==b->health_before && a->health_after==b->health_after &&
        a->life_before==b->life_before && a->life_after==b->life_after &&
        a->action_before==b->action_before && a->action_after==b->action_after &&
        a->timer_before==b->timer_before && a->timer_after==b->timer_after;
}
static inline int reaction_entry_valid(const SyncReactionChoice *entry) {
    if (!entry || entry->slot>=SYNC_MAX_ACTORS || !entry->generation || entry->character<0 || entry->character>=4096 ||
        entry->old_action<INT16_MIN || entry->old_action>INT16_MAX ||
        !isfinite(entry->origin[0]) || !isfinite(entry->origin[1]) || !isfinite(entry->origin[2])) return 0;
    if (entry->kind==SYNC_REACTION_DAMAGE_DRAW)
        return entry->source_id && !entry->arena_attacker_slot && !entry->arena_attacker_generation && entry->damage_draw<=UINT16_MAX && reaction_hit_outcome_empty(&entry->hit);
    if (entry->kind==SYNC_REACTION_ITEM_RANGE) {
        const SyncItemRange *range=&entry->range;
        if (range->target_slot>=SYNC_MAX_ACTORS || range->target_slot==entry->slot || !range->target_generation ||
            range->reverse>1 || range->reserved || !isfinite(range->reach) ||
            !isfinite(range->actor_radius) || !isfinite(range->target_radius)) return 0;
        for (unsigned i=0;i<3;++i)
            if (!isfinite(range->actor_position[i]) || !isfinite(range->target_position[i])) return 0;
        return 1;
    }
    if (entry->kind!=SYNC_REACTION_CLIP) return 0;
    if (entry->hit.completed) {
        if (entry->clip!=-1 || !entry->source_id || entry->arena_attacker_generation || !reaction_hit_outcome_valid(&entry->hit)) return 0;
    } else {
        if (!reaction_hit_outcome_empty(&entry->hit)) return 0;
    }
    return (entry->arena_attacker_generation ?
        entry->arena_attacker_slot<SYNC_MAX_ACTORS && entry->arena_attacker_slot!=entry->slot && !entry->source_id :
        !entry->arena_attacker_slot) &&
        entry->clip>=(entry->arena_attacker_generation ? REACTION_ARENA_NO_CLIP : -1) && entry->clip<4096;
}
void reaction_journal_begin(ReactionJournal *,SyncFrame *,int);
int reaction_journal_record(ReactionJournal *,const SyncReactionChoice *);
const SyncReactionChoice *reaction_journal_peek(const ReactionJournal *);
int reaction_journal_apply(ReactionJournal *,const SyncReactionChoice *,int,int,uint32_t,int,uint32_t *);
int reaction_journal_finish(const ReactionJournal *);
int reaction_journal_complete_no_clip(ReactionJournal *,uint32_t,uint32_t,uint32_t,uint32_t,const SyncReactionHitOutcome *);
int reaction_install(void);
int reaction_ready(void);
int reaction_begin(SyncFrame *,int);
int reaction_finish(void);
int reaction_drain_arena(void);
int reaction_client_duplicate_projectile(void *actor,uint32_t source_id);

void reaction_cancel(void);

typedef CohortModuleLease ReactionFrameLease;
typedef struct ReactionDamageReceipt {
    ReactionFrameLease lease;
    uint32_t cursor,slot,generation,source_id;
    const unsigned char *actor;
    uint32_t local_generation;
    SyncReactionHitOutcome hit;
    int valid;
} ReactionDamageReceipt;
void reaction_damage_begin(ReactionDamageReceipt *,const void *,uint32_t);
void reaction_damage_complete(const ReactionDamageReceipt *);
int reaction_bind_cohort(const CoherentFrameToken *);
int reaction_frame_lease_get(ReactionFrameLease *);
int reaction_frame_cancelled(const ReactionFrameLease *);
int reaction_abort_frame(const ReactionFrameLease *);
