#if defined(CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER) && !defined(CLONEWARS_CONSTRUCTOR_OBSERVER)
#error constructor_query_requires_constructor_observer
#endif
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
#include "constructor_query_observer.h"
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include "projectile_sync.h"
#include "entity_sync.h"
#include "combat_observer.h"
#include "shot_context.h"
#include "shooter_observer.h"
#include "constructor_lexical_seh.h"
#include "constructor_observer_thunk.h"
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
#include "constructor_observer.h"
#include "constructor_lexical_seh.h"
#endif
#ifdef CLONEWARS_BASE_AIM_OBSERVER
#include "base_aim_observer.h"
#endif

typedef char *(__attribute__((thiscall)) *Create)(void *,void *,const float *,const float *,const char *,uint32_t,void *);
typedef unsigned char (__attribute__((thiscall)) *Remove)(void *,void *,uint32_t,int);
typedef struct Tracked {
    SyncShot birth;
    char *object;
    void *resource;
} Tracked;
static Tracked tracked[SYNC_MAX_PROJECTILES];
static uint32_t instance_serial[SYNC_MAX_PROJECTILES],creation_count[SYNC_MAX_PROJECTILES],next_instance_serial;
static SyncFrame *current;
static int is_host,failed,level=-1;
static uint32_t next_id;
static unsigned char consumed[SYNC_MAX_SHOTS];
static SyncShot pending[SYNC_MAX_SHOTS];
static unsigned pending_count;
typedef struct PendingProvenance {uint32_t epoch;int32_t level;uint32_t release,session;uint64_t generation;uint32_t committed;} PendingProvenance;
static PendingProvenance pending_provenance[SYNC_MAX_SHOTS];
static uint64_t reset_generation=1;static uint32_t last_session,last_session_epoch,revoked_session,revoked_session_epoch;
static SpanEngineAdapter*control_adapter;static ProjectileSessionProvider session_provider;static ProjectileRejectAtomic reject_provider;static void*control_user;
static volatile LONG projectile_hooks_installed;

typedef struct ProjectileOperation {uint32_t kind,serial;ProjectileFrameLease frame;RootControlLease control;ProjectileSessionContext session;uint64_t reset_generation;} ProjectileOperation;
enum {PROJECTILE_UNKEYED=1,PROJECTILE_KEYED=2,PROJECTILE_REJECTED=3,PROJECTILE_CONTROL=4,PROJECTILE_BARRIER=5,PROJECTILE_CLIENT_DECLINE=6,PROJECTILE_CONTROL_FAULT=7};
static ProjectileOperation operation_capture(void);
static int operation_live(const ProjectileOperation*);
static void operation_exception(const ProjectileOperation*);
static __thread uint32_t fire_cleanup_stamp=1;
static void fire_detach(void);
typedef struct FireContext { struct FireContext *previous; void *actor; uint32_t caller; int mode;ProjectileOperation operation;uint32_t cleanup_stamp,local_generation;
#ifdef CLONEWARS_BASE_AIM_OBSERVER
 uint32_t scope_id,serial,frame_nonce,epoch,sequence;SyncFrame *frame;
#endif
} FireContext;
static __thread FireContext *active_fire;
#ifdef CLONEWARS_BASE_AIM_OBSERVER
static volatile LONG base_aim_scope_id,base_aim_frame_nonce,base_aim_frame_open;
static uint32_t base_aim_next(volatile LONG *counter){LONG id=InterlockedIncrement(counter);if(!id)id=InterlockedIncrement(counter);return (uint32_t)id;}
static void base_aim_close_frame(void){InterlockedExchange(&base_aim_frame_open,0);base_aim_next(&base_aim_frame_nonce);}
#endif
typedef struct ProjectileFailure {
    uint32_t reason,sequence,thread,caller,fire_caller,fire_mode,clock,rng_game,rng_engine;
    uint32_t ordinal,shot_count,projectile_count,expected_index,weapon,flags,target_local;
    uint32_t qpc_low,qpc_high;
    SyncShot expected;
    ShooterActorObservation actor;
    uint32_t action_timer,cooldown,pending_local,pending_valid,pending_words[7];
} ProjectileFailure;
typedef char ProjectileFailureLayout[(sizeof(ProjectileFailure)==620) ? 1 : -1];
__declspec(dllexport) volatile LONG clonewars_projectile_failure_committed;
__declspec(dllexport) volatile uint32_t clonewars_projectile_failure_stride=sizeof(ProjectileFailure);
__declspec(dllexport) volatile ProjectileFailure clonewars_projectile_failure;
static int network_active,authority;
static uint32_t lifecycle_serial;
static ProjectileFrameLease frame_lease;static ProjectileSessionContext frame_context;
static int frame_bound,frame_associated,frame_started,frame_complete,binding_cancelled;
static uint32_t next_binding,frame_lifecycle;static int dispatch_completed;static uint64_t dispatch_revision,dispatch_completed_revision;static CoherentFrameToken retired_frame_token;static int retired_frame_valid;
static volatile LONG projectile_main_thread;
static int session_read(ProjectileSessionContext*s){if(!session_provider||!session_provider(s,control_user)||s->host>1||s->classification>PROJECTILE_SESSION_FAULT)return 0;return s->classification!=PROJECTILE_SESSION_ESTABLISHED||(s->session&&s->epoch&&s->level>=0&&s->level<4096);}
static int session_permission(const ProjectileSessionContext*s){if(!s->session||!s->epoch||(s->session==revoked_session&&s->epoch==revoked_session_epoch))return 0;return !last_session||(s->session==last_session&&s->epoch==last_session_epoch)||((s->session>last_session||(s->session==last_session&&s->epoch>last_session_epoch))&&level==-1&&!pending_count&&!next_id);}
static void session_accept(const ProjectileSessionContext*s){last_session=s->session;last_session_epoch=s->epoch;}
static int session_same(const ProjectileSessionContext*a,const ProjectileSessionContext*b){return a->epoch==b->epoch&&a->level==b->level&&a->host==b->host&&a->classification==b->classification&&a->session==b->session;}
static int frame_context_live(void){uint32_t thread=(uint32_t)InterlockedCompareExchange(&projectile_main_thread,0,0);if(!thread||thread!=GetCurrentThreadId())return 0;ProjectileSessionContext now;if(!control_adapter)return 1;return frame_associated&&frame_context.session&&session_read(&now)&&now.session==frame_context.session&&now.epoch==frame_context.epoch&&now.level==frame_context.level&&now.host==frame_context.host;}
static int projectile_thread_owned(void){uint32_t own=(uint32_t)InterlockedCompareExchange(&projectile_main_thread,0,0),thread=GetCurrentThreadId();if(own)return own==thread;CoherentFrameToken token;RootControlLease control;uint32_t proven=0;if(coherent_frame_get(&token,COHERENT_ALL_PHASES))proven=token.thread;else if(control_adapter&&span_engine_control_get(control_adapter,&control))proven=control.thread;if(!proven)return 0;LONG prior=InterlockedCompareExchange(&projectile_main_thread,(LONG)proven,0);return !prior||(uint32_t)prior==thread;}
int projectiles_configure_coherent(SpanEngineAdapter*a,ProjectileSessionProvider provider,ProjectileRejectAtomic reject,void*user){
 if(!a||!provider||!reject||a->window_thread!=GetCurrentThreadId()||!a->callbacks.main_confirmed||!a->callbacks.main_confirmed(GetCurrentThreadId(),a->callbacks.user))return 0;
 if(control_adapter)return control_adapter==a&&session_provider==provider&&reject_provider==reject&&control_user==user;
 CoherentFrameToken live;if(frame_associated||active_fire||pending_count||coherent_frame_get(&live,COHERENT_ALL_PHASES))return 0;
 control_adapter=a;session_provider=provider;reject_provider=reject;control_user=user;InterlockedCompareExchange(&projectile_main_thread,(LONG)GetCurrentThreadId(),0);return 1;
}

