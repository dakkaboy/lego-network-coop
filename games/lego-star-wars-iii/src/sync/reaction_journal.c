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
    if (!reaction_entry_valid(entry) || entry->clip==REACTION_ARENA_NO_CLIP || !available) { journal->failed=5;return 0; }
    *clip=(uint32_t)entry->clip;++journal->cursor;return 1;
}
int reaction_journal_finish(const ReactionJournal *journal) { return !journal->failed && (journal->host || journal->cursor==journal->frame->reaction_count); }
