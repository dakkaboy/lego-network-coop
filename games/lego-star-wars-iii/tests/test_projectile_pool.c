#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../src/sync/projectile_sync.c"

static unsigned checks,failures,native_calls,rejections,phase_now,mutate,native_result=1;
static unsigned child_calls;
static int fence_live=1;
static CoherentFrameToken fixture_token;
static RootControlLease fixture_control;
static ProjectileSessionContext fixture_session;
static SpanEngineAdapter adapter;
static SyncFrame *fixture_frame;
static char manager_root[0x40],manager_pool[0x40],objects[SYNC_MAX_PROJECTILES][0x210],resources[SYNC_MAX_PROJECTILES][0x80];
#define CHECK(x) do{++checks;if(!(x)){++failures;printf("FAIL line%d: %s\n",__LINE__,#x);}}while(0)

int coherent_frame_valid(const CoherentFrameToken*t,uint32_t phases){return fence_live&&fixture_control.release==fixture_token.release&&t->frame==fixture_token.frame&&t->cohort_nonce==fixture_token.cohort_nonce&&t->epoch==fixture_token.epoch&&t->sequence==fixture_token.sequence&&t->release==fixture_token.release&&(phases&COHERENT_PHASE_BIT(phase_now));}
int coherent_frame_get(CoherentFrameToken*out,uint32_t phases){if(!coherent_frame_valid(&fixture_token,phases))return 0;*out=fixture_token;return 1;}
uint32_t coherent_frame_release(void){return fixture_control.release;}
void coherent_frame_cancel_atomic(uint32_t reason){(void)reason;fence_live=0;}
int span_engine_control_valid(SpanEngineAdapter*a,const RootControlLease*l){return a==&adapter&&fence_live&&!memcmp(l,&fixture_control,sizeof *l);}
int span_engine_control_get(SpanEngineAdapter*a,RootControlLease*out){if(a!=&adapter||!fence_live)return 0;*out=fixture_control;return 1;}
static int fixture_session_read(ProjectileSessionContext*out,void*unused){(void)unused;*out=fixture_session;return 1;}
static void fixture_reject(unsigned why,const ProjectileRejectContext*c,void*unused){(void)why;(void)c;(void)unused;++rejections;}

int combat_observer_remove_begin(CombatObservationScope*s,void*m,void*o,uint32_t f,int e,uint32_t c){(void)s;(void)m;(void)o;(void)f;(void)e;(void)c;return 0;}
void combat_observer_remove_end(CombatObservationScope*s,int r){(void)s;(void)r;}
void combat_observer_remove_abort(CombatObservationScope*s){(void)s;}
void combat_observer_fire_requested(void){}
void combat_observer_projectile_created(void){}
int shooter_observer_fire_begin(ShooterObservationScope*s,void*a,const char*w,int m,void*x,void*y,uint32_t c){(void)s;(void)a;(void)w;(void)m;(void)x;(void)y;(void)c;return 0;}
void shooter_observer_fire_end(ShooterObservationScope*s){(void)s;}
void shooter_observer_fire_abort(ShooterObservationScope*s){(void)s;}
void shooter_observer_actor_snapshot(ShooterActorObservation*s,void*a){(void)a;memset(s,0,sizeof *s);}
void*entities_actor(uint32_t a,uint32_t b){(void)a;(void)b;return NULL;}
uint32_t entities_generation(const void*a){(void)a;return 0;}
uint32_t entities_observed_generation(const void*a){(void)a;return 0;}
int entities_slot(const void*a){(void)a;return -1;}
int entities_allocation_live(const void*a,uint32_t b){(void)a;(void)b;return 0;}
int entities_is_retired(uint32_t a,uint32_t b){(void)a;(void)b;return 0;}
void entities_update(void){}
void combat_observer_removal_ready(void){}