unsigned projectiles_cohort_capabilities(void){return PROJECTILE_COHORT_FRAME|PROJECTILE_COHORT_CONTROL;}
int projectiles_control_pending_missing(void){return !control_adapter||!session_provider||!reject_provider;}
int projectiles_cohort_ready(void){return !projectiles_control_pending_missing()&&InterlockedCompareExchange(&projectile_hooks_installed,0,0);}
#define PROJECTILE_COHORT_PHASES (COHERENT_PHASE_BIT(COHERENT_PREPARE)|COHERENT_PHASE_BIT(COHERENT_DISPATCH)|COHERENT_PHASE_BIT(COHERENT_FINISH))
static int same_cohort(const CoherentFrameToken*a,const CoherentFrameToken*b){return a->owner==b->owner&&a->owner_nonce==b->owner_nonce&&a->cohort_nonce==b->cohort_nonce&&a->thread==b->thread&&a->release==b->release&&a->epoch==b->epoch&&a->sequence==b->sequence&&a->frame==b->frame;}
static __attribute__((unused)) int frame_live(void){return projectile_thread_owned()&&frame_bound&&frame_context_live()&&coherent_frame_valid(&frame_lease.cohort,PROJECTILE_COHORT_PHASES)&&!binding_cancelled&&frame_lifecycle==lifecycle_serial&&current==frame_lease.cohort.frame;}
int projectiles_bind_cohort(const CoherentFrameToken*t){
 if(!t||!projectile_thread_owned())return 0;ProjectileSessionContext session={0};if(control_adapter&&(!session_read(&session)||!session.session||session.epoch!=t->epoch||(frame_associated&&!frame_context_live())))return 0;if(!coherent_frame_valid(t,COHERENT_PHASE_BIT(COHERENT_PREPARE)))return 0;
 if(retired_frame_valid&&same_cohort(t,&retired_frame_token))return 0;
 if(frame_associated)return same_cohort(t,&frame_lease.cohort)&&!binding_cancelled&&coherent_frame_valid(t,COHERENT_PHASE_BIT(COHERENT_PREPARE));
 if(next_binding==UINT32_MAX){coherent_frame_cancel_atomic(0x100000u);return 0;}
 frame_lease=(ProjectileFrameLease){++next_binding,*t};frame_context=session;frame_associated=1;frame_started=frame_complete=binding_cancelled=dispatch_completed=0;dispatch_revision=dispatch_completed_revision=0;current=NULL;return 1;
}
int projectiles_cohort_valid(const CoherentFrameToken*t){return t&&projectile_thread_owned()&&frame_associated&&!binding_cancelled&&same_cohort(t,&frame_lease.cohort)&&frame_context_live()&&coherent_frame_valid(t,COHERENT_ALL_PHASES);}
int projectiles_frame_cancelled(const ProjectileFrameLease*l){return !l||!projectile_thread_owned()||!frame_associated||l->serial!=frame_lease.serial||binding_cancelled||!same_cohort(&l->cohort,&frame_lease.cohort)||!frame_context_live()||!coherent_frame_valid(&l->cohort,COHERENT_ALL_PHASES);}
int projectiles_frame_lease_get(ProjectileFrameLease*out){if(!out||!projectile_thread_owned()||!frame_associated||frame_lease.cohort.thread!=GetCurrentThreadId())return 0;*out=frame_lease;return 1;}

static int control_valid(const RootControlLease*lease,const ProjectileSessionContext*session,uint64_t generation){ProjectileSessionContext now;if(!control_adapter||generation!=reset_generation||frame_bound||!span_engine_control_valid(control_adapter,lease)||!session_read(&now)||!session_same(session,&now)||!session_permission(&now)||now.classification!=PROJECTILE_SESSION_ESTABLISHED||!now.epoch||now.epoch!=lease->epoch||now.level!=lease->level)return 0;return span_engine_control_valid(control_adapter,lease);}
static void operation_reject(const ProjectileOperation*o,unsigned reason){if(o&&o->session.session&&o->session.epoch){revoked_session=o->session.session;revoked_session_epoch=o->session.epoch;}ProjectileRejectContext c={0};if(o){c.capability=o->kind;if(o->kind==PROJECTILE_CONTROL){c.epoch=o->control.epoch;c.level=o->control.level;c.release=o->control.release;}else if(o->kind==PROJECTILE_KEYED){c.epoch=o->frame.cohort.epoch;c.level=o->session.level;c.release=o->frame.cohort.release;c.sequence=o->frame.cohort.sequence;}else{c.epoch=o->session.epoch;c.level=o->session.level;c.release=coherent_frame_release();}}coherent_frame_cancel_atomic(0x200000u);if(reject_provider)reject_provider(reason,&c,control_user);}
static int operation_live(const ProjectileOperation*o){
 if(!o||!projectile_thread_owned()||o->serial!=lifecycle_serial)return 0;
 if(o->kind==PROJECTILE_CONTROL)return control_valid(&o->control,&o->session,o->reset_generation);
 if(o->kind==PROJECTILE_UNKEYED||o->kind==PROJECTILE_BARRIER)return !frame_bound&&!current;
 return o->kind==PROJECTILE_KEYED&&o->session.session==frame_context.session&&frame_context_live()&&coherent_frame_valid(&o->frame.cohort,PROJECTILE_COHORT_PHASES)&&frame_bound&&same_cohort(&o->frame.cohort,&frame_lease.cohort)&&o->frame.serial==frame_lease.serial&&!binding_cancelled&&current==o->frame.cohort.frame;
}
static ProjectileOperation operation_capture(void){
 ProjectileOperation o={0};o.kind=PROJECTILE_REJECTED;if(!projectile_thread_owned())return o;o.serial=lifecycle_serial;o.reset_generation=reset_generation;
 if(frame_bound){o.frame=frame_lease;o.session.epoch=frame_lease.cohort.epoch;o.session.level=level;o.session.host=(uint32_t)is_host;o.session.session=frame_context.session;o.kind=PROJECTILE_KEYED;if(!operation_live(&o))o.kind=PROJECTILE_REJECTED;return o;}
 if(!control_adapter){if(!frame_associated)o.kind=PROJECTILE_UNKEYED;return o;}
 if(!session_read(&o.session)){o.kind=PROJECTILE_CONTROL_FAULT;return o;}
 if(o.session.classification==PROJECTILE_SESSION_OFFLINE||o.session.classification==PROJECTILE_SESSION_BOOTSTRAP||o.session.classification==PROJECTILE_SESSION_TRANSITION){o.kind=PROJECTILE_BARRIER;return o;}
 if(o.session.classification==PROJECTILE_SESSION_ESTABLISHED){if(span_engine_control_get(control_adapter,&o.control)&&control_valid(&o.control,&o.session,o.reset_generation)){session_accept(&o.session);o.kind=PROJECTILE_CONTROL;return o;}}
 if(o.session.classification==PROJECTILE_SESSION_ESTABLISHED&&!o.session.host){o.kind=PROJECTILE_CLIENT_DECLINE;return o;}o.kind=PROJECTILE_CONTROL_FAULT;return o;
}
static void operation_admit_event(const ProjectileOperation*o){if(o&&o->kind==PROJECTILE_CONTROL_FAULT)operation_reject(o,PROJECTILE_CONTROL_UNAVAILABLE);}
static void operation_exception(const ProjectileOperation*o){if(o&&(o->kind==PROJECTILE_KEYED||o->kind==PROJECTILE_CONTROL))operation_reject(o,PROJECTILE_CONTROL_EXCEPTION);}

