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
static uint32_t fire_task_cursor;
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
__attribute__((used)) static volatile uintptr_t fire_task_gate_allow=0x42fe42,fire_task_gate_skip=0x42fff6;
__attribute__((used)) static volatile uintptr_t attack_support_resume=0x8789f7;
__attribute__((used)) static volatile uintptr_t breakup_visible_resume=0x968a9c,breakup_hidden_resume=0x968d4b;
__attribute__((used)) static volatile uintptr_t death_breakup_resume=0x968f1c;
__attribute__((used)) static volatile uintptr_t fall_visible_resume=0x9c49b9,fall_hidden_resume=0x9c4a09;
__declspec(dllexport) volatile LONG clonewars_cadence_installed;
__declspec(dllexport) volatile uint32_t clonewars_cadence_debug[20];
__declspec(dllexport) volatile uint32_t clonewars_cadence_failure[14];
__declspec(dllexport) volatile uint32_t clonewars_fire_task_gate_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_attack_support_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_breakup_visibility_debug[4],clonewars_breakup_visibility_correction[8];
__declspec(dllexport) volatile uint32_t clonewars_death_breakup_debug[4],clonewars_death_breakup_correction[8];
__declspec(dllexport) volatile uint32_t clonewars_fall_visibility_debug[4],clonewars_fall_visibility_correction[8];
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
        SyncCadence entry={.slot=(uint32_t)actor_slot,.generation=identity.generation,.spawn_tag=identity.spawn_tag,.spawn_source=identity.spawn_source,
            .character=*(int16_t *)(p+0xdc0),.period=*period,.phase=phase,.elapsed=*elapsed};
        memcpy(entry.origin,identity.spawn_position,12);
        if (!cadence_journal_record(&journal,&entry)) { failed(&op,actor,&entry,4);return; }
        ++clonewars_cadence_debug[0];
    } else {
        const SyncCadence *entry=cadence_journal_peek(&journal);SyncActor identity={0};
        if (entry) { identity.slot=entry->slot;identity.generation=entry->generation;identity.spawn_tag=entry->spawn_tag;identity.spawn_source=entry->spawn_source;identity.character=entry->character;memcpy(identity.spawn_position,entry->origin,12); }
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
static int apply_actor_gate(void *actor,uint32_t kind,uint16_t flags,uint16_t action,int value,
                           SyncFireTaskState *state,volatile uint32_t *debug) {
    CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active) return value;
    const int failure_value=(kind==SYNC_FIRE_TASK_VISIBILITY || kind==SYNC_ACTOR_DEATH_BREAKUP) ? 0 : kind==SYNC_ACTOR_BREAKUP_VISIBILITY ? 1 : value;
    if (journal.failed) return failure_value;
    if (journal.host) {
        entities_update();
        if (!op_live(&op)) return failure_value;
        SyncActor identity={0};
        entities_describe(&identity,actor);
        const int slot=entities_slot(actor);
        if (!op_live(&op)) return failure_value;
        if (slot>=0 && slot<SYNC_MAX_ACTORS && identity.generation && journal.frame->fire_task_gate_count<SYNC_MAX_ACTORS) {
            SyncFireTaskGate gate={
                .slot=(uint32_t)slot,.generation=identity.generation,.spawn_tag=identity.spawn_tag,.spawn_source=identity.spawn_source,
                .character=*(int16_t *)((unsigned char *)actor+0xdc0),.flags=flags,.action=action,.value=value,.kind=kind
            };
            memcpy(gate.origin,identity.spawn_position,sizeof(gate.origin));
            if (state) gate.state=*state;
            journal.frame->fire_task_gates[journal.frame->fire_task_gate_count++]=gate;
            ++debug[0];
            return value;
        }
    } else if (fire_task_cursor<journal.frame->fire_task_gate_count) {
        const SyncFireTaskGate *gate=&journal.frame->fire_task_gates[fire_task_cursor];
        if (gate->kind==kind && gate->flags==flags && gate->action==action) {
            SyncActor identity={.slot=gate->slot,.generation=gate->generation,.spawn_tag=gate->spawn_tag,.spawn_source=gate->spawn_source,.character=gate->character};
            memcpy(identity.spawn_position,gate->origin,sizeof(gate->origin));
            const int matches=entities_resolve_reference(&identity)==actor;
            if (!op_live(&op)) return failure_value;
            if (matches) {
                ++fire_task_cursor;
                ++debug[1];
                debug[2]+=value!=gate->value;
                if (state) *state=gate->state;
                return gate->value;
            }
        }
    }
    journal.failed=5;
    ++debug[3];
    failed(&op,actor,NULL,5);
    return failure_value;
}

