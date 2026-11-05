#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "reaction_sync.h"
#include "../engine/reaction_thunk.h"
#include "entity_sync.h"
#include "../debug/combat_observer.h"
#include "game_sync.h"
#include "../engine/module_cohort_binding.h"
static ReactionJournal reaction_journal;
static int active;
static int cancelled;
static ModuleCohortBinding binding;
static int op_live(const ReactionFrameLease *op){return module_binding_live(&binding,op)&&reaction_journal.frame==op->cohort.frame;}
int reaction_client_duplicate_projectile(void *actor,uint32_t source_id) {
    ReactionFrameLease op;
    if (!source_id || !reaction_frame_lease_get(&op) || !op_live(&op) || !active ||
        reaction_journal.host || reaction_journal.failed || !reaction_journal.cursor ||
        reaction_journal.cursor!=reaction_journal.frame->reaction_count) return 0;
    const SyncReactionChoice *previous=&reaction_journal.frame->reactions[reaction_journal.cursor-1];
    uint32_t slot,generation;
    return previous->source_id==source_id && entities_observed_identity(actor,&slot,&generation) &&
        op_live(&op) && slot==previous->slot && generation==previous->generation;
}
int reaction_bind_cohort(const CoherentFrameToken *original){return module_binding_bind(&binding,original);}
int reaction_frame_lease_get(ReactionFrameLease*out){return module_binding_get(&binding,out);}
int reaction_frame_cancelled(const ReactionFrameLease*op){return module_binding_cancelled(&binding,op);}
int reaction_abort_frame(const ReactionFrameLease*op){if(!module_binding_detach(&binding,op))return 0;active=0;cancelled=1;memset(&reaction_journal,0,sizeof(reaction_journal));return 1;}

static uint32_t last_epoch;
static __thread void *arena_attacker,*arena_victim;
typedef uint32_t (__cdecl *ArenaHit)(void *,void *,uint32_t,uint32_t,uint32_t,uint32_t);
static const ArenaHit native_hit=(ArenaHit)0x96a4c0;

