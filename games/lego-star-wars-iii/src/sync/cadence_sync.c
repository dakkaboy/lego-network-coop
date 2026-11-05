#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "cadence_sync.h"
#include "../engine/cadence_thunk.h"
#include "entity_sync.h"
#include "game_sync.h"
#include "../engine/module_cohort_binding.h"
static CadenceJournal journal;
static int active;
static int cancelled;
static ModuleCohortBinding binding;
static int op_live(const CadenceFrameLease *op){return module_binding_live(&binding,op)&&journal.frame==op->cohort.frame;}
int cadence_bind_cohort(const CoherentFrameToken *original){return module_binding_bind(&binding,original);}
int cadence_frame_lease_get(CadenceFrameLease*out){return module_binding_get(&binding,out);}
int cadence_frame_cancelled(const CadenceFrameLease*op){return module_binding_cancelled(&binding,op);}
int cadence_abort_frame(const CadenceFrameLease*op){if(!module_binding_detach(&binding,op))return 0;active=0;cancelled=1;memset(&journal,0,sizeof(journal));return 1;}

static uint32_t last_epoch;
__attribute__((used)) static volatile uintptr_t cadence_resume=0x96d954;
__declspec(dllexport) volatile LONG clonewars_cadence_installed;
__declspec(dllexport) volatile uint32_t clonewars_cadence_debug[20];
__declspec(dllexport) volatile uint32_t clonewars_cadence_failure[14];
static int valid(const void *pointer,unsigned size) {
    MEMORY_BASIC_INFORMATION m;return pointer && VirtualQuery(pointer,&m,sizeof(m)) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && (uintptr_t)pointer+size>=(uintptr_t)pointer && (uintptr_t)pointer+size<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static uint32_t bits(float value) { uint32_t result;memcpy(&result,&value,4);return result; }
static void failed(const CadenceFrameLease *op,void *actor,const SyncCadence *entry,unsigned reason) {
    if(!op_live(op))return;
    if (!clonewars_cadence_failure[0]) {
        uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(actor,&slot,&generation);if(!op_live(op))return;
        uint32_t values[]={journal.frame->epoch,journal.frame->sequence,journal.host ? journal.frame->cadence_count : journal.cursor,entry ? entry->slot : UINT32_MAX,entry ? entry->generation : 0,
            slot,generation,reason,entry ? entry->phase : UINT32_MAX,valid(actor,0x1440) ? *((unsigned char *)actor+0x57) : UINT32_MAX,
            entry ? entry->period : 0,0,0,0};
        memcpy((void *)clonewars_cadence_failure,values,sizeof(values));
        clonewars_cadence_debug[18]=journal.frame->sequence;clonewars_cadence_debug[19]=reason;
    }
    if(!op_live(op))return;++clonewars_cadence_debug[4];game_sync_native_fault(14);
}
__attribute__((used,noinline)) void cadence_apply_period(void *actor,uint32_t *period) {
    CadenceFrameLease op;if(!cadence_frame_lease_get(&op)||!op_live(&op))return;
    if (!active || journal.failed) return;
    if (!valid(actor,0x1440) || !valid(period,4)) { journal.failed=4;failed(&op,actor,NULL,4);return; }
    unsigned char *p=actor;float *elapsed=(float *)(p+0xe28);uint32_t phase=p[0x57];
    if (journal.host) {
        entities_update();if(!op_live(&op))return;SyncActor identity={0};entities_describe(&identity,actor);if(!op_live(&op))return;
        int actor_slot=entities_slot(actor);if(!op_live(&op))return;
        SyncCadence entry={.slot=(uint32_t)actor_slot,.generation=identity.generation,.spawn_tag=identity.spawn_tag,
            .character=*(int16_t *)(p+0xdc0),.period=*period,.phase=phase,.elapsed=*elapsed};
        memcpy(entry.origin,identity.spawn_position,12);
        if (!cadence_journal_record(&journal,&entry)) { failed(&op,actor,&entry,4);return; }
        ++clonewars_cadence_debug[0];
    } else {
        const SyncCadence *entry=cadence_journal_peek(&journal);SyncActor identity={0};
        if (entry) { identity.slot=entry->slot;identity.generation=entry->generation;identity.spawn_tag=entry->spawn_tag;identity.character=entry->character;memcpy(identity.spawn_position,entry->origin,12); }
        uint32_t local_period=*period,local_elapsed=bits(*elapsed);
        int owner_matches=entry && entities_resolve_reference(&identity)==actor;if(!op_live(&op))return;
        if (!cadence_journal_apply(&journal,entry,owner_matches,phase,period,elapsed)) { failed(&op,actor,entry,(unsigned)journal.failed);return; }
        ++clonewars_cadence_debug[1];clonewars_cadence_debug[2]+=local_period!=entry->period;clonewars_cadence_debug[3]+=local_elapsed!=bits(entry->elapsed);
        clonewars_cadence_debug[5]=entry->slot;clonewars_cadence_debug[6]=entry->generation;clonewars_cadence_debug[7]=local_period;clonewars_cadence_debug[8]=entry->period;
        clonewars_cadence_debug[9]=phase;clonewars_cadence_debug[10]=entry->phase;clonewars_cadence_debug[11]=local_elapsed;clonewars_cadence_debug[12]=bits(entry->elapsed);
        clonewars_cadence_debug[13]=journal.frame->sequence;clonewars_cadence_debug[14]=journal.cursor;
    }
}
__attribute__((naked,used)) static void cadence_period_thunk(void) { __asm__ volatile(CADENCE_THUNK_ASM); }
int cadence_install(void) {
    unsigned char *entry=(unsigned char *)0x96d94a;
    static const unsigned char original[]={0x8b,0x4c,0x24,0x14,0x88,0x8f,0x8e,0x13,0,0};DWORD protection;
    if (memcmp(entry,original,10) || !VirtualProtect(entry,10,PAGE_EXECUTE_READWRITE,&protection)) { clonewars_cadence_installed=-1;return 0; }
    entry[0]=0xe9;*(int32_t *)(entry+1)=(int32_t)((uintptr_t)cadence_period_thunk-(uintptr_t)entry-5);memset(entry+5,0x90,5);
    FlushInstructionCache(GetCurrentProcess(),entry,10);VirtualProtect(entry,10,protection,&protection);clonewars_cadence_installed=1;return 1;
}
int cadence_ready(void) { return clonewars_cadence_installed==1; }
void cadence_cancel(void) { if(binding.bound||!binding.lease.cohort.thread||binding.lease.cohort.thread!=GetCurrentThreadId())return;active=0;cancelled=1;memset(&journal,0,sizeof(journal)); }
int cadence_begin(SyncFrame *frame,int host) {
    if(!module_binding_begin(&binding,frame))return 0;
    CadenceFrameLease op=binding.lease;if(!module_binding_live(&binding,&op))return 0;
    cancelled=0;
    if (last_epoch!=op.cohort.epoch) { memset((void *)clonewars_cadence_failure,0,sizeof(clonewars_cadence_failure));last_epoch=op.cohort.epoch; }
    cadence_journal_begin(&journal,frame,host);active=1;return op_live(&op);
}
int cadence_finish(void) {
    CadenceFrameLease op;if(!cadence_frame_lease_get(&op)||!op_live(&op)||!active)return 0;
    if (cancelled) return 0;
    active=0;++clonewars_cadence_debug[15];
    if (!cadence_journal_finish(&journal)) { ++clonewars_cadence_debug[16];if (!journal.failed) { const SyncCadence *entry=cadence_journal_peek(&journal);journal.failed=3;failed(&op,NULL,entry,3); }return 0; }
    return 1;
}
