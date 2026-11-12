#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "cadence_sync.h"
#include "../engine/cadence_thunk.h"
#include "../engine/aim_task_input.h"
#include "../engine/aim_task_thunk.h"
#include "../engine/aim_base_thunk.h"
#include "../engine/force_target_thunk.h"
#include "../engine/force_geometry_thunk.h"
#include "../engine/character_motion_thunk.h"
#include "../engine/character_support_input.h"
#include "physics_input_sync.h"
#include "../engine/primary_perception_thunk.h"
#include "../engine/spellit_query_thunk.h"
#include "../engine/native_authored_poi.h"
#include "../engine/native_resource_identity.h"
#include "../engine/native_script_shoot_source.h"
#include "../engine/script_shoot_thunk.h"
#include "../engine/script_shoot_dispatch_thunk.h"
#include "../engine/rts_competitor_input.h"
#include "../engine/rts_competitor_thunk.h"
#include "entity_sync.h"
#include "game_sync.h"
#include "../engine/module_cohort_binding.h"
static CadenceJournal journal;
__attribute__((used)) static volatile uintptr_t character_velocity_native=0xa08380;
__declspec(dllexport) volatile uint32_t clonewars_character_motion_debug[4],clonewars_character_motion_correction[16];
__declspec(dllexport) volatile uint32_t clonewars_character_support_debug[8];
__declspec(dllexport) volatile uint32_t clonewars_character_support_local[10],clonewars_character_support_host[10];
_Static_assert(sizeof(SyncCharacterMotionState)==68,"native motion and support input");
static uint32_t fire_task_cursor;
static int active;
static int cancelled;
static ModuleCohortBinding binding;
typedef struct SpellItScope {
    CadenceFrameLease lease;
    void *actor,*manager;
    uintptr_t native_frame;
    uint32_t generation;
    uint32_t node_visit;
    SyncSpellItQueryState input;
} SpellItScope;
static __thread SpellItScope spellit_scopes[64];
static __thread unsigned spellit_scope_count;
static int op_live(const CadenceFrameLease *op){return module_binding_live(&binding,op)&&journal.frame==op->cohort.frame;}
int cadence_bind_cohort(const CoherentFrameToken *original){return module_binding_bind(&binding,original);}
int cadence_frame_lease_get(CadenceFrameLease*out){return module_binding_get(&binding,out);}
int cadence_frame_cancelled(const CadenceFrameLease*op){return module_binding_cancelled(&binding,op);}
int cadence_abort_frame(const CadenceFrameLease*op){if(!module_binding_detach(&binding,op))return 0;active=0;cancelled=1;spellit_scope_count=0;memset(&journal,0,sizeof(journal));return 1;}

