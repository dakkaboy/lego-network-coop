#pragma once
#include "sync_wire.h"
typedef struct SteeringJournal { SyncFrame *frame; uint32_t cursor; int host,failed; } SteeringJournal;
int steering_entry_valid(const SyncSteering *entry);
void steering_journal_begin(SteeringJournal *journal,SyncFrame *frame,int host);
int steering_journal_record(SteeringJournal *journal,const SyncSteering *entry);
const SyncSteering *steering_journal_peek(const SteeringJournal *journal);
int steering_journal_validate(SteeringJournal *journal,const SyncSteering *entry,int owner_matches,const SyncSteering *local);
int steering_journal_finish(const SteeringJournal *journal);
int steering_install(void);
int steering_ready(void);
void steering_begin(SyncFrame *frame,int host);
int steering_finish(void);