static int apply_fire_task_state(void *actor,unsigned char *task,int allowed,float *delta) {
    uint16_t flags,action;
    memcpy(&flags,task+4,sizeof(flags));
    if (!(flags&SYNC_FIRE_TASK_QUEUES_SHOT)) return allowed;
    CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active) return allowed;
    if (!valid(task,0x30) || !valid(delta,sizeof(*delta))) {
        failed(&op,actor,NULL,5);
        return 0;
    }
    memcpy(&action,task+6,sizeof(action));
    SyncFireTaskState state={.repeat=task[2],.delta=*delta};
    memcpy(state.timers,task+8,sizeof(state.timers));
    memcpy(state.target,task+0x20,sizeof(state.target));
    const int result=apply_actor_gate(actor,SYNC_FIRE_TASK_VISIBILITY,flags,action,allowed,&state,clonewars_fire_task_gate_debug);
    if (!op_live(&op) || journal.failed || !active) return 0;
    if (!journal.host) {
        task[2]=(unsigned char)state.repeat;
        memcpy(task+8,state.timers,sizeof(state.timers));
        memcpy(task+0x20,state.target,sizeof(state.target));
        *delta=state.delta;
    }
    return result;
}

__attribute__((used,noinline)) int cadence_apply_fire_task_gate(void *actor,unsigned char *task,int allowed,float *delta) {
    const DWORD error=GetLastError();
    const int result=apply_fire_task_state(actor,task,allowed,delta);
    SetLastError(error);
    return result;
}

__attribute__((used,noinline)) void cadence_apply_attack_support(void *actor,int *support) {
    DWORD error=GetLastError();
    const int native_support=*support;
    const int authoritative_support=apply_actor_gate(actor,SYNC_FIRE_ATTACK_SUPPORT,0,0,native_support,NULL,clonewars_attack_support_debug);
    // The native setup reads this temporary again for the second compatibility check.
    if (authoritative_support!=native_support) *support=authoritative_support;
    SetLastError(error);
}

__attribute__((used,noinline)) int cadence_apply_breakup_visibility(void *actor,int hidden) {
    const DWORD error=GetLastError();
    // Separate cameras may disagree on model visibility, but physical breakup affects the world.
    const int result=apply_actor_gate(actor,SYNC_ACTOR_BREAKUP_VISIBILITY,0,0,hidden,NULL,clonewars_breakup_visibility_debug);
    CadenceFrameLease op;
    if (result!=hidden && !clonewars_breakup_visibility_correction[0] &&
        cadence_frame_lease_get(&op) && op_live(&op) && active && !journal.failed) {
        uint32_t slot=UINT32_MAX,generation=0;
        entities_observed_identity(actor,&slot,&generation);
        if (op_live(&op)) {
            const uint32_t values[]={journal.frame->epoch,journal.frame->sequence,slot,generation,
                (uint32_t)hidden,(uint32_t)result,*(uint32_t *)0xfb4b6c,0x968a94};
            memcpy((void *)clonewars_breakup_visibility_correction,values,sizeof(values));
        }
    }
    SetLastError(error);
    return result;
}

