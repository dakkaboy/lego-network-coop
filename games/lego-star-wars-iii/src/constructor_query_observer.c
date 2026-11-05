#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string.h>
#include "constructor_query_observer.h"
#include "constructor_query_thunk.h"
#include "constructor_observer_thunk.h"
#include "entity_sync.h"
#include "projectile_sync.h"
__declspec(dllexport) volatile LONG clonewars_constructor_query_enabled,clonewars_constructor_query_count,clonewars_constructor_query_active_scopes;
__declspec(dllexport) volatile uint32_t clonewars_constructor_query_version=3,clonewars_constructor_query_stride=sizeof(ConstructorQueryRecord),clonewars_constructor_query_capacity=CONSTRUCTOR_QUERY_CAPACITY,clonewars_constructor_query_installed;
__declspec(dllexport) volatile uint32_t clonewars_constructor_query_debug[8];
__declspec(dllexport) volatile ConstructorQueryRecord clonewars_constructor_query_records[CONSTRUCTOR_QUERY_CAPACITY];
__attribute__((used)) uintptr_t constructor_query_success=0x8c89e2,constructor_query_miss=0x8c8a8b;
static __thread ConstructorQueryScope *active_scope;
static __thread unsigned depth;
static __thread CoherentFrameToken cleanup_cohort;
static __thread RootControlLease cleanup_control;static __thread uint64_t cleanup_generation;static __thread uint32_t cleanup_kind;
static __thread uint32_t cleanup_valid,cleanup_stamp=1,cleanup_disabled;
static int cleanup_same(const CoherentFrameToken*a,const CoherentFrameToken*b){return a->owner==b->owner&&a->owner_nonce==b->owner_nonce&&a->cohort_nonce==b->cohort_nonce&&a->thread==b->thread&&a->release==b->release&&a->epoch==b->epoch&&a->sequence==b->sequence&&a->frame==b->frame;}
static int cleanup_control_same(const RootControlLease*a,const RootControlLease*b){return a->owner==b->owner&&a->owner_nonce==b->owner_nonce&&a->thread==b->thread&&a->root_serial==b->root_serial&&a->release==b->release&&a->epoch==b->epoch&&a->level==b->level&&a->delegate_esp==b->delegate_esp;}
static void cleanup_advance(void){if(cleanup_stamp==UINT32_MAX)cleanup_disabled=1;else ++cleanup_stamp;}
static void cleanup_detach(void){active_scope=NULL;if(depth)InterlockedExchangeAdd(&clonewars_constructor_query_active_scopes,-(LONG)depth);depth=0;cleanup_valid=0;cleanup_advance();}
int constructor_query_abort_cohort(const CoherentFrameToken*c){
 if(!c||c->thread!=GetCurrentThreadId()||!cleanup_valid||cleanup_kind!=CONSTRUCTOR_CAP_FRAME||!cleanup_same(c,&cleanup_cohort))return 0;
 cleanup_detach();return 1;
}