static void map_page(uintptr_t address){void*p=VirtualAlloc((void*)address,0x10000,MEM_RESERVE|MEM_COMMIT,PAGE_EXECUTE_READWRITE);if(!p){DWORD e=GetLastError();MEMORY_BASIC_INFORMATION m;VirtualQuery((void*)address,&m,sizeof m);printf("map fail %lx %lu base%p alloc%p state%lx size%lx exe%p\n",(unsigned long)address,e,m.BaseAddress,m.AllocationBase,m.State,(unsigned long)m.RegionSize,GetModuleHandleA(NULL));exit(2);}}
static void setup(int host,unsigned count){
 control_adapter=NULL;last_session=last_session_epoch=revoked_session=revoked_session_epoch=0;frame_associated=0;projectiles_reset_state(1);
 retire_draining=0;memset((void*)clonewars_projectile_retire_debug,0,sizeof clonewars_projectile_retire_debug);
 memset(fixture_frame,0,sizeof *fixture_frame);memset(objects,0,sizeof objects);memset(resources,0,sizeof resources);
 native_calls=rejections=mutate=child_calls=0;native_result=1;fence_live=1;phase_now=COHERENT_PREPARE;
 fixture_session=(ProjectileSessionContext){1,6,(uint32_t)host,PROJECTILE_SESSION_ESTABLISHED,17};
 fixture_control=(RootControlLease){.thread=GetCurrentThreadId(),.release=7,.epoch=1,.level=6,.root_serial=3};
 fixture_frame->epoch=1;fixture_frame->sequence=10;fixture_frame->level=6;
 fixture_token=(CoherentFrameToken){.owner=(void*)0x123,.owner_nonce=5,.cohort_nonce=11,.thread=GetCurrentThreadId(),.release=7,.epoch=1,.sequence=10,.frame=fixture_frame};
 control_adapter=&adapter;session_provider=fixture_session_read;reject_provider=fixture_reject;control_user=NULL;
 projectile_main_thread=(LONG)GetCurrentThreadId();level=6;
 next_id=count;next_instance_serial=100+count;*(uint32_t*)0xfb4b6c=100;*(float*)0xfb4b74=0.016f;*(uint32_t*)0xea178c=123;*(uint32_t*)0xe637b4=234;
 *(void**)0xe9019c=manager_root;*(void**)(manager_root+0x38)=manager_pool;
 for(unsigned i=0;i<count;++i){tracked[i].birth.id=i+1;tracked[i].object=objects[i];tracked[i].resource=resources[i];instance_serial[i]=100+i;*(void**)(objects[i]+0x14)=resources[i];}
}
static void begin(void){CHECK(projectiles_bind_cohort(&fixture_token));CHECK(projectiles_begin(fixture_frame,(int)fixture_session.host));phase_now=COHERENT_DISPATCH;}
static unsigned pool_calls,pool_mode;
static char backing_pool[8];
static void * __attribute__((thiscall,noinline)) fake_pool_release(void *request,uint32_t a,uint32_t b,uint32_t d){
 ++pool_calls;CHECK(!a&&!b&&!d);CHECK(*(void**)request==backing_pool);
 char*object=*(void**)((char*)request+4);
 if(pool_mode!=1){
  char**link=(char**)(manager_pool+0x28);
  while(*link&&*link!=object)link=(char**)(*link+0xc);
  CHECK(*link==object);*link=*(char**)(object+0xc);--*(uint32_t*)(manager_pool+0x2c);
 }
 if(pool_mode==2){
  ++*(uint32_t*)(object+8);*(char**)(object+0xc)=*(char**)(manager_pool+0x28);*(char**)(manager_pool+0x28)=object;++*(uint32_t*)(manager_pool+0x2c);
  ProjectileOperation op=operation_capture();SyncShot birth={.id=99,.owner=-1};CHECK(remember(&op,&birth,object));
 }
 if(pool_mode==3)fence_live=0;
 if(pool_mode==4)projectiles_reset_state(1);
 return (void*)0xaabbccdd;
}
static void pool_setup(int host){
 setup(host,2);begin();pool_calls=pool_mode=0;memset(manager_pool,0,sizeof manager_pool);
 *(void**)(manager_pool+0x20)=backing_pool;*(void**)(backing_pool+4)=backing_pool;
 *(char**)(manager_pool+0x28)=objects[0];*(uint32_t*)(manager_pool+0x2c)=2;
 for(unsigned i=0;i<2;++i){*(uint32_t*)(objects[i]+8)=1000+i;tracked[i].native_stamp=1000+i;*(char**)(objects[i]+0xc)=i?NULL:objects[1];}
}
static void*pool_call(void){void*request[6]={backing_pool,objects[0],NULL,NULL,NULL,NULL};return pool_release_hook(request,NULL,0,0,0);}
int main(void){
 map_page(0xe90000);map_page(0xea0000);map_page(0xe60000);map_page(0xfb0000);
 native_pool_release=fake_pool_release;
 fixture_frame=VirtualAlloc(NULL,sizeof *fixture_frame,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE);CHECK(fixture_frame);
 for(unsigned host=0;host<2;++host){
  pool_setup(host);SetLastError(12345);CHECK(pool_call()==(void*)0xaabbccdd);CHECK(GetLastError()==12345);CHECK(pool_calls==1&&!tracked[0].object);CHECK(host?!tracked[0].birth.id:tracked[0].birth.id==1);CHECK(tracked[1].object==objects[1]);
  pool_setup(host);pool_mode=1;CHECK(pool_call()==(void*)0xaabbccdd);CHECK(pool_calls==1&&tracked[0].object==objects[0]);
  pool_setup(host);pool_mode=2;CHECK(pool_call()==(void*)0xaabbccdd);CHECK(pool_calls==1&&!tracked[0].object&&find(99)&&find(99)->object==objects[0]&&find(99)->native_stamp==1001);CHECK(tracked[1].object==objects[1]);
  ProjectileIdentityView view;CHECK(projectiles_observe_live(objects[0],&view)==SHOT_LIVE&&view.id==99);
  pool_setup(host);pool_mode=3;CHECK(pool_call()==(void*)0xaabbccdd);CHECK(pool_calls==1&&tracked[0].object==objects[0]);
  pool_setup(host);pool_mode=4;CHECK(pool_call()==(void*)0xaabbccdd);CHECK(pool_calls==1&&!tracked[0].birth.id&&!tracked[0].object);
  pool_setup(host);++*(uint32_t*)(objects[0]+8);CHECK(projectiles_observe_live(objects[0],&view)==SHOT_REPLACED);
 }
 for(unsigned i=0;i<1000;++i){pool_setup(i&1);CHECK(pool_call()==(void*)0xaabbccdd);CHECK(pool_calls==1&&!tracked[0].object&&tracked[1].object==objects[1]);}
 printf("%u checks, %u failures\n",checks,failures);return failures?1:0;
}