__attribute__((used,noinline)) void cadence_apply_death_breakup(void *actor,uint32_t *argument) {
    const DWORD error=GetLastError();
    const int local=*argument!=0;
    const int result=apply_actor_gate(actor,SYNC_ACTOR_DEATH_BREAKUP,0,0,local,NULL,clonewars_death_breakup_debug);
    CadenceFrameLease op;
    if (result!=local) {
        *argument=(uint32_t)result;
        if (!clonewars_death_breakup_correction[0] && cadence_frame_lease_get(&op) && op_live(&op) && active && !journal.failed) {
            uint32_t slot=UINT32_MAX,generation=0;
            entities_observed_identity(actor,&slot,&generation);
            if (op_live(&op)) {
                const uint32_t values[]={journal.frame->epoch,journal.frame->sequence,slot,generation,
                    (uint32_t)local,(uint32_t)result,*(uint32_t *)0xfb4b6c,0x968f14};
                memcpy((void *)clonewars_death_breakup_correction,values,sizeof(values));
            }
        }
    }
    SetLastError(error);
}

__attribute__((used,noinline)) int cadence_apply_fall_visibility(void *actor,int visible) {
    const DWORD error=GetLastError();
    const int result=apply_actor_gate(actor,SYNC_ACTOR_FALL_VISIBILITY,0,0,visible,NULL,clonewars_fall_visibility_debug);
    CadenceFrameLease op;
    if (result!=visible && !clonewars_fall_visibility_correction[0] &&
        cadence_frame_lease_get(&op) && op_live(&op) && active && !journal.failed) {
        uint32_t slot=UINT32_MAX,generation=0;
        entities_observed_identity(actor,&slot,&generation);
        if (op_live(&op)) {
            const uint32_t values[]={journal.frame->epoch,journal.frame->sequence,slot,generation,
                (uint32_t)visible,(uint32_t)result,*(uint32_t *)0xfb4b6c,0x9c49b3};
            memcpy((void *)clonewars_fall_visibility_correction,values,sizeof(values));
        }
    }
    SetLastError(error);return result;
}

__attribute__((naked,used)) static void fire_task_gate_thunk(void) { __asm__ volatile(FIRE_TASK_GATE_THUNK_ASM); }
__attribute__((naked,used)) static void attack_support_thunk(void) { __asm__ volatile(ATTACK_SUPPORT_THUNK_ASM); }
__attribute__((naked,used)) static void breakup_visibility_thunk(void) { __asm__ volatile(BREAKUP_VISIBILITY_THUNK_ASM); }
__attribute__((naked,used)) static void death_breakup_thunk(void) { __asm__ volatile(DEATH_BREAKUP_THUNK_ASM); }
__attribute__((naked,used)) static void fall_visibility_thunk(void) { __asm__ volatile(FALL_VISIBILITY_THUNK_ASM); }