static void dispatch_changed(const ProjectileOperation*op){if(op->kind!=PROJECTILE_KEYED||!operation_live(op))return;if(dispatch_revision==UINT64_MAX)operation_reject(op,PROJECTILE_CONTROL_EXHAUSTED);else ++dispatch_revision;}
static void fire_detach(void){active_fire=NULL;if(fire_cleanup_stamp!=UINT32_MAX)++fire_cleanup_stamp;}
uint32_t projectiles_lifecycle_serial(void) { return lifecycle_serial; }
#ifdef CLONEWARS_BASE_AIM_OBSERVER
static int base_aim_binding_live(const FireContext *f){return frame_live()&&f&&operation_live(&f->operation)&&f->cleanup_stamp==fire_cleanup_stamp&&f->serial==lifecycle_serial&&base_aim_frame_open&&network_active&&f->frame&&f->frame==current&&f->frame_nonce&&(uint32_t)base_aim_frame_nonce==f->frame_nonce;}
int projectiles_base_aim_context(const void *actor,BaseAimContext *out) {
    if(!out)return 0;memset(out,0,sizeof(*out));FireContext *f=active_fire;
    if(!frame_live()||!f||!base_aim_binding_live(f)||f->actor!=actor||!f->local_generation||!entities_allocation_live(actor,f->local_generation))return 0;
    if(!base_aim_binding_live(f))return 0;
    if(f->frame->epoch!=f->epoch||f->frame->sequence!=f->sequence||!base_aim_binding_live(f))return 0;
    *out=(BaseAimContext){f->serial,f->epoch,f->sequence,f->scope_id,f->caller,(uint32_t)f->mode};return 1;
}
#endif
static char *legacy[SYNC_MAX_PROJECTILES];
static uint64_t legacy_version[SYNC_MAX_PROJECTILES],next_legacy_version;
static int legacy_set(const ProjectileOperation*op,unsigned i,char*object){if(!operation_live(op))return 0;if(next_legacy_version==UINT64_MAX){operation_exception(op);return 0;}legacy_version[i]=++next_legacy_version;legacy[i]=object;dispatch_changed(op);return operation_live(op);}
__declspec(dllexport) volatile uint32_t clonewars_projectile_debug[12];
__declspec(dllexport) volatile uint32_t clonewars_fire_debug[8];
static const unsigned flight_offsets[]={0x12c,0x130,0x134,0x138,0x154,0x158,0x15c,0x128,0x13c,0x140,0x144,0x148,0x14c,0x150};

