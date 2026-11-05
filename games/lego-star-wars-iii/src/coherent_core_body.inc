#ifdef CLONEWARS_HIT_ENTRY_OBSERVER
#include "hit_entry_observer.h"
#define HIT_ENTRY_BOUNDARY(original) hit_entry_poll(original)
#else
#define HIT_ENTRY_BOUNDARY(original) ((void)0)
#endif
typedef struct CoreFrameDraft {
 NativeOwnerScope*owner;unsigned owner_nonce,release,host,depth_accounted,opened,bound_mask;
 CoherentFrameToken token;char*engine;void*packet;unsigned main_calls,optional_calls,expected_calls,expected_plan,published,session,control_stale;
} CoreFrameDraft;
static CoreFrameDraft core;
static CoreCohortBinding core_bindings[CORE_COHORT_COUNT];
static SpanEngineAdapter core_adapter;
static const int core_finish_order_verified=1;
static int core_dependency_install_state,core_base_install_state,core_mapping_configured;
static uint32_t core_mapping_session;static int core_owned_mapping;
static CoreMainBoundary main_boundary;
static unsigned main_boundary_serial;
static NativeOwnerScope*permission_install_owner;static uint32_t permission_install_nonce;
static int main_boundary_active;

static uint32_t core_registered;
__declspec(dllexport) volatile uint32_t clonewars_coherent_debug[20];
static uint32_t core_run_count,core_publish_count;
#include "coherent_core_bindings.inc"
int game_sync_coherent_register_cohort(CoreCohort id,const CoreCohortBinding*b){
 if((unsigned)id>=CORE_COHORT_COUNT||!b||b->version!=1||!b->ready||!b->bind_metadata||!b->valid||!b->abort_metadata||core.owner||!core_tick_thread||GetCurrentThreadId()!=core_tick_thread)return 0;
 if(core_registered&(1u<<id)){const CoreCohortBinding*p=&core_bindings[id];return p->version==b->version&&p->ready==b->ready&&p->bind_metadata==b->bind_metadata&&p->valid==b->valid&&p->abort_metadata==b->abort_metadata;}core_bindings[id]=*b;core_registered|=1u<<id;return 1;
}
uint32_t game_sync_coherent_missing(void){uint32_t missing=CORE_COHORT_ALL&~core_registered;for(unsigned i=0;i<CORE_COHORT_COUNT;++i)if((core_registered&(1u<<i))&&!core_bindings[i].ready())missing|=1u<<i;return missing;}
int game_sync_coherent_restore_pending(void){return (int)InterlockedCompareExchange(&deferred_assignment_restore,0,0);}
uint32_t game_sync_coherent_blockers(void){
 uint32_t bits=0;if(game_sync_coherent_missing())bits|=1;if(!hooked)bits|=2;if(game_sync_coherent_restore_pending())bits|=4;if(!core_tick_thread)bits|=8;if(!core_mapping_configured||!user_mapping_install_ready()||user_mapping_session_pending())bits|=512;if(core_base_install_state!=1||core_dependency_install_state!=1)bits|=16;if(!core_finish_order_verified)bits|=128;if(fault||InterlockedCompareExchange(&core_reject_bits,0,0))bits|=1024;
#if !defined(CLONEWARS_REMOTE_INPUT_TRACE_DISABLED) || defined(CLONEWARS_POSE_OBSERVER) || defined(CLONEWARS_INTENT_OBSERVER) || defined(CLONEWARS_BASE_AIM_OBSERVER) || defined(CLONEWARS_ACTION_TRANSITION_OBSERVER) || defined(CLONEWARS_CONSTRUCTOR_OBSERVER) || defined(CLONEWARS_CONSTRUCTOR_QUERY_OBSERVER)
 bits|=256;
#endif

 return bits;
}
int game_sync_coherent_register_actual_modules(void){
 if(core.owner||!core_tick_thread||GetCurrentThreadId()!=core_tick_thread)return 0;
 for(unsigned i=0;i<CORE_COHORT_COUNT;++i)if(!game_sync_coherent_register_cohort((CoreCohort)i,&core_actual_bindings[i]))return 0;
 return 1;
}
static int core_live(void){
 if(!core.opened||core.session!=lan_session_serial()||!core.owner||GetCurrentThreadId()!=core_tick_thread||release_changed(core.release)||InterlockedCompareExchange(&core_reject_bits,0,0)||!coherent_frame_valid(&core.token,COHERENT_ALL_PHASES))return 0;
 for(unsigned i=0;i<CORE_COHORT_COUNT;++i)if((core.bound_mask&(1u<<i))&&!core_bindings[i].valid(&core.token,COHERENT_ALL_PHASES))return 0;
 return 1;
}
static int core_dispatch_authority(void){return core.opened&&core_live()&&coherent_frame_valid(&core.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH));}
static int core_capture_dispatch(CoherentFrameToken*out){if(!out||!core_live()||!coherent_frame_valid(&core.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;*out=core.token;return 1;}
static void core_reject_atomic(unsigned why,void*unused){(void)unused;InterlockedOr(&core_reject_bits,1u<<(why%31));InterlockedExchange(&deferred_assignment_restore,1);coherent_frame_cancel_atomic(1u<<(why%31));}
static int core_session_tag(TagSessionContext*out){
 if(!out||!core_window_thread||GetCurrentThreadId()!=core_window_thread)return 0;
 out->session=lan_session_serial();out->epoch=interval.active?interval.epoch:0;out->level=game_current_level();
 if(lan_status()!=LAN_CONNECTED){out->classification=TAG_SESSION_OFFLINE;return 1;}
 if(!out->session||out->session==UINT32_MAX)return 0;
 if(fault||InterlockedCompareExchange(&core_reject_bits,0,0)){out->classification=TAG_SESSION_UNAVAILABLE;return 1;}
 int pending=*(int*)0xe6e61c;int target=game_network_target_level();
 if(pending>=0||(target>=0&&target!=out->level)){out->classification=TAG_SESSION_TRANSITION;return 1;}
 char*root=*(char**)0xfb2e60;
 NativeOwnerScope*current_owner=native_owner_current();
 int install_root=current_owner==permission_install_owner&&current_owner&&native_owner_scope_nonce(current_owner)==permission_install_nonce;
 int permitted=game_actor_count()>0&&initialized_level==out->level&&observed_lan_session==out->session&&core_dependency_install_state==1&&!install_root&&!core.control_stale&&interval.active&&interval.epoch&&interval.level==out->level&&valid(root,0x1b7c)&&*(int*)(root+0x1b78)==0xe&&game_native_profile_ready()&&game_network_profile_ready()&&game_network_level_authorized(out->level)&&game_load_status()!=1;
 out->classification=permitted?TAG_SESSION_ESTABLISHED:TAG_SESSION_BOOTSTRAP;return out->session==lan_session_serial();
}
static int core_session_projectile(ProjectileSessionContext*out,void*user){
 (void)user;TagSessionContext t;if(!out||!core_session_tag(&t))return 0;
 out->epoch=t.epoch;out->level=t.level;out->host=lan_is_host();out->session=t.session;
 switch(t.classification){case TAG_SESSION_OFFLINE:out->classification=PROJECTILE_SESSION_OFFLINE;break;case TAG_SESSION_BOOTSTRAP:out->classification=PROJECTILE_SESSION_BOOTSTRAP;break;case TAG_SESSION_TRANSITION:out->classification=PROJECTILE_SESSION_TRANSITION;break;case TAG_SESSION_ESTABLISHED:out->classification=PROJECTILE_SESSION_ESTABLISHED;break;default:out->classification=PROJECTILE_SESSION_FAULT;break;}return 1;
}
static void core_projectile_reject(unsigned why,const ProjectileRejectContext*context,void*user){(void)context;core_reject_atomic(why,user);}
static int core_patch_call(uintptr_t address,uintptr_t original,void*replacement){
 unsigned char*p=(unsigned char*)address;if(!valid(p,5)||p[0]!=0xe8||address+5+*(int32_t*)(p+1)!=original)return 0;
 DWORD old;if(!VirtualProtect(p,5,PAGE_EXECUTE_READWRITE,&old))return 0;
 int32_t relative=(int32_t)((uintptr_t)replacement-address-5);memcpy(p+1,&relative,4);
 int ok=FlushInstructionCache(GetCurrentProcess(),p,5);DWORD ignored;if(!VirtualProtect(p,5,old,&ignored))ok=0;return ok;
}
static int core_install_base(void){
 if(core_base_install_state)return core_base_install_state>0;core_base_install_state=-1;
 const uintptr_t sites[]={0x889fa0,0x8889ba,0x58f4c6,0x58f5e7,0x5e2a15,0x634a95,0x755347,0x9c53fd,0x9c33bf,0x9c53f7};
 const uintptr_t originals[]={0x889640,0x887ac0,0x57b340,0x57b340,0x57b340,0x57b340,0x57b340,0x9ab020,0x9ab020,0x8b0f90};
 void*hooks[]={tick_hook,world_hook,device_refresh,device_refresh,device_refresh,device_refresh,device_refresh,actor_prepare_normal,actor_prepare_alternate,actor_ai_normal_hook};
 for(unsigned i=0;i<10;++i){unsigned char*p=(unsigned char*)sites[i];if(!valid(p,5)||p[0]!=0xe8||sites[i]+5+*(int32_t*)(p+1)!=originals[i])return 0;}
 for(unsigned i=0;i<10;++i)if(!core_patch_call(sites[i],originals[i],hooks[i]))return 0;
 InterlockedExchange(&clonewars_input_prep_installed,7);core_base_install_state=1;return 1;
}
static int core_mapping_source_valid(const void*p,uint32_t n){return game_sync_main_boundary_valid(p,n,NULL);}
static uint32_t core_mapping_current_session(void*unused){(void)unused;return lan_session_serial();}
static int core_mapping_install_allowed(void*unused){(void)unused;NativeOwnerScope*owner=native_owner_current();return GetCurrentThreadId()==core_window_thread&&!core.owner&&owner&&native_owner_scope_valid(owner,native_owner_scope_nonce(owner));}
static int core_mapping_install(void){
 if(core_mapping_configured)return user_mapping_install_ready();
 UserMappingInstallConfig install={core_window_thread,core_mapping_source_valid,core_mapping_install_allowed,NULL};
 if(!user_mapping_install_safe(&install))return 0;
 UserMappingSessionConfig session={1,core_window_thread,game_sync_main_boundary_valid,core_mapping_current_session,NULL};
 if(!user_mapping_session_configure(&session))return 0;core_mapping_configured=1;return 1;
}
static int core_install_safe(void*engine,const NativeOwnerInput*input,void*user){
 (void)engine;(void)user;
 if(!input||GetCurrentThreadId()!=core_window_thread||core.owner||native_owner_current()==NULL)return 0;
 if(!core_mapping_install()||!camera_install_qualified_main()||!core_install_base()){core_reject_atomic(24,NULL);return 0;}
 if(!core_tick_thread)return 1;
 if(core_tick_thread!=core_window_thread)return 0;
 if(!core_dependency_install_state){
  core_dependency_install_state=-1;
  if(!tags_configure_coherent(&core_adapter,core_session_tag)||!projectiles_configure_coherent(&core_adapter,core_session_projectile,core_projectile_reject,NULL))return 0;
  if(!entities_install())return 0;core_module_install_mask|=(1u<<CORE_NPC)|(1u<<CORE_WORLD_VARS);
  if(!tags_install())return 0;core_module_install_mask|=1u<<CORE_TAG;
  if(!projectiles_install())return 0;core_module_install_mask|=1u<<CORE_PROJECTILES;
  if(!spawn_observer_install()||!combat_observer_install()||!collision_observer_install())return 0;core_module_install_mask|=1u<<CORE_GEOMETRY;
  if(!cadence_install())return 0;core_module_install_mask|=1u<<CORE_CADENCE;
  if(!reaction_install())return 0;core_module_install_mask|=1u<<CORE_REACTION;
  if(!model_input_install())return 0;core_module_install_mask|=1u<<CORE_MODEL;
  if(!game_sync_coherent_register_actual_modules())return 0;
  core_dependency_install_state=1;hooked=1;permission_install_owner=native_owner_current();permission_install_nonce=native_owner_scope_nonce(permission_install_owner);
 }
 return core_dependency_install_state>0;
}
static int core_dependencies_ready(void*user){(void)user;uint32_t blockers=game_sync_coherent_blockers();clonewars_coherent_debug[0]=blockers;clonewars_coherent_debug[1]=core_adapter.installer.state;clonewars_coherent_debug[2]=core_adapter.installer.ready&&!core_adapter.sticky&&!blockers&&GetCurrentThreadId()==core_window_thread&&core_tick_thread==core_window_thread;clonewars_coherent_debug[3]=core_base_install_state;clonewars_coherent_debug[4]=core_dependency_install_state;clonewars_coherent_debug[5]=core_tick_thread;clonewars_coherent_debug[6]=core_window_thread;clonewars_coherent_debug[7]=coherent_frame_release();clonewars_coherent_debug[8]=core_reject_bits;clonewars_coherent_debug[9]=core_run_count;clonewars_coherent_debug[10]=core_publish_count;clonewars_coherent_debug[11]=core_registered;clonewars_coherent_debug[12]=lan_session_serial();clonewars_coherent_debug[13]=fault;clonewars_coherent_debug[17]=user_mapping_install_ready()?127:0;clonewars_coherent_debug[18]=user_mapping_session_pending();clonewars_coherent_debug[19]=core_module_install_mask;return blockers==0;}
static int core_control_context(SpanControlContext*out,void*user){(void)user;TagSessionContext t;if(!out||!core_session_tag(&t))return 0;*out=(SpanControlContext){t.epoch,t.level,t.classification==TAG_SESSION_ESTABLISHED};return 1;}
static int core_main_confirmed(DWORD thread,void*user){(void)user;return thread==core_tick_thread&&thread==core_window_thread;}
static int core_plan(const OwnerU32*b,char*engine,uint32_t*out){
 void*framework=(void*)(uintptr_t)b[7];if(!valid(engine,0xe34)||!valid(framework,0x2c)||*(void**)0xfb0b70!=framework)return 0;
 unsigned early=(b[8]&0x40u)!=0;if(!early)early=*(void**)((char*)framework+0x28)==NULL;
 *out=(early?CORE_PLAN_EARLY:0)|(*(void**)0xfb0b60?CORE_PLAN_OPTIONAL:0)|(*(uint32_t*)(engine+0xe28)?CORE_PLAN_MAIN:0);return 1;
}
static int core_open(NativeOwnerScope*owner,unsigned nonce){
 if(!coherent_frame_open(&core.token,owner,nonce,&working,working.epoch,working.sequence,coherent_frame_release()))return 0;core.opened=1;
 for(unsigned i=0;i<CORE_COHORT_COUNT;++i){core.bound_mask|=1u<<i;if(!core_bindings[i].bind_metadata(&core.token)||!core_live())return 0;}return core_live();
}
static int core_prepare_session_mapping(CoreMainBoundary*boundary,int*requested){
 *requested=0;if(!game_sync_main_boundary_valid(boundary,sizeof *boundary,NULL)||!core_mapping_configured)return 0;
 uint32_t session=lan_session_serial();int connected=lan_status()==LAN_CONNECTED;
 if(core_mapping_session&&(!connected||session!=core_mapping_session)){
  user_mapping_session_retire(core_mapping_session,1);core_mapping_session=0;core_owned_mapping=0;
  assignment_lease_remap(assignment_lease_version());memset(remote_device,0,sizeof remote_device);InterlockedExchange(&deferred_assignment_restore,1);
 }
 if(game_sync_coherent_restore_pending()){
  for(unsigned slot=0;slot<2;++slot){if(!game_sync_main_boundary_valid(boundary,sizeof *boundary,NULL))return 0;release_assignment(slot);}
  if(!game_sync_main_boundary_valid(boundary,sizeof *boundary,NULL))return 0;
  InterlockedExchange(&deferred_assignment_restore,0);
  if(!game_sync_main_boundary_valid(boundary,sizeof *boundary,NULL)){InterlockedExchange(&deferred_assignment_restore,1);return 0;}
 }
 if(connected&&session&&session!=UINT32_MAX){if(!user_mapping_session_begin(session))return 0;core_mapping_session=session;}
 for(unsigned n=0;user_mapping_session_pending()&&n<UM_SESSION_CAPACITY;++n){
  if(!game_sync_main_boundary_valid(boundary,sizeof *boundary,NULL))return 0;
  int result=user_mapping_session_drain(boundary,sizeof *boundary,session);
  if(result==UM_DRAIN_UNPROVED||result==UM_DRAIN_CONSUMED_UNWIND){core_reject_atomic(30,NULL);return 0;}
  if(result==UM_DRAIN_DEFERRED||result==UM_DRAIN_RESTORED_RECHECK)return 0;
 }
 if(user_mapping_session_pending()||!game_sync_main_boundary_valid(boundary,sizeof *boundary,NULL))return 0;
 if(!connected)return 1;
 TagSessionContext status;if(!core_session_tag(&status))return 0;
 if(status.classification==TAG_SESSION_ESTABLISHED&&*(int*)0xeb1a78<0&&*(unsigned char*)(0xead928+13*0x90)){
  UserMappingRequest request={.user=1,.requested=13,.saved_negative=*(int*)0xeb1a78};
  request.source.epoch=interval.epoch;request.source.level=interval.level;request.source.release=boundary->release;request.source.owner_nonce=boundary->owner_nonce;request.source.assignment=(uint32_t)assignment_lease_serial;
  request.source.proof_bytes=sizeof *boundary;memcpy(request.source.proof,boundary,sizeof *boundary);
  UserMappingKey key;*requested=1;
  int acquired=user_mapping_session_owned_request(session,&request,&key);
  if(!game_sync_main_boundary_valid(boundary,sizeof *boundary,NULL))return 0;
  if(!acquired){core_reject_atomic(30,NULL);return 0;}core_owned_mapping=1;
 }
 if(core_owned_mapping){UserMappingObservation current;if(!user_mapping_session_device_get(session,&current))return 0;}
 return game_sync_main_boundary_valid(boundary,sizeof *boundary,NULL);
}
static int core_poll_witness_same(const OwnerU32*b,void*receiver,uint32_t release,uint32_t session,uint32_t epoch,int level){
 void*framework=(void*)(uintptr_t)b[7];unsigned saved_bit=(b[8]&0x40u)?0:2;
 return coherent_frame_release()==release&&lan_session_serial()==session&&interval.epoch==epoch&&interval.level==level&&*(void**)0xfb0afc==receiver&&*(void**)0xfb0b70==framework&&valid(framework,0x4e)&&(*(unsigned char*)((char*)framework+0x4d)&2)==saved_bit;
}
static unsigned core_prepare(NativeOwnerScope*owner,unsigned nonce,void*packet,void*receiver,const OwnerU32*b,const void*fx,unsigned ready_snapshot,void*user){
 (void)fx;(void)user;(void)ready_snapshot;if(core.owner){core_reject_atomic(28,NULL);return CORE_SPAN_SKIP;}
 core=(CoreFrameDraft){.owner=owner,.owner_nonce=nonce,.engine=receiver,.packet=packet,.depth_accounted=1};++outer_depth;
 if(!main_boundary_serial||main_boundary_serial!=UINT32_MAX){if(main_boundary_serial==UINT32_MAX-1){core_reject_atomic(26,NULL);return CORE_SPAN_SKIP;}++main_boundary_serial;}
 main_boundary=(CoreMainBoundary){owner,nonce,GetCurrentThreadId(),coherent_frame_release(),main_boundary_serial};main_boundary_active=1;
 uint32_t old_release=coherent_frame_release(),old_session=lan_session_serial(),old_epoch=interval.epoch;int old_level=interval.level;
 SpanControlContext permission_before={0};core_control_context(&permission_before,NULL);
 int requested_mapping=0;
 if(!core_prepare_session_mapping(&main_boundary,&requested_mapping)){main_boundary_active=0;return CORE_SPAN_SKIP;}
 loading_poll();game_poll();game_native_tick();
 main_boundary_active=0;
 SpanControlContext permission_after={0};core_control_context(&permission_after,NULL);
 if(permission_before.epoch!=permission_after.epoch||permission_before.level!=permission_after.level||permission_before.established!=permission_after.established){core.control_stale=1;return CORE_SPAN_SKIP;}
 if(requested_mapping){core.control_stale=1;return CORE_SPAN_SKIP;}
 if(!core_poll_witness_same(b,receiver,old_release,old_session,old_epoch,old_level)){core.control_stale=1;return CORE_SPAN_SKIP;}
 if(!ready_snapshot){TagSessionContext warm;if(!core_session_tag(&warm))return CORE_SPAN_SKIP;return warm.classification==TAG_SESSION_OFFLINE||warm.classification==TAG_SESSION_BOOTSTRAP||warm.classification==TAG_SESSION_TRANSITION?CORE_SPAN_PASS:CORE_SPAN_SKIP;}
 char*engine=receiver;char*root=*(char**)0xfb2e60;
 if(!valid(root,0x1b7c)||*(int*)(root+0x1b78)!=0xe||*(int*)0xe6e61c>=0||lan_status()!=LAN_CONNECTED||!player(0)||!controller(1))return CORE_SPAN_PASS;
 int level=game_current_level();if(initialized_level!=level)return CORE_SPAN_PASS;
 if(!hooked||!valid(packet,0x18)||!global_step_packet_valid(*(uint32_t*)packet,*(uint32_t*)((char*)packet+4),*(float*)((char*)packet+8))||!valid(engine,0xe34))return CORE_SPAN_SKIP;
 if(game_sync_coherent_blockers()||InterlockedCompareExchange(&core_reject_bits,0,0))return CORE_SPAN_SKIP;
 if(!game_network_level_authorized(level)){lan_publish_ready(0);return CORE_SPAN_SKIP;}lan_publish_ready(game_network_profile_ready());
 if(!game_network_profile_ready()||!interval.active||interval.level!=level||!interval.epoch||fault||lan_remote_level()!=level||!lan_peer_ready())return CORE_SPAN_SKIP;
 RootControlLease admission_control;if(!span_engine_control_get(&core_adapter,&admission_control)){core.control_stale=1;return CORE_SPAN_SKIP;}
 sample_wait_input();if(!span_engine_control_valid(&core_adapter,&admission_control))return CORE_SPAN_SKIP;uint32_t callback_release_token=release_token();core.release=callback_release_token;core.host=lan_is_host();core.session=lan_session_serial();
 if(core.host){
  interval.sequence=sequence;if(sync_epoch_unacknowledged(&interval,lan_epoch(),lan_peer_ack())>=8)return CORE_SPAN_SKIP;
  memset(&working,0,sizeof working);working.epoch=interval.epoch;working.sequence=++sequence;working.level=level;interval.sequence=sequence;interval_started=1;
  working.clock=*(uint32_t*)0xfb4b6c;working.rng_game=*(uint32_t*)0xe637b4;working.rng_engine=*(uint32_t*)0xea178c;working.delta=*(float*)0xfb4b74;working.engine_delta=*(float*)((char*)packet+8);working.engine_mode=*(uint32_t*)(engine+0xe30);
 }else{
  if(!lan_receive_frame(&working))return CORE_SPAN_SKIP;
  if(sync_epoch_apply(&interval,level,working.epoch,working.level,working.sequence)<=0){fault=4;return CORE_SPAN_SKIP;}expected=working.sequence;interval_started=1;
  if(*(uint32_t*)(engine+0xe30)!=working.engine_mode){fault=12;return CORE_SPAN_SKIP;}core.expected_calls=working.native_span_calls;core.expected_plan=working.native_span_plan;
 }
 if(release_changed(callback_release_token)||!core_open(owner,nonce))return CORE_SPAN_SKIP;
 if(!core.host){
  /* Restore the host context before Tag/world/native preparation, not after it. */
  *(uint32_t*)0xfb4b6c=working.clock;*(uint32_t*)0xe637b4=working.rng_game;*(uint32_t*)0xea178c=working.rng_engine;*(float*)0xfb4b74=working.delta;*(float*)((char*)packet+8)=working.engine_delta;*(uint32_t*)((char*)packet+0xc)=working.engine_mode;*(float*)(engine+0xe0c)=working.engine_delta;
 }
 if(core.host){
        int world_ready=world_vars_collect(&working);
        if (!core_live()) { return CORE_SPAN_SKIP; }
        if (!world_ready) { if (!fault) fault=6;return CORE_SPAN_SKIP; }
        if (!core_live()) { return CORE_SPAN_SKIP; }
        int tags_started=tags_begin(&working,1);
        if (!core_live() || tags_started==TAG_FRAME_CANCELLED) { return CORE_SPAN_SKIP; }
        if (tags_started!=TAG_FRAME_OK) { if (!fault) fault=9;return CORE_SPAN_SKIP; }
        int projectiles_started=projectiles_begin(&working,1);
        if (!projectiles_started || !core_live()) { return CORE_SPAN_SKIP; }
        if(!core_live())return CORE_SPAN_SKIP;
        if(!geometry_begin(&working,lan_is_host()))return CORE_SPAN_SKIP;
        if(!core_live())return CORE_SPAN_SKIP;
        if(!cadence_begin(&working,lan_is_host()))return CORE_SPAN_SKIP;
        if(!core_live())return CORE_SPAN_SKIP;
        if(!model_input_begin(&working,lan_is_host()))return CORE_SPAN_SKIP;
        if(!core_live())return CORE_SPAN_SKIP;
        if(!npc_input_begin(&npc_inputs,&working,lan_is_host()))return CORE_SPAN_SKIP;
        if(!core_live())return CORE_SPAN_SKIP;
        if(!reaction_begin(&working,lan_is_host()))return CORE_SPAN_SKIP;

 }else{
        int tags_started=tags_begin(&working,0);
        if (!core_live() || tags_started==TAG_FRAME_CANCELLED) { return CORE_SPAN_SKIP; }
        if (tags_started!=TAG_FRAME_OK) { if (!fault) fault=9;return CORE_SPAN_SKIP; }
        int world_ready=world_vars_apply(&working);
        if (!core_live()) { return CORE_SPAN_SKIP; }
        if (!world_ready) { tags_cancel();if (!fault) fault=6;return CORE_SPAN_SKIP; }
        entities_bind(&working);
        if(!core_live())return CORE_SPAN_SKIP;
        int projectiles_started=projectiles_begin(&working,0);
        if (!projectiles_started || !core_live()) { return CORE_SPAN_SKIP; }
        if(!core_live())return CORE_SPAN_SKIP;
        if(!geometry_begin(&working,lan_is_host()))return CORE_SPAN_SKIP;
        if(!core_live())return CORE_SPAN_SKIP;
        if(!cadence_begin(&working,lan_is_host()))return CORE_SPAN_SKIP;
        if(!core_live())return CORE_SPAN_SKIP;
        if(!model_input_begin(&working,lan_is_host()))return CORE_SPAN_SKIP;
        if(!core_live())return CORE_SPAN_SKIP;
        if(!npc_input_begin(&npc_inputs,&working,lan_is_host()))return CORE_SPAN_SKIP;
        if(!core_live())return CORE_SPAN_SKIP;
        if(!reaction_begin(&working,lan_is_host()))return CORE_SPAN_SKIP;

 }
 if(!core_live())return CORE_SPAN_SKIP;
 uint32_t actual_plan;
 /* Native TEST has already run. Compare gates after prep using its SAVED ZF/EAX;
    optional and main execution are observed later, not inferred from this snapshot. */
 if(!core_plan(b,engine,&actual_plan))return CORE_SPAN_SKIP;
 if(core.host)working.native_span_plan=actual_plan;else if(actual_plan!=core.expected_plan){fault=11;return CORE_SPAN_SKIP;}
 global_step=(GlobalStepState){0};core.main_calls=core.optional_calls=0;clonewars_coherent_debug[14]=clonewars_coherent_debug[15]=0;clonewars_coherent_debug[16]=actual_plan;
 if(!coherent_frame_set_phase(&core.token,COHERENT_DISPATCH)||!core_live())return CORE_SPAN_SKIP;
#ifdef CLONEWARS_HIT_ENTRY_OBSERVER
 HIT_ENTRY_BOUNDARY(&core.token);
 if(!core_live()||!coherent_frame_valid(&core.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return CORE_SPAN_SKIP;
#endif
 running=1;++core_run_count;action_dispatch_open(callback_release_token);return CORE_SPAN_RUN;
}
static void core_marker(NativeOwnerScope*owner,unsigned nonce,unsigned kind,void*unused){(void)unused;if(owner!=core.owner||nonce!=core.owner_nonce||!core_live())return;if(kind==1)++core.main_calls;else if(kind==2)++core.optional_calls;clonewars_coherent_debug[14]=core.main_calls;clonewars_coherent_debug[15]=core.optional_calls;if(core.main_calls>1||core.optional_calls>1)core_reject_atomic(27,NULL);}
static int core_drain_dispatch(void){
 for(unsigned cycle=0;cycle<SYNC_MAX_SHOTS+SYNC_MAX_TAGS+1u;++cycle){
  if(!core_live()||!coherent_frame_valid(&core.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;
  uint64_t projectile_before,tag_before,projectile_after,tag_after;
  if(!projectiles_dispatch_revision(&core.token,&projectile_before)||!tags_dispatch_revision(&core.token,&tag_before))return 0;
  int projectile_pending=projectiles_dispatch_pending(),tag_pending=tags_dispatch_pending();
  if(projectile_pending<0||tag_pending<0)return 0;
  if(!projectile_pending&&!tag_pending)return 1;
  if(projectile_pending&&!projectiles_dispatch_complete())return 0;
  if(!core_live())return 0;
  tag_pending=tags_dispatch_pending();if(tag_pending<0)return 0;
  if(tag_pending&&tags_dispatch_complete()!=TAG_FRAME_OK)return 0;
  if(!core_live())return 0;
  projectile_pending=projectiles_dispatch_pending();tag_pending=tags_dispatch_pending();
  if(projectile_pending<0||tag_pending<0)return 0;
  if(!projectile_pending&&!tag_pending)return 1;
  if(!projectiles_dispatch_revision(&core.token,&projectile_after)||!tags_dispatch_revision(&core.token,&tag_after))return 0;
  if(projectile_before==projectile_after&&tag_before==tag_after)return 0;
 }
 return 0;
}
static void core_finish(NativeOwnerScope*owner,unsigned nonce,void*unused){
 (void)unused;if(owner!=core.owner||nonce!=core.owner_nonce||!core_live())return;
 uint32_t callback_release_token=core.release;
 action_dispatch_close();running=0;
 if(!core_finish_order_verified||!core_drain_dispatch()){core_reject_atomic(29,NULL);return;}
 if(!core.host){
  if(working.level==12&&!reaction_drain_arena()){if(!fault)fault=17;return;}
  if(!core_live())return;
  POSE_BOUNDARY(POSE_CLIENT_PRE_CORRECT);
  if(!core_live())return;
  int actors_ok=correct_actors(&working);
  if(!core_live())return;
  if(!actors_ok){if(!fault)fault=5;return;}
  POSE_BOUNDARY(POSE_CLIENT_POST_CORRECT);
  clonewars_coherent_debug[16]|=0x80000000u;
  if(projectiles_dispatch_pending()!=0||tags_dispatch_pending()!=0){core_reject_atomic(29,NULL);return;}
 }
 if(!coherent_frame_set_phase(&core.token,COHERENT_FINISH)||!core_live())return;
 unsigned actual_calls=(core.main_calls?SYNC_NATIVE_SPAN_MAIN_CALL:0)|(core.optional_calls?SYNC_NATIVE_SPAN_OPTIONAL_CALL:0);
 if(core.main_calls>1||core.optional_calls>1){fault=11;return;}if(core.host)working.native_span_calls=actual_calls;else if(actual_calls!=core.expected_calls){fault=11;return;}
 if(core.host){
        POSE_BOUNDARY(POSE_HOST_DISPATCH_COMPLETE);
        if (prep_gate_depth) { prep_fail(4,prep_gates[prep_gate_depth-1].actor,NULL);prep_gate_depth=0; }
        int reaction_ok=reaction_finish();if(!core_live())return;if(!reaction_ok&&!fault)fault=17;
        if(!core_live())return;
        int geometry_ok=geometry_finish();if(!core_live())return;if(!geometry_ok&&!fault)fault=15;
        if(!core_live())return;
        int model_input_ok=model_input_finish();if(!core_live())return;if(!model_input_ok&&!fault)fault=20;
        if(!core_live())return;
        int cadence_ok=cadence_finish();if(!core_live())return;if(!cadence_ok&&!fault)fault=14;
        if(!core_live())return;
        int npc_ok=npc_input_finish(&npc_inputs);if(!core_live())return;if(!npc_ok){++clonewars_npc_input_debug[13];if(!fault)fault=13;}
        ++clonewars_npc_input_debug[12];
        working.world_calls=global_step.worlds; working.tick_calls=global_step.ticks;
        if(!core_live())return;
        int tags_ready=tags_finish();
        if (tags_ready==TAG_FRAME_CANCELLED || !core_live() || model_input_cancelled()) { return; }
        if (tags_ready!=TAG_FRAME_OK && !fault) fault=9;
        if (model_input_cancelled()) { return; }
        if(!core_live())return;
        uint32_t projectile_finish_serial=projectiles_lifecycle_serial();
        int projectiles_ready=projectiles_finish();
        if (projectiles_lifecycle_serial()!=projectile_finish_serial || !core_live() || model_input_cancelled()) { return; }
        if (!projectiles_ready && !fault) fault=8;
        if(!core_live())return;
        working.rng_game_after=*(uint32_t *)0xe637b4; working.rng_engine_after=*(uint32_t *)0xea178c;
        if(!core_live())return;
        if(!coherent_frame_set_phase(&core.token,COHERENT_COLLECT)||!core_live())return;
        if (!collect_actors(&working) && core_live() && !fault) fault=3;
        if (!fault && core_live() && !model_input_cancelled()) POSE_BOUNDARY(POSE_HOST_COLLECT_COMPLETE);
        if(!core_live())return;
        remote_input_trace_finish((unsigned)fault,player(1));
        if(!coherent_frame_set_phase(&core.token,COHERENT_PUBLISH)||!core_live())return;
        if (!fault && core_live() && !model_input_cancelled()) {
            int sent=lan_send_frame(&working);if(!core_live())return;if(!sent)fault=3;
            else {core.published=1;++core_publish_count;combat_observer_frame_queued(working.epoch,working.sequence);}
        }

 }else{
        POSE_BOUNDARY(POSE_CLIENT_DISPATCH_COMPLETE);
        if (prep_gate_depth) { prep_fail(4,prep_gates[prep_gate_depth-1].actor,NULL);prep_gate_depth=0; }
        int reaction_ok=reaction_finish();if(!core_live())return;if(!reaction_ok&&!fault)fault=17;
        if(!core_live())return;
        int geometry_ok=geometry_finish();if(!core_live())return;if(!geometry_ok&&!fault)fault=15;
        if(!core_live())return;
        int model_input_ok=model_input_finish();if(!core_live())return;if(!model_input_ok&&!fault)fault=20;
        if(!core_live())return;
        int cadence_ok=cadence_finish();if(!core_live())return;if(!cadence_ok&&!fault)fault=14;
        if(!core_live())return;
        int npc_ok=npc_input_finish(&npc_inputs);if(!core_live())return;if(!npc_ok){++clonewars_npc_input_debug[13];if(!fault)fault=13;}
        ++clonewars_npc_input_debug[12];
        if (!global_step_matches(&global_step,working.world_calls,working.tick_calls) && !fault) fault=10;
        if(!core_live())return;
        int tags_ready=tags_finish();
        if (tags_ready==TAG_FRAME_CANCELLED || !core_live() || model_input_cancelled()) { return; }
        int actors_ready=tags_ready==TAG_FRAME_OK;
        if(!core_live())return;
        uint32_t projectile_finish_serial=projectiles_lifecycle_serial();
        int projectiles_ready=projectiles_finish();
        if (projectiles_lifecycle_serial()!=projectile_finish_serial || !core_live() || model_input_cancelled()) { return; }
        if (!projectiles_ready && !fault) fault=8;
        if (tags_ready!=TAG_FRAME_OK && !fault) fault=9;
        else if (!actors_ready && !fault) fault=5;
        if(!core_live())return;
        remote_input_trace_finish((unsigned)fault,player(1));
        if(!coherent_frame_set_phase(&core.token,COHERENT_PUBLISH)||!core_live())return;
        if (!fault && core_live() && !model_input_cancelled()) { *(uint32_t *)0xe637b4=working.rng_game_after; *(uint32_t *)0xea178c=working.rng_engine_after; }
        if (!fault && core_live() && !model_input_cancelled()) {lan_publish_ack(expected);if(core_live()){core.published=1;++core_publish_count;}}

 }
 if(!core_live())return;
 camera_select(core.host?0:1);
}
static void core_end(NativeOwnerScope*owner,unsigned nonce,NativeOwnerExit why,unsigned aborted,void*unused){
 (void)unused;if(owner!=core.owner||nonce!=core.owner_nonce)return;
 /* Only captured metadata is touched here; packet/actor/controller may be retired. */
 main_boundary_active=0;running=0;action_dispatch_close();
 if(core.opened){
  while(prep_gate_depth){const PrepGate*g=&prep_gates[prep_gate_depth-1];if(!core_token_same(&g->cohort,&core.token))break;--prep_gate_depth;}
  if(!core.published&&core.session==lan_session_serial()&&core.token.epoch==interval.epoch){InterlockedOr(&core_reject_bits,0x40000000);InterlockedExchange(&deferred_assignment_restore,1);coherent_frame_cancel_atomic(0x40000000);}
  if(aborted||why==OWNER_UNWIND||core.token.release!=coherent_frame_release()||release_changed(core.release)||InterlockedCompareExchange(&core_reject_bits,0,0)){coherent_frame_cancel_atomic(1u);InterlockedExchange(&deferred_assignment_restore,1);}
  for(unsigned i=0;i<CORE_COHORT_COUNT;++i)if(core.bound_mask&(1u<<i))core_bindings[i].abort_metadata(&core.token);
  coherent_frame_close(&core.token);
 }
 if(core.depth_accounted&&outer_depth)--outer_depth;
 memset(&core,0,sizeof core);
}
static void core_lan_invalidate(uint32_t session,void*unused){(void)session;(void)unused;coherent_frame_cancel_atomic(0x08000000);}
int game_sync_prepare_worker(DWORD window_thread){
 char setting[8];neutral_background_input=GetEnvironmentVariableA("CLONEWARS_BACKGROUND_CAPTURE",setting,sizeof setting)==1&&setting[0]=='1';enabled=!(GetEnvironmentVariableA("CLONEWARS_ENABLE_EXPERIMENTAL_SYNC",setting,sizeof setting)==1&&setting[0]=='0');if(!enabled)return -1;core_window_thread=window_thread;
 /* No build flag/installer is supplied. Missing cohort and restore policies cannot be bypassed. */

 SpanEngineCallbacks cb={.version=4,.user=NULL,.reject_atomic=core_reject_atomic,.install_safe=core_install_safe,.dependencies_ready=core_dependencies_ready,.main_confirmed=core_main_confirmed,.control_context=core_control_context,.enter=core_prepare,.marker=core_marker,.finish=core_finish,.end=core_end};
 if(!lan_set_session_invalidator(core_lan_invalidate,NULL))return 0;
 if(!window_thread||!span_engine_prepare(&core_adapter,(unsigned char*)0x760000,(void*volatile*)0xadc268,(void*)0xadc24c,(void*volatile*)0xfb0afc,window_thread,1,&cb))return 0;
 return span_engine_publish_bootstrap(&core_adapter);
}

int game_sync_main_boundary_valid(const void*raw,uint32_t bytes,void*unused){
 (void)unused;if(!raw||bytes!=sizeof(CoreMainBoundary)||!main_boundary_active||core.opened||GetCurrentThreadId()!=core_window_thread)return 0;
 const CoreMainBoundary*b=raw;return b->owner==main_boundary.owner&&b->owner_nonce==main_boundary.owner_nonce&&b->thread==GetCurrentThreadId()&&b->release==main_boundary.release&&b->release==coherent_frame_release()&&b->boundary_serial==main_boundary_serial&&native_owner_current()==b->owner&&native_owner_scope_valid(b->owner,b->owner_nonce);
}
int game_sync_main_boundary_get(CoreMainBoundary*out){if(!out||!game_sync_main_boundary_valid(&main_boundary,sizeof main_boundary,NULL))return 0;*out=main_boundary;return game_sync_main_boundary_valid(out,sizeof *out,NULL);}

static int core_main_lifecycle_allowed(void){return game_sync_main_boundary_valid(&main_boundary,sizeof main_boundary,NULL);}

static void core_note_initialized_level(int level){if(initialized_level!=level&&core.owner&&!core.opened)core.control_stale=1;initialized_level=level;}
