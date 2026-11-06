#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include "../engine/game_state.h"
#include "../engine/loading.h"
#include "../net/lan.h"
#include "../render/overlay.h"
#include "../render/network_window.h"
#include "game_sync.h"
#include "coherent_core_draft.h"
#include "../engine/core_main_boundary.h"
#include "../engine/user_mapping_install.h"
#include "../engine/user_mapping_session.h"
#include "../engine/constructor_lexical_seh.h"
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
#include "../debug/constructor_observer.h"
#endif
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
#include "../debug/constructor_query_observer.h"
#endif
#ifdef CLONEWARS_BASE_AIM_OBSERVER
#include "../debug/base_aim_observer.h"
#endif
#ifdef CLONEWARS_POSE_OBSERVER
#include "../debug/pose_observer.h"
#define POSE_BOUNDARY(stage) pose_observer_capture(&working,(stage),callback_release_token)
#else
#define POSE_BOUNDARY(stage) ((void)0)
#endif
#include "world_vars.h"
#include "spawn_timer_sync.h"
#include "projectile_sync.h"
#include "entity_sync.h"
#include "epoch_state.h"
#include "input_buffer.h"
#include "tag_sync.h"
#include "../debug/spawn_observer.h"
#include "../debug/combat_observer.h"
#include "global_step.h"
#include "../debug/shooter_observer.h"
#include "npc_input.h"
#include "cadence_sync.h"
#include "../debug/collision_observer.h"
#include "geometry_sync.h"
#include "reaction_sync.h"
#include "../debug/remote_input_trace.h"
#include "../debug/decision_observer.h"
#include "../debug/world_contact_observer.h"
#include "../debug/pool_birth_observer.h"
#include "model_input_sync.h"
#ifdef CLONEWARS_INTENT_OBSERVER
#include "../debug/intent_frame_observer.h"
#endif

typedef void (__attribute__((thiscall)) *Tick)(void *);
typedef void (__attribute__((stdcall)) *World)(void *,void *);
static SyncFrame working;
static unsigned sequence,expected;
static SyncEpochCursor interval={.level=-1};
static int session_active,interval_started;
static uint32_t observed_lan_session;
static int core_main_lifecycle_allowed(void);
static int running, fault;
static volatile LONG lifecycle_release_serial;
static uint32_t release_token(void){return (uint32_t)InterlockedCompareExchange(&lifecycle_release_serial,0,0);}
static int release_changed(uint32_t token){return release_token()!=token;}
static unsigned outer_depth;
static int core_live(void);
static int core_capture_dispatch(CoherentFrameToken*);
static int core_dispatch_authority(void);
static void core_note_initialized_level(int);
static DWORD core_tick_thread;
static DWORD core_window_thread;
static volatile LONG deferred_assignment_restore,core_reject_bits;
static GlobalStepState global_step;
static NpcInputJournal npc_inputs;
__declspec(dllexport) volatile uint32_t clonewars_npc_input_debug[16];
__declspec(dllexport) volatile uint32_t clonewars_npc_input_failure[14];
static int hooked;
static int enabled;
static int neutral_background_input;
static int initialized_level=-1;
__declspec(dllexport) volatile uint32_t clonewars_sync_debug[20];
__declspec(dllexport) volatile LONG clonewars_input_override[4];
__declspec(dllexport) volatile uint32_t clonewars_actor_debug[8];
__declspec(dllexport) volatile LONG clonewars_input_prep_installed;
__declspec(dllexport) volatile uint32_t clonewars_input_prep_failure[8];
__declspec(dllexport) volatile uint32_t clonewars_epoch_debug[8];
__declspec(dllexport) volatile LONG clonewars_wait_input_sampling;
static SyncInput latched_input[2];
static uint32_t pending_actor_pressed[2];
static int latched_ready;
static __thread unsigned prep_gate_depth;
static unsigned char remote_device[2][0x200];
static char *changed_controller[2];
static void *saved_device[2];
static char *changed_actor[2];
static uint32_t saved_human[2],changed_generation[2];



static SyncInput local_input;
static uint32_t previous_local_held;
static InputBuffer local_buffer;
static RemoteInputPulse remote_pulse;
static int sampled_for_flow;