static uint32_t last_epoch;
__attribute__((used)) static volatile uintptr_t cadence_resume=0x96d954;
__attribute__((used)) static volatile uintptr_t fire_task_gate_allow=0x42fe42,fire_task_gate_skip=0x42fff6;
__attribute__((used)) static volatile uintptr_t attack_support_resume=0x8789f7;
__attribute__((used)) static volatile uintptr_t breakup_visible_resume=0x968a9c,breakup_hidden_resume=0x968d4b;
__attribute__((used)) static volatile uintptr_t death_breakup_resume=0x968f1c;
__attribute__((used)) static volatile uintptr_t fall_visible_resume=0x9c49b9,fall_hidden_resume=0x9c4a09;
__attribute__((used)) static volatile uintptr_t aim_task_input_resume=0x899f3c,aim_task_visible_resume=0x89a09d,aim_task_hidden_resume=0x89a179;
__attribute__((used)) static volatile uintptr_t rts_competitor_input_resume=0x541186;
__attribute__((used)) static volatile uintptr_t aim_base_input_resume=0x899ed8;
__declspec(dllexport) volatile uint32_t clonewars_aim_base_debug[4],clonewars_aim_base_correction[12],clonewars_actor_gate_failure[16];
_Static_assert(sizeof(SyncAimBaseState)==sizeof(SyncFireTaskState),"aim base input variant");
__attribute__((used)) static volatile uintptr_t force_target_visible_resume=0x7f8181,force_target_hidden_resume=0x7f83b1;
__declspec(dllexport) volatile uint32_t clonewars_force_target_debug[4],clonewars_force_target_correction[10];
__declspec(dllexport) volatile uint32_t clonewars_force_geometry_debug[4],clonewars_force_geometry_correction[20];
__attribute__((used)) static volatile uintptr_t force_distance_native=0x574ec0;
__attribute__((used)) static volatile uintptr_t spellit_prepare_resume=0x7da946,spellit_first_heading_resume=0x7da950;
__attribute__((used)) static volatile uintptr_t spellit_second_heading_resume=0x7da96f,spellit_height_resume=0x7daa83;
__attribute__((used)) static volatile uintptr_t spellit_distance_native=0x574f60;
__attribute__((used)) static volatile uintptr_t spellit_node_resume=0x7daa71;
__declspec(dllexport) volatile uint32_t clonewars_spellit_query_debug[4],clonewars_spellit_query_correction[20];
__declspec(dllexport) volatile uint32_t clonewars_spellit_node_debug[4],clonewars_spellit_node_correction[24],clonewars_spellit_node_failure[16];
_Static_assert(sizeof(SyncSpellItNodeState)==sizeof(SyncRtsCompetitorState),"SpellIt node input variant");
_Static_assert(sizeof(SyncSpellItQueryState)==sizeof(SyncFireTaskState),"SpellIt query input variant");
_Static_assert(sizeof(SyncForceQueryState)==sizeof(SyncFireTaskState),"force query input variant");
_Static_assert(sizeof(SyncScriptShootState)==sizeof(NativeScriptShootInput),"script shoot input variant");
_Static_assert(sizeof(SyncScriptShootState)<=sizeof(((SyncFireTaskGate*)0)->storage),"script shoot wire storage");
_Static_assert(SYNC_SCRIPT_SHOOT_MAX_ARGUMENTS==NATIVE_SCRIPT_SHOOT_MAX_ARGUMENTS,"script argument bounds");
__attribute__((used)) static volatile uintptr_t script_shoot_visible_resume=0x963cb4,script_shoot_hidden_resume=0x963cab;
__declspec(dllexport) volatile uint32_t clonewars_script_shoot_debug[4],clonewars_script_shoot_correction[12],clonewars_script_shoot_failure[16];
__declspec(dllexport) volatile uint32_t clonewars_rts_competitor_debug[8],clonewars_rts_competitor_correction[10];
__declspec(dllexport) volatile LONG clonewars_cadence_installed;
__declspec(dllexport) volatile uint32_t clonewars_cadence_debug[20];
__declspec(dllexport) volatile uint32_t clonewars_cadence_failure[14];
__declspec(dllexport) volatile uint32_t clonewars_fire_task_gate_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_attack_support_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_breakup_visibility_debug[4],clonewars_breakup_visibility_correction[8];
__declspec(dllexport) volatile uint32_t clonewars_death_breakup_debug[4],clonewars_death_breakup_correction[8];
__declspec(dllexport) volatile uint32_t clonewars_fall_visibility_debug[4],clonewars_fall_visibility_correction[8];
__declspec(dllexport) volatile uint32_t clonewars_aim_task_debug[4],clonewars_aim_task_correction[12];
typedef struct AimTaskScope {CadenceFrameLease lease;void *actor,*task;uint32_t generation;int visible,prepared;} AimTaskScope;
static __thread AimTaskScope aim_task_scope;
_Static_assert(sizeof(SyncAimTaskState)==sizeof(SyncFireTaskState),"actor gate input variants");
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
                           void *state,volatile uint32_t *debug) {
    CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active) return value;
    const unsigned state_bytes=kind==SYNC_ACTOR_RTS_COMPETITOR ? sizeof(SyncRtsCompetitorState) :
        kind==SYNC_ACTOR_FORCE_GEOMETRY ? sizeof(SyncForceGeometryState) :
        kind==SYNC_ACTOR_CHARACTER_MOTION ? sizeof(SyncCharacterMotionState) :
        kind==SYNC_ACTOR_SPELLIT_NODE ? sizeof(SyncSpellItNodeState) :
        kind==SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY ? sizeof(SyncScriptShootState) :
        kind==SYNC_ACTOR_PRIMARY_PERCEPTION ? sizeof(SyncPrimaryPerceptionState) : sizeof(SyncFireTaskState);
    const int failure_value=(kind==SYNC_FIRE_TASK_VISIBILITY || kind==SYNC_ACTOR_DEATH_BREAKUP || kind==SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY) ? 0 : kind==SYNC_ACTOR_BREAKUP_VISIBILITY ? 1 : value;
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
            if (state) memcpy(&gate.state,state,state_bytes);
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
            if (matches && kind==SYNC_ACTOR_AIM_TASK && !aim_task_context_equal(&gate->aim,state)) {
                journal.failed=7;++debug[3];failed(&op,actor,NULL,7);return failure_value;
            }
            if (matches && kind==SYNC_ACTOR_AIM_BASE) {
                const SyncAimBaseState *a=&gate->aim_base,*b=state;
                if(a->clock!=b->clock || a->task_class!=b->task_class || a->callback_class!=b->callback_class) {
                    journal.failed=12;++debug[3];failed(&op,actor,NULL,12);return failure_value;
                }
            }
            if (matches && kind==SYNC_ACTOR_FORCE_VISIBILITY && memcmp(&gate->force,state,sizeof(SyncForceQueryState))) {
                journal.failed=11;++debug[3];failed(&op,actor,NULL,11);return failure_value;
            }
            if (matches && kind==SYNC_ACTOR_FORCE_GEOMETRY && memcmp(&gate->force_geometry,state,4*sizeof(uint32_t))) {
                journal.failed=13;++debug[3];failed(&op,actor,NULL,13);return failure_value;
            }
            if (matches && kind==SYNC_ACTOR_CHARACTER_MOTION &&
                (memcmp(&gate->character_motion,state,2*sizeof(uint32_t)) ||
                 !character_support_same_source(&gate->character_motion,(const SyncCharacterMotionState *)state))) {
                journal.failed=16;++debug[3];failed(&op,actor,NULL,16);return failure_value;
            }
            if (matches && kind==SYNC_ACTOR_SPELLIT_QUERY && memcmp(&gate->spellit,state,3*sizeof(uint32_t))) {
                journal.failed=15;++debug[3];failed(&op,actor,NULL,15);return failure_value;
            }
            if (matches && kind==SYNC_ACTOR_SPELLIT_NODE && memcmp(&gate->spellit_node,state,13*sizeof(uint32_t))) {
                if (!clonewars_spellit_node_failure[0]) {
                    uint32_t values[16]={journal.frame->epoch,journal.frame->sequence,1};
                    for (unsigned i=0;i<13;++i) if (((const uint32_t *)&gate->spellit_node)[i]!=((const uint32_t *)state)[i]) {
                        values[3]=i;values[4]=((const uint32_t *)&gate->spellit_node)[i];values[5]=((const uint32_t *)state)[i];break;
                    }
                    memcpy((void *)clonewars_spellit_node_failure,values,sizeof(values));
                }
                journal.failed=17;++debug[3];failed(&op,actor,NULL,17);return failure_value;
            }
            if (matches && kind==SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY && memcmp(&gate->script_shoot,state,sizeof(SyncScriptShootState))) {
                if (!clonewars_script_shoot_failure[0]) {
                    uint32_t values[16]={journal.frame->epoch,journal.frame->sequence,1,*(uint32_t*)0xfb4b6c};
                    for (unsigned i=0;i<sizeof(SyncScriptShootState)/4;++i) if (((const uint32_t*)&gate->script_shoot)[i]!=((const uint32_t*)state)[i]) {
                        values[4]=i;values[5]=((const uint32_t*)&gate->script_shoot)[i];values[6]=((const uint32_t*)state)[i];break;
                    }
                    memcpy((void*)clonewars_script_shoot_failure,values,sizeof(values));
                }
                journal.failed=18;++debug[3];failed(&op,actor,NULL,18);return failure_value;
            }
            if (matches && kind==SYNC_ACTOR_RTS_COMPETITOR && !rts_competitor_context_equal(&gate->competitor,state)) {
                journal.failed=10;++debug[3];failed(&op,actor,NULL,10);return failure_value;
            }
            if (matches) {
                ++fire_task_cursor;
                ++debug[1];
                debug[2]+=value!=gate->value;
                if (state) memcpy(state,&gate->state,state_bytes);
                return gate->value;
            }
        }
    }
    if (!clonewars_actor_gate_failure[0]) {
        uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(actor,&slot,&generation);
        const SyncFireTaskGate *expected=fire_task_cursor<journal.frame->fire_task_gate_count?journal.frame->fire_task_gates+fire_task_cursor:NULL;
        const uint32_t values[]={journal.frame->epoch,journal.frame->sequence,fire_task_cursor,kind,slot,generation,*(uint32_t *)0xfb4b6c,
            expected?expected->kind:UINT32_MAX,expected?expected->slot:UINT32_MAX,expected?expected->generation:0,flags,action,
            expected?expected->flags:0,expected?expected->action:0,journal.frame->fire_task_gate_count,0};
        memcpy((void *)clonewars_actor_gate_failure,values,sizeof(values));
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

__attribute__((used,noinline)) void cadence_prepare_aim_task(void *actor,unsigned char *task) {
    const DWORD error=GetLastError();
    aim_task_scope=(AimTaskScope){0};
    CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active || journal.failed) goto done;
    if (!valid(actor,0x1440) || !valid(task,0x2c)) {journal.failed=8;failed(&op,actor,NULL,8);goto done;}
    unsigned char *model=*(unsigned char **)((unsigned char *)actor+8);
    MEMORY_BASIC_INFORMATION table;
    const uintptr_t image=(uintptr_t)GetModuleHandleA(NULL),vtable=*(uintptr_t *)task;
    if (!valid(model,0x43) || !VirtualQuery((void *)vtable,&table,sizeof(table)) ||
        table.State!=MEM_COMMIT || (uintptr_t)table.AllocationBase!=image || vtable<=image) {
        journal.failed=8;failed(&op,actor,NULL,8);goto done;
    }
    entities_update();
    if (!op_live(&op)) goto done;
    SyncAimTaskState inputs={.rng_engine=*(uint32_t *)0xea178c,.clock=*(uint32_t *)0xfb4b6c,.task_class=(uint32_t)(vtable-image)};
    memcpy(&inputs.remaining,task+0x1c,4);memcpy(&inputs.minimum,task+0x14,8);
    void *target=*(void **)(task+0x10);
    if (target && !entities_observed_identity(target,&inputs.target_slot,&inputs.target_generation)) {
        journal.failed=8;failed(&op,actor,NULL,8);goto done;
    }
    if (!op_live(&op)) goto done;
    const SyncAimTaskState local=inputs;
    const int visible=model[0x42]!=0;
    const int effective=apply_actor_gate(actor,SYNC_ACTOR_AIM_TASK,0,0,visible,&inputs,clonewars_aim_task_debug);
    if (!op_live(&op) || !active || journal.failed) goto done;
    if (!journal.host) {
        // Supply the timer and random-stream input; the stock task still chooses and advances its cooldown.
        memcpy(task+0x1c,&inputs.remaining,4);*(uint32_t *)0xea178c=inputs.rng_engine;
        if (!clonewars_aim_task_correction[0] &&
            (local.rng_engine!=inputs.rng_engine || bits(local.remaining)!=bits(inputs.remaining) || visible!=effective)) {
            uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(actor,&slot,&generation);
            if (!op_live(&op)) goto done;
            const uint32_t values[]={journal.frame->epoch,journal.frame->sequence,slot,generation,
                local.rng_engine,inputs.rng_engine,bits(local.remaining),bits(inputs.remaining),
                (uint32_t)visible,(uint32_t)effective,inputs.clock,inputs.task_class};
            memcpy((void *)clonewars_aim_task_correction,values,sizeof(values));
        }
    }
    aim_task_scope=(AimTaskScope){op,actor,task,entities_observed_generation(actor),effective,1};
done:
    SetLastError(error);
}
__attribute__((used,noinline)) int cadence_aim_task_visibility(void *actor,void *task,int visible) {
    const DWORD error=GetLastError();
    CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active) {SetLastError(error);return visible!=0;}
    int result=0;
    if (!journal.failed && aim_task_scope.prepared && aim_task_scope.actor==actor && aim_task_scope.task==task &&
        op_live(&aim_task_scope.lease) && entities_observed_generation(actor)==aim_task_scope.generation) result=aim_task_scope.visible;
    else if (!journal.failed) {journal.failed=9;failed(&op,actor,NULL,9);}
    aim_task_scope.prepared=0;
    SetLastError(error);return result;
}
__attribute__((naked,used)) static void aim_task_input_thunk(void) {__asm__ volatile(AIM_TASK_INPUT_THUNK_ASM);}
__attribute__((naked,used)) static void aim_task_visibility_thunk(void) {__asm__ volatile(AIM_TASK_VISIBILITY_THUNK_ASM);}

