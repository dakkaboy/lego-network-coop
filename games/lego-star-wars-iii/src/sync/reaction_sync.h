#pragma once
#include <math.h>
#include "../net/sync_wire.h"
#include "../engine/cohort_module_lease.h"
typedef struct ReactionJournal { SyncFrame *frame;uint32_t cursor;int host,failed; } ReactionJournal;
#define REACTION_ARENA_NO_CLIP (-2)
static inline int reaction_entry_valid(const SyncReactionChoice *entry) {
    return entry && entry->slot<SYNC_MAX_ACTORS && entry->generation && entry->character>=0 && entry->character<4096 &&
        (entry->arena_attacker_generation ?
         entry->arena_attacker_slot<SYNC_MAX_ACTORS && entry->arena_attacker_slot!=entry->slot && !entry->source_id :
         !entry->arena_attacker_slot) &&
        entry->old_action>=-32768 && entry->old_action<=32767 && entry->clip>=(entry->arena_attacker_generation ? REACTION_ARENA_NO_CLIP : -1) && entry->clip<4096 &&
        isfinite(entry->origin[0]) && isfinite(entry->origin[1]) && isfinite(entry->origin[2]);
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