static int valid(const void *p,SIZE_T size) {
    MEMORY_BASIC_INFORMATION m;
    return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT &&
           !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
           (uintptr_t)p+size <= (uintptr_t)m.BaseAddress+m.RegionSize;
}
static char *player(int slot) {
    char *p=((char **)0xfb4940)[slot];
    return valid(p,0x1440) ? p : NULL;
}
#ifdef CLONEWARS_POSE_OBSERVER
int game_sync_pose_valid(uint32_t token){return !release_changed(token)&&!model_input_cancelled();}
void *game_sync_pose_player(unsigned role){return role<2?player((int)role):NULL;}
#endif
#ifdef CLONEWARS_ACTION_TRANSITION_OBSERVER
#include "../debug/action_transition_observer.h"
static const SyncFrame *action_dispatch_frame;
static ActionLease action_dispatch_lease;
static uint32_t action_dispatch_nonce;
static int action_dispatch_active;
static CoherentFrameToken action_cohort;
static DWORD action_main_thread;
static void action_dispatch_open(uint32_t release) {
    CoherentFrameToken original;
    if(GetCurrentThreadId()!=action_main_thread||!core_capture_dispatch(&original))return;
    action_dispatch_active=0;
    if(release_changed(release)||model_input_cancelled()||!running||!working.epoch||!working.sequence)return;
    if(!++action_dispatch_nonce)++action_dispatch_nonce;
    action_dispatch_frame=&working;
    action_dispatch_lease=(ActionLease){action_dispatch_nonce,release,GetCurrentThreadId(),working.epoch,working.sequence,(uint32_t)(uintptr_t)&working};
    action_cohort=original;
    action_dispatch_active=1;
}
static void action_dispatch_close(void){action_dispatch_active=0;action_dispatch_frame=NULL;}
uint32_t game_sync_action_lifecycle(void){return release_token();}
int game_sync_action_lease_valid(const ActionLease *lease) {
    if(!coherent_frame_valid(&action_cohort,COHERENT_PHASE_BIT(COHERENT_DISPATCH))||!running||!action_dispatch_active||!lease||lease->nonce!=action_dispatch_lease.nonce||
       lease->release!=action_dispatch_lease.release||lease->thread!=action_main_thread||lease->thread!=GetCurrentThreadId()||
       release_changed(lease->release)||model_input_cancelled()||lease->frame_local!=(uint32_t)(uintptr_t)&working||action_dispatch_frame!=&working)return 0;
    if(lease->epoch!=action_dispatch_lease.epoch||lease->sequence!=action_dispatch_lease.sequence)return 0;
    uint32_t epoch=action_dispatch_frame->epoch,sequence=action_dispatch_frame->sequence;
    return action_dispatch_active&&!release_changed(lease->release)&&!model_input_cancelled()&&
        lease->nonce==action_dispatch_lease.nonce&&action_dispatch_frame==&working&&epoch==lease->epoch&&sequence==lease->sequence;
}
int game_sync_action_lease_get(ActionLease *out) {
    if(!out||!action_dispatch_active||action_dispatch_lease.thread!=GetCurrentThreadId())return 0;
    ActionLease lease=action_dispatch_lease;
    if(!game_sync_action_lease_valid(&lease))return 0;
    *out=lease;return game_sync_action_lease_valid(out);
}
#else
#define action_dispatch_open(release) ((void)0)
#define action_dispatch_close() ((void)0)
#endif
static char *controller(int slot) {
    char *p=player(slot);
    char *c=p ? *(char **)(p+0x6cc) : NULL;
    return valid(c,0x60) ? c : NULL;
}
static uint64_t assignment_lease_serial;
static uint64_t assignment_lease_version(void){return assignment_lease_serial;}
static void assignment_lease_remap(uint64_t version) {
    if (version!=assignment_lease_serial) return;
    int changed=0;
    for (int slot=0;slot<2;++slot) {
        void *owner=NULL;uint32_t allocation=0;
        if (changed_actor[slot] && tags_resolve_controller_owner(changed_actor[slot],changed_generation[slot],changed_controller[slot],&owner,&allocation) &&
            (owner!=changed_actor[slot] || allocation!=changed_generation[slot])) {
            changed_actor[slot]=owner;changed_generation[slot]=allocation;changed=1;
        }
    }
    if (changed) ++assignment_lease_serial;
}
static void release_assignment(int slot) {
    char *c=changed_controller[slot],*actor=changed_actor[slot];
    uint32_t allocation=changed_generation[slot];
    void *owner=NULL;uint32_t owner_allocation=0;
    if (actor && tags_resolve_controller_owner(actor,allocation,c,&owner,&owner_allocation)) {
        actor=owner;allocation=owner_allocation;
    }
    int owns=entities_allocation_live(actor,allocation) && *(char **)(actor+0x6cc)==c;
    if (owns && valid(c,4) && *(void **)c==remote_device[slot]) *(void **)c=saved_device[slot];
    if (owns) {
        if (actor==player(slot)) *(uint32_t *)(actor+0x50)=(*(uint32_t *)(actor+0x50)&~0x200u)|saved_human[slot];

    }
    changed_controller[slot]=changed_actor[slot]=NULL;
    changed_generation[slot]=0;++assignment_lease_serial;
}
static void release_remote(void) {
    assignment_lease_remap(assignment_lease_version());
    memset(remote_device,0,sizeof remote_device);
    InterlockedIncrement(&lifecycle_release_serial);
    coherent_frame_cancel_atomic(1u);
    InterlockedExchange(&deferred_assignment_restore,1);
    action_dispatch_close();running=0;
    latched_ready=0;remote_input_pulse_reset(&remote_pulse);remote_input_trace_reset();prep_gate_depth=0;
    memset(pending_actor_pressed,0,sizeof pending_actor_pressed);

}

