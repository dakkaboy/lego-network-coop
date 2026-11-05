#include <math.h>
#include "cadence_sync.h"
void cadence_journal_begin(CadenceJournal *journal,SyncFrame *frame,int host) {
    *journal=(CadenceJournal){.frame=frame,.host=host};
    if (host) frame->cadence_count=frame->cadence_reserved=0;
}
static int entry_valid(const SyncCadence *entry) {
    return entry && entry->slot<SYNC_MAX_ACTORS && entry->generation && entry->period && entry->period<=255 && entry->phase<=255 && isfinite(entry->elapsed) && entry->elapsed>=0;
}
int cadence_journal_record(CadenceJournal *journal,const SyncCadence *entry) {
    if (journal->failed || !journal->host || journal->frame->cadence_count>=SYNC_MAX_ACTORS || !entry_valid(entry)) { journal->failed=4;return 0; }
    journal->frame->cadence[journal->frame->cadence_count++]=*entry;return 1;
}
const SyncCadence *cadence_journal_peek(const CadenceJournal *journal) {
    return !journal->failed && journal->cursor<journal->frame->cadence_count ? journal->frame->cadence+journal->cursor : 0;
}
int cadence_journal_apply(CadenceJournal *journal,const SyncCadence *entry,int owner_matches,uint32_t local_phase,uint32_t *period,float *elapsed) {
    if (journal->failed) return 0;
    if (!entry || entry!=cadence_journal_peek(journal)) { journal->failed=3;return 0; }
    if (!owner_matches) { journal->failed=1;return 0; }
    if (entry->phase!=local_phase) { journal->failed=2;return 0; }
    if (!entry_valid(entry)) { journal->failed=4;return 0; }
    *period=entry->period;*elapsed=entry->elapsed;++journal->cursor;return 1;
}
int cadence_journal_finish(const CadenceJournal *journal) { return !journal->failed && (journal->host || journal->cursor==journal->frame->cadence_count); }