#include "script_shoot_dispatch_sync.inc"
__attribute__((naked,used)) static void script_shoot_visibility_thunk(void) {__asm__ volatile(SCRIPT_SHOOT_VISIBILITY_THUNK_ASM);}

__attribute__((used,noinline)) void cadence_prepare_rts_competitor(unsigned char *competitor,float *delta) {
    const DWORD error=GetLastError();
    CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active || journal.failed) goto done;
    if (!valid(competitor,0xd4) || !valid(delta,4)) {journal.failed=11;failed(&op,NULL,NULL,11);goto done;}
    void *actor=*(void **)(competitor+0xd0);
    // A competitor can represent an actor or a non-actor battlefield owner. Only this native actor backlink is bound here.
    if (!valid(actor,0x1440)) {++clonewars_rts_competitor_debug[4];goto done;}
    unsigned char *component=*(unsigned char **)((unsigned char *)actor+0x142c);
    if (!valid(component,0x90) || *(void **)(component+0x8c)!=competitor) {++clonewars_rts_competitor_debug[4];goto done;}
    MEMORY_BASIC_INFORMATION table;
    const uintptr_t image=(uintptr_t)GetModuleHandleA(NULL),vtable=*(uintptr_t *)competitor;
    if (!VirtualQuery((void *)vtable,&table,sizeof(table)) || table.State!=MEM_COMMIT ||
        (uintptr_t)table.AllocationBase!=image || vtable<=image) {journal.failed=11;failed(&op,actor,NULL,11);goto done;}
    entities_update();
    if (!op_live(&op)) goto done;
    SyncRtsCompetitorState inputs={.rng_game=*(uint32_t *)0xe637b4,.rng_engine=*(uint32_t *)0xea178c,
        .clock=*(uint32_t *)0xfb4b6c,.competitor_class=(uint32_t)(vtable-image),.delta=*delta};
    static const unsigned offsets[]={0x60,0x64,0x68,0x6c,0x70,0x74,0x78,0x7c,0xa0,0xa4,0xa8,0xac};
    for (unsigned i=0;i<12;++i) memcpy(inputs.timers+i,competitor+offsets[i],4);
    const SyncRtsCompetitorState local=inputs;
    apply_actor_gate(actor,SYNC_ACTOR_RTS_COMPETITOR,0,0,0,&inputs,clonewars_rts_competitor_debug);
    if (!op_live(&op) || !active || journal.failed) goto done;
    if (!journal.host) {
        if (!clonewars_rts_competitor_correction[0] && memcmp(&local,&inputs,sizeof(inputs))) {
            uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(actor,&slot,&generation);
            if (!op_live(&op)) goto done;
            const uint32_t values[]={journal.frame->epoch,journal.frame->sequence,slot,generation,
                local.rng_engine,inputs.rng_engine,bits(local.timers[0]),bits(inputs.timers[0]),inputs.clock,inputs.competitor_class};
            memcpy((void *)clonewars_rts_competitor_correction,values,sizeof(values));
        }
        for (unsigned i=0;i<12;++i) memcpy(competitor+offsets[i],inputs.timers+i,4);
        *delta=inputs.delta;*(uint32_t *)0xe637b4=inputs.rng_game;*(uint32_t *)0xea178c=inputs.rng_engine;
    }
done:
    SetLastError(error);
}
__attribute__((naked,used)) static void rts_competitor_input_thunk(void) {__asm__ volatile(RTS_COMPETITOR_INPUT_THUNK_ASM);}

__attribute__((used,noinline)) void cadence_prepare_aim_base(unsigned char *task,unsigned char *wrapper,float *delta) {
    const DWORD error=GetLastError();CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active || journal.failed) goto done;
    if (!valid(wrapper,8)) goto done;
    unsigned char *actor=*(unsigned char **)(wrapper+4);
    if (!valid(actor,0x1440)) goto done;
    unsigned char *model=*(unsigned char **)(actor+8);
    if (!valid(model,0x38)) goto done;
    unsigned char *brain=*(unsigned char **)(model+0x34);
    if (!valid(brain,0x19c) || !*(uint32_t *)(brain+0x198)) goto done;
    if (!valid(task,0x2c) || !valid(delta,4)) {journal.failed=12;failed(&op,actor,NULL,12);goto done;}
    const uintptr_t image=(uintptr_t)GetModuleHandleA(NULL),vtable=*(uintptr_t *)task;
    MEMORY_BASIC_INFORMATION table;
    if (!VirtualQuery((void *)vtable,&table,sizeof(table)) || table.State!=MEM_COMMIT ||
        (uintptr_t)table.AllocationBase!=image || vtable<=image) {journal.failed=12;failed(&op,actor,NULL,12);goto done;}
    SyncAimBaseState inputs={.rng_engine=*(uint32_t *)0xea178c,.rng_game=*(uint32_t *)0xe637b4,
        .clock=*(uint32_t *)0xfb4b6c,.task_class=(uint32_t)(vtable-image),.delta=*delta};
    void *callback=*(void **)(task+4);
    if (callback) {
        if (!valid(callback,4)) {journal.failed=12;failed(&op,actor,NULL,12);goto done;}
        const uintptr_t callback_table=*(uintptr_t *)callback;
        if (!VirtualQuery((void *)callback_table,&table,sizeof(table)) || table.State!=MEM_COMMIT ||
            (uintptr_t)table.AllocationBase!=image || callback_table<=image) {journal.failed=12;failed(&op,actor,NULL,12);goto done;}
        inputs.callback_class=(uint32_t)(callback_table-image);
    }
    memcpy(&inputs.elapsed,task+8,4);memcpy(&inputs.remaining,task+0x1c,4);
    const SyncAimBaseState local=inputs;
    apply_actor_gate(actor,SYNC_ACTOR_AIM_BASE,0,0,0,&inputs,clonewars_aim_base_debug);
    if (!op_live(&op) || !active || journal.failed) goto done;
    if (!journal.host) {
        memcpy(task+8,&inputs.elapsed,4);memcpy(task+0x1c,&inputs.remaining,4);*delta=inputs.delta;
        *(uint32_t *)0xea178c=inputs.rng_engine;*(uint32_t *)0xe637b4=inputs.rng_game;
        if(memcmp(&local,&inputs,sizeof(inputs))) {
            ++clonewars_aim_base_debug[2];
            if(!clonewars_aim_base_correction[0]) {
                uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(actor,&slot,&generation);
                if(op_live(&op)) {
                    const uint32_t values[]={journal.frame->epoch,journal.frame->sequence,slot,generation,inputs.clock,inputs.task_class,inputs.callback_class,
                        bits(local.elapsed),bits(inputs.elapsed),bits(local.remaining),bits(inputs.remaining),bits(inputs.delta)};
                    memcpy((void *)clonewars_aim_base_correction,values,sizeof(values));
                }
            }
        }
    }
