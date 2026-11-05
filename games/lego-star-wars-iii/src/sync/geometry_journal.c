#include <math.h>
#include "geometry_sync.h"
void geometry_journal_begin(GeometryJournal *journal,SyncFrame *frame,int host) {
    *journal=(GeometryJournal){.frame=frame,.host=host};if (host) frame->geometry_count=frame->geometry_calls=0;
}
int geometry_journal_phase(GeometryJournal *journal,uint32_t mode,GeometryBatch *batch) {
    journal->validated=0;
    *batch=(GeometryBatch){.start=journal->cursor,.ordinal=++journal->ordinal,.mode=mode};
    if (journal->failed || journal->ordinal>64 || (!journal->host && journal->ordinal>journal->frame->geometry_calls)) { journal->failed=3;return 0; }
    if (journal->host) { journal->frame->geometry_calls=journal->ordinal;return 1; }
    while (batch->start+batch->count<journal->frame->geometry_count) {
        const SyncCollider *entry=journal->frame->geometry+batch->start+batch->count;
        if (entry->manager_ordinal<journal->ordinal) { journal->failed=3;return 0; }
        if (entry->manager_ordinal!=journal->ordinal) break;
        ++batch->count;
    }
    if (mode && batch->count) { journal->failed=3;return 0; }return 1;
}
int geometry_journal_record(GeometryJournal *journal,const SyncCollider *entry) {
    if (journal->failed || !journal->host || journal->frame->geometry_count>=SYNC_MAX_ACTORS || entry->manager_ordinal!=journal->ordinal || !geometry_entry_valid(entry)) { journal->failed=2;return 0; }
    if (journal->frame->geometry_count) {
        const SyncCollider *previous=journal->frame->geometry+journal->frame->geometry_count-1;
        if (previous->manager_ordinal==entry->manager_ordinal && previous->slot>=entry->slot) { journal->failed=5;return 0; }
    }
    journal->frame->geometry[journal->frame->geometry_count++]=*entry;return 1;
}
int geometry_journal_validate(GeometryJournal *journal,const SyncCollider *entry,int owner_matches) {
    if (journal->failed) return 0;
    if (!entry || journal->cursor+journal->validated>=journal->frame->geometry_count || entry!=journal->frame->geometry+journal->cursor+journal->validated || entry->manager_ordinal!=journal->ordinal || !geometry_entry_valid(entry)) { journal->failed=2;return 0; }
    if (journal->validated && (entry-1)->slot>=entry->slot) { journal->failed=5;return 0; }
    if (!owner_matches) { journal->failed=4;return 0; }++journal->validated;return 1;
}
int geometry_journal_commit(GeometryJournal *journal,const GeometryBatch *batch) {
    if (journal->failed || journal->host || batch->start!=journal->cursor || batch->ordinal!=journal->ordinal || batch->start+batch->count>journal->frame->geometry_count || journal->validated!=batch->count) { journal->failed=3;return 0; }
    journal->cursor+=batch->count;return 1;
}
int geometry_journal_finish(const GeometryJournal *journal) { return !journal->failed && (journal->host || (journal->cursor==journal->frame->geometry_count && journal->ordinal==journal->frame->geometry_calls)); }