static void prepare_epoch(uint32_t epoch,int level) {
    release_remote();projectiles_reset();tags_reset();entities_reset_bindings();
    running=fault=0; sequence=expected=0;
    memset((void *)clonewars_npc_input_failure,0,sizeof(clonewars_npc_input_failure));
    memset((void *)clonewars_input_prep_failure,0,sizeof(clonewars_input_prep_failure)); interval_started=0;
    previous_local_held=0;
    input_buffer_reset(&local_buffer); sampled_for_flow=0;
    interval=(SyncEpochCursor){.epoch=epoch,.level=level,.active=1};
    lan_publish_transition(epoch,level);
}
static void suspend_epoch_publication(void) {
    uint32_t previous=interval.epoch;
    prepare_epoch(0,-1);interval.epoch=previous;interval.active=0;
}
int game_sync_poll_epoch(int target,int transitioning) {
    if(!core_main_lifecycle_allowed())return 0;
    uint32_t actual_session=lan_session_serial();
    if(actual_session!=observed_lan_session){
        release_remote();projectiles_reset();tags_reset();entities_reset_bindings();
        observed_lan_session=actual_session;session_active=0;interval.active=0;interval_started=0;sequence=expected=0;
    }
    if (lan_status()!=LAN_CONNECTED) {
        session_active=0; interval.active=0; interval_started=0;
        return 0;
    }
    if (!session_active) {
        session_active=1;
        if (!lan_is_host()) interval=(SyncEpochCursor){.level=-1};
    }
    if (lan_is_host()) {
        if (target<0 || target>=290) {
            if(interval.active||lan_epoch()){suspend_epoch_publication();return 1;}
            return 0;
        }
        if (!interval.active || interval.level!=target || (interval_started && transitioning)) {
            if(interval.epoch==UINT32_MAX){InterlockedOr(&core_reject_bits,0x10000000);coherent_frame_cancel_atomic(0x10000000);return 0;}
            uint32_t epoch=interval.epoch+1;
            prepare_epoch(epoch,target);
            return 1;
        }
    } else {
        LanTransition remote=lan_remote_transition();
        uint32_t epoch=remote.epoch;int level=remote.level;
        if(!epoch){if(interval.active){suspend_epoch_publication();return 1;}return 0;}
        if (epoch && epoch>interval.epoch && level>=0 && level<290) {
            prepare_epoch(epoch,level);
            return 1;
        }
    }
    return 0;
}
uint32_t game_sync_epoch(void) { return interval.active ? interval.epoch : 0; }
int game_sync_epoch_level(void) { return interval.level; }
static SyncInput read_input(void) {
    SyncInput input={0,0,128,128,128,128};
    if (network_window_input_blocked()) { previous_local_held=0;return input; }
    char *input_service=*(char **)0xfb0b70;
    if ((*(unsigned char *)0xf91eb4&2) ||
        (valid(input_service,0x2c) && *(int *)(input_service+0x28))) {
        previous_local_held=0;
        return input;
    }
    char *c=controller(0);
    if (!c) return input;
    if (InterlockedCompareExchange(&clonewars_input_override[3],0,0)>0) {
        input.held=(uint32_t)clonewars_input_override[0];
        input.pressed=(uint32_t)InterlockedExchange(&clonewars_input_override[1],0) | (input.held&~previous_local_held);
        uint32_t axes=(uint32_t)clonewars_input_override[2];
        input.analog_x=(uint8_t)axes; input.analog_y=(uint8_t)(axes>>8);
        if (input.analog_x<43) input.held|=*(uint32_t *)0xe64124;
        if (input.analog_x>212) input.held|=*(uint32_t *)0xe64128;
        if (input.analog_y<43) input.held|=*(uint32_t *)0xe6411c;
        if (input.analog_y>212) input.held|=*(uint32_t *)0xe64120;
        input.pressed|=input.held&~previous_local_held;
        previous_local_held=input.held;
        InterlockedDecrement(&clonewars_input_override[3]);
        return input;
    }
    if (neutral_background_input) { previous_local_held=0;return input; }
    input.held=*(uint32_t *)(c+4); input.pressed=*(uint32_t *)(c+8);
    unsigned char *device=*(unsigned char **)c;
    char *root=*(char **)0xfb2e60;
    if (valid(root,0x1850)) {
        unsigned char *physical=*(unsigned char **)(root+0x184c);
        if (valid(physical,0xb0)) {
            device=physical;
            input.held=*(uint32_t *)(physical+0x70);
            input.pressed=*(uint32_t *)(physical+0x78);
            if (physical[0x9d]<43) input.held|=*(uint32_t *)0xe64124;
            if (physical[0x9d]>212) input.held|=*(uint32_t *)0xe64128;
            if (physical[0x9e]<43) input.held|=*(uint32_t *)0xe6411c;
            if (physical[0x9e]>212) input.held|=*(uint32_t *)0xe64120;
            input.pressed|=input.held&~previous_local_held;
            previous_local_held=input.held;
        }
    }
    if (valid(device,0x9f)) { input.analog_x=device[0x9d]; input.analog_y=device[0x9e]; input.aim_x=device[0x9b]; input.aim_y=device[0x9c]; }
    return input;
}
static int core_input_same(int slot,char*p,char*c,uint32_t allocation,uint32_t release,uint64_t assignment){
    return core_live()&&!release_changed(release)&&assignment==assignment_lease_serial&&
        player(slot)==p&&controller(slot)==c&&entities_allocation_live(p,allocation);
}
static int write_input(int slot, const SyncInput *input) {
    if(!core_live())return 0;
    char *c=controller(slot), *p=player(slot);
    if (!c || !p) return 0;
    uint32_t allocation=entities_local_generation(p);
    if (!allocation) return 0;
    unsigned char *joined=(unsigned char *)(0xfb484d+slot*0x20);
    *joined=1;
    if(slot==1 && *(int*)0xeb1a78<0)return 0;
    if (changed_controller[slot]!=c || changed_actor[slot]!=p || changed_generation[slot]!=allocation) {
        int native_source_known=entities_allocation_live(changed_actor[slot],changed_generation[slot]) && valid(changed_controller[slot],4);
        void *native_device=saved_device[slot];
        release_assignment(slot);
        unsigned char *source=*(unsigned char **)c;
        if (source==remote_device[0] || source==remote_device[1]) {
            if (source!=remote_device[slot] || !native_source_known) return 0;
            source=native_device;
        }
        memset(remote_device[slot],0,sizeof(remote_device[slot]));
        if (valid(source,0xb0)) memcpy(remote_device[slot],source,0xb0);
        saved_device[slot]=source; changed_controller[slot]=c;
        changed_actor[slot]=p; changed_generation[slot]=allocation; saved_human[slot]=*(uint32_t *)(p+0x50)&0x200;++assignment_lease_serial;
    }
    *(void **)c=remote_device[slot];
    *(uint32_t *)(p+0x50)|=0x200;
    uint32_t held=input->held|input->pressed;
    *(uint32_t *)(c+4)=held; *(uint32_t *)(c+8)=input->pressed;
    unsigned char *device=*(unsigned char **)c;
    *(uint32_t *)(device+0x70)=held;
    *(uint32_t *)(device+0x78)=input->pressed;
    *(uint32_t *)(device+0x88)|=4;
    device[0x9b]=input->aim_x; device[0x9c]=input->aim_y;
    device[0x9d]=input->analog_x; device[0x9e]=input->analog_y;
    return 1;
}
static void sample_wait_input(void) {
    sampled_for_flow=0;
    if (!clonewars_wait_input_sampling || InterlockedCompareExchange(&clonewars_input_override[3],0,0)>0) {
        input_buffer_reset(&local_buffer);
        return;
    }
    SyncInput input=read_input();
    input_buffer_sample(&local_buffer,&input);
    sampled_for_flow=1;
    if (!lan_is_host()) {
        local_input=input_buffer_take(&local_buffer);
        lan_publish_input(&local_input);
    }
}
static int device_refresh(void *device) {
    if (device==remote_device[0] || device==remote_device[1]) return 1;
    return ((int (*)(void *))0x57b340)(device);
}
typedef struct PrepGate { void *actor;uint32_t generation;int blocked;CoherentFrameToken cohort; } PrepGate;
static __thread PrepGate prep_gates[64];
typedef struct PrepLexical {void*actor;int alternate,blocked,bound;CoherentFrameToken token;unsigned char fx[512] __attribute__((aligned(16)));DWORD error;} PrepLexical;
static void prep_capture(PrepLexical*c){__asm__ volatile("fxsave %0":"=m"(c->fx)::"memory");c->error=GetLastError();}
static void prep_restore(const PrepLexical*c){SetLastError(c->error);__asm__ volatile("fxrstor %0"::"m"(c->fx):"memory");}