done:SetLastError(error);
}
__attribute__((naked,used)) static void aim_base_input_thunk(void) {__asm__ volatile(AIM_BASE_INPUT_THUNK_ASM);}

__attribute__((used,noinline)) int cadence_force_target_visibility(void *candidate,void *caster,uint32_t mode,int visible) {
    const DWORD error=GetLastError();
    CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active) return visible;
    if (!valid(candidate,0x1440) || !valid(caster,0x1440)) {
        journal.failed=11;++clonewars_force_target_debug[3];failed(&op,candidate,NULL,11);SetLastError(error);return visible;
    }
    entities_update();
    if (!op_live(&op)) {SetLastError(error);return visible;}
    SyncForceQueryState context={.mode=mode,.clock=*(uint32_t *)0xfb4b6c};
    if (!entities_observed_identity(caster,&context.caster_slot,&context.caster_generation)) {
        journal.failed=11;++clonewars_force_target_debug[3];failed(&op,candidate,NULL,11);SetLastError(error);return visible;
    }
    const int result=apply_actor_gate(candidate,SYNC_ACTOR_FORCE_VISIBILITY,0,0,visible!=0,&context,clonewars_force_target_debug);
    if (result!=(visible!=0) && !clonewars_force_target_correction[0] && op_live(&op) && !journal.failed) {
        uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(candidate,&slot,&generation);
        if (op_live(&op)) {
            const uint32_t values[]={journal.frame->epoch,journal.frame->sequence,slot,generation,(uint32_t)(visible!=0),(uint32_t)result,context.clock,context.caster_slot,context.caster_generation,mode};
            memcpy((void *)clonewars_force_target_correction,values,sizeof(values));
        }
    }
    SetLastError(error);return result;
}
__attribute__((naked,used)) static void force_target_visibility_thunk(void) {__asm__ volatile(FORCE_TARGET_VISIBILITY_THUNK_ASM);}

__attribute__((used,noinline)) void cadence_force_geometry_input(void *candidate,void *caster,uint32_t mode,float *points) {
    const DWORD error=GetLastError();CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active || journal.failed) goto done;
    if (!valid(candidate,0x1440) || !valid(caster,0x1440) || !valid(points,6*sizeof(float))) {
        journal.failed=13;++clonewars_force_geometry_debug[3];failed(&op,candidate,NULL,13);goto done;
    }
    entities_update();if (!op_live(&op)) goto done;
    SyncForceGeometryState inputs={.mode=mode,.clock=*(uint32_t *)0xfb4b6c};
    if (!entities_observed_identity(caster,&inputs.caster_slot,&inputs.caster_generation)) {
        journal.failed=13;++clonewars_force_geometry_debug[3];failed(&op,candidate,NULL,13);goto done;
    }
    memcpy(inputs.caster_position,points,3*sizeof(float));memcpy(inputs.candidate_position,points+3,3*sizeof(float));
    const SyncForceGeometryState local=inputs;
    apply_actor_gate(candidate,SYNC_ACTOR_FORCE_GEOMETRY,0,0,0,&inputs,clonewars_force_geometry_debug);
    if (!op_live(&op) || !active || journal.failed || journal.host) goto done;
    if (memcmp(local.caster_position,inputs.caster_position,6*sizeof(float))) {
        ++clonewars_force_geometry_debug[2];
        if (!clonewars_force_geometry_correction[0]) {
            uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(candidate,&slot,&generation);
            if (!op_live(&op)) goto done;
            uint32_t values[20]={journal.frame->epoch,journal.frame->sequence,slot,generation,inputs.clock,
                inputs.caster_slot,inputs.caster_generation,mode};
            memcpy(values+8,local.caster_position,6*sizeof(float));memcpy(values+14,inputs.caster_position,6*sizeof(float));
            memcpy((void *)clonewars_force_geometry_correction,values,sizeof(values));
        }
    }
    memcpy(points,inputs.caster_position,3*sizeof(float));memcpy(points+3,inputs.candidate_position,3*sizeof(float));
done:SetLastError(error);
}
__attribute__((naked,used)) static void force_geometry_input_thunk(void) {__asm__ volatile(FORCE_GEOMETRY_INPUT_THUNK_ASM);}

static int spellit_manager_matches(void *manager) {
    unsigned char *world=*(unsigned char **)0xfb4a20,*provider=*(unsigned char **)0xe90220,*registry=*(unsigned char **)0xe90184;
    if (!valid(world,0x404) || !valid(provider,0x3c) || !valid(registry,0x2c)) return 0;
    const int index=*(int *)(provider+0x38),count=*(int *)(registry+0x28);
    void ***handle=*(void ****)(world+0x400);
    if (index<0 || index>=count || count>4096 || !valid(handle,sizeof(*handle))) return 0;
    void **table=*handle;
    return valid(table,(unsigned)(index+1)*sizeof(*table)) && table[index]==manager;
}
static int cadence_image_offset(const void *pointer,uint32_t *offset) {
    const uintptr_t image=(uintptr_t)GetModuleHandleA(NULL),address=(uintptr_t)pointer;
    MEMORY_BASIC_INFORMATION memory;
    if (address<=image || !VirtualQuery(pointer,&memory,sizeof(memory)) || memory.State!=MEM_COMMIT ||
        (uintptr_t)memory.AllocationBase!=image || (memory.Protect&(PAGE_NOACCESS|PAGE_GUARD))) return 0;
    *offset=(uint32_t)(address-image);return 1;
}
__attribute__((used,noinline)) void cadence_spellit_prepare(void *actor,void *manager,uintptr_t native_frame,float *limit) {
    const DWORD error=GetLastError();CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active || journal.failed) goto done;
    if (!valid(actor,0x1440) || !valid(manager,4) || !valid((void *)native_frame,12) || !valid(limit,4) ||
        *(void **)(native_frame+8)!=actor || !spellit_manager_matches(manager)) goto invalid;
    unsigned char *model=*(unsigned char **)((unsigned char *)actor+8);
    if (model && !valid(model,0x42)) goto invalid;
    SyncSpellItQueryState inputs={.clock=*(uint32_t *)0xfb4b6c,.heading=model?*(uint16_t *)(model+0x40):0,.limit=*limit};
    if (!cadence_image_offset(*(void **)manager,&inputs.manager_class) ||
        !cadence_image_offset(*(void **)(native_frame+4),&inputs.caller_site)) goto invalid;
    memcpy(inputs.position,(unsigned char *)actor+0x24,sizeof(inputs.position));
    const SyncSpellItQueryState local=inputs;
    entities_update();if (!op_live(&op)) goto done;
    const uint32_t generation=entities_observed_generation(actor);
    if (!generation || !entities_allocation_live(actor,generation)) goto invalid;
    apply_actor_gate(actor,SYNC_ACTOR_SPELLIT_QUERY,0,0,0,&inputs,clonewars_spellit_query_debug);
    if (!op_live(&op) || !active || journal.failed) goto done;
    unsigned index=0;
    while (index<spellit_scope_count && spellit_scopes[index].native_frame!=native_frame) ++index;
    if (index==spellit_scope_count) {
        if (index==sizeof(spellit_scopes)/sizeof(spellit_scopes[0])) goto invalid;
        ++spellit_scope_count;
    }
    spellit_scopes[index]=(SpellItScope){.lease=op,.actor=actor,.manager=manager,.native_frame=native_frame,.generation=generation,.input=inputs};
    if (!journal.host) {
        *limit=inputs.limit;
        if (memcmp(&local,&inputs,sizeof(inputs))) {
            ++clonewars_spellit_query_debug[2];
            if (!clonewars_spellit_query_correction[0]) {
                uint32_t slot=UINT32_MAX,remote_generation=0;entities_observed_identity(actor,&slot,&remote_generation);
                if (!op_live(&op)) goto done;
                uint32_t values[20]={journal.frame->epoch,journal.frame->sequence,slot,remote_generation,inputs.clock,local.heading,inputs.heading};
                memcpy(values+7,local.position,12);memcpy(values+10,inputs.position,12);
                values[13]=bits(local.limit);values[14]=bits(inputs.limit);values[15]=inputs.manager_class;values[16]=inputs.caller_site;
                memcpy((void *)clonewars_spellit_query_correction,values,sizeof(values));
            }
        }
    }
    goto done;