static int install_jump(unsigned char *entry,size_t size,void (*thunk)(void)) {
    DWORD protection;
    if (!VirtualProtect(entry,size,PAGE_EXECUTE_READWRITE,&protection)) return 0;
    entry[0]=0xe9;
    *(int32_t *)(entry+1)=(int32_t)((uintptr_t)thunk-(uintptr_t)entry-5);
    memset(entry+5,0x90,size-5);
    FlushInstructionCache(GetCurrentProcess(),entry,size);
    VirtualProtect(entry,size,protection,&protection);
    return 1;
}
int cadence_install(void) {
    unsigned char *period=(unsigned char *)0x96d94a,*fire_task=(unsigned char *)0x42fe2b;
    unsigned char *attack_support=(unsigned char *)0x8789f0;
    unsigned char *breakup_visibility=(unsigned char *)0x968a94;
    unsigned char *death_breakup=(unsigned char *)0x968f14;
    unsigned char *fall_visibility=(unsigned char *)0x9c49b3;
    static const unsigned char fall_visibility_native[]={0x80,0x7a,0x42,0x00,0x74,0x50};
    static const unsigned char death_breakup_native[]={0x83,0xbc,0x24,0xa0,0x00,0x00,0x00,0x00};
    static const unsigned char breakup_visibility_native[]={0x84,0xdb,0x0f,0x85,0xaf,0x02,0x00,0x00};
    static const unsigned char attack_support_native[]={0x8b,0x74,0x24,0x54,0x8b,0x4d,0x24};
    static const unsigned char period_native[]={0x8b,0x4c,0x24,0x14,0x88,0x8f,0x8e,0x13,0,0};
    static const unsigned char fire_task_native[]={
        0x8b,0x43,0x08,0x85,0xc0,0x74,0x06,0x80,0x78,0x42,0x00,0x75,0x0a,
        0xf6,0x46,0x04,0x08,0x0f,0x84,0xb4,0x01,0x00,0x00
    };
    if (memcmp(period,period_native,sizeof(period_native)) || memcmp(fire_task,fire_task_native,sizeof(fire_task_native)) ||
        memcmp(attack_support,attack_support_native,sizeof(attack_support_native)) ||
        memcmp(breakup_visibility,breakup_visibility_native,sizeof(breakup_visibility_native)) ||
        memcmp(death_breakup,death_breakup_native,sizeof(death_breakup_native)) ||
        memcmp(fall_visibility,fall_visibility_native,sizeof(fall_visibility_native)) ||
        !install_jump(period,sizeof(period_native),cadence_period_thunk) ||
        !install_jump(fire_task,sizeof(fire_task_native),fire_task_gate_thunk) ||
        !install_jump(attack_support,sizeof(attack_support_native),attack_support_thunk) ||
        !install_jump(breakup_visibility,sizeof(breakup_visibility_native),breakup_visibility_thunk) ||
        !install_jump(death_breakup,sizeof(death_breakup_native),death_breakup_thunk) ||
        !install_jump(fall_visibility,sizeof(fall_visibility_native),fall_visibility_thunk)) {
        clonewars_cadence_installed=-1;
        return 0;
    }
    clonewars_cadence_installed=1;
    return 1;
}
int cadence_ready(void) { return clonewars_cadence_installed==1; }
void cadence_cancel(void) { if(binding.bound||!binding.lease.cohort.thread||binding.lease.cohort.thread!=GetCurrentThreadId())return;active=0;cancelled=1;memset(&journal,0,sizeof(journal)); }
int cadence_begin(SyncFrame *frame,int host) {
    if(!module_binding_begin(&binding,frame))return 0;
    CadenceFrameLease op=binding.lease;if(!module_binding_live(&binding,&op))return 0;
    cancelled=0;
    if (last_epoch!=op.cohort.epoch) {
        memset((void *)clonewars_cadence_failure,0,sizeof(clonewars_cadence_failure));
        memset((void *)clonewars_breakup_visibility_correction,0,sizeof(clonewars_breakup_visibility_correction));
        memset((void *)clonewars_death_breakup_correction,0,sizeof(clonewars_death_breakup_correction));
        memset((void *)clonewars_fall_visibility_correction,0,sizeof(clonewars_fall_visibility_correction));
        last_epoch=op.cohort.epoch;
    }
    cadence_journal_begin(&journal,frame,host);
    fire_task_cursor=0;
    if (host) frame->fire_task_gate_count=0;
    active=1;return op_live(&op);
}
int cadence_finish(void) {
    CadenceFrameLease op;if(!cadence_frame_lease_get(&op)||!op_live(&op)||!active)return 0;
    if (cancelled) return 0;
    active=0;++clonewars_cadence_debug[15];
    if (!cadence_journal_finish(&journal)) { ++clonewars_cadence_debug[16];if (!journal.failed) { const SyncCadence *entry=cadence_journal_peek(&journal);journal.failed=3;failed(&op,NULL,entry,3); }return 0; }
    if (!journal.host && fire_task_cursor!=journal.frame->fire_task_gate_count) {
        ++clonewars_fire_task_gate_debug[3];
        journal.failed=6;
        failed(&op,NULL,NULL,6);
        return 0;
    }
    return 1;
}
