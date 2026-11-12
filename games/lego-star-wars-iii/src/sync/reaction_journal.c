#include "reaction_sync.h"
void reaction_journal_begin(ReactionJournal *journal,SyncFrame *frame,int host) {
    *journal=(ReactionJournal){.frame=frame,.host=host};
    if (host) frame->reaction_count=frame->reaction_reserved=0;
}
int reaction_journal_record(ReactionJournal *journal,const SyncReactionChoice *entry) {
    if (journal->failed || !journal->host || journal->frame->reaction_count>=SYNC_MAX_ACTORS || !reaction_entry_valid(entry)) { journal->failed=6;return 0; }
    journal->frame->reactions[journal->frame->reaction_count++]=*entry;return 1;
}
const SyncReactionChoice *reaction_journal_peek(const ReactionJournal *journal) {
    return !journal->failed && journal->cursor<journal->frame->reaction_count ? journal->frame->reactions+journal->cursor : 0;
}
int reaction_journal_apply(ReactionJournal *journal,const SyncReactionChoice *entry,int owner_matches,int old_action,uint32_t source_id,int available,uint32_t *clip) {
    if (journal->failed) return 0;
    if (!entry || entry!=reaction_journal_peek(journal)) { journal->failed=1;return 0; }
    if (!owner_matches) { journal->failed=2;return 0; }
    if (entry->old_action!=old_action) { journal->failed=3;return 0; }
    if (entry->source_id!=source_id) { journal->failed=4;return 0; }
    if (!reaction_entry_valid(entry) || entry->kind!=SYNC_REACTION_CLIP || entry->clip==REACTION_ARENA_NO_CLIP || !available) { journal->failed=5;return 0; }
    *clip=(uint32_t)entry->clip;++journal->cursor;return 1;
}
int reaction_journal_finish(const ReactionJournal *journal) { return !journal->failed && (journal->host || journal->cursor==journal->frame->reaction_count); }
int reaction_journal_complete_no_clip(ReactionJournal *journal,uint32_t begin,uint32_t slot,uint32_t generation,uint32_t source_id,const SyncReactionHitOutcome *actual) {
    if (!journal || journal->host || journal->failed || !source_id || !generation || begin>journal->cursor) return 0;
    for (uint32_t i=begin;i<journal->cursor;++i) {
        const SyncReactionChoice *entry=journal->frame->reactions+i;
        if (entry->kind==SYNC_REACTION_CLIP && entry->slot==slot && entry->generation==generation &&
            entry->source_id==source_id) {
            if (entry->hit.completed && !reaction_hit_outcome_same(&entry->hit,actual)) {journal->failed=11;return -1;}
            return 0;
        }
    }
    const SyncReactionChoice *entry=reaction_journal_peek(journal);
    if (!entry || !reaction_entry_valid(entry) || entry->kind!=SYNC_REACTION_CLIP || entry->clip!=-1 ||
        entry->arena_attacker_generation || entry->slot!=slot || entry->generation!=generation || entry->source_id!=source_id || !entry->hit.completed) return 0;
    if (!reaction_hit_outcome_same(&entry->hit,actual)) {journal->failed=11;return -1;}
    ++journal->cursor;return 1;
}