invalid:
    if (op_live(&op)) {journal.failed=15;++clonewars_spellit_query_debug[3];failed(&op,actor,NULL,15);}
done:SetLastError(error);
}
static SpellItScope *spellit_scope_for(uintptr_t native_frame) {
    CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active || journal.failed) return NULL;
    for (unsigned i=0;i<spellit_scope_count;++i) {
        SpellItScope *scope=spellit_scopes+i;
        if (scope->native_frame!=native_frame) continue;
        if (scope->lease.serial==op.serial && module_cohort_same(&scope->lease.cohort,&op.cohort) &&
            scope->input.clock==*(uint32_t *)0xfb4b6c && valid((void *)native_frame,12) &&
            *(void **)(native_frame+8)==scope->actor && entities_allocation_live(scope->actor,scope->generation) && op_live(&op)) return scope;
        break;
    }
    if (op_live(&op)) {journal.failed=15;++clonewars_spellit_query_debug[3];failed(&op,NULL,NULL,15);}
    return NULL;
}
__attribute__((used,noinline)) uint32_t cadence_spellit_operand(uintptr_t native_frame,uint32_t kind,uint32_t local) {
    const DWORD error=GetLastError();const SpellItScope *scope=spellit_scope_for(native_frame);
    const uint32_t result=scope?(kind?bits(scope->input.position[1]):scope->input.heading):local;
    SetLastError(error);return result;
}
__attribute__((used,noinline)) void cadence_spellit_position(uintptr_t native_frame,float *position) {
    const DWORD error=GetLastError();const SpellItScope *scope=spellit_scope_for(native_frame);
    if (scope) memcpy(position,scope->input.position,sizeof(scope->input.position));
    SetLastError(error);
}

typedef struct SpellItResourceKey {
    uint32_t epoch;
    NativeResourceIdentity source;
} SpellItResourceKey;
static unsigned spellit_name_length(const unsigned char *name) {
    unsigned length=0;
    if (!name) return 0;
    while (length<1024) {
        MEMORY_BASIC_INFORMATION memory;
        if (!VirtualQuery(name+length,&memory,sizeof(memory)) || memory.State!=MEM_COMMIT ||
            (memory.Protect&(PAGE_GUARD|PAGE_NOACCESS))) return 0;
        const uintptr_t end=(uintptr_t)memory.BaseAddress+memory.RegionSize;
        unsigned limit=(unsigned)(end-(uintptr_t)name);
        if (limit>1024) limit=1024;
        while (length<limit) if (!name[length++]) return length>1?length:0;
    }
    return 0;
}
static int spellit_name_key(const unsigned char *name,uint32_t key[4]) {
    const unsigned length=spellit_name_length(name);
    for (unsigned n=0;n<length;++n) for (unsigned i=0;i<4;++i) key[i]=(key[i]^name[n])*(16777619u+2u*i);
    return length!=0;
}
static int spellit_resource_key(const CadenceFrameLease *op,unsigned char *resource,uint32_t key[4],SpellItResourceKey *witness) {
    NativeResourceIdentity source;
    if (!op_live(op) || !native_resource_identity_resolve(*(void **)0xfb4a20,resource,&source) || !op_live(op)) return 0;
    if (witness) *witness=(SpellItResourceKey){.epoch=journal.frame->epoch,.source=source};
    memcpy(key,source.key,sizeof(source.key));
    return op_live(op);
}
__attribute__((used,noinline)) void cadence_spellit_node(uintptr_t native_frame,unsigned char *gizmo,unsigned char *node,float *position) {
    const DWORD error=GetLastError();SpellItScope *scope=spellit_scope_for(native_frame);
    if (!scope) goto done;
    const CadenceFrameLease op=scope->lease;uint32_t reason=2;
    unsigned char *entity=NULL,*receiver=NULL,*resource=NULL,*poi=NULL,*runtime=NULL,*array=NULL;
    uint32_t count=0;NativeAuthoredPoi poi_witness={0};
    if (!valid(gizmo,0x28) || !valid(node,12) || !valid(position,12) || !valid(scope->manager,0x28)) goto invalid;
    entity=*(unsigned char **)(node+8);
    if (!valid(entity,0x40)) goto invalid;
    receiver=*(unsigned char **)(entity+0x3c);
    if (!valid(receiver,0x34)) goto invalid;
    resource=*(unsigned char **)(receiver+0x2c);poi=*(unsigned char **)(receiver+0x30);
    reason=4;
    if (!native_authored_poi_resolve(entity,&poi_witness) || poi_witness.receiver!=receiver || !op_live(&op)) goto invalid;
    resource=poi_witness.resource;poi=poi_witness.poi;runtime=poi_witness.runtime;
    array=poi_witness.array;count=poi_witness.poi_count;
    SyncSpellItNodeState input={.clock=scope->input.clock,.poi_count=count,
        .poi_ordinal=poi_witness.poi_ordinal,.node_ordinal=scope->node_visit};
    reason=5;
    SpellItResourceKey resource_witness;
    unsigned char *component=*(unsigned char **)(receiver+0x14);
    if (!cadence_image_offset(*(void **)gizmo,&input.gizmo_class) || !cadence_image_offset(*(void **)receiver,&input.receiver_class) ||
        !valid(component,4) || !cadence_image_offset(*(void **)component,&input.component_class) ||
        !spellit_resource_key(&op,resource,input.resource_name,&resource_witness)) goto invalid;
    reason=6;uint32_t name[4]={2166136261u,0x9e3779b9u,0x85ebca6bu,0xc2b2ae35u};
    if (!spellit_name_key(*(const unsigned char **)(poi+0xb4),name) || !name[0]) goto invalid;
    input.poi_name=name[0];
    unsigned char *current=*(unsigned char **)((unsigned char *)scope->manager+0x24);
    reason=7;
    while (current!=gizmo && input.gizmo_ordinal<65536) {
        if (!valid(current,0x28)) goto invalid;
        current=*(unsigned char **)(current+0x24);++input.gizmo_ordinal;
    }
    if (current!=gizmo || input.gizmo_ordinal>=65536 || input.node_ordinal>=65536 || !op_live(&op)) goto invalid;
    if (!native_authored_poi_revalidate(&poi_witness)) goto invalid;
    memcpy(input.position,position,sizeof(input.position));
    reason=8;for (unsigned i=0;i<3;++i) if ((bits(input.position[i])&0x7f800000u)==0x7f800000u) goto invalid;
    const SyncSpellItNodeState local=input;
    apply_actor_gate(scope->actor,SYNC_ACTOR_SPELLIT_NODE,0,0,0,&input,clonewars_spellit_node_debug);
    if (!op_live(&op) || !active || journal.failed) goto done;
    ++scope->node_visit;
    if (!journal.host) {
        reason=9;
        SpellItResourceKey after_witness;uint32_t after_key[4],after_class;
        if (!valid(node,12) || !valid(entity,0x40) || !valid(receiver,0x34) || !valid(poi,0xe0) ||
            *(uint32_t *)0xfb4b6c!=input.clock || *(void **)(node+8)!=entity || *(void **)(entity+0x3c)!=receiver ||
            !native_authored_poi_revalidate(&poi_witness) || *(void **)(poi+0xd4)!=poi_witness.authored_receiver ||
            *(void **)(receiver+0x14)!=component || !valid(resource,0x738) || *(void **)(resource+0x6f8)!=runtime ||
            !valid(runtime,0x70) || *(void **)(runtime+0x6c)!=array || *(uint32_t *)(runtime+0x68)!=count ||
            !cadence_image_offset(*(void **)gizmo,&after_class) || after_class!=input.gizmo_class ||
            !cadence_image_offset(*(void **)receiver,&after_class) || after_class!=input.receiver_class ||
            !valid(component,4) || !cadence_image_offset(*(void **)component,&after_class) || after_class!=input.component_class ||
            !spellit_resource_key(&op,resource,after_key,&after_witness) || memcmp(&resource_witness,&after_witness,sizeof(resource_witness)) ||
            memcmp(input.resource_name,after_key,sizeof(after_key)) || !entities_allocation_live(scope->actor,scope->generation) || !op_live(&op)) goto invalid;
        if (memcmp(local.position,input.position,sizeof(input.position))) {
            ++clonewars_spellit_node_debug[2];
            if (!clonewars_spellit_node_correction[0]) {
                uint32_t values[24]={journal.frame->epoch,journal.frame->sequence};
                memcpy(values+2,&input,13*sizeof(uint32_t));memcpy(values+15,local.position,12);memcpy(values+18,input.position,12);
                memcpy((void *)clonewars_spellit_node_correction,values,sizeof(values));
            }
        }
        memcpy(position,input.position,sizeof(input.position));
    }
    goto done;
invalid:
    if (op_live(&op)) {
        if (!clonewars_spellit_node_failure[0]) {
            uint32_t values[16]={journal.frame->epoch,journal.frame->sequence,reason,scope->node_visit,scope->input.clock,
                (uintptr_t)gizmo,(uintptr_t)node,(uintptr_t)entity,(uintptr_t)receiver,(uintptr_t)resource,
                (uintptr_t)poi,(uintptr_t)runtime,(uintptr_t)array,count,(uintptr_t)poi_witness.authored_receiver,poi_witness.chain_count};
            memcpy((void *)clonewars_spellit_node_failure,values,sizeof(values));
        }
        journal.failed=17;++clonewars_spellit_node_debug[3];failed(&op,scope->actor,NULL,17);
    }
done:SetLastError(error);
}
__attribute__((naked,used)) static void spellit_node_thunk(void) {__asm__ volatile(SPELLIT_NODE_THUNK_ASM);}
__attribute__((naked,used)) static void spellit_prepare_thunk(void) {__asm__ volatile(SPELLIT_PREPARE_THUNK_ASM);}
__attribute__((naked,used)) static void spellit_first_heading_thunk(void) {__asm__ volatile(SPELLIT_HEADING_THUNK_ASM("%eax",spellit_first_heading_resume));}
__attribute__((naked,used)) static void spellit_second_heading_thunk(void) {__asm__ volatile(SPELLIT_HEADING_THUNK_ASM("%esi",spellit_second_heading_resume));}
__attribute__((naked,used)) static void spellit_height_thunk(void) {__asm__ volatile(SPELLIT_HEIGHT_THUNK_ASM);}
__attribute__((naked,used)) static void spellit_position_thunk(void) {__asm__ volatile(SPELLIT_POSITION_THUNK_ASM);}