static int valid(const void *p,SIZE_T bytes) {
#ifdef PROJECTILE_COHORT_FIXTURE
 extern void projectile_cohort_read_boundary(const void*,SIZE_T);projectile_cohort_read_boundary(p,bytes);
#endif
    MEMORY_BASIC_INFORMATION m;
    return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && (uintptr_t)p+bytes<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static int actor_slot(const void *actor) { return entities_slot(actor); }
static void record_failure(const ProjectileOperation*op,uint32_t reason,void *owner,const char *weapon,uint32_t flags,void *target,uint32_t caller,unsigned expected_index) {
    if (!op||op->kind!=PROJECTILE_KEYED||!operation_live(op)||InterlockedCompareExchange(&clonewars_projectile_failure_committed,-1,0)!=0) return;
    ProjectileFailure value;memset(&value,0,sizeof(value));
    value.reason=reason;value.sequence=current ? current->sequence : 0;value.thread=GetCurrentThreadId();
    value.caller=caller;value.fire_caller=active_fire ? active_fire->caller : 0;
    value.fire_mode=active_fire ? (uint32_t)active_fire->mode : 0;
    value.clock=*(uint32_t *)0xfb4b6c;value.rng_game=*(uint32_t *)0xe637b4;value.rng_engine=*(uint32_t *)0xea178c;
    value.ordinal=clonewars_projectile_debug[7];value.shot_count=current ? current->shot_count : 0;
    value.projectile_count=current ? current->projectile_count : 0;value.expected_index=expected_index;
    value.weapon=valid(weapon,1) ? (uint32_t)(int32_t)*weapon : UINT32_MAX;
    value.flags=flags;value.target_local=(uint32_t)(uintptr_t)target;
    LARGE_INTEGER qpc;QueryPerformanceCounter(&qpc);value.qpc_low=qpc.LowPart;value.qpc_high=(uint32_t)qpc.HighPart;
    if (current && expected_index<current->shot_count) value.expected=current->shots[expected_index];
    shooter_observer_actor_snapshot(&value.actor,owner);
    if(!operation_live(op)){InterlockedExchange(&clonewars_projectile_failure_committed,0);return;}
    if (valid(owner,0x1440)) {
        char *actor=(char *)owner;value.action_timer=*(uint32_t *)(actor+0x2ac);value.cooldown=*(uint32_t *)(actor+0x7ec);
        char *pending=*(char **)(actor+0x142c);value.pending_local=(uint32_t)(uintptr_t)pending;
        if (valid(pending,0x144)) {
            value.pending_valid=1;const unsigned offsets[]={0xbc,0xcc,0xd8,0xdc,0xe0,0x140,0};
            for (unsigned i=0;i<7;++i) value.pending_words[i]=*(uint32_t *)(pending+offsets[i]);
        }
    }
    if(!operation_live(op)){InterlockedExchange(&clonewars_projectile_failure_committed,0);return;}
    memcpy((void *)&clonewars_projectile_failure,&value,sizeof(value));
    InterlockedExchange(&clonewars_projectile_failure_committed,1);
}
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
extern volatile LONG clonewars_constructor_observer_enabled;
static uint32_t constructor_nonce,constructor_hooks_ready,constructor_thread;
static int constructor_open;
static void constructor_close(void){if(!++constructor_nonce)++constructor_nonce;constructor_open=0;}
static __attribute__((unused)) ConstructorLease constructor_lease(void){
 ConstructorLease l={lifecycle_serial,constructor_nonce,(uint32_t)(uintptr_t)current,0,0,0};
 if(frame_live()&&constructor_open&&current&&constructor_thread==GetCurrentThreadId()){l.epoch=frame_lease.cohort.epoch;l.sequence=frame_lease.cohort.sequence;l.frame_valid=1;}
 return l;
}
int projectiles_constructor_cohort_valid(const ConstructorLease*l,const CoherentFrameToken*c){
 if(!l||!c)return 0;
 if(!l->frame_valid)return !c->cohort_nonce&&!frame_associated&&!constructor_open&&!current&&l->serial==lifecycle_serial&&l->nonce==constructor_nonce&&!l->frame_local;
 if(!frame_context_live()||!coherent_frame_valid(c,PROJECTILE_COHORT_PHASES))return 0;
 if(!frame_bound||!same_cohort(c,&frame_lease.cohort)||binding_cancelled||frame_lifecycle!=lifecycle_serial||l->serial!=lifecycle_serial||l->nonce!=constructor_nonce||l->frame_local!=(uint32_t)(uintptr_t)current||c->frame!=current||!constructor_open||constructor_thread!=GetCurrentThreadId())return 0;
 return l->epoch==c->epoch&&l->sequence==c->sequence&&current->epoch==c->epoch&&current->sequence==c->sequence&&coherent_frame_valid(c,PROJECTILE_COHORT_PHASES);
}
int projectiles_constructor_lease_valid(const ConstructorLease*l){CoherentFrameToken unkeyed={0};return l&&!l->frame_valid&&projectiles_constructor_cohort_valid(l,&unkeyed);}
typedef struct ConstructorLexicalContext {
 void *manager,*owner;const float *origin,*transform;const char *weapon;uint32_t flags;void *target;
 ConstructorScope *observation;
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
 ConstructorQueryScope *query;
#endif
} ConstructorLexicalContext;
static void* __cdecl constructor_lexical_invoke(void*opaque){ConstructorLexicalContext*c=opaque;return ((Create)0x869060)(c->manager,c->owner,c->origin,c->transform,c->weapon,c->flags,c->target);}
static void __cdecl constructor_lexical_abort(void*opaque){
 DWORD error=GetLastError();ConstructorLexicalContext*c=opaque;
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
 if(c->query)constructor_query_scope_end(c->query,NULL);
#endif
 if(c->observation)c->observation->ready=0;
 SetLastError(error);
}
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
#ifdef PROJECTILE_COHORT_FIXTURE
extern ConstructorQueryScope *projectile_cohort_scope_storage(void);
#define QUERY_STORAGE(name) ConstructorQueryScope *name=projectile_cohort_scope_storage()
#else
#define QUERY_STORAGE(name) ConstructorQueryScope name##_storage;ConstructorQueryScope *name=&name##_storage
#endif
#endif
int projectiles_constructor_control_valid(const ConstructorLease*l,const RootControlLease*control,const ProjectileSessionContext*captured,uint64_t generation){
 if(!l||!control||l->frame_valid||l->frame_local||l->epoch||l->sequence||!projectile_thread_owned()||l->serial!=lifecycle_serial||l->nonce!=constructor_nonce||frame_bound||current||generation!=reset_generation)return 0;
 if(!captured||captured->classification!=PROJECTILE_SESSION_ESTABLISHED||captured->epoch!=control->epoch||captured->level!=control->level)return 0;
 return control_valid(control,captured,generation);
}
static void constructor_identity(ConstructorScope*s,const ProjectileOperation*op){
 s->ready=0;s->cohort=(CoherentFrameToken){0};s->control=(RootControlLease){0};s->control_session=op->session;s->reset_generation=op->reset_generation;
 s->capability=op->kind==PROJECTILE_KEYED?CONSTRUCTOR_CAP_FRAME:op->kind==PROJECTILE_CONTROL?CONSTRUCTOR_CAP_CONTROL:op->kind==PROJECTILE_UNKEYED?CONSTRUCTOR_CAP_NONE:CONSTRUCTOR_CAP_REJECTED;
 if(s->capability==CONSTRUCTOR_CAP_FRAME)s->cohort=op->frame.cohort;if(s->capability==CONSTRUCTOR_CAP_CONTROL)s->control=op->control;
}
static char* create_observed_context(const ProjectileOperation*op,void*manager,void*owner,const float*origin,const float*transform,const char*weapon,uint32_t flags,void*target,const SyncShot*birth,uint32_t kind,uint32_t caller){
 if(!projectile_thread_owned()||!clonewars_constructor_observer_enabled){
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
  QUERY_STORAGE(barrier);ConstructorScope identity;constructor_identity(&identity,op);constructor_query_scope_begin(barrier,&identity);
  ConstructorLexicalContext lexical={manager,owner,origin,transform,weapon,flags,target,NULL,barrier};
  char*object=constructor_lexical_seh(&lexical,constructor_lexical_invoke,constructor_lexical_abort);
  constructor_query_scope_end(barrier,object);return object;
#else
  return ((Create)0x869060)(manager,owner,origin,transform,weapon,flags,target);
#endif
 }
 uint32_t serial=lifecycle_serial;
 ConstructorScope observation;constructor_identity(&observation,op);
 ConstructorLease lease={op->serial,constructor_nonce,0,0,0,0};if(op->kind==PROJECTILE_KEYED){lease.frame_local=(uint32_t)(uintptr_t)op->frame.cohort.frame;if(operation_live(op)){lease.epoch=op->frame.cohort.epoch;lease.sequence=op->frame.cohort.sequence;lease.frame_valid=1;}}
 ConstructorCall call={.lease=lease,.birth=op->kind==PROJECTILE_CONTROL?NULL:birth,.manager=manager,.owner=owner,.origin=origin,.transform=transform,.weapon=weapon,.flags=flags,.target=target,.kind=kind,.caller=caller,.cohort=observation.cohort,.control=observation.control,.control_session=observation.control_session,.reset_generation=op->reset_generation,.capability=observation.capability};
 constructor_observer_begin(&observation,&call);
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
 QUERY_STORAGE(query_scope);
 constructor_query_scope_begin(query_scope,&observation);
#endif
 ConstructorLexicalContext lexical={manager,owner,origin,transform,weapon,flags,target,&observation
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
 ,query_scope
#endif
 };
 char*object=constructor_lexical_seh(&lexical,constructor_lexical_invoke,constructor_lexical_abort);
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
 constructor_query_scope_end(query_scope,object);
#endif
 if(serial==lifecycle_serial)constructor_observer_end(&observation,object);
 return object;
}
static __attribute__((unused)) char* create_observed(void*m,void*o,const float*p,const float*t,const char*w,uint32_t f,void*x,const SyncShot*b,uint32_t k,uint32_t caller){ProjectileOperation op=operation_capture();return create_observed_context(&op,m,o,p,t,w,f,x,b,k,caller);}
#define OBSERVED_CREATE_CTX(op,m,o,p,t,w,f,x,b,k,c) create_observed_context(op,m,o,p,t,w,f,x,b,k,c)
#define OBSERVED_CREATE(m,o,p,t,w,f,x,b,k,c) create_observed(m,o,p,t,w,f,x,b,k,c)
#else
#define OBSERVED_CREATE(m,o,p,t,w,f,x,b,k,c) (((Create)0x869060)(m,o,p,t,w,f,x))
#define OBSERVED_CREATE_CTX(op,m,o,p,t,w,f,x,b,k,c) (((Create)0x869060)(m,o,p,t,w,f,x))
#endif
int projectiles_abort_frame(const ProjectileFrameLease*captured){
 if(!captured||captured->cohort.thread!=GetCurrentThreadId()||!projectile_thread_owned()||!frame_associated||frame_lease.serial!=captured->serial||!same_cohort(&captured->cohort,&frame_lease.cohort))return 0;
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
 constructor_query_abort_cohort(&captured->cohort);
#endif
 retired_frame_token=captured->cohort;retired_frame_valid=1;
 if(!++lifecycle_serial)++lifecycle_serial;
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
 constructor_close();
#endif
#ifdef CLONEWARS_BASE_AIM_OBSERVER
 base_aim_close_frame();
#endif
 fire_detach();current=NULL;network_active=authority=0;frame_bound=frame_associated=frame_started=frame_complete=0;binding_cancelled=1;return 1;
}
typedef void (__attribute__((stdcall)) *Fire)(void *,const char *,int,void *,void *);
typedef struct FireCall {FireContext fire;ShooterObservationScope observation;int observing;void *actor,*output1,*output2;const char *weapon;int mode;} FireCall;
static void fire_unlink(FireCall*c){if(active_fire==&c->fire&&c->fire.cleanup_stamp==fire_cleanup_stamp){active_fire=operation_live(&c->fire.operation)?c->fire.previous:NULL;}}
static void* __cdecl fire_invoke(void*opaque){FireCall*c=opaque;((Fire)0x879710)(c->actor,c->weapon,c->mode,c->output1,c->output2);return NULL;}
static void __cdecl fire_abort(void*opaque){DWORD error=GetLastError();FireCall*c=opaque;if(c->observing)shooter_observer_fire_abort(&c->observation);operation_exception(&c->fire.operation);fire_unlink(c);SetLastError(error);}
__attribute__((used,noinline)) static void fire_complete_impl(FireCall*c,void*unused){(void)unused;if(!operation_live(&c->fire.operation)){if(c->observing)shooter_observer_fire_abort(&c->observation);fire_unlink(c);return;}if(c->observing)shooter_observer_fire_end(&c->observation);fire_unlink(c);}
__attribute__((naked)) static void fire_complete(FireCall*c,void*p){__asm__ volatile(CONSTRUCTOR_OBSERVER_THUNK_ASM("_fire_complete_impl"));}
static void __attribute__((stdcall)) fire_hook(void *actor,const char *weapon,int mode,void *output1,void *output2) {
 FireCall c={0};c.actor=actor;c.weapon=weapon;c.mode=mode;c.output1=output1;c.output2=output2;
 c.fire.operation=operation_capture();operation_admit_event(&c.fire.operation);c.fire.previous=active_fire;c.fire.cleanup_stamp=fire_cleanup_stamp;c.fire.actor=actor;c.fire.caller=(uint32_t)(uintptr_t)__builtin_return_address(0);c.fire.mode=mode;
 if(c.fire.operation.kind==PROJECTILE_KEYED&&operation_live(&c.fire.operation)){
  c.fire.local_generation=entities_observed_generation(actor);
  if(!operation_live(&c.fire.operation))goto fire_native;
#ifdef CLONEWARS_BASE_AIM_OBSERVER
  c.fire.scope_id=base_aim_next(&base_aim_scope_id);c.fire.serial=c.fire.operation.serial;c.fire.frame_nonce=(uint32_t)base_aim_frame_nonce;c.fire.frame=current;c.fire.epoch=c.fire.operation.frame.cohort.epoch;c.fire.sequence=c.fire.operation.frame.cohort.sequence;
#endif
  c.observing=shooter_observer_fire_begin(&c.observation,actor,weapon,mode,output1,output2,c.fire.caller);
  if(operation_live(&c.fire.operation)){combat_observer_fire_requested();++clonewars_fire_debug[0];}
 }
fire_native:
 active_fire=&c.fire;
 constructor_lexical_seh(&c,fire_invoke,fire_abort);
 fire_complete(&c,NULL);
}
static char *actor_at(int slot,uint32_t generation) {
    char *actor=slot>=0 ? entities_actor((uint32_t)slot,generation) : NULL;
    return valid(actor,0x1440) && (*(uint32_t *)(actor+0x50)&3)==3 ? actor : NULL;
}
static Tracked *find(uint32_t id) {
    for (unsigned i=0;i<SYNC_MAX_PROJECTILES;++i) if (tracked[i].birth.id==id) return tracked+i;
    return NULL;
}
int projectiles_observe_live(const void *object,ProjectileIdentityView *view) {
 memset(view,0,sizeof(*view));view->owner=-1;view->weapon=-1;ProjectileOperation op=operation_capture();
 if((op.kind!=PROJECTILE_KEYED&&op.kind!=PROJECTILE_CONTROL)||!operation_live(&op))return view->status=SHOT_UNTRACKED;
 if(!object)return view->status=SHOT_NULL;if(!valid(object,0x210)||!operation_live(&op))return view->status=SHOT_INVALID;
 void *resource=*(void**)((const char*)object+0x14);ProjectileIdentityCandidate candidates[SYNC_MAX_PROJECTILES];
 for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i)candidates[i]=(ProjectileIdentityCandidate){(uintptr_t)tracked[i].object,(uintptr_t)tracked[i].resource,tracked[i].birth.id};
 uint32_t id=0;view->status=projectile_identity_select(candidates,SYNC_MAX_PROJECTILES,(uintptr_t)object,(uintptr_t)resource,&id);if(view->status!=SHOT_LIVE||!operation_live(&op))return view->status=SHOT_UNTRACKED;
 Tracked *e=find(id);if(!e||e->object!=object||e->resource!=resource||!operation_live(&op)||*(void**)((const char*)object+0x14)!=resource)return view->status=SHOT_RESOURCE_MISMATCH;
 view->id=id;view->owner=e->birth.owner;view->owner_generation=e->birth.owner_generation;view->weapon=e->birth.weapon;view->resource_local=(uint32_t)(uintptr_t)resource;unsigned i=(unsigned)(e-tracked);view->instance_serial=instance_serial[i];view->creation_count=creation_count[i];return view->status;
}
static Tracked *remember(const ProjectileOperation*op,const SyncShot *shot,char *object) {
 if(!operation_live(op)||(op->kind!=PROJECTILE_KEYED&&op->kind!=PROJECTILE_CONTROL))return NULL;SyncShot birth=*shot;Tracked *e=find(birth.id);
 if(!e)for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i)if(!tracked[i].birth.id){e=tracked+i;break;}
 if(!e){operation_reject(op,PROJECTILE_PENDING_CAPACITY);return NULL;}
 void*resource=NULL;if(valid(object,0x210)){if(!operation_live(op))return NULL;resource=*(void**)(object+0x14);}if(!operation_live(op))return NULL;
 unsigned i=(unsigned)(e-tracked);if(e->birth.id!=birth.id)creation_count[i]=0;
 if(object){if(next_instance_serial==UINT32_MAX||creation_count[i]==UINT32_MAX){operation_reject(op,PROJECTILE_CONTROL_EXHAUSTED);return NULL;}instance_serial[i]=++next_instance_serial;++creation_count[i];}
 e->birth=birth;e->object=object;e->resource=resource;dispatch_changed(op);return operation_live(op)?e:NULL;
}
typedef struct ReplayCall {ProjectileOperation op;void*manager,*owner,*target;SyncShot birth;char weapon;uint32_t caller;} ReplayCall;
__attribute__((used,noinline)) static void replay_complete_impl(ReplayCall*c,void*object){const ProjectileOperation*op=&c->op;if(!operation_live(op)){if(op->kind==PROJECTILE_CONTROL)operation_reject(op,PROJECTILE_CONTROL_ABANDONED);return;}if(object)combat_observer_projectile_created();if(!operation_live(op))return;*(void**)0xe8ed28=NULL;remember(op,&c->birth,object);if(operation_live(op)){++clonewars_projectile_debug[3];if(c->birth.owner==1)++clonewars_projectile_debug[9];}}
__attribute__((naked)) static void replay_complete(ReplayCall*c,void*object){__asm__ volatile(CONSTRUCTOR_OBSERVER_THUNK_ASM("_replay_complete_impl"));}
static void* __cdecl replay_invoke(void*opaque){ReplayCall*c=opaque;char*object=OBSERVED_CREATE_CTX(&c->op,c->manager,c->owner,c->birth.origin,c->birth.transform,&c->weapon,c->birth.flags,c->target,&c->birth,c->birth.phase==1?3:2,c->caller);replay_complete(c,object);return object;}
static void __cdecl replay_abort(void*opaque){DWORD error=GetLastError();ReplayCall*c=opaque;operation_exception(&c->op);SetLastError(error);}
static char *replay(const ProjectileOperation*op,void*manager,const SyncShot*shot,void*target,uint32_t caller){
 if(!operation_live(op)||op->kind!=PROJECTILE_KEYED)return NULL;ReplayCall c={.op=*op,.manager=manager,.target=target,.birth=*shot,.caller=caller};c.weapon=(char)c.birth.weapon;c.owner=actor_at(c.birth.owner,c.birth.owner_generation);
 if(!operation_live(op))return NULL;if(c.birth.owner>=0&&!c.owner&&!entities_is_retired((uint32_t)c.birth.owner,c.birth.owner_generation)){if(operation_live(op))failed=1;return NULL;}
 return constructor_lexical_seh(&c,replay_invoke,replay_abort);
}
typedef struct CreateAuthorityCall {ProjectileOperation op;void *manager,*owner,*target;const float *origin,*transform;const char *weapon;uint32_t flags,caller,path,pending_index;const SyncShot*birth;} CreateAuthorityCall;
__attribute__((used,noinline)) static void create_commit_impl(CreateAuthorityCall*c,void*object){
 const ProjectileOperation*op=&c->op;if(!operation_live(op)){if(op->kind==PROJECTILE_CONTROL)operation_reject(op,PROJECTILE_CONTROL_ABANDONED);return;}if(object)combat_observer_projectile_created();if(!operation_live(op)){if(op->kind==PROJECTILE_CONTROL)operation_reject(op,PROJECTILE_CONTROL_ABANDONED);return;}
 if(c->path==1){if(object)for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i)if(!legacy[i]){legacy_set(op,i,object);break;}return;}
 if(c->path==3){if(c->pending_index>=pending_count||pending[c->pending_index].id!=c->birth->id){operation_reject(op,PROJECTILE_PENDING_PROVENANCE);return;}if(!remember(op,c->birth,object)||!operation_live(op))return;pending_provenance[c->pending_index].committed=1;return;}
 if(c->path==2){remember(op,c->birth,object);if(operation_live(op)){++clonewars_projectile_debug[2];if(c->birth->owner==1)++clonewars_projectile_debug[9];}}
}
__attribute__((naked)) static void create_commit(CreateAuthorityCall*c,void*object){__asm__ volatile(CONSTRUCTOR_OBSERVER_THUNK_ASM("_create_commit_impl"));}
static void* __cdecl create_authority_invoke(void*opaque){CreateAuthorityCall*c=opaque;const ProjectileOperation*op=&c->op;
 operation_admit_event(op);if(op->kind==PROJECTILE_CLIENT_DECLINE||op->kind==PROJECTILE_CONTROL_FAULT)return NULL;
 if(op->kind==PROJECTILE_CONTROL){
  if(!op->session.host)return NULL;if(!operation_live(op)){operation_reject(op,PROJECTILE_CONTROL_ABANDONED);return NULL;}
  if(pending_count==SYNC_MAX_SHOTS){operation_reject(op,PROJECTILE_PENDING_CAPACITY);return NULL;}if(next_id==UINT32_MAX){operation_reject(op,PROJECTILE_CONTROL_EXHAUSTED);return NULL;}
  entities_update();if(!operation_live(op)){operation_reject(op,PROJECTILE_CONTROL_ABANDONED);return NULL;}
  SyncShot birth={0};birth.owner=actor_slot(c->owner);birth.owner_generation=entities_generation(c->owner);if(!operation_live(op))return NULL;
  if(!valid(c->weapon,1)||!valid(c->origin,12)||!valid(c->transform,64)||!operation_live(op)||(c->owner&&birth.owner<0)||*c->weapon<0){operation_reject(op,PROJECTILE_CONTROL_UNAVAILABLE);return NULL;}
  birth.id=++next_id;birth.weapon=*c->weapon;birth.flags=c->flags;birth.phase=1;birth.clock=*(uint32_t*)0xfb4b6c;birth.rng_game=*(uint32_t*)0xe637b4;birth.rng_engine=*(uint32_t*)0xea178c;birth.delta=*(float*)0xfb4b74;memcpy(birth.origin,c->origin,12);memcpy(birth.transform,c->transform,64);
  if(!operation_live(op))return NULL;c->path=3;c->pending_index=pending_count;pending[pending_count]=birth;pending_provenance[pending_count++]=(PendingProvenance){.epoch=op->control.epoch,.level=op->control.level,.release=op->control.release,.session=op->session.session,.generation=op->reset_generation,.committed=0};c->birth=&birth;
  char*object=OBSERVED_CREATE_CTX(&c->op,c->manager,c->owner,c->origin,c->transform,c->weapon,c->flags,c->target,&birth,4,c->caller);create_commit(c,object);return object;
 }
 if(op->kind!=PROJECTILE_KEYED||!operation_live(op))return OBSERVED_CREATE_CTX(&c->op,c->manager,c->owner,c->origin,c->transform,c->weapon,c->flags,c->target,NULL,0,c->caller);
 ++clonewars_projectile_debug[7];
 if(!is_host){
  if(!authority){c->path=1;char*object=OBSERVED_CREATE_CTX(&c->op,c->manager,c->owner,c->origin,c->transform,c->weapon,c->flags,c->target,NULL,0,c->caller);create_commit(c,object);return object;}
  int slot=actor_slot(c->owner);uint32_t generation=entities_generation(c->owner);if(!operation_live(op))return NULL;
  for(unsigned i=0;operation_live(op)&&i<current->shot_count;++i){SyncShot*shot=current->shots+i;if(consumed[i]||shot->phase!=0)continue;
   if(shot_native_match(shot,0,slot,generation,*c->weapon)){consumed[i]=1;return replay(op,c->manager,shot,c->target,c->caller);}
   record_failure(op,1,c->owner,c->weapon,c->flags,c->target,c->caller,i);if(operation_live(op))failed=1;break;
  }
  if(operation_live(op)){record_failure(op,2,c->owner,c->weapon,c->flags,c->target,c->caller,UINT32_MAX);failed=1;++clonewars_projectile_debug[4];}return NULL;
 }
 if(current->shot_count==SYNC_MAX_SHOTS){failed=1;return NULL;}
 entities_update();if(!operation_live(op))return NULL;
 if(next_id==UINT32_MAX){operation_reject(op,PROJECTILE_CONTROL_EXHAUSTED);return NULL;}SyncShot birth={0};birth.id=++next_id;birth.owner=actor_slot(c->owner);birth.owner_generation=entities_generation(c->owner);if(!operation_live(op))return NULL;
 if(!valid(c->weapon,1)||!operation_live(op))return NULL;birth.weapon=*c->weapon;birth.flags=c->flags;
 if((c->owner&&birth.owner<0)||!valid(c->origin,12)||!valid(c->transform,64)||birth.weapon<0){if(operation_live(op))failed=1;return OBSERVED_CREATE_CTX(&c->op,c->manager,c->owner,c->origin,c->transform,c->weapon,c->flags,c->target,NULL,0,c->caller);}
 if(!operation_live(op))return NULL;birth.phase=0;birth.clock=*(uint32_t*)0xfb4b6c;birth.rng_game=*(uint32_t*)0xe637b4;birth.rng_engine=*(uint32_t*)0xea178c;birth.delta=*(float*)0xfb4b74;memcpy(birth.origin,c->origin,12);memcpy(birth.transform,c->transform,64);
 if(!operation_live(op))return NULL;current->shots[current->shot_count++]=birth;
 c->path=2;c->birth=&birth;char*object=OBSERVED_CREATE_CTX(&c->op,c->manager,c->owner,c->origin,c->transform,c->weapon,c->flags,c->target,&birth,1,c->caller);create_commit(c,object);return object;
}
static void __cdecl create_authority_abort(void*opaque){CreateAuthorityCall*c=opaque;DWORD error=GetLastError();operation_exception(&c->op);SetLastError(error);}
static char *__attribute__((fastcall)) create_hook(void *manager,void *unused,void *owner,const float *origin,const float *transform,const char *weapon,uint32_t flags,void *target){
 (void)unused;CreateAuthorityCall c={.op=operation_capture(),.manager=manager,.owner=owner,.target=target,.origin=origin,.transform=transform,.weapon=weapon,.flags=flags,.caller=(uint32_t)(uintptr_t)__builtin_return_address(0)};return constructor_lexical_seh(&c,create_authority_invoke,create_authority_abort);
}
typedef struct RemoveCall {ProjectileOperation op;void *manager,*object;uint32_t flags;int effects;CombatObservationScope observation;int observing;uint32_t captured_id[SYNC_MAX_PROJECTILES],captured_instance[SYNC_MAX_PROJECTILES];uint64_t captured_legacy[SYNC_MAX_PROJECTILES];uint32_t hook_commit;} RemoveCall;
static void* __cdecl remove_invoke(void*opaque){RemoveCall*c=opaque;return (void*)(uintptr_t)((Remove)0x846460)(c->manager,c->object,c->flags,c->effects);}
static void __cdecl remove_abort(void*opaque){DWORD error=GetLastError();RemoveCall*c=opaque;if(c->observing)combat_observer_remove_abort(&c->observation);operation_exception(&c->op);SetLastError(error);}
__attribute__((used,noinline)) static void remove_complete_impl(RemoveCall*c,void*result){
 unsigned char removed=(unsigned char)(uintptr_t)result;
 if(!operation_live(&c->op)){if(c->observing)combat_observer_remove_abort(&c->observation);return;}
 if(c->observing)combat_observer_remove_end(&c->observation,removed);if(!c->hook_commit||!removed||(c->op.kind!=PROJECTILE_KEYED&&c->op.kind!=PROJECTILE_CONTROL)||!operation_live(&c->op))return;
 for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i)if(c->captured_id[i]&&tracked[i].birth.id==c->captured_id[i]&&instance_serial[i]==c->captured_instance[i]&&tracked[i].object==c->object){tracked[i].object=NULL;if(c->op.session.host)memset(tracked+i,0,sizeof(Tracked));dispatch_changed(&c->op);}
 for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i)if(c->captured_legacy[i]&&legacy[i]==c->object&&legacy_version[i]==c->captured_legacy[i])legacy_set(&c->op,i,NULL);
}
__attribute__((naked)) static void remove_complete(RemoveCall*c,void*result){__asm__ volatile(CONSTRUCTOR_OBSERVER_THUNK_ASM("_remove_complete_impl"));}
static unsigned char remove_observed(RemoveCall*c,uint32_t reason){
 if((c->op.kind==PROJECTILE_KEYED||c->op.kind==PROJECTILE_CONTROL)&&operation_live(&c->op)){c->observing=combat_observer_remove_begin(&c->observation,c->manager,c->object,c->flags,c->effects,(uint32_t)(uintptr_t)__builtin_return_address(0));if(c->observing)c->observation.record.arguments[4]=reason;}
 unsigned char removed=(unsigned char)(uintptr_t)constructor_lexical_seh(c,remove_invoke,remove_abort);
 remove_complete(c,(void*)(uintptr_t)removed);return removed;
}
static unsigned char __attribute__((fastcall)) remove_hook(void *manager,void *unused,void *object,uint32_t flags,int effects){
 (void)unused;RemoveCall c={0};c.op=operation_capture();operation_admit_event(&c.op);c.manager=manager;c.object=object;c.flags=flags;c.effects=effects;c.hook_commit=1;
 if((c.op.kind==PROJECTILE_KEYED||c.op.kind==PROJECTILE_CONTROL)&&operation_live(&c.op))for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i)if(tracked[i].object==object){c.captured_id[i]=tracked[i].birth.id;c.captured_instance[i]=instance_serial[i];}
 if((c.op.kind==PROJECTILE_KEYED||c.op.kind==PROJECTILE_CONTROL)&&operation_live(&c.op))for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i)if(legacy[i]==object)c.captured_legacy[i]=legacy_version[i];
 return remove_observed(&c,0);
}
static int compare(const void *a,const void *b) {
    uint32_t left=((const SyncProjectile *)a)->id,right=((const SyncProjectile *)b)->id;
    return left<right ? -1 : left>right;
}
static int capture(const ProjectileOperation*op,SyncProjectile *state,const Tracked *entry){
 if(!operation_live(op)||op->kind!=PROJECTILE_KEYED)return 0;char*p=entry->object;if(!valid(p,0x210)||!operation_live(op))return 0;
 SyncProjectile value={0};value.id=entry->birth.id;memcpy(value.transform,p+0x24,128);memcpy(value.position,p+0xa4,12);memcpy(value.previous,p+0xbc,12);memcpy(value.velocity,p+0xc8,12);memcpy(value.direction,p+0xd4,12);memcpy(value.previous_direction,p+0xe0,12);for(unsigned j=0;j<14;++j)value.flight[j]=*(float*)(p+flight_offsets[j]);memcpy(value.flags,p+0x160,12);
 if(!operation_live(op))return 0;*state=value;return 1;
}
static int correct(const ProjectileOperation*op,const SyncProjectile *state,Tracked *entry){
 if(!operation_live(op)||op->kind!=PROJECTILE_KEYED)return 0;SyncProjectile value=*state;char*p=entry->object;
 if(!valid(p,0x210)||!operation_live(op))return 0;
 memcpy(p+0x24,value.transform,128);memcpy(p+0xa4,value.position,12);memcpy(p+0xbc,value.previous,12);memcpy(p+0xc8,value.velocity,12);memcpy(p+0xd4,value.direction,12);memcpy(p+0xe0,value.previous_direction,12);for(unsigned j=0;j<14;++j)*(float*)(p+flight_offsets[j])=value.flight[j];memcpy(p+0x160,value.flags,12);
 float radius=*(float*)(p+0x13c);for(unsigned j=0;j<3;++j){*(float*)(p+0xf8+j*4)=value.position[j]-radius;*(float*)(p+0x104+j*4)=value.position[j]+radius;}
 return operation_live(op);
}
static void projectiles_reset_state(int normalize) {
    if(!normalize&&last_session){revoked_session=last_session;revoked_session_epoch=last_session_epoch;}
    if(reset_generation!=UINT64_MAX)++reset_generation;else {ProjectileOperation op={0};operation_reject(&op,PROJECTILE_CONTROL_EXHAUSTED);return;}
#ifdef CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER
    if(frame_associated)constructor_query_abort_cohort(&frame_lease.cohort);
#endif
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
    constructor_close();
#endif
#ifdef CLONEWARS_BASE_AIM_OBSERVER
    base_aim_close_frame();
#endif
    if (!++lifecycle_serial) ++lifecycle_serial;
    fire_detach();
    InterlockedExchange(&clonewars_projectile_failure_committed,0);
    frame_bound=0;frame_started=frame_complete=dispatch_completed=0;if(frame_associated)binding_cancelled=1;current=NULL; level=-1; next_id=0; failed=0; pending_count=0; network_active=authority=0;
    memset(tracked,0,sizeof(tracked));
    memset(instance_serial,0,sizeof(instance_serial));memset(creation_count,0,sizeof(creation_count));next_instance_serial=0;
    memset(legacy,0,sizeof(legacy));memset(legacy_version,0,sizeof legacy_version);next_legacy_version=0;
}
void projectiles_reset(void){projectiles_reset_state(0);}
int projectiles_begin(SyncFrame *frame,int host){
 if(!projectile_thread_owned()||!frame_associated||binding_cancelled||frame_started||frame_lease.cohort.frame!=frame||!frame_context_live()||!coherent_frame_valid(&frame_lease.cohort,COHERENT_PHASE_BIT(COHERENT_PREPARE)))return 0;
 CoherentFrameToken captured=frame_lease.cohort;ProjectileSessionContext session={0};if(control_adapter&&(!session_read(&session)||!session_permission(&session)||session.epoch!=captured.epoch||session.level!=frame->level||session.host!=(uint32_t)(host!=0)||session.classification==PROJECTILE_SESSION_FAULT||session.classification==PROJECTILE_SESSION_UNAVAILABLE)){binding_cancelled=1;coherent_frame_cancel_atomic(0x200000u);return 0;}if(control_adapter)session_accept(&session);
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
 constructor_close();
#endif
#ifdef CLONEWARS_BASE_AIM_OBSERVER
 base_aim_close_frame();
#endif
 if(level!=frame->level){
  if(pending_count){
   int adopt=control_adapter&&host&&level==-1;for(unsigned i=0;adopt&&i<pending_count;++i)adopt=pending_provenance[i].committed&&pending_provenance[i].epoch==captured.epoch&&pending_provenance[i].level==frame->level&&pending_provenance[i].release==captured.release&&pending_provenance[i].session==session.session&&pending_provenance[i].generation==reset_generation;
   if(!adopt){binding_cancelled=1;coherent_frame_cancel_atomic(0x100000u);return 0;}level=frame->level;
  }else{ProjectileFrameLease original=frame_lease;projectiles_reset_state(1);frame_lease=original;frame_associated=1;binding_cancelled=0;level=frame->level;}
 }if(!coherent_frame_valid(&captured,PROJECTILE_COHORT_PHASES))return 0;
 if(control_adapter){ProjectileSessionContext now;if(!session_read(&now)||!session_same(&session,&now)){binding_cancelled=1;ProjectileOperation rejected={.kind=PROJECTILE_KEYED,.frame=frame_lease};operation_reject(&rejected,PROJECTILE_CONTROL_UNAVAILABLE);return 0;}}
 current=frame;is_host=host;frame_lifecycle=lifecycle_serial;frame_started=1;frame_bound=frame_associated=1;ProjectileOperation op=operation_capture();
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
 constructor_thread=GetCurrentThreadId();constructor_open=1;
#endif
#ifdef CLONEWARS_BASE_AIM_OBSERVER
 InterlockedExchange(&base_aim_frame_open,1);
#endif
 network_active=1;memset(consumed,0,sizeof consumed);
 if(host){if(!operation_live(&op))return 0;if(control_adapter)for(unsigned i=0;i<pending_count;++i)if(!pending_provenance[i].committed||pending_provenance[i].epoch!=captured.epoch||pending_provenance[i].level!=level||pending_provenance[i].release!=captured.release||pending_provenance[i].session!=session.session||pending_provenance[i].generation!=reset_generation){binding_cancelled=1;operation_reject(&op,PROJECTILE_PENDING_PROVENANCE);return 0;}frame->shot_count=pending_count;frame->projectile_count=0;memcpy(frame->shots,pending,pending_count*sizeof(SyncShot));pending_count=0;return operation_live(&op);}
 if(!operation_live(&op))return 0;authority=frame->combat_ready!=0;char*manager=*(char**)0xe9019c;if(!valid(manager,0x3c)){if(operation_live(&op))failed=1;return operation_live(&op);}
 if(authority)for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i){if(!operation_live(&op))return 0;char*object=legacy[i];uint64_t version=legacy_version[i];if(!object)continue;RemoveCall c={0};c.op=op;c.manager=*(void**)(manager+0x38);c.object=object;if(valid(object,0x210)){if(!operation_live(&op))return 0;remove_observed(&c,2);}if(!operation_live(&op))return 0;if(legacy[i]==object&&legacy_version[i]==version)legacy_set(&op,i,NULL);}
 for(unsigned i=0;;++i){if(!operation_live(&op))return 0;if(i>=frame->shot_count)break;if(consumed[i]||frame->shots[i].phase!=1)continue;SyncShot *shot=frame->shots+i;char*owner=shot->owner<0?NULL:actor_at(shot->owner,shot->owner_generation);if(!operation_live(&op))return 0;if(shot->owner>=0&&!owner)continue;
  ShotContext incoming=shot_context_read((uint32_t*)0xfb4b6c,(uint32_t*)0xe637b4,(uint32_t*)0xea178c,(float*)0xfb4b74);ShotContext birth={shot->clock,shot->rng_game,shot->rng_engine,shot->delta};
  if(!operation_live(&op))return 0;shot_context_apply(&birth,(uint32_t*)0xfb4b6c,(uint32_t*)0xe637b4,(uint32_t*)0xea178c,(float*)0xfb4b74);consumed[i]=1;replay(&op,manager,shot,NULL,0);if(!operation_live(&op))return 0;shot_context_apply(&incoming,(uint32_t*)0xfb4b6c,(uint32_t*)0xe637b4,(uint32_t*)0xea178c,(float*)0xfb4b74);
 }
 return operation_live(&op);
}
static int dispatch_quiet(const ProjectileOperation*op){
 if(!operation_live(op)||failed||!dispatch_completed||dispatch_revision!=dispatch_completed_revision)return 0;
 if(!is_host)for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i){if(!operation_live(op))return 0;if(!tracked[i].birth.id)continue;unsigned j=0;while(j<current->projectile_count&&current->projectiles[j].id!=tracked[i].birth.id)++j;if(j==current->projectile_count)return 0;}
 return operation_live(op);
}
int projectiles_dispatch_revision(const CoherentFrameToken*original,uint64_t*out){if(!out||!projectiles_cohort_valid(original)||!coherent_frame_valid(original,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;*out=dispatch_revision;return projectiles_cohort_valid(original)&&coherent_frame_valid(original,COHERENT_PHASE_BIT(COHERENT_DISPATCH));}
int projectiles_dispatch_pending(void){ProjectileOperation op=operation_capture();if(op.kind!=PROJECTILE_KEYED||!operation_live(&op)||failed||!coherent_frame_valid(&op.frame.cohort,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return -1;return dispatch_quiet(&op)?0:1;}
int projectiles_dispatch_complete(void){
 ProjectileOperation op=operation_capture();if(op.kind!=PROJECTILE_KEYED||!operation_live(&op)||projectiles_dispatch_pending()!=1)return 0;dispatch_completed=0;SyncFrame*frame=current;if(is_host){dispatch_completed_revision=dispatch_revision;dispatch_completed=1;return 1;}
  char*manager=*(char**)0xe9019c;if(!valid(manager,0x3c)){if(operation_live(&op))failed=1;}else{

   for(unsigned i=0;;++i){if(!operation_live(&op))return 0;if(i>=frame->projectile_count)break;const SyncProjectile*state=frame->projectiles+i;Tracked*e=find(state->id);
    if(!e){record_failure(&op,4,NULL,NULL,state->id,NULL,0,UINT32_MAX);if(!operation_live(&op))return 0;failed=1;continue;}
    if(!valid(e->object,0x210)){if(!operation_live(&op))return 0;record_failure(&op,5,actor_at(e->birth.owner,e->birth.owner_generation),NULL,state->id,e->object,0,UINT32_MAX);if(!operation_live(&op))return 0;failed=1;continue;}
    if(!operation_live(&op))return 0;if(*(void**)(e->object+0x14)!=e->resource){record_failure(&op,5,actor_at(e->birth.owner,e->birth.owner_generation),NULL,state->id,e->object,0,UINT32_MAX);if(!operation_live(&op))return 0;failed=1;continue;}
    if(!correct(&op,state,e))return 0;
   }
   for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i){if(!operation_live(&op))return 0;if(!tracked[i].birth.id)continue;unsigned j=0;while(j<frame->projectile_count&&frame->projectiles[j].id!=tracked[i].birth.id)++j;if(j<frame->projectile_count)continue;
    uint32_t id=tracked[i].birth.id,instance=instance_serial[i];char*object=tracked[i].object;void*resource=tracked[i].resource;RemoveCall c={0};c.op=op;c.manager=*(void**)(manager+0x38);c.object=object;
    if(valid(object,0x210)){if(!operation_live(&op))return 0;if(*(void**)(object+0x14)==resource)remove_observed(&c,1);}if(!operation_live(&op))return 0;if(tracked[i].birth.id==id&&instance_serial[i]==instance)memset(tracked+i,0,sizeof tracked[i]);
   }
  }
 if(!operation_live(&op)||failed)return 0;dispatch_completed_revision=dispatch_revision;dispatch_completed=1;return 1;
}
int projectiles_finish(void){
 ProjectileOperation op=operation_capture();if(op.kind!=PROJECTILE_KEYED||!operation_live(&op)||!dispatch_quiet(&op)||!coherent_frame_valid(&op.frame.cohort,COHERENT_PHASE_BIT(COHERENT_FINISH)))return 0;SyncFrame*frame=current;
 if(is_host){
  for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i){if(!operation_live(&op))return 0;Tracked*e=tracked+i;if(!e->birth.id)continue;
   if(!valid(e->object,0x210)){if(!operation_live(&op))return 0;memset(e,0,sizeof *e);continue;}if(!operation_live(&op))return 0;if(*(void**)(e->object+0x14)!=e->resource){memset(e,0,sizeof *e);continue;}
   if(frame->projectile_count==SYNC_MAX_PROJECTILES){failed=1;break;}if(!capture(&op,&frame->projectiles[frame->projectile_count],e))return 0;if(!operation_live(&op))return 0;++frame->projectile_count;
  }
  if(!operation_live(&op))return 0;qsort(frame->projectiles,frame->projectile_count,sizeof(SyncProjectile),compare);if(!operation_live(&op))return 0;frame->combat_ready=next_id!=0;
 }
 if(!is_host){
   for(unsigned i=0;;++i){if(!operation_live(&op))return 0;if(i>=frame->shot_count)break;if(!consumed[i]){const SyncShot*s=frame->shots+i;void*owner=actor_at(s->owner,s->owner_generation);if(!operation_live(&op))return 0;record_failure(&op,3,owner,NULL,0,NULL,0,i);if(!operation_live(&op))return 0;failed=1;}}
 }
 if(!operation_live(&op))return 0;clonewars_projectile_debug[0]=frame->shot_count;clonewars_projectile_debug[1]=frame->projectile_count;clonewars_projectile_debug[5]=failed;clonewars_projectile_debug[6]=frame->sequence;clonewars_projectile_debug[10]=(uint32_t)(uintptr_t)tracked;clonewars_projectile_debug[11]=sizeof(Tracked);
 if(failed||!operation_live(&op))return 0;
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
 constructor_close();
#endif
#ifdef CLONEWARS_BASE_AIM_OBSERVER
 base_aim_close_frame();
#endif
 current=NULL;frame_bound=0;frame_complete=1;network_active=authority=0;return 1;
}
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
int projectiles_constructor_hooks_ready(void){
 const unsigned char*p=(void*)0x44e4c0;
#ifdef CONSTRUCTOR_OBSERVER_TEST
 extern const unsigned char*constructor_test_native_site;p=constructor_test_native_site;
#endif
 if(!constructor_hooks_ready||!valid(p,5)||p[0]!=0xe8)return 0;int32_t relative;memcpy(&relative,p+1,4);return(uintptr_t)(p+5)+relative==(uintptr_t)create_hook;
}
#endif
static int patch_call(uintptr_t address,uintptr_t target,void *hook) {
    unsigned char *p=(unsigned char *)address;
#ifdef PROJECTILE_COHORT_FIXTURE
    extern unsigned char*projectile_cohort_patch_site(uintptr_t);p=projectile_cohort_patch_site(address);address=(uintptr_t)p;
#endif
    if (!valid(p,5) || *p!=0xe8) return 0;int32_t relative;memcpy(&relative,p+1,4);if(address+5+relative!=target)return 0;
    DWORD old;
    if (!VirtualProtect(p,5,PAGE_EXECUTE_READWRITE,&old)) return 0;
    relative=(int32_t)((uintptr_t)hook-address-5);memcpy(p+1,&relative,4);
    FlushInstructionCache(GetCurrentProcess(),p,5); VirtualProtect(p,5,old,&old);
    return 1;
}
int projectiles_install(void) {
    InterlockedExchange(&projectile_hooks_installed,0);
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
    constructor_hooks_ready=0;
#endif
    const uintptr_t sites[]={0x85b33f,0x85ba1f,0x85be70,0x8643a1};
    if (!patch_call(0x44e4c0,0x869060,create_hook)) return 0;
    for (unsigned i=0;i<4;++i) if (!patch_call(sites[i],0x846460,remove_hook)) return 0;
    const uintptr_t fire_sites[]={0x45a98f,0x45aa31,0x45aab5,0x884b4c};
    for (unsigned i=0;i<4;++i) if (!patch_call(fire_sites[i],0x879710,fire_hook)) return 0;
    combat_observer_removal_ready();
#ifdef CLONEWARS_CONSTRUCTOR_OBSERVER
    constructor_hooks_ready=1;
#endif
    InterlockedExchange(&projectile_hooks_installed,1);return 1;
}

