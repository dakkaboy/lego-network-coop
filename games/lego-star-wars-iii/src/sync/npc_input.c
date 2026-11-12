#include "npc_input.h"
#include <windows.h>
static int same(const CoherentFrameToken *a,const CoherentFrameToken *b) {
 return a->owner==b->owner&&a->owner_nonce==b->owner_nonce&&a->cohort_nonce==b->cohort_nonce&&
  a->thread==b->thread&&a->release==b->release&&a->epoch==b->epoch&&a->sequence==b->sequence&&a->frame==b->frame;
}
int npc_input_cohort_valid(const NpcInputJournal *journal,const CoherentFrameToken *token,uint32_t phases) {
 return journal&&token&&journal->bound&&!journal->disabled&&!journal->cancelled&&same(&journal->cohort,token)&&coherent_frame_valid(token,phases);
}
int npc_input_bind_cohort(NpcInputJournal *journal,const CoherentFrameToken *token) {
 if(!journal||!token||journal->disabled||!coherent_frame_valid(token,COHERENT_PHASE_BIT(COHERENT_PREPARE)))return 0;
 if(journal->retired_valid&&same(token,&journal->retired))return 0;
 if(journal->bound&&same(&journal->cohort,token))return npc_input_cohort_valid(journal,token,COHERENT_PHASE_BIT(COHERENT_PREPARE));
 if(journal->bound&&!same(&journal->cohort,token)&&coherent_frame_valid(&journal->cohort,COHERENT_ALL_PHASES))return 0;
 if(journal->nonce==UINT32_MAX){journal->disabled=1;return 0;}
 ++journal->nonce;journal->cohort=*token;journal->bound=1;journal->cancelled=journal->started=0;journal->frame=NULL;return 1;
}
int npc_input_abort_cohort(NpcInputJournal *journal,const CoherentFrameToken *token) {
 if(!journal||!token||!journal->bound||token->thread!=GetCurrentThreadId()||!same(&journal->cohort,token))return 0;
 if(journal->nonce==UINT32_MAX)journal->disabled=1;else ++journal->nonce;
 journal->retired=*token;journal->retired_valid=1;journal->bound=0;journal->frame=NULL;journal->cancelled=1;return 1;
}
#define NPC_DISPATCH COHERENT_PHASE_BIT(COHERENT_DISPATCH)
static int live(const NpcInputJournal *journal,uint32_t phases) {
 return journal&&journal->started&&journal->frame&&!journal->cancelled&&npc_input_cohort_valid(journal,&journal->cohort,phases)&&journal->frame==journal->cohort.frame;
}
int npc_input_begin(NpcInputJournal *journal,SyncFrame *frame,int host) {
    if(!journal||!npc_input_cohort_valid(journal,&journal->cohort,COHERENT_PHASE_BIT(COHERENT_PREPARE)))return 0;
    if(frame!=journal->cohort.frame||journal->started){journal->cancelled=1;coherent_frame_cancel_atomic(0x40000u);return 0;}
    if(journal->nonce==UINT32_MAX){journal->disabled=1;coherent_frame_cancel_atomic(0x80000u);return 0;}
    ++journal->nonce;journal->frame=frame;journal->cursor=0;journal->host=host;journal->failed=journal->cancelled=0;journal->started=1;
    if (host) frame->actor_input_count=0;
    return 1;
}
int npc_input_record(NpcInputJournal *journal,const SyncActorInput *entry) {
    if(!live(journal,NPC_DISPATCH))return 0;
    if (journal->failed || !journal->host || journal->frame->actor_input_count>=SYNC_MAX_ACTORS || !entry || entry->slot>=SYNC_MAX_ACTORS || !entry->generation) { journal->failed=1;return 0; }
    journal->frame->actor_inputs[journal->frame->actor_input_count++]=*entry;return 1;
}
const SyncActorInput *npc_input_peek(const NpcInputJournal *journal) {
    if(!live(journal,NPC_DISPATCH))return 0;
    return !journal->failed && journal->frame->actor_input_count<=SYNC_MAX_ACTORS && journal->cursor<journal->frame->actor_input_count ? journal->frame->actor_inputs+journal->cursor : 0;
}
int npc_input_apply(NpcInputJournal *journal,const SyncActorInput *entry,int owner_matches,uint32_t *held,uint32_t *pressed,NpcInputScope *scope) {
    if(!scope)return 0;
    *scope=(NpcInputScope){0};
    if(!live(journal,NPC_DISPATCH))return 0;
    if (journal->failed || journal->host || !entry || entry!=npc_input_peek(journal) || !owner_matches) { journal->failed=1;return 0; }
    if(!npc_input_scope_capture(journal,held,pressed,scope))return 0;
    *held=entry->held;*pressed=entry->pressed;++journal->cursor;return 1;
}
int npc_input_scope_capture(NpcInputJournal *journal,const uint32_t *held,const uint32_t *pressed,NpcInputScope *scope) {
 if(!scope)return 0;*scope=(NpcInputScope){0};
 if(!held||!pressed||!live(journal,NPC_DISPATCH))return 0;
 scope->cohort=journal->cohort;scope->journal=journal;scope->nonce=journal->nonce;
 scope->held_local=held;scope->pressed_local=pressed;scope->held=*held;scope->pressed=*pressed;scope->applied=1;
 return npc_input_scope_valid(scope);
}
int npc_input_scope_valid(const NpcInputScope *scope) {
 if(!scope||!scope->applied||!coherent_frame_valid(&scope->cohort,NPC_DISPATCH))return 0;
 const NpcInputJournal *journal=scope->journal;
 return live(journal,NPC_DISPATCH)&&scope->nonce==journal->nonce&&same(&scope->cohort,&journal->cohort);
}
int npc_input_restore(const NpcInputScope *scope,uint32_t *held,uint32_t *pressed) {
 if(!npc_input_scope_valid(scope)||held!=scope->held_local||pressed!=scope->pressed_local)return 0;
 *held=scope->held;*pressed=scope->pressed;return 1;
}
int npc_input_finish(const NpcInputJournal *journal) {
 return live(journal,COHERENT_PHASE_BIT(COHERENT_FINISH))&&!journal->failed&&journal->frame->actor_input_count<=SYNC_MAX_ACTORS&&(journal->host||journal->cursor==journal->frame->actor_input_count);
}