__attribute__((used,noinline)) void cadence_character_motion_input(unsigned char *actor,void *body,float *velocity) {
    const DWORD error=GetLastError();CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active || journal.failed) goto done;
    if (!valid(actor,0x1440) || !valid(body,0xca) || !valid(velocity,4*sizeof(float))) goto invalid;
    unsigned char *model=*(unsigned char **)(actor+8);
    if (!valid(model,0x3c) || *(void **)(model+0x38)!=body) goto invalid;
    SyncCharacterMotionState input={.clock=*(uint32_t *)0xfb4b6c};
    if (!cadence_image_offset(*(void **)body,&input.body_class)) goto invalid;
    input.rest_counter=*(uint16_t *)((unsigned char *)body+0xc8);
    memcpy(input.velocity,velocity,sizeof(input.velocity));
    void *support=NULL;uint32_t support_source[2]={0};
    if (valid(body,0x140)) {
        support=*(void **)((unsigned char *)body+0xec);
        if (valid(support,0x1a) && (((unsigned char *)support)[0x19]&0x60)==0x40 &&
            physics_effect_body_source(support,support_source)) {
            input.support_frame=support_source[0];input.support_event=support_source[1];
            memcpy(input.support_anchor,(unsigned char *)body+0x110,sizeof input.support_anchor);
            memcpy(input.support_normal,(unsigned char *)body+0xf0,sizeof input.support_normal);
            input.support_material_flags=*(uint16_t *)((unsigned char *)body+0x102) |
                ((*(uint32_t *)((unsigned char *)body+0xc0)&1u)<<16);
        }
    }
    if (!character_support_input_valid(&input)) goto invalid;
    for (unsigned i=0;i<4;++i) if ((bits(input.velocity[i])&0x7f800000u)==0x7f800000u) goto invalid;
    entities_update();if (!op_live(&op)) goto done;
    const uint32_t allocation=entities_observed_generation(actor);
    if (!allocation || !entities_allocation_live(actor,allocation)) goto invalid;
    const SyncCharacterMotionState local=input;
    if (journal.host && input.support_frame) ++clonewars_character_support_debug[0];
    apply_actor_gate(actor,SYNC_ACTOR_CHARACTER_MOTION,0,0,0,&input,clonewars_character_motion_debug);
    if (!op_live(&op) || !active || journal.failed || journal.host) goto done;
    uint32_t body_class;
    if (!entities_allocation_live(actor,allocation) || *(unsigned char **)(actor+8)!=model || !valid(model,0x3c) ||
        *(void **)(model+0x38)!=body || !valid(body,0xca) || !cadence_image_offset(*(void **)body,&body_class) ||
        body_class!=input.body_class || input.clock!=*(uint32_t *)0xfb4b6c || input.rest_counter>UINT16_MAX ||
        !character_support_same_source(&local,&input)) goto invalid;
    if (input.support_frame) {
        uint32_t current_source[2]={0};
        if (!valid(body,0x140) || *(void **)((unsigned char *)body+0xec)!=support ||
            !physics_effect_body_source(support,current_source) ||
            memcmp(current_source,support_source,sizeof current_source)) goto invalid;
        if (memcmp(local.support_anchor,input.support_anchor,sizeof input.support_anchor) ||
            memcmp(local.support_normal,input.support_normal,sizeof input.support_normal) ||
            local.support_material_flags!=input.support_material_flags) {
            ++clonewars_character_support_debug[2];
            if (!clonewars_character_support_debug[3]) {
                clonewars_character_support_debug[3]=input.clock;
                clonewars_character_support_debug[4]=input.support_frame;
                clonewars_character_support_debug[5]=input.support_event;
                memcpy((void *)clonewars_character_support_local,&local.support_frame,40);
                memcpy((void *)clonewars_character_support_host,&input.support_frame,40);
            }
        }
        /* A31D30 consumes the previous support's local anchor and normal before the new contact query. */
        if (!character_support_replay(body,&local,&input)) goto invalid;
    }
    if (input.support_frame) ++clonewars_character_support_debug[1];
    if (memcmp(local.velocity,input.velocity,sizeof(input.velocity)) || local.rest_counter!=input.rest_counter) {
        ++clonewars_character_motion_debug[2];
        if (!clonewars_character_motion_correction[0]) {
            uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(actor,&slot,&generation);
            if (!op_live(&op)) goto done;
            uint32_t values[16]={journal.frame->epoch,journal.frame->sequence,slot,generation,input.clock,input.body_class};
            memcpy(values+6,local.velocity,sizeof(local.velocity));memcpy(values+10,input.velocity,sizeof(input.velocity));
            values[14]=local.rest_counter;values[15]=input.rest_counter;
            memcpy((void *)clonewars_character_motion_correction,values,sizeof(values));
        }
    }
    memcpy(velocity,input.velocity,sizeof(input.velocity));
    /* A15C60 consumes this history before deciding whether to run the contact solver. */
    *(uint16_t *)((unsigned char *)body+0xc8)=(uint16_t)input.rest_counter;
    goto done;
