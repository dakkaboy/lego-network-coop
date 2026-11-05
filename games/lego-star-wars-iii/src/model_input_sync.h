#pragma once
#include "sync_wire.h"
#include "cohort_module_lease.h"
typedef CohortModuleLease ModelInputFrameLease;
int model_input_bind_cohort(const CoherentFrameToken *);
int model_input_frame_lease_get(ModelInputFrameLease *);
int model_input_frame_cancelled(const ModelInputFrameLease *);
int model_input_abort_frame(const ModelInputFrameLease *);
typedef struct ModelInputJournal {SyncFrame *frame;uint32_t cursor;int host,failed;} ModelInputJournal;
int model_input_entry_valid(const SyncModelInput *entry);
void model_input_journal_begin(ModelInputJournal *journal,SyncFrame *frame,int host);
int model_input_journal_record(ModelInputJournal *journal,const SyncModelInput *entry);
const SyncModelInput *model_input_journal_peek(const ModelInputJournal *journal);
int model_input_journal_validate(ModelInputJournal *journal,const SyncModelInput *expected,int owner_matches,const SyncModelInput *local);
int model_input_journal_finish(const ModelInputJournal *journal);
int model_input_install(void);
int model_input_ready(void);
int model_input_begin(SyncFrame *frame,int host);
int model_input_finish(void);
void model_input_cancel(void);
int model_input_cancelled(void);