int constructor_query_abort_control(const RootControlLease*c,uint64_t generation){if(!c||c->thread!=GetCurrentThreadId()||!cleanup_valid||cleanup_kind!=CONSTRUCTOR_CAP_CONTROL||cleanup_generation!=generation||!cleanup_control_same(c,&cleanup_control))return 0;cleanup_detach();return 1;}
static volatile LONG scope_serial;
static int patched;
static int readable(const void *p,SIZE_T n){
#ifdef CONSTRUCTOR_QUERY_TEST
 extern int cq_test_readable(const void *,SIZE_T);return cq_test_readable(p,n);
#else
 MEMORY_BASIC_INFORMATION m;return p&&VirtualQuery(p,&m,sizeof m)&&m.State==MEM_COMMIT&&!(m.Protect&(PAGE_GUARD|PAGE_NOACCESS))&&(uintptr_t)p+n>=(uintptr_t)p&&(uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;
#endif
}
static uintptr_t address(uintptr_t p){
#ifdef CONSTRUCTOR_QUERY_TEST
 extern uintptr_t cq_test_address(uintptr_t);return cq_test_address(p);
#else
 return p;
#endif
}
static uint32_t word(const void *p){uint32_t x;memcpy(&x,p,4);return x;}
static uint32_t half(const void *p){uint16_t x;memcpy(&x,p,2);return x;}
static uint32_t clock_now(void){const void *p=(void*)address(0xfb4b6c);return readable(p,4)?word(p):0;}
static void stamp(uint32_t q[2]){LARGE_INTEGER x;QueryPerformanceCounter(&x);q[0]=x.LowPart;q[1]=(uint32_t)x.HighPart;}
static int query_context_valid(const ConstructorQueryScope*s){if(s->capability==CONSTRUCTOR_CAP_REJECTED)return 0;if(s->capability==CONSTRUCTOR_CAP_CONTROL)return projectiles_constructor_control_valid(&s->input.lease,&s->control,&s->control_session,s->reset_generation);return projectiles_constructor_cohort_valid(&s->input.lease,&s->cohort);}
static int scope_live(const ConstructorQueryScope *s){
 if(!s||!s->ready||s->thread!=GetCurrentThreadId()||!query_context_valid(s))return 0;
 if(s->owner_valid){const void *owner=(void*)(uintptr_t)s->input.owner_local;uint32_t slot,g;
  if(!entities_allocation_live(owner,s->owner_local_generation)||!entities_observed_identity(owner,&slot,&g)||slot!=s->owner_slot||g!=s->owner_generation||!readable(owner,0x1440)||half((char*)owner+0xdc0)!=(uint16_t)s->owner_character)return 0;
 }
 return query_context_valid(s);
}
__attribute__((used,noinline)) void cq_scope_begin_impl(ConstructorQueryScope *s,const ConstructorScope *source){
 s->ready=s->linked=0;
 if(!clonewars_constructor_query_enabled&&!active_scope)return;
 CoherentFrameToken association={0};RootControlLease control={0};uint64_t generation=0;uint32_t kind=CONSTRUCTOR_CAP_NONE;
 if(source&&source->capability==CONSTRUCTOR_CAP_CONTROL){control=source->control;generation=source->reset_generation;kind=CONSTRUCTOR_CAP_CONTROL;}
 else if(source&&source->cohort.cohort_nonce){association=source->cohort;kind=CONSTRUCTOR_CAP_FRAME;}
 else if(active_scope&&cleanup_valid){association=cleanup_cohort;control=cleanup_control;generation=cleanup_generation;kind=cleanup_kind;}
 else{ProjectileFrameLease l;if(projectiles_frame_lease_get(&l)){association=l.cohort;kind=CONSTRUCTOR_CAP_FRAME;}}
 int same_key=kind==cleanup_kind&&(kind==CONSTRUCTOR_CAP_FRAME?cleanup_same(&association,&cleanup_cohort):kind==CONSTRUCTOR_CAP_CONTROL?generation==cleanup_generation&&cleanup_control_same(&control,&cleanup_control):1);
 if(active_scope&&kind&&(!cleanup_valid||!same_key))cleanup_detach();
 if(!active_scope){cleanup_advance();cleanup_cohort=association;cleanup_control=control;cleanup_generation=generation;cleanup_kind=kind;cleanup_valid=kind!=CONSTRUCTOR_CAP_NONE;}
 /* Rejected nested invocations must shadow their parent until native return. */
 memset(s,0,sizeof *s);s->cleanup_stamp=cleanup_stamp;s->previous=active_scope;s->linked=1;s->thread=GetCurrentThreadId();active_scope=s;++depth;
 InterlockedIncrement(&clonewars_constructor_query_active_scopes);
 if(cleanup_disabled||!clonewars_constructor_query_enabled||clonewars_constructor_query_installed!=3)return;
 if(depth>32){InterlockedIncrement((volatile LONG*)&clonewars_constructor_query_debug[1]);return;}
 if(!source||!source->ready||source->record.thread!=GetCurrentThreadId()){InterlockedIncrement((volatile LONG*)&clonewars_constructor_query_debug[7]);return;}
 if(source->capability==CONSTRUCTOR_CAP_REJECTED||(source->capability==CONSTRUCTOR_CAP_CONTROL?!projectiles_constructor_control_valid(&source->record.input.lease,&source->control,&source->control_session,source->reset_generation):!projectiles_constructor_cohort_valid(&source->record.input.lease,&source->cohort))){InterlockedIncrement((volatile LONG*)&clonewars_constructor_query_debug[2]);return;}
 s->cohort=source->cohort;s->control=source->control;s->control_session=source->control_session;s->reset_generation=source->reset_generation;s->capability=source->capability;s->input=source->record.input;
 s->owner_valid=(source->record.valid&1)!=0;s->owner_slot=source->record.owner_slot;s->owner_generation=source->record.owner_generation;s->owner_local_generation=source->record.owner_local_generation;s->owner_character=source->record.owner_character;
 if(s->input.birth_known&&s->input.birth.owner>=0&&!s->owner_valid)return;
 s->ready=1;if(!scope_live(s)){s->ready=0;InterlockedIncrement((volatile LONG*)&clonewars_constructor_query_debug[2]);return;}
 LONG id=InterlockedIncrement(&scope_serial);if(!id)id=InterlockedIncrement(&scope_serial);s->id=(uint32_t)id;
 s->parent=scope_live(s->previous)?s->previous->id:0;
}
__attribute__((used,noinline)) void cq_scope_end_impl(ConstructorQueryScope *s,void *object){
 (void)object;if(!s->linked)return;
 if(s->cleanup_stamp!=cleanup_stamp){s->ready=s->linked=0;return;}
 if(active_scope!=s){InterlockedIncrement((volatile LONG*)&clonewars_constructor_query_debug[3]);return;}
 active_scope=s->previous;s->ready=s->linked=0;--depth;InterlockedDecrement(&clonewars_constructor_query_active_scopes);if(!depth)cleanup_valid=0;
}
__attribute__((naked)) void constructor_query_scope_begin(ConstructorQueryScope*s,const ConstructorScope*c){__asm__ volatile(CONSTRUCTOR_OBSERVER_THUNK_ASM("_cq_scope_begin_impl"));}
__attribute__((naked)) void constructor_query_scope_end(ConstructorQueryScope*s,void*object){__asm__ volatile(CONSTRUCTOR_OBSERVER_THUNK_ASM("_cq_scope_end_impl"));}
typedef struct QueryBinding {uint32_t scope,ordinal,thread;ConstructorLease lease;CoherentFrameToken cohort;RootControlLease control;ProjectileSessionContext control_session;uint64_t reset_generation;uint32_t capability;} QueryBinding;
static int binding_live(const QueryBinding *b){return active_scope&&active_scope->id==b->scope&&active_scope->ordinal==b->ordinal&&active_scope->thread==b->thread&&!memcmp(&active_scope->input.lease,&b->lease,sizeof b->lease)&&!memcmp(&active_scope->cohort,&b->cohort,sizeof b->cohort)&&!memcmp(&active_scope->control_session,&b->control_session,sizeof b->control_session)&&active_scope->capability==b->capability&&active_scope->reset_generation==b->reset_generation&&cleanup_control_same(&active_scope->control,&b->control)&&scope_live(active_scope);}
static int acquire(QueryBinding *b,ConstructorQueryRecord *r){
 ConstructorQueryScope*s=active_scope;if(!scope_live(s)){InterlockedIncrement((volatile LONG*)&clonewars_constructor_query_debug[4]);return 0;}
 if(!++s->ordinal){InterlockedIncrement((volatile LONG*)&clonewars_constructor_query_debug[5]);return 0;}
 *b=(QueryBinding){s->id,s->ordinal,s->thread,s->input.lease,s->cohort,s->control,s->control_session,s->reset_generation,s->capability};
 r->thread=s->thread;r->constructor_scope=s->id;r->constructor_parent_scope=s->parent;r->query_ordinal=s->ordinal;
 memcpy(&r->lease_serial,&s->input.lease,sizeof s->input.lease);
 r->constructor_kind=s->input.kind;r->constructor_caller=s->input.caller;r->birth_known=s->input.birth_known;r->shot_id=s->input.birth_known?s->input.birth.id:0;r->shot_phase=s->input.birth_known?s->input.birth.phase:0;
 r->owner_slot=s->owner_slot;r->owner_generation=s->owner_generation;r->owner_local_generation=s->owner_local_generation;r->owner_character=s->owner_character;r->owner_local=s->input.owner_local;r->input_flags=s->input.flags;r->input_weapon=s->input.weapon;
 if(s->owner_valid)r->valid_mask|=CQ_OWNER;
 return binding_live(b);
}
static int identity_word(const QueryBinding*b,uintptr_t p,uint32_t*out){
 if(!binding_live(b)||!readable((void*)p,4)||!binding_live(b))return 0;
 *out=word((void*)p);return binding_live(b);
}
static int identity_chain(const QueryBinding*b,ConstructorColliderIdentity*x){
 uint32_t value;uintptr_t d=x->descriptor_local;
 if(!identity_word(b,d,&value))return CCI_UNREADABLE;
 if(value!=0xc69eac||!identity_word(b,d+0x18,&value)||(value&255)!=1)return CCI_UNSUPPORTED_BODY;
 x->valid_mask|=2;
 if(!identity_word(b,d+0x30,&x->wrapper_local))return CCI_UNREADABLE;
 if(!x->wrapper_local)return CCI_NO_WRAPPER;
 if(!identity_word(b,x->wrapper_local,&x->wrapper_vtable_local))return CCI_UNREADABLE;
 if(x->wrapper_vtable_local!=0xc1ed6c)return CCI_UNSUPPORTED_WRAPPER;
 if(!identity_word(b,address((uintptr_t)x->wrapper_vtable_local+0x2c),&x->wrapper_class_method_local))return CCI_UNREADABLE;
 if(x->wrapper_class_method_local!=0xa32dc0)return CCI_UNSUPPORTED_WRAPPER;
 x->valid_mask|=4;
 if(!identity_word(b,(uintptr_t)x->wrapper_local+0x10,&x->nuanim_local)||!x->nuanim_local)return CCI_UNREADABLE;
 x->valid_mask|=8;
 if(!identity_word(b,(uintptr_t)x->nuanim_local+0x122c,&x->api_local)||!x->api_local)return CCI_UNREADABLE;
 x->valid_mask|=16;
 if(!identity_word(b,(uintptr_t)x->api_local+0x30,&x->userdata_local)||!x->userdata_local)return CCI_UNREADABLE;
 if(!identity_word(b,x->userdata_local,&value))return CCI_UNREADABLE;
 if(value&255)return CCI_BAD_USERDATA;
 if(!identity_word(b,(uintptr_t)x->userdata_local+4,&x->actor_local)||!x->actor_local)return CCI_UNREADABLE;
 x->valid_mask|=32;
 if(!binding_live(b))return CCI_CANCELLED;
 void*actor=(void*)(uintptr_t)x->actor_local;
 x->actor_local_generation=entities_observed_generation(actor);
 if(!x->actor_local_generation)return CCI_UNOBSERVED_ACTOR;
 if(!binding_live(b)||!entities_allocation_live(actor,x->actor_local_generation))return CCI_ALLOCATION_NOT_LIVE;
 if(!identity_word(b,(uintptr_t)actor+8,&x->actor_model_local))return CCI_UNREADABLE;
 if(x->actor_model_local!=x->api_local)return CCI_API_MISMATCH;
 if(!binding_live(b)||!readable((char*)actor+0xdc0,2)||!binding_live(b))return CCI_UNREADABLE;
 x->actor_character=half((char*)actor+0xdc0);
 if(!entities_observed_identity(actor,&x->actor_network_slot,&x->actor_network_generation)||!x->actor_network_generation||x->actor_network_slot>=SYNC_MAX_ACTORS)return CCI_UNMAPPED;
 return binding_live(b)?CCI_NONE:CCI_CANCELLED;
}
static void identity_capture(const QueryBinding*b,ConstructorQueryRecord*r){
 ConstructorColliderIdentity*x=&r->collider_identity;memset(x,0,sizeof*x);
 x->actor_network_slot=UINT32_MAX;x->clock_before=clock_now();x->sample_release_serial=b->lease.serial;
 if(!(r->native_eax&255)||!(r->valid_mask&CQ_DESCRIPTOR)){x->reason=CCI_NOT_ACCEPTED;return;}
 x->valid_mask=1;x->descriptor_local=r->selected_descriptor_local;
 x->reason=identity_chain(b,x);
 if(x->reason)return;
 if(r->selected_descriptor_raw[0]!=0xc69eac||(r->selected_descriptor_raw[6]&255)!=1||r->selected_descriptor_raw[12]!=x->wrapper_local){x->reason=CCI_CHANGED;return;}
 x->allocation_live_before=1;x->valid_mask|=64;
 ConstructorColliderIdentity again;memset(&again,0,sizeof again);again.descriptor_local=x->descriptor_local;again.valid_mask=1;
 uint32_t reason=identity_chain(b,&again);x->clock_after=clock_now();
 if(reason){x->reason=reason;return;}
 if(memcmp(&x->descriptor_local,&again.descriptor_local,13*sizeof(uint32_t))||x->clock_before!=x->clock_after||r->clock_before!=x->clock_before){x->reason=CCI_CHANGED;return;}
 if(!binding_live(b)||!entities_allocation_live((void*)(uintptr_t)x->actor_local,x->actor_local_generation)||entities_observed_generation((void*)(uintptr_t)x->actor_local)!=x->actor_local_generation){x->reason=CCI_ALLOCATION_NOT_LIVE;return;}
 x->allocation_live_after=1;x->association_kind=1;x->valid_mask=0x1ff;x->status=1;
}
static int source_span(const QueryBinding*b,uintptr_t p,SIZE_T size){return binding_live(b)&&readable((void*)p,size)&&binding_live(b);}
static uint32_t source_links(const QueryBinding*b,const ConstructorQueryRecord*r,ConstructorSourceLinks*x,uint32_t*mask,uint32_t*ordinal){
 uintptr_t d=r->selected_descriptor_local;
 if(!identity_word(b,d,&x->descriptor_vtable)||!identity_word(b,d+0x18,&x->descriptor_type_word18)||!identity_word(b,d+0x1c,&x->descriptor_name1c_raw)||!identity_word(b,d+0x28,&x->descriptor_receiver28_raw)||!identity_word(b,d+0x30,&x->descriptor_wrapper30_raw))return CQS_UNREADABLE_DESCRIPTOR;
 if(x->descriptor_vtable!=r->selected_descriptor_raw[0]||x->descriptor_type_word18!=r->selected_descriptor_raw[6]||x->descriptor_name1c_raw!=r->selected_descriptor_raw[7]||x->descriptor_receiver28_raw!=r->selected_descriptor_raw[10]||x->descriptor_wrapper30_raw!=r->selected_descriptor_raw[12])return CQS_CHANGED;
 if(x->descriptor_vtable!=0xc69eac||(x->descriptor_type_word18&255)!=1)return CQS_UNSUPPORTED_BODY;
 *mask|=2;
 uintptr_t receiver=x->descriptor_receiver28_raw;if(!receiver)return CQS_NO_RECEIVER;*mask|=4;
 if(!source_span(b,receiver,0x1a8))return CQS_UNREADABLE_RECEIVER;*mask|=8;
 if(!identity_word(b,receiver,&x->receiver_vtable))return CQS_UNREADABLE_RECEIVER;
 if(x->receiver_vtable!=0xc20b1c&&x->receiver_vtable!=0xc20f64)return CQS_UNSUPPORTED_RECEIVER;*mask|=16;
 if(!identity_word(b,receiver+0x1a0,&x->receiver_descriptor1a0_raw)||!identity_word(b,receiver+0x1a4,&x->receiver_name1a4_raw))return CQS_UNREADABLE_RECEIVER;
 if(x->receiver_descriptor1a0_raw!=r->selected_descriptor_local||x->receiver_name1a4_raw!=x->descriptor_name1c_raw)return CQS_REVERSE_PAIR_MISMATCH;*mask|=32;
 if(!identity_word(b,receiver+0x2c,&x->receiver_resource2c_raw)||!identity_word(b,receiver+0x30,&x->receiver_poi30_raw))return CQS_UNREADABLE_RECEIVER;
 if(!x->receiver_resource2c_raw||!x->receiver_poi30_raw)return CQS_NO_HANDLE;*mask|=64;
 uintptr_t resource=x->receiver_resource2c_raw;if(!source_span(b,resource,0x6fc)||!identity_word(b,resource+0x6f8,&x->resource_runtime6f8_raw))return CQS_UNREADABLE_RESOURCE;*mask|=128;
 uintptr_t runtime=x->resource_runtime6f8_raw;if(!runtime)return CQS_NO_RUNTIME;
 if(!source_span(b,runtime,0x70)||!identity_word(b,runtime+0x68,&x->runtime_count68_raw)||!identity_word(b,runtime+0x6c,&x->runtime_array6c_raw))return CQS_UNREADABLE_RUNTIME;*mask|=256;
 uint32_t count=x->runtime_count68_raw;if((int32_t)count<0)return CQS_INVALID_COUNT;if(!count)return CQS_EMPTY_TABLE;if(count>CONSTRUCTOR_SOURCE_COUNT_CAP)return CQS_COUNT_CAP;
 if(!x->runtime_array6c_raw)return CQS_NO_ARRAY;
 uint64_t end=(uint64_t)x->runtime_array6c_raw+(uint64_t)count*0xe0u;if(end>UINT32_MAX)return CQS_TABLE_OVERFLOW;*mask|=512;
 uintptr_t poi=x->receiver_poi30_raw;if(poi<x->runtime_array6c_raw||(uint64_t)poi+0xe0u>end)return CQS_RECORD_OUT_OF_RANGE;
 uint32_t offset=(uint32_t)poi-x->runtime_array6c_raw;if(offset%0xe0u)return CQS_RECORD_MISALIGNED;
 if(!source_span(b,poi,0xe0))return CQS_UNREADABLE_RECORD;*mask|=1024;*ordinal=offset/0xe0u;
 if(!identity_word(b,poi+0xd4,&x->record_bindingd4_raw)||!identity_word(b,poi+0xb4,&x->record_nameb4_raw))return CQS_UNREADABLE_RECORD;
 if(x->record_bindingd4_raw!=receiver)return CQS_D4_NOT_SELF_BOUND;
 *mask|=2048;return CQS_NONE;
}
static void source_name(const QueryBinding*b,ConstructorQuerySource*x){
 uintptr_t p=x->first.record_nameb4_raw;if(!p){x->name_flags=CQS_NAME_NULL;return;}
 for(unsigned i=0;i<sizeof x->name_raw;++i){
  if(p>UINTPTR_MAX-i||!source_span(b,p+i,1)){x->name_flags|=CQS_NAME_UNREADABLE;return;}
  unsigned char value=*(const unsigned char*)(p+i);
  x->name_flags|=CQS_NAME_PREFIX;if(!value){x->name_flags|=CQS_NAME_NUL;return;}
  x->name_raw[i]=value;x->name_size=i+1;
 }
 x->name_flags|=CQS_NAME_TRUNCATED;
}
static void source_optional(const QueryBinding*b,ConstructorQuerySource*x){
 if(!(x->valid_mask&16))return;
 uintptr_t receiver=x->first.descriptor_receiver28_raw;
 if(identity_word(b,receiver+0x14,&x->receiver14_local_raw))x->valid_mask|=1u<<14;
 if(source_span(b,receiver+0x198,1)){x->receiver198_byte_raw=*(const unsigned char*)(receiver+0x198);x->valid_mask|=1u<<15;}
 if((x->valid_mask&(1u<<14))&&x->receiver14_local_raw&&identity_word(b,x->receiver14_local_raw,&x->component_vtable_local_raw))x->valid_mask|=1u<<16;
}
static void source_capture(const QueryBinding*b,ConstructorQueryRecord*r){
 ConstructorQuerySource*x=&r->source_witness;memset(x,0,sizeof*x);x->count_cap=CONSTRUCTOR_SOURCE_COUNT_CAP;x->poi_ordinal=UINT32_MAX;x->sample_release_serial=b->lease.serial;x->clock_before=clock_now();
 if(!(r->native_eax&255)||!(r->valid_mask&CQ_DESCRIPTOR)){x->reason=CQS_NOT_ACCEPTED;x->clock_after=clock_now();return;}
 x->valid_mask=1;uint32_t first_reason=source_links(b,r,&x->first,&x->valid_mask,&x->poi_ordinal);
 source_optional(b,x);
 if(first_reason!=CQS_NONE&&first_reason!=CQS_D4_NOT_SELF_BOUND){x->reason=first_reason;x->clock_after=clock_now();return;}
 source_name(b,x);
 uint32_t second_mask=1,second_ordinal=UINT32_MAX;uint32_t second_reason=source_links(b,r,&x->second,&second_mask,&second_ordinal);x->clock_after=clock_now();
 if(first_reason!=second_reason||x->poi_ordinal!=second_ordinal||memcmp(&x->first,&x->second,sizeof x->first)){
  x->reason=CQS_CHANGED;if(x->first.record_nameb4_raw!=x->second.record_nameb4_raw)x->name_flags|=CQS_NAME_CHANGED;return;
 }
 x->valid_mask|=4096;
 if(!binding_live(b)){x->reason=CQS_CANCELLED;return;}
 if(x->clock_before!=x->clock_after||r->clock_before!=x->clock_before){x->reason=CQS_CLOCK_CHANGED;return;}
 x->valid_mask|=8192;x->association_kind=1;x->reason=first_reason;
 if(!first_reason&&(x->valid_mask&0x3fff)==0x3fff)x->status=1;
}
__attribute__((used,noinline)) void constructor_query_checkpoint(uint32_t *saved,const unsigned char *fx){
 if(!clonewars_constructor_query_enabled)return;
 ConstructorQueryRecord r;memset(&r,0,sizeof r);r.version=3;QueryBinding binding;if(!acquire(&binding,&r))return;
 stamp(r.qpc_before);r.clock_before=clock_now();r.native_ebp=saved[2];r.native_esp=(uint32_t)(uintptr_t)saved+36;r.native_esi=saved[1];r.native_eax=saved[7];r.native_control_word=half(fx);r.native_mxcsr=word(fx+24);
 const void *caller_esi=(void*)((uintptr_t)saved+40);if(readable(caller_esi,4)){r.caller_esi_raw=word(caller_esi);r.valid_mask|=CQ_CALLER_ESI;}
 const unsigned char *frame=(void*)(uintptr_t)r.native_ebp;
 if(readable(frame,0x28)){r.query_caller=word(frame+4);memcpy(r.native_arguments,frame+8,32);r.valid_mask|=CQ_FRAME_ARGS;
  if(r.query_caller==0x81e26e){r.parent_ebp=word(frame);const unsigned char *parent=(void*)(uintptr_t)r.parent_ebp;if(readable(parent,8)){r.parent_caller=word(parent+4);if(r.parent_caller==0x85aef8||r.parent_caller==0x85b029)r.valid_mask|=CQ_PARENT;}}
  const void *start=(void*)(uintptr_t)r.native_arguments[0],*displacement=(void*)(uintptr_t)r.native_arguments[1];
  if(readable(start,12)){memcpy(r.start_raw,start,12);r.valid_mask|=CQ_START;}
  if(readable(displacement,12)){memcpy(r.displacement_raw,displacement,12);r.valid_mask|=CQ_DISPLACEMENT;}
 }
 const void *query=(void*)((uintptr_t)saved+36+0x30);if(readable(query,52)){memcpy(r.query_s30_raw,query,52);r.valid_mask|=CQ_QUERY;}
 const unsigned char *g=(void*)address(0xfb9770);
 if(readable(g,0xb0)){r.result_vtable=word(g);r.fraction_raw=word(g+0x10);r.candidate_context_local=word(g+0x60);r.selected_descriptor_local=word(g+0x78);r.reported_shape_raw=word(g+0x7c);r.category_raw=g[0x80];r.subtype_raw=g[0x81];r.mask_word_raw=half(g+0x82);memcpy(r.point_raw,g+0x90,16);memcpy(r.normal_raw,g+0xa0,16);r.valid_mask|=CQ_GLOBAL;}
 if((r.native_eax&255)&&(r.valid_mask&CQ_GLOBAL)&&binding_live(&binding)){
  const unsigned char*d=(void*)(uintptr_t)r.selected_descriptor_local;
  if(readable(d,128)){memcpy(r.selected_descriptor_raw,d,128);r.valid_mask|=CQ_DESCRIPTOR;r.root_shape_local=word(d+0x24);const unsigned char*shape=(void*)(uintptr_t)r.root_shape_local;
   if(readable(shape,64)){memcpy(r.root_shape_header_raw,shape,64);r.root_shape_vtable=word(shape);r.valid_mask|=CQ_ROOT;const unsigned char*vt=(void*)(uintptr_t)r.root_shape_vtable;
    if(readable((void*)((uintptr_t)vt+0x34),12)){r.root_radius_target_local=word(vt+0x34);r.root_ray_target_local=word(vt+0x3c);r.valid_mask|=CQ_ROOT_VTABLE;}
   }
  }
 }
 identity_capture(&binding,&r);
 source_capture(&binding,&r);
 r.clock_after=clock_now();stamp(r.qpc_after);
 if(r.collider_identity.status&&r.clock_after!=r.collider_identity.clock_after){r.collider_identity.status=0;r.collider_identity.valid_mask&=0x7f;r.collider_identity.reason=CCI_CHANGED;}
 if(r.source_witness.status&&r.clock_after!=r.source_witness.clock_after){r.source_witness.status=0;r.source_witness.valid_mask&=~8192u;r.source_witness.reason=CQS_CLOCK_CHANGED;}
 if(!clonewars_constructor_query_enabled||!binding_live(&binding)){InterlockedIncrement((volatile LONG*)&clonewars_constructor_query_debug[6]);return;}
 r.id=(uint32_t)InterlockedIncrement(&clonewars_constructor_query_count);volatile ConstructorQueryRecord*out=clonewars_constructor_query_records+(r.id-1)%CONSTRUCTOR_QUERY_CAPACITY;
 out->committed=0;memcpy((void*)out,&r,sizeof r);MemoryBarrier();out->committed=r.id;
}
__attribute__((naked,used)) void constructor_query_post(void){__asm__ volatile(CONSTRUCTOR_QUERY_POST_ASM);}
int constructor_query_install(void){
 static const unsigned char expected[8]={0x84,0xc0,0x0f,0x84,0xa9,0,0,0};
 if(!projectiles_constructor_hooks_ready()){clonewars_constructor_query_installed=0;return 0;}
 unsigned char*site=(void*)0x8c89da;
#ifdef CONSTRUCTOR_QUERY_TEST
 extern unsigned char*cq_test_site;extern int cq_test_protect(void*,SIZE_T,DWORD*);site=cq_test_site;
#endif
 if(!patched){if(!readable(site,8)||memcmp(site,expected,8))return 0;DWORD old;
#ifdef CONSTRUCTOR_QUERY_TEST
  if(!cq_test_protect(site,8,&old))return 0;
#else
  if(!VirtualProtect(site,8,PAGE_EXECUTE_READWRITE,&old))return 0;
#endif
  site[0]=0xe9;uint32_t rel=(uint32_t)((uintptr_t)constructor_query_post-(uintptr_t)(site+5));memcpy(site+1,&rel,4);memset(site+5,0x90,3);FlushInstructionCache(GetCurrentProcess(),site,8);DWORD ignored;VirtualProtect(site,8,old,&ignored);patched=1;}
 if(!readable(site,8)||site[0]!=0xe9||(uintptr_t)(site+5)+*(int32_t*)(site+1)!=(uintptr_t)constructor_query_post||site[5]!=0x90||site[6]!=0x90||site[7]!=0x90){clonewars_constructor_query_installed=0;return 0;}
 clonewars_constructor_query_installed=3;return 1;
}