invalid:
    if (op_live(&op)) {journal.failed=16;++clonewars_character_motion_debug[3];failed(&op,actor,NULL,16);}
done:SetLastError(error);
}
__attribute__((naked,used)) static void character_motion_thunk(void) {__asm__ volatile(CHARACTER_MOTION_INPUT_THUNK_ASM);}

__attribute__((used)) static volatile uintptr_t primary_perception_resume=0x9ddc1f;
__declspec(dllexport) volatile uint32_t clonewars_primary_perception_debug[4];

static int perception_target_live(const unsigned char *target) {
    return valid(target,0x1440) && (*(const uint32_t *)(target+0x50)&3)==3 && !target[0x54];
}

__attribute__((used,noinline)) static void cadence_primary_perception(unsigned char *actor) {
    const DWORD error=GetLastError();
    CadenceFrameLease op;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active || journal.failed) goto done;
    if (!valid(actor,0x1440)) goto invalid;

    const uint32_t clock=*(uint32_t *)0xfb4b6c;
    unsigned char *local_target=*(unsigned char **)(actor+0x164);
    const float local_distance=*(float *)(actor+0x168);
    uint32_t *flags=(uint32_t *)(actor+0x1c8);
    SyncPrimaryPerceptionState input={.clock=clock,.target_slot=UINT32_MAX};
    entities_update();
    if (!op_live(&op)) goto done;
    const uint32_t generation=entities_observed_generation(actor);
    if (!generation) goto invalid;
    if (journal.host && perception_target_live(local_target)) {
        SyncActor identity={0};
        entities_describe(&identity,local_target);
        if (!op_live(&op)) goto done;
        const int slot=entities_slot(local_target);
        if (slot<0 || slot>=SYNC_MAX_ACTORS || !identity.generation ||
            (bits(local_distance)&0x7f800000u)==0x7f800000u || local_distance<0) goto invalid;
        input.target_slot=(uint32_t)slot;
        input.target_generation=identity.generation;
        input.target_tag=identity.spawn_tag;
        input.target_character=*(const int16_t *)(local_target+0xdc0);
        input.target_source=identity.spawn_source;
        memcpy(input.target_origin,identity.spawn_position,sizeof(input.target_origin));
        input.distance=local_distance;
        input.target_visible=(*flags>>5)&1;
    }

    apply_actor_gate(actor,SYNC_ACTOR_PRIMARY_PERCEPTION,0,0,0,&input,clonewars_primary_perception_debug);
    if (!op_live(&op) || !active || journal.failed || journal.host) goto done;
    unsigned char *target=NULL;
    if (input.target_slot!=UINT32_MAX) {
        SyncActor identity={.slot=input.target_slot,.generation=input.target_generation,.spawn_tag=input.target_tag,
            .character=input.target_character,.spawn_source=input.target_source};
        memcpy(identity.spawn_position,input.target_origin,sizeof(identity.spawn_position));
        target=entities_resolve_reference(&identity);
        if (!op_live(&op)) goto done;
        if (!perception_target_live(target)) goto invalid;
    }
    if (input.clock!=clock || !entities_allocation_live(actor,generation)) goto invalid;
    if (!op_live(&op)) goto done;
    if (target!=local_target || (target && (bits(input.distance)!=bits(local_distance) || input.target_visible!=((*flags>>5)&1))))
        ++clonewars_primary_perception_debug[2];
    // The stock publisher consumes these temporary operands and clears them before returning.
    *(unsigned char **)(actor+0x164)=target;
    if (target) {
        *(float *)(actor+0x168)=input.distance;
        *flags=(*flags&~0x20u)|(input.target_visible<<5);
    }
    goto done;
invalid:
    if (op_live(&op)) {journal.failed=19;++clonewars_primary_perception_debug[3];failed(&op,actor,NULL,19);}
done:
    SetLastError(error);
}

