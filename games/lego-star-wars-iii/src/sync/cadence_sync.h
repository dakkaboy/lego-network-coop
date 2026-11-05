#pragma once
#include "../net/sync_wire.h"
#include "../engine/cohort_module_lease.h"
typedef struct CadenceJournal { SyncFrame *frame; uint32_t cursor; int host,failed; } CadenceJournal;
void cadence_journal_begin(CadenceJournal *journal,SyncFrame *frame,int host);
int cadence_journal_record(CadenceJournal *journal,const SyncCadence *entry);
const SyncCadence *cadence_journal_peek(const CadenceJournal *journal);
int cadence_journal_apply(CadenceJournal *journal,const SyncCadence *entry,int owner_matches,uint32_t local_phase,uint32_t *period,float *elapsed);
int cadence_journal_finish(const CadenceJournal *journal);
int cadence_install(void);
int cadence_ready(void);
int cadence_begin(SyncFrame *frame,int host);
int cadence_finish(void);

void cadence_cancel(void);

typedef CohortModuleLease CadenceFrameLease;
int cadence_bind_cohort(const CoherentFrameToken *);
int cadence_frame_lease_get(CadenceFrameLease *);
int cadence_frame_cancelled(const CadenceFrameLease *);
int cadence_abort_frame(const CadenceFrameLease *);
