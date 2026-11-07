#pragma once
#include <math.h>
#include "../net/sync_wire.h"
#include "../engine/cohort_module_lease.h"
typedef struct ReactionJournal { SyncFrame *frame;uint32_t cursor;int host,failed; } ReactionJournal;
#define REACTION_ARENA_NO_CLIP (-2)
static inline int reaction_entry_valid(const SyncReactionChoice *entry) {
    if (!entry || entry->slot>=SYNC_MAX_ACTORS || !entry->generation || entry->character<0 || entry->character>=4096 ||
        entry->old_action<INT16_MIN || entry->old_action>INT16_MAX ||
        !isfinite(entry->origin[0]) || !isfinite(entry->origin[1]) || !isfinite(entry->origin[2])) return 0;
    if (entry->kind==SYNC_REACTION_DAMAGE_DRAW)
        return entry->source_id && !entry->arena_attacker_slot && !entry->arena_attacker_generation && entry->damage_draw<=UINT16_MAX;
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
int reaction_install(void);
int reaction_ready(void);
int reaction_begin(SyncFrame *,int);
int reaction_finish(void);
int reaction_drain_arena(void);
int reaction_client_duplicate_projectile(void *actor,uint32_t source_id);

void reaction_cancel(void);

typedef CohortModuleLease ReactionFrameLease;
int reaction_bind_cohort(const CoherentFrameToken *);
int reaction_frame_lease_get(ReactionFrameLease *);
int reaction_frame_cancelled(const ReactionFrameLease *);
int reaction_abort_frame(const ReactionFrameLease *);