__attribute__((naked,used)) static void primary_perception_thunk(void) {__asm__ volatile(PRIMARY_PERCEPTION_THUNK_ASM);}

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
    unsigned char *rts_competitor=(unsigned char *)0x541180;
    unsigned char *force_target=(unsigned char *)0x7f8177;
    unsigned char *aim_base=(unsigned char *)0x899ed0;
    unsigned char *script_shoot=(unsigned char *)0x963ca5;
    static const unsigned char script_shoot_native[]={0x80,0x78,0x42,0x00,0x75,0x09};
    unsigned char *character_motion=(unsigned char *)0x9c43d1;
    static const unsigned char character_motion_bytes[]={0xe8,0xaa,0x3f,0x04,0x00};
    unsigned char *primary_perception=(unsigned char *)0x9ddc19;
    static const unsigned char primary_perception_bytes[]={0x8b,0x86,0x64,0x01,0x00,0x00};
    unsigned char *force_geometry=(unsigned char *)0x7f8310;
    static const unsigned char force_geometry_native[]={0xe8,0xab,0xcb,0xd7,0xff};
    unsigned char *spellit_prepare=(unsigned char *)0x7da941,*spellit_first_heading=(unsigned char *)0x7da948;
    unsigned char *spellit_second_heading=(unsigned char *)0x7da967,*spellit_height=(unsigned char *)0x7daa7c,*spellit_position=(unsigned char *)0x7daaeb;
    static const unsigned char spellit_prepare_bytes[]={0x8b,0x46,0x08,0x85,0xc0};
    static const unsigned char spellit_first_heading_bytes[]={0x0f,0xb7,0x40,0x40,0xeb,0x02};
    static const unsigned char spellit_second_heading_bytes[]={0x0f,0xb7,0x46,0x40,0xeb,0x02};
    static const unsigned char spellit_height_bytes[]={0xd9,0x40,0x28,0x89,0x4c,0x24,0x2c};
    static const unsigned char spellit_position_bytes[]={0xe8,0x70,0xa4,0xd9,0xff};
    unsigned char *spellit_node=(unsigned char *)0x7daa69;
    static const unsigned char spellit_node_bytes[]={0x8b,0x44,0x24,0x70,0x8b,0x4c,0x24,0x74};
    static const unsigned char aim_base_native[]={0xd9,0x44,0x24,0x14,0x8b,0x44,0x24,0x0c};
    static const unsigned char force_target_native[]={0x80,0x78,0x42,0x00,0x0f,0x84,0x30,0x02,0x00,0x00};
    static const unsigned char rts_competitor_native[]={0x55,0x8b,0xec,0x83,0xe4,0xf0};
    unsigned char *aim_input=(unsigned char *)0x899f37,*aim_visibility=(unsigned char *)0x89a093;
    static const unsigned char aim_input_native[]={0x8b,0x4f,0x10,0x85,0xc9};
    static const unsigned char aim_visibility_native[]={0x80,0x78,0x42,0x00,0x0f,0x84,0xdc,0x00,0x00,0x00};
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
        memcmp(rts_competitor,rts_competitor_native,sizeof(rts_competitor_native)) ||
        memcmp(force_target,force_target_native,sizeof(force_target_native)) ||
        memcmp(aim_base,aim_base_native,sizeof(aim_base_native)) ||
        memcmp(script_shoot,script_shoot_native,sizeof(script_shoot_native)) ||
        memcmp(force_geometry,force_geometry_native,sizeof(force_geometry_native)) ||
        memcmp(character_motion,character_motion_bytes,sizeof(character_motion_bytes)) ||
        memcmp(primary_perception,primary_perception_bytes,sizeof(primary_perception_bytes)) ||
        memcmp(spellit_prepare,spellit_prepare_bytes,sizeof(spellit_prepare_bytes)) ||
        memcmp(spellit_first_heading,spellit_first_heading_bytes,sizeof(spellit_first_heading_bytes)) ||
        memcmp(spellit_second_heading,spellit_second_heading_bytes,sizeof(spellit_second_heading_bytes)) ||
        memcmp(spellit_height,spellit_height_bytes,sizeof(spellit_height_bytes)) ||
        memcmp(spellit_position,spellit_position_bytes,sizeof(spellit_position_bytes)) ||
        memcmp(spellit_node,spellit_node_bytes,sizeof(spellit_node_bytes)) ||
        memcmp(aim_input,aim_input_native,sizeof(aim_input_native)) || memcmp(aim_visibility,aim_visibility_native,sizeof(aim_visibility_native)) ||
        !install_jump(period,sizeof(period_native),cadence_period_thunk) ||
        !install_jump(fire_task,sizeof(fire_task_native),fire_task_gate_thunk) ||
        !install_jump(attack_support,sizeof(attack_support_native),attack_support_thunk) ||
        !install_jump(breakup_visibility,sizeof(breakup_visibility_native),breakup_visibility_thunk) ||
        !install_jump(death_breakup,sizeof(death_breakup_native),death_breakup_thunk) ||
        !install_jump(fall_visibility,sizeof(fall_visibility_native),fall_visibility_thunk) ||
        !install_jump(aim_input,sizeof(aim_input_native),aim_task_input_thunk) ||
        !install_jump(aim_visibility,sizeof(aim_visibility_native),aim_task_visibility_thunk) ||
        !install_jump(rts_competitor,sizeof(rts_competitor_native),rts_competitor_input_thunk) ||
        !install_jump(force_target,sizeof(force_target_native),force_target_visibility_thunk) ||
        !install_jump(primary_perception,sizeof(primary_perception_bytes),primary_perception_thunk) ||
        !install_jump(aim_base,sizeof(aim_base_native),aim_base_input_thunk) ||
        !native_script_shoot_dispatch_install() ||
        !install_jump(script_shoot,sizeof(script_shoot_native),script_shoot_visibility_thunk) ||
        !install_jump(spellit_prepare,sizeof(spellit_prepare_bytes),spellit_prepare_thunk) ||
        !install_jump(spellit_first_heading,sizeof(spellit_first_heading_bytes),spellit_first_heading_thunk) ||
        !install_jump(spellit_second_heading,sizeof(spellit_second_heading_bytes),spellit_second_heading_thunk) ||
        !install_jump(spellit_height,sizeof(spellit_height_bytes),spellit_height_thunk) ||
        !install_jump(spellit_node,sizeof(spellit_node_bytes),spellit_node_thunk)) {
        clonewars_cadence_installed=-1;
        return 0;
    }
    DWORD protection;
    if (!VirtualProtect(force_geometry,5,PAGE_EXECUTE_READWRITE,&protection)) {clonewars_cadence_installed=-1;return 0;}
    *(int32_t *)(force_geometry+1)=(int32_t)((uintptr_t)force_geometry_input_thunk-(uintptr_t)force_geometry-5);
    FlushInstructionCache(GetCurrentProcess(),force_geometry,5);
    VirtualProtect(force_geometry,5,protection,&protection);
    if (!VirtualProtect(spellit_position,5,PAGE_EXECUTE_READWRITE,&protection)) {clonewars_cadence_installed=-1;return 0;}
    *(int32_t *)(spellit_position+1)=(int32_t)((uintptr_t)spellit_position_thunk-(uintptr_t)spellit_position-5);
    FlushInstructionCache(GetCurrentProcess(),spellit_position,5);
    VirtualProtect(spellit_position,5,protection,&protection);
    if (!VirtualProtect(character_motion,5,PAGE_EXECUTE_READWRITE,&protection)) {clonewars_cadence_installed=-1;return 0;}
    *(int32_t *)(character_motion+1)=(int32_t)((uintptr_t)character_motion_thunk-(uintptr_t)character_motion-5);
    FlushInstructionCache(GetCurrentProcess(),character_motion,5);
    VirtualProtect(character_motion,5,protection,&protection);
    clonewars_cadence_installed=1;
    return 1;
}
int cadence_ready(void) { return clonewars_cadence_installed==1; }
void cadence_cancel(void) { if(binding.bound||!binding.lease.cohort.thread||binding.lease.cohort.thread!=GetCurrentThreadId())return;active=0;cancelled=1;spellit_scope_count=0;memset(&journal,0,sizeof(journal)); }
int cadence_begin(SyncFrame *frame,int host) {
    if(!module_binding_begin(&binding,frame))return 0;
    CadenceFrameLease op=binding.lease;if(!module_binding_live(&binding,&op))return 0;
    cancelled=0;
    if (last_epoch!=op.cohort.epoch) {
        memset((void *)clonewars_cadence_failure,0,sizeof(clonewars_cadence_failure));
        memset((void *)clonewars_breakup_visibility_correction,0,sizeof(clonewars_breakup_visibility_correction));
        memset((void *)clonewars_death_breakup_correction,0,sizeof(clonewars_death_breakup_correction));
        memset((void *)clonewars_fall_visibility_correction,0,sizeof(clonewars_fall_visibility_correction));
        memset((void *)clonewars_aim_task_correction,0,sizeof(clonewars_aim_task_correction));
        memset((void *)clonewars_rts_competitor_correction,0,sizeof(clonewars_rts_competitor_correction));
        memset((void *)clonewars_force_target_correction,0,sizeof(clonewars_force_target_correction));
        memset((void *)clonewars_force_geometry_correction,0,sizeof(clonewars_force_geometry_correction));
        memset((void *)clonewars_spellit_query_correction,0,sizeof(clonewars_spellit_query_correction));
        memset((void *)clonewars_character_motion_correction,0,sizeof(clonewars_character_motion_correction));
        memset((void *)clonewars_spellit_node_correction,0,sizeof(clonewars_spellit_node_correction));
        memset((void *)clonewars_spellit_node_failure,0,sizeof(clonewars_spellit_node_failure));
        memset((void *)clonewars_aim_base_correction,0,sizeof(clonewars_aim_base_correction));
        memset((void *)clonewars_script_shoot_correction,0,sizeof(clonewars_script_shoot_correction));
        memset((void *)clonewars_script_shoot_failure,0,sizeof(clonewars_script_shoot_failure));
        memset((void *)clonewars_actor_gate_failure,0,sizeof(clonewars_actor_gate_failure));
        last_epoch=op.cohort.epoch;
    }
    cadence_journal_begin(&journal,frame,host);
    fire_task_cursor=0;
    aim_task_scope=(AimTaskScope){0};
    spellit_scope_count=0;
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
