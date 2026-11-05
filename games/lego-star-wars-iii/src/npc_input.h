#pragma once
#include "sync_wire.h"
#include "coherent_frame_fence.h"
typedef struct NpcInputJournal {
 SyncFrame *frame; uint32_t cursor; int host,failed;
 CoherentFrameToken cohort; uint32_t nonce,bound,cancelled,disabled,started;
 CoherentFrameToken retired; uint32_t retired_valid;
} NpcInputJournal;
typedef struct NpcInputScope {
 uint32_t held,pressed; int applied;
 NpcInputJournal *journal; CoherentFrameToken cohort; uint32_t nonce;
 const uint32_t *held_local,*pressed_local;
} NpcInputScope;
int npc_input_bind_cohort(NpcInputJournal *,const CoherentFrameToken *);
int npc_input_cohort_valid(const NpcInputJournal *,const CoherentFrameToken *,uint32_t);
int npc_input_abort_cohort(NpcInputJournal *,const CoherentFrameToken *);
int npc_input_scope_valid(const NpcInputScope *);
int npc_input_scope_capture(NpcInputJournal *,const uint32_t *,const uint32_t *,NpcInputScope *);
static inline int npc_input_eligible(const void *actor,const void *hero0,const void *hero1) { return actor && actor!=hero0 && actor!=hero1; }
static inline int npc_input_owner_live(uint32_t flags,uint32_t generation,uint32_t expected_generation,const void *controller,const void *expected_controller) {
    return (flags&3)==3 && expected_generation && generation==expected_generation && controller==expected_controller;
}
int npc_input_begin(NpcInputJournal *journal,SyncFrame *frame,int host);
int npc_input_record(NpcInputJournal *journal,const SyncActorInput *entry);
const SyncActorInput *npc_input_peek(const NpcInputJournal *journal);
int npc_input_apply(NpcInputJournal *journal,const SyncActorInput *entry,int owner_matches,uint32_t *held,uint32_t *pressed,NpcInputScope *scope);
int npc_input_restore(const NpcInputScope *scope,uint32_t *held,uint32_t *pressed);
int npc_input_finish(const NpcInputJournal *journal);