__attribute__((used)) static volatile uintptr_t reaction_resume=0x96a1c4;
__declspec(dllexport) volatile LONG clonewars_reaction_installed;
__declspec(dllexport) volatile uint32_t clonewars_reaction_debug[20];
__declspec(dllexport) volatile uint32_t clonewars_reaction_failure[14];
__declspec(dllexport) volatile uint32_t clonewars_reaction_first_correction[12];
#ifdef REACTION_SYNC_TEST
extern int reaction_test_valid(const void *,unsigned);
extern uint32_t reaction_test_word(uintptr_t);
extern int reaction_test_available(void *,int);
#define valid reaction_test_valid
#define word reaction_test_word
#define clip_available reaction_test_available
#else
static int valid(const void *pointer,unsigned size) {
    MEMORY_BASIC_INFORMATION m;return pointer && VirtualQuery(pointer,&m,sizeof(m)) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && (uintptr_t)pointer+size>=(uintptr_t)pointer && (uintptr_t)pointer+size<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static uint32_t word(uintptr_t address) { return *(uint32_t *)address; }
static int clip_available(void *actor,int clip) {
    void *resource=*(void **)((char *)actor+0xf04);
    return valid(resource,0x10) && ((unsigned char (*)(void *,int))0x8a8e70)(resource,clip)!=0;
}
#endif
static void failed(const ReactionFrameLease *op,void *actor,const SyncReactionChoice *entry,int old_action,uint32_t source_id,unsigned reason,uint32_t local_clip) {
    if(!op_live(op))return;
    if (!clonewars_reaction_failure[0]) {
        uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(actor,&slot,&generation);if(!op_live(op))return;
        uint32_t values[]={reaction_journal.frame->epoch,reaction_journal.frame->sequence,reaction_journal.host ? reaction_journal.frame->reaction_count : reaction_journal.cursor,
            entry ? entry->slot : UINT32_MAX,entry ? entry->generation : 0,slot,generation,reason,
            entry ? (uint32_t)entry->old_action : 0,(uint32_t)old_action,entry ? entry->source_id : 0,source_id,entry ? (uint32_t)entry->clip : UINT32_MAX,local_clip};
        memcpy((void *)clonewars_reaction_failure,values,sizeof(values));
    }
    if(!op_live(op))return;++clonewars_reaction_debug[3];game_sync_native_fault(17);
}
__attribute__((used,noinline)) void reaction_apply_choice(void *actor,uint32_t *clip) {
    ReactionFrameLease op;if(!reaction_frame_lease_get(&op)||!op_live(&op))return;
    if (!active) { ++clonewars_reaction_debug[4];return; }
    if (reaction_journal.failed) return;
    if (!valid(actor,0x1440) || !valid(clip,4)) { reaction_journal.failed=5;failed(&op,actor,NULL,0,0,5,UINT32_MAX);return; }
    int old_action=*(int16_t *)((char *)actor+0x2f4);uint32_t source_id=combat_damage_source_id();if(!op_live(&op))return;uint32_t local_clip=*clip;
    if (reaction_journal.host) {
        entities_update();if(!op_live(&op))return;SyncActor identity={0};entities_describe(&identity,actor);if(!op_live(&op))return;
        int actor_slot=entities_slot(actor);if(!op_live(&op))return;
        SyncReactionChoice entry={.slot=(uint32_t)actor_slot,.generation=identity.generation,.spawn_tag=identity.spawn_tag,
            .character=*(int16_t *)((char *)actor+0xdc0),.old_action=old_action,.clip=(int32_t)*clip,.source_id=source_id};
        memcpy(entry.origin,identity.spawn_position,12);
        if (arena_attacker && actor==arena_victim &&
            !entities_observed_identity(arena_attacker,&entry.arena_attacker_slot,&entry.arena_attacker_generation)) {
            reaction_journal.failed=6;failed(&op,actor,&entry,old_action,source_id,6,local_clip);return;
        }
        if (!reaction_journal_record(&reaction_journal,&entry)) { failed(&op,actor,&entry,old_action,source_id,6,local_clip);return; }
        ++clonewars_reaction_debug[0];
    } else {
        const SyncReactionChoice *entry=reaction_journal_peek(&reaction_journal);SyncActor identity={0};
        if (entry) { identity.slot=entry->slot;identity.generation=entry->generation;identity.spawn_tag=entry->spawn_tag;identity.character=entry->character;memcpy(identity.spawn_position,entry->origin,12); }
        int owner_matches=entry && entities_resolve_reference(&identity)==actor;if(!op_live(&op))return;
        if (entry && (!!entry->arena_attacker_generation != !!(arena_attacker && arena_victim==actor))) {
            reaction_journal.failed=8;failed(&op,actor,entry,old_action,source_id,8,local_clip);return;
        }
        int available=entry && entry->clip!=REACTION_ARENA_NO_CLIP && reaction_entry_valid(entry) && owner_matches && entry->old_action==old_action && entry->source_id==source_id && (entry->clip==-1 || clip_available(actor,entry->clip));
        if(!op_live(&op))return;
        if (!reaction_journal_apply(&reaction_journal,entry,owner_matches,old_action,source_id,available,clip)) {
            failed(&op,actor,entry,old_action,source_id,(unsigned)reaction_journal.failed,local_clip);return;
        }
        ++clonewars_reaction_debug[1];clonewars_reaction_debug[2]+=local_clip!=*clip;
        if (local_clip!=*clip && !clonewars_reaction_first_correction[0]) {
            uint32_t values[]={reaction_journal.frame->epoch,reaction_journal.frame->sequence,reaction_journal.cursor-1,entry->slot,entry->generation,local_clip,*clip,(uint32_t)old_action,source_id,
                word(0xe637b4),word(0xea178c),*(uint32_t *)((char *)actor+0xf04)};
            memcpy((void *)clonewars_reaction_first_correction,values,sizeof(values));
        }
        clonewars_reaction_debug[8]=entry->slot;clonewars_reaction_debug[9]=entry->generation;
        clonewars_reaction_debug[10]=local_clip;clonewars_reaction_debug[11]=*clip;clonewars_reaction_debug[12]=source_id;clonewars_reaction_debug[13]=(uint32_t)old_action;clonewars_reaction_debug[14]=reaction_journal.cursor;
    }
    clonewars_reaction_debug[7]=reaction_journal.frame->sequence;
}
static int arena_replay(const ReactionFrameLease *op,const SyncReactionChoice *entry) {
    void *attacker=entities_actor(entry->arena_attacker_slot,entry->arena_attacker_generation);
    void *victim=entities_actor(entry->slot,entry->generation);
    if (!op_live(op) || !valid(attacker,0x1440) || !valid(victim,0x1440) ||
        *(int16_t *)((char *)victim+0xdc0)!=entry->character ||
        *(int16_t *)((char *)victim+0x2f4)!=entry->old_action) return 0;
    uint32_t cursor=reaction_journal.cursor;
    arena_attacker=attacker;arena_victim=victim;
    native_hit(attacker,victim,1,0x400000,0,1);
    arena_attacker=arena_victim=NULL;
    const int no_clip=entry->clip==REACTION_ARENA_NO_CLIP;
    if (!op_live(op) || reaction_journal.failed || reaction_journal.cursor!=cursor+!no_clip ||
        entities_actor(entry->slot,entry->generation)!=victim || !op_live(op)) return 0;
    if (no_clip) ++reaction_journal.cursor;
    *(float *)((char *)victim+0xd3c)=2.5f;
    return 1;
}
int reaction_drain_arena(void) {
    ReactionFrameLease op;
    if (!reaction_frame_lease_get(&op) || !op_live(&op) || !active) return 0;
    if (reaction_journal.host || reaction_journal.frame->level!=12) return 1;
    const SyncReactionChoice *entry;
    while ((entry=reaction_journal_peek(&reaction_journal)) && entry->arena_attacker_generation) {
        if (!arena_replay(&op,entry)) {
            if (op_live(&op)) {
                reaction_journal.failed=8;
                failed(&op,NULL,entry,0,0,8,UINT32_MAX);
            }
            return 0;
        }
    }
    return !reaction_journal.failed;
}
#ifndef REACTION_SYNC_TEST
__attribute__((used,noinline)) static int __cdecl arena_contact_hit(void *attacker,void *victim) {
    ReactionFrameLease op;
    if (!reaction_frame_lease_get(&op) || !op_live(&op) || !active || reaction_journal.frame->level!=12) {
        native_hit(attacker,victim,1,0x400000,0,1);
        return 1;
    }
    if (!reaction_journal.host) {
        const SyncReactionChoice *entry=reaction_journal_peek(&reaction_journal);
        if (entry && entry->arena_attacker_generation &&
            entities_actor(entry->slot,entry->generation)==victim &&
            entities_actor(entry->arena_attacker_slot,entry->arena_attacker_generation)==attacker &&
            !arena_replay(&op,entry) && op_live(&op)) {
            reaction_journal.failed=8;
            failed(&op,victim,entry,0,0,8,UINT32_MAX);
        }
        return 0;
    }
    const uint32_t before=reaction_journal.frame->reaction_count;
    SyncActor identity={0};
    entities_update();
    if (!op_live(&op)) return 0;
    entities_describe(&identity,victim);
    if (!op_live(&op)) return 0;
    SyncReactionChoice marker={.slot=(uint32_t)entities_slot(victim),.generation=identity.generation,
        .spawn_tag=identity.spawn_tag,.character=*(int16_t *)((char *)victim+0xdc0),
        .old_action=*(int16_t *)((char *)victim+0x2f4),.clip=REACTION_ARENA_NO_CLIP};
    memcpy(marker.origin,identity.spawn_position,12);
    if (!entities_observed_identity(attacker,&marker.arena_attacker_slot,&marker.arena_attacker_generation) ||
        !op_live(&op) || !reaction_entry_valid(&marker)) {
        if (op_live(&op)) { reaction_journal.failed=8;failed(&op,victim,NULL,0,0,8,UINT32_MAX); }
        return 0;
    }
    arena_attacker=attacker;arena_victim=victim;
    native_hit(attacker,victim,1,0x400000,0,1);
    arena_attacker=arena_victim=NULL;
    if (!op_live(&op)) return 0;
    if (!reaction_journal.failed && reaction_journal.frame->reaction_count==before) {
        if (reaction_journal_record(&reaction_journal,&marker)) { ++clonewars_reaction_debug[0];return 1; }
    }
    if (reaction_journal.failed || reaction_journal.frame->reaction_count!=before+1 ||
        !reaction_journal.frame->reactions[before].arena_attacker_generation) {
        reaction_journal.failed=8;
        failed(&op,victim,NULL,0,0,8,UINT32_MAX);
        return 0;
    }
    return 1;
}
__attribute__((used)) static const uintptr_t arena_skip_timer=0x410d10;
__attribute__((naked)) static void arena_contact_hit_thunk(void) {
    __asm__ volatile(
        "pushl 8(%esp)\n\tpushl 8(%esp)\n\tcall _arena_contact_hit\n\taddl $8,%esp\n\t"
        "testl %eax,%eax\n\tjz 1f\n\tret\n\t"
        "1: addl $28,%esp\n\tjmp *_arena_skip_timer\n\t");
}
static int arena_install_hit(void) {
    unsigned char *site=(unsigned char *)0x410cf3;
    int32_t relative;
    memcpy(&relative,site+1,4);
    DWORD protection;
    if (*site!=0xe8 || 0x410cf8+relative!=0x96a4c0 ||
        !VirtualProtect(site,5,PAGE_EXECUTE_READWRITE,&protection)) return 0;
    relative=(int32_t)((uintptr_t)arena_contact_hit_thunk-0x410cf8);
    memcpy(site+1,&relative,4);
    int ok=FlushInstructionCache(GetCurrentProcess(),site,5);
    return VirtualProtect(site,5,protection,&protection) && ok;
}
__attribute__((naked,used)) static void reaction_choice_thunk(void) { __asm__ volatile(REACTION_THUNK_ASM); }
int reaction_install(void) {
    unsigned char *entry=(unsigned char *)0x96a1bd;
    static const unsigned char original[]={0x8b,0x7c,0x24,0x50,0x83,0xff,0xff};DWORD protection;
    if (memcmp(entry,original,7) || !VirtualProtect(entry,7,PAGE_EXECUTE_READWRITE,&protection)) { clonewars_reaction_installed=-1;return 0; }
    if (!arena_install_hit()) {
        VirtualProtect(entry,7,protection,&protection);
        clonewars_reaction_installed=-1;return 0;
    }
    entry[0]=0xe9;*(int32_t *)(entry+1)=(int32_t)((uintptr_t)reaction_choice_thunk-(uintptr_t)entry-5);memset(entry+5,0x90,2);
    FlushInstructionCache(GetCurrentProcess(),entry,7);VirtualProtect(entry,7,protection,&protection);clonewars_reaction_installed=1;return 1;
}
#endif
int reaction_ready(void) { return clonewars_reaction_installed==1 && combat_damage_source_ready(); }
void reaction_cancel(void) { if(binding.bound||!binding.lease.cohort.thread||binding.lease.cohort.thread!=GetCurrentThreadId())return;active=0;cancelled=1;memset(&reaction_journal,0,sizeof(reaction_journal)); }
int reaction_begin(SyncFrame *frame,int host) {
    if(!module_binding_begin(&binding,frame))return 0;
    ReactionFrameLease op=binding.lease;if(!module_binding_live(&binding,&op))return 0;
    cancelled=0;
    if (last_epoch!=op.cohort.epoch) {
        memset((void *)clonewars_reaction_failure,0,sizeof(clonewars_reaction_failure));
        memset((void *)clonewars_reaction_first_correction,0,sizeof(clonewars_reaction_first_correction));last_epoch=op.cohort.epoch;
    }
    reaction_journal_begin(&reaction_journal,frame,host);active=1;return op_live(&op);
}
int reaction_finish(void) {
    ReactionFrameLease op;if(!reaction_frame_lease_get(&op)||!op_live(&op)||!active)return 0;
    if (cancelled) return 0;
    active=0;++clonewars_reaction_debug[5];
    if (!reaction_journal_finish(&reaction_journal)) {
        ++clonewars_reaction_debug[6];if (!reaction_journal.failed) { const SyncReactionChoice *entry=reaction_journal_peek(&reaction_journal);reaction_journal.failed=7;failed(&op,NULL,entry,0,0,7,UINT32_MAX); }return 0;
    }
    return 1;
}
