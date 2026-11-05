#pragma once
#include "../net/sync_wire.h"
#include "../engine/cohort_module_lease.h"
#include <math.h>
typedef struct GeometryJournal { SyncFrame *frame;uint32_t cursor,ordinal,validated;int host,failed; } GeometryJournal;
typedef struct GeometryBatch { uint32_t start,count,ordinal,mode; } GeometryBatch;
static inline int geometry_entry_valid(const SyncCollider *entry) {
    if (!entry || !entry->manager_ordinal || entry->manager_ordinal>64 || entry->slot>=SYNC_MAX_ACTORS || !entry->generation || entry->character<0 || entry->character>=4096) return 0;
    for (unsigned i=0;i<3;++i) if (!isfinite(entry->origin[i]) || !isfinite(entry->center[i]) || !isfinite(entry->bounds[i]) || !isfinite(entry->bounds[i+3]) || entry->bounds[i]>entry->bounds[i+3]) return 0;
    return isfinite(entry->extents[0]) && isfinite(entry->extents[1]) && entry->extents[0]>=0 && entry->extents[1]>=0;
}
void geometry_journal_begin(GeometryJournal *journal,SyncFrame *frame,int host);
int geometry_journal_phase(GeometryJournal *journal,uint32_t mode,GeometryBatch *batch);
int geometry_journal_record(GeometryJournal *journal,const SyncCollider *entry);
int geometry_journal_validate(GeometryJournal *journal,const SyncCollider *entry,int owner_matches);
int geometry_journal_commit(GeometryJournal *journal,const GeometryBatch *batch);
int geometry_journal_finish(const GeometryJournal *journal);
void geometry_manager_ready(void);
int geometry_ready(void);
int geometry_begin(SyncFrame *frame,int host);
int geometry_phase(uint32_t mode);
int geometry_finish(void);

void geometry_cancel(void);

typedef CohortModuleLease GeometryFrameLease;
int geometry_bind_cohort(const CoherentFrameToken *);
int geometry_frame_lease_get(GeometryFrameLease *);
int geometry_frame_cancelled(const GeometryFrameLease *);
int geometry_abort_frame(const GeometryFrameLease *);