static void __cdecl prep_lexical_abort(void*raw){
 PrepLexical*c=raw;if(!c->bound)return;
 if(coherent_frame_close(&c->token)){coherent_frame_cancel_atomic(0x10000000);InterlockedExchange(&deferred_assignment_restore,1);}
 while(prep_gate_depth){PrepGate*g=&prep_gates[prep_gate_depth-1];if(g->cohort.cohort_nonce!=c->token.cohort_nonce||g->cohort.owner!=c->token.owner||g->cohort.release!=c->token.release)break;--prep_gate_depth;}
}
static void prep_fail(unsigned reason,void *expected_actor,void *actual_actor) {
    if (!clonewars_input_prep_failure[2]) {
        uint32_t values[]={working.epoch,working.sequence,reason,prep_gate_depth,(uint32_t)(uintptr_t)expected_actor,(uint32_t)(uintptr_t)actual_actor,
            expected_actor ? entities_observed_generation(expected_actor) : 0,actual_actor ? entities_observed_generation(actual_actor) : 0};
        memcpy((void *)clonewars_input_prep_failure,values,sizeof(values));
    }
    if (!fault) fault=16;
}
static void actor_ai_normal_impl(void *actor,int cached_player_gate,PrepLexical*context) {
    CoherentFrameToken original;int authority=core_capture_dispatch(&original);
    if(running&&!authority){coherent_frame_cancel_atomic(0x10000000);prep_restore(context);((void(*)(void*))0x8b0f90)(actor);prep_capture(context);return;}
    if (authority) {
        if (prep_gate_depth==64 || !valid(actor,0x1440)) prep_fail(1,NULL,actor);
        else {
            uint32_t flags=*(uint32_t *)((char *)actor+0x50);
            int blocked=((flags&0x200) && !(flags&0x800) && (cached_player_gate!=-1 || *(int *)0xfbdd2c==2)) || (*(uint32_t *)((char *)actor+0x8e0)&0x200);
            prep_gates[prep_gate_depth++]=(PrepGate){actor,entities_observed_generation(actor),blocked,original};
        }
    }
    prep_restore(context);
    decision_observer_invoke_actor(2,actor,(void (*)(void *))0x8b0f90,0x9c53f7);
    prep_capture(context);
}
static void*__cdecl actor_ai_invoke(void*raw){PrepLexical*c=raw;actor_ai_normal_impl(c->actor,c->blocked,c);return NULL;}
static void actor_ai_normal(void*actor,int cached_player_gate){PrepLexical c;prep_capture(&c);c.actor=actor;c.alternate=0;c.blocked=cached_player_gate;c.bound=core_capture_dispatch(&c.token);constructor_lexical_seh(&c,actor_ai_invoke,prep_lexical_abort);prep_restore(&c);}
static void __attribute__((naked)) actor_ai_normal_hook(void *actor) {
    __asm__ volatile("movl 0xc0(%%esp),%%eax\n\tpushl %%eax\n\tpushl 8(%%esp)\n\tcall %P0\n\taddl $8,%%esp\n\tret"::"i"(actor_ai_normal):"memory");
}
static void actor_prepare_common_impl(void *actor,int alternate,int native_blocked,PrepLexical*context) {
    CoherentFrameToken actor_cohort;
    int journal_dispatch=core_dispatch_authority();
    if(running&&!journal_dispatch){coherent_frame_cancel_atomic(0x10000000);prep_restore(context);((void(*)(void*))0x9ab020)(actor);prep_capture(context);return;}
    if(journal_dispatch&&!core_capture_dispatch(&actor_cohort))return;
    ++clonewars_actor_debug[0];
    if (running) ++clonewars_actor_debug[1]; else ++clonewars_actor_debug[2];
    char *restore_controller=NULL;uint32_t restore_generation=0;int restore_hero=-1;
    NpcInputScope restore_scope={0};
    if (running && latched_ready) for (int slot=0;slot<2;++slot) if (actor==player(slot)) {
        SyncInput input=latched_input[slot];
        input.pressed=pending_actor_pressed[slot];
        pending_actor_pressed[slot]=0;
        int blocked=!alternate && native_blocked;
        if (blocked) { ++clonewars_actor_debug[7];input.held=input.pressed=0; }
        else {
            if (alternate) {
                restore_controller=*(char **)((char *)actor+0x6cc);
                if (!valid(restore_controller,12)) { if (!fault) fault=2;return; }
                if(!npc_input_scope_capture(&npc_inputs,(uint32_t*)(restore_controller+4),(uint32_t*)(restore_controller+8),&restore_scope))return;
                restore_generation=entities_observed_generation(actor);restore_hero=slot;
            }
            if (!write_input(slot,&input)) { if (!fault) fault=2;return; }
        }
        if (slot==1) {
            ++clonewars_actor_debug[3];
            if (input.pressed) ++clonewars_actor_debug[4];
            clonewars_actor_debug[5]=input.held;
            clonewars_actor_debug[6]=input.pressed;
        }
    }
    char *npc_controller=NULL;
    NpcInputScope npc_scope={0};
    uint32_t npc_generation=0;
    if (journal_dispatch && npc_input_eligible(actor,player(0),player(1))) {
        if (npc_inputs.failed) return;
        npc_controller=*(char **)((char *)actor+0x6cc);
        if (!valid(npc_controller,12)) { ++clonewars_npc_input_debug[14];if (!fault) fault=13;return; }
        uint32_t *held=(uint32_t *)(npc_controller+4),*pressed=(uint32_t *)(npc_controller+8);
        if (lan_is_host()) {
            entities_update();if(!core_live()||!npc_input_cohort_valid(&npc_inputs,&actor_cohort,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return;SyncActor identity={0};entities_describe(&identity,actor);
            if(!npc_input_cohort_valid(&npc_inputs,&actor_cohort,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return;
            SyncActorInput entry={.slot=(uint32_t)entities_slot(actor),.generation=identity.generation,.spawn_tag=identity.spawn_tag,
                .character=*(int16_t *)((char *)actor+0xdc0),.held=*held,.pressed=*pressed};
            memcpy(entry.origin,identity.spawn_position,12);
            if (!npc_input_record(&npc_inputs,&entry)) { if (!fault) fault=13;return; }
            ++clonewars_npc_input_debug[0];
        } else {
            const SyncActorInput *entry=npc_input_peek(&npc_inputs);
            SyncActor identity={0};
            if (entry) { identity.slot=entry->slot;identity.generation=entry->generation;identity.spawn_tag=entry->spawn_tag;identity.character=entry->character;memcpy(identity.spawn_position,entry->origin,12); }
            clonewars_npc_input_debug[3]=entry ? entry->slot : UINT32_MAX;clonewars_npc_input_debug[4]=entry ? entry->generation : 0;
            clonewars_npc_input_debug[7]=*held;clonewars_npc_input_debug[8]=*pressed;
            int owner_matches=entry && entities_resolve_reference(&identity)==actor;
            if(!npc_input_cohort_valid(&npc_inputs,&actor_cohort,COHERENT_PHASE_BIT(COHERENT_DISPATCH))||!core_live())return;
            if (!npc_input_apply(&npc_inputs,entry,owner_matches,held,pressed,&npc_scope)) {
                if (!clonewars_npc_input_failure[0]) {
                    uint32_t actual_slot=UINT32_MAX,actual_generation=0;entities_observed_identity(actor,&actual_slot,&actual_generation);
                    uint32_t values[]={working.epoch,working.sequence,npc_inputs.cursor,entry ? entry->slot : UINT32_MAX,entry ? entry->generation : 0,
                        actual_slot,actual_generation,entities_observed_generation(actor),entry ? entry->held : 0,entry ? entry->pressed : 0,*held,*pressed,0,0};
                    memcpy((void *)clonewars_npc_input_failure,values,sizeof(values));
                }
                ++clonewars_npc_input_debug[2];if (!fault) fault=13;return;
            }
            clonewars_npc_input_debug[5]=entry->held;clonewars_npc_input_debug[6]=entry->pressed;
            clonewars_npc_input_debug[9]+=npc_scope.held!=entry->held || npc_scope.pressed!=entry->pressed;
            clonewars_npc_input_debug[10]=working.sequence;clonewars_npc_input_debug[11]=npc_inputs.cursor;
            ++clonewars_npc_input_debug[1];
        }
    }
    if(journal_dispatch&&(!core_live()||!npc_input_cohort_valid(&npc_inputs,&actor_cohort,COHERENT_PHASE_BIT(COHERENT_DISPATCH))))return;
    if (npc_scope.applied) npc_generation=entities_observed_generation(actor);
    int remote_sample=remote_input_trace_before(actor,running && actor==player(1));
    prep_restore(context);
    decision_observer_invoke_actor(3,actor,(void (*)(void *))0x9ab020,alternate?0x9c33bf:0x9c53fd);
    prep_capture(context);
    remote_input_trace_after(actor,remote_sample);
    if(journal_dispatch&&(!core_live()||!npc_input_cohort_valid(&npc_inputs,&actor_cohort,COHERENT_PHASE_BIT(COHERENT_DISPATCH))))return;
    if (!alternate) return;
    if (npc_scope.applied) { restore_scope=npc_scope;restore_controller=npc_controller;restore_generation=npc_generation; }
    if (restore_scope.applied && npc_input_scope_valid(&restore_scope) && entities_allocation_live(actor,restore_generation) && valid(actor,0x1440) && valid(restore_controller,12) &&
        (restore_hero>=0 ? actor==player(restore_hero) : npc_input_eligible(actor,player(0),player(1))) &&
        npc_input_owner_live(*(uint32_t *)((char *)actor+0x50),entities_observed_generation(actor),restore_generation,*(char **)((char *)actor+0x6cc),restore_controller))
        npc_input_restore(&restore_scope,(uint32_t *)(restore_controller+4),(uint32_t *)(restore_controller+8));
}
static void*__cdecl actor_prepare_invoke(void*raw){PrepLexical*c=raw;actor_prepare_common_impl(c->actor,c->alternate,c->blocked,c);return NULL;}
static void actor_prepare_common(void*actor,int alternate,int blocked){PrepLexical c;prep_capture(&c);c.actor=actor;c.alternate=alternate;c.blocked=blocked;c.bound=core_capture_dispatch(&c.token);constructor_lexical_seh(&c,actor_prepare_invoke,prep_lexical_abort);prep_restore(&c);}
static void actor_prepare_normal(void *actor) {
    if(running&&!core_dispatch_authority()){actor_prepare_common(actor,0,0);return;}
    int blocked=0;
    if (prep_gate_depth) {
        PrepGate gate=prep_gates[--prep_gate_depth];
        if(!npc_input_cohort_valid(&npc_inputs,&gate.cohort,COHERENT_PHASE_BIT(COHERENT_DISPATCH))){coherent_frame_cancel_atomic(0x10000000);return;}
        if (gate.actor!=actor || !entities_allocation_live(actor,gate.generation)) { prep_fail(2,gate.actor,actor);return; }
        blocked=gate.blocked;
    } else if (core_dispatch_authority()) { prep_fail(3,NULL,actor);return; }
    actor_prepare_common(actor,0,blocked);
}
static void actor_prepare_alternate(void *actor) { actor_prepare_common(actor,1,0); }
static int collect_actors(SyncFrame *frame) {
    entities_update();
    char *base=*(char **)0xfb2f60;
    int count=game_actor_count(); frame->actor_count=0;
    if (!valid(base,(SIZE_T)count*0x1440)) return 0;
    for (int slot=0;slot<count;++slot) {
        char *p=base+slot*0x1440;
        uint32_t flags=*(uint32_t *)(p+0x50);
        if ((flags&3)!=3) continue;
        if (frame->actor_count==SYNC_MAX_ACTORS) return 0;
        SyncActor *a=&frame->actors[frame->actor_count++];
        entities_describe(a,p);
        a->slot=slot; a->character=*(short *)(p+0xdc0); a->flags=flags;
        memcpy(a->position,p+0x24,12);
        memcpy(a->previous_position,p+0x30,12);
        memcpy(a->render_position,p+0xf28,12);
        memcpy(a->previous_render_position,p+0xf40,12);
        memcpy(a->velocity,p+0xf10,12);
        a->heading=*(uint16_t *)(p+0x6c);
        a->render_heading=*(uint16_t *)(p+0xf0c);
        a->health=*(int8_t *)(p+0xdde); a->max_health=*(uint8_t *)(p+0xddd);
        uint64_t *wallet=*(uint64_t **)(p+0x5b0);
        a->has_wallet=valid(wallet,8); a->wallet=a->has_wallet ? *wallet : 0;
        memcpy(a->animation.frames,p+0xee4,20);
        a->animation.current=*(int16_t *)(p+0x2e8);
        a->animation.flags=*(uint16_t *)(p+0xef8);
        memcpy(a->animation.clips,p+0xefa,10);
        a->animation.reserved=0;
    }
    return entities_collect_dormant_party(frame) && sync_frame_valid(frame,sync_frame_size(frame));
}
static int correct_actors_impl(const SyncFrame *frame,const CoherentFrameToken*original) {
    if(!core_live()||!coherent_frame_valid(original,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;
    if (!entities_bind(frame)) return 0;
    if(!core_live()||!coherent_frame_valid(original,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;
    unsigned count=frame->actor_count;if(count>SYNC_MAX_ACTORS)return 0;
    for (unsigned i=0;i<count;++i) {
        if(!core_live()||!coherent_frame_valid(original,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;
        const SyncActor *a=&frame->actors[i];
        char *p=entities_actor(a->slot,a->generation);
        if (!valid(p,0x1440)) {
            if (a->player<0 && a->health==0 && entities_is_retired(a->slot,a->generation)) continue;
            return 0;
        }
        if ((*(uint32_t *)(p+0x50)&3)!=3 || *(short *)(p+0xdc0)!=a->character) return 0;
    }
    for (unsigned i=0;i<count;++i) {
        if(!core_live()||!coherent_frame_valid(original,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;
        SyncActor saved=frame->actors[i];const SyncActor*a=&saved;char *p=entities_actor(a->slot,a->generation);
        if (!p && a->player<0 && a->health==0 && entities_is_retired(a->slot,a->generation)) continue;
        uint32_t allocation=entities_local_generation(p);
        if(!allocation||!entities_allocation_live(p,allocation))return 0;
        void*controller_before=*(void**)(p+0x6cc);
        memcpy(p+0x24,a->position,12); memcpy(p+0xf28,a->render_position,12);
        memcpy(p+0x30,a->previous_position,12); memcpy(p+0xf40,a->previous_render_position,12);
        memcpy(p+0xf10,a->velocity,12);
        *(uint16_t *)(p+0x6c)=a->heading;
        *(uint16_t *)(p+0xf0c)=a->render_heading;
        *(int8_t *)(p+0xdde)=a->health; *(uint8_t *)(p+0xddd)=a->max_health;
        uint64_t *wallet=*(uint64_t **)(p+0x5b0);
        if (a->has_wallet && valid(wallet,8)) *wallet=a->wallet;
        if (*(int16_t *)(p+0x2e8)!=a->animation.current) {
            char *model=*(char **)(p+8);
            void *body=valid(model,0x40) ? *(void **)(model+0x3c) : NULL;
            ((void (*)(void *,void *,int))0x8a93f0)(body,p+0xee0,a->animation.current);
            if(!core_live()||!coherent_frame_valid(original,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;
            if(!entities_allocation_live(p,allocation)||entities_actor(a->slot,a->generation)!=p||*(void**)(p+0x6cc)!=controller_before)return 0;
        }
        *(int16_t *)(p+0x2e8)=a->animation.current;
        memcpy(p+0xee4,a->animation.frames,20);
        *(uint16_t *)(p+0xef8)=a->animation.flags;
        memcpy(p+0xefa,a->animation.clips,10);
    }
    return 1;
}
typedef struct CorrectLexical {const SyncFrame*frame;CoherentFrameToken token;int bound,result;} CorrectLexical;
static void*__cdecl correct_invoke(void*raw){CorrectLexical*c=raw;c->result=correct_actors_impl(c->frame,&c->token);return NULL;}
static void __cdecl correct_abort(void*raw){CorrectLexical*c=raw;if(c->bound&&coherent_frame_close(&c->token)){coherent_frame_cancel_atomic(0x10000000);InterlockedExchange(&deferred_assignment_restore,1);}}
static int correct_actors(const SyncFrame*frame){CorrectLexical c={.frame=frame};c.bound=core_capture_dispatch(&c.token);if(!c.bound||c.token.frame!=frame)return 0;constructor_lexical_seh(&c,correct_invoke,correct_abort);return c.result;}
typedef struct DispatchLexical {void*first,*second;int bound,kind;CoherentFrameToken token;unsigned char fx[512] __attribute__((aligned(16)));DWORD error;} DispatchLexical;
static void dispatch_capture(DispatchLexical*c){__asm__ volatile("fxsave %0":"=m"(c->fx)::"memory");c->error=GetLastError();}
static void dispatch_restore(const DispatchLexical*c){SetLastError(c->error);__asm__ volatile("fxrstor %0"::"m"(c->fx):"memory");}
static void __cdecl dispatch_abort(void*raw){DispatchLexical*c=raw;if(c->bound&&coherent_frame_close(&c->token)){coherent_frame_cancel_atomic(0x10000000);InterlockedExchange(&deferred_assignment_restore,1);}}
static void world_hook_impl(void *area,void *output,DispatchLexical*context) {
    if (running && core_live()) {
        int first_world=global_step_world(&global_step);
        SyncInput remote_raw={0};
        if (first_world && lan_is_host()) {
            working.inputs[0]=sampled_for_flow ? input_buffer_take(&local_buffer) : read_input();
            remote_raw=lan_consume_input();
            working.inputs[1]=remote_input_execute(&remote_pulse,&remote_raw);
        } else if (first_world && !sampled_for_flow) { local_input=read_input(); lan_publish_input(&local_input); }
        if(!core_live())goto native_world;
        if (first_world) remote_input_trace_begin(&working,lan_is_host(),lan_is_host()?&remote_raw:NULL,player(1));
        for (int slot=0;slot<2;++slot) {
            latched_input[slot]=working.inputs[slot];
            if (first_world) pending_actor_pressed[slot]|=working.inputs[slot].pressed;
        }
        SyncInput step_input[2]={working.inputs[0],working.inputs[1]};
        if (!first_world) step_input[0].pressed=step_input[1].pressed=0;
        latched_ready=1;
        if ((!write_input(0,&step_input[0]) || !write_input(1,&step_input[1])) && core_live()) fault=2;
    }
native_world:
    dispatch_restore(context);
    ((World)0x887ac0)(area,output);
    dispatch_capture(context);
    if(context->bound&&!coherent_frame_valid(&context->token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return;
    char *root=*(char **)0xfb2e60;
    if (valid(root,0x1b7c) && *(int *)(root+0x1b78)==0xe)
        core_note_initialized_level(game_current_level());
}
static void tick_hook_impl(void *flow,DispatchLexical*context) {
    if(GetCurrentThreadId()!=core_window_thread){coherent_frame_cancel_atomic(0x10000000);dispatch_restore(context);((Tick)0x889640)(flow);dispatch_capture(context);return;}
    if(!core_tick_thread){core_tick_thread=GetCurrentThreadId();coherent_frame_register_main();tags_observe_controller_handoffs(assignment_lease_version,assignment_lease_remap);}
    /* This records a real native Tick; no executable installation occurs here. */
#ifdef CLONEWARS_ACTION_TRANSITION_OBSERVER
    if(!action_main_thread)action_main_thread=GetCurrentThreadId();
#endif
    /* Native lifecycle polling is not a Tick side effect in this draft. */
    if (running) ++global_step.ticks;
    spawn_observer_flow(1); combat_observer_flow(1);
    dispatch_restore(context);
    ((Tick)0x889640)(flow);
    dispatch_capture(context);
    combat_observer_flow(0); spawn_observer_flow(0);
}
static void*__cdecl dispatch_invoke(void*raw){DispatchLexical*c=raw;if(c->kind)tick_hook_impl(c->first,c);else world_hook_impl(c->first,c->second,c);return NULL;}
static void __attribute__((stdcall)) world_hook(void*area,void*output){DispatchLexical c;dispatch_capture(&c);c.first=area;c.second=output;c.kind=0;c.bound=core_capture_dispatch(&c.token);constructor_lexical_seh(&c,dispatch_invoke,dispatch_abort);dispatch_restore(&c);}
static void __attribute__((fastcall)) tick_hook(void*flow,void*unused){(void)unused;DispatchLexical c;dispatch_capture(&c);c.first=flow;c.second=NULL;c.kind=1;c.bound=core_capture_dispatch(&c.token);constructor_lexical_seh(&c,dispatch_invoke,dispatch_abort);dispatch_restore(&c);}
#include "coherent_core_body.inc"
int game_sync_install(void){return 0;}

int game_sync_restart_required(void) {
    return InterlockedCompareExchange(&core_reject_bits,0,0)!=0;
}
int game_sync_status(void) {
    if (!enabled) return -8;
    if (!hooked) return -1;
    if (fault) return -fault-1;
    if (lan_status()==LAN_CONNECTED && game_sync_restart_required()) return GAME_SYNC_RESTART_REQUIRED;
    return sequence || expected ? 2 : 0;
}
unsigned game_sync_sequence(void) { return lan_is_host()?sequence:expected; }
void game_sync_inspect(void) {
    clonewars_epoch_debug[0]=interval.epoch;
    clonewars_epoch_debug[1]=(uint32_t)interval.level;
    clonewars_epoch_debug[2]=(uint32_t)interval.active;
    clonewars_epoch_debug[3]=(uint32_t)interval_started;
    clonewars_epoch_debug[4]=lan_epoch();
    clonewars_epoch_debug[5]=lan_remote_epoch();
    clonewars_epoch_debug[6]=game_sync_sequence();
    clonewars_epoch_debug[7]=lan_peer_ack();
    clonewars_sync_debug[0]=(uint32_t)game_sync_status();
    clonewars_sync_debug[1]=(uint32_t)lan_status();
    clonewars_sync_debug[2]=(uint32_t)game_current_level();
    clonewars_sync_debug[3]=(uint32_t)lan_remote_level();
    clonewars_sync_debug[4]=game_sync_sequence();
    clonewars_sync_debug[5]=(uint32_t)game_actor_count();
    clonewars_sync_debug[6]=working.inputs[0].held;
    clonewars_sync_debug[7]=working.inputs[1].held;
    clonewars_sync_debug[8]=(uint32_t)lan_peer_ready();
    clonewars_sync_debug[9]=(uint32_t)game_load_status();
    clonewars_sync_debug[10]=working.actor_count;
    clonewars_sync_debug[11]=(uint32_t)lan_error();
    clonewars_sync_debug[12]=working.variable_count;
    clonewars_sync_debug[13]=(uint32_t)initialized_level;
    char *root=*(char **)0xfb2e60;
    clonewars_sync_debug[14]=valid(root,0x1b7c) ? *(uint32_t *)(root+0x1b78) : UINT32_MAX;
    clonewars_sync_debug[15]=sizeof(SyncFrame);
    clonewars_sync_debug[16]=working.inputs[0].pressed;
    clonewars_sync_debug[17]=working.inputs[1].pressed;
    clonewars_sync_debug[18]=local_input.pressed;
    clonewars_sync_debug[19]=working.shot_count;
}

void game_sync_native_fault(int code) { if (!fault) fault=code; }
