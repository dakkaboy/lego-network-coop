#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>
#include <string.h>
#include "pose_observer.h"
#include "pose_observer_thunk.h"
#include "../sync/entity_sync.h"
_Static_assert(sizeof(PoseRecord)==200,"pose record");
_Static_assert(offsetof(PoseRecord,matrix_f90_xyz)==112,"raw F90 offset");
__declspec(dllexport) volatile LONG clonewars_pose_observer_enabled;
__declspec(dllexport) volatile uint32_t clonewars_pose_observer_version=1,clonewars_pose_observer_stride=sizeof(PoseRecord),clonewars_pose_observer_capacity=POSE_OBSERVER_CAPACITY,clonewars_pose_observer_installed=1;
__declspec(dllexport) volatile uint32_t clonewars_pose_observer_debug[8];
__declspec(dllexport) volatile LONG clonewars_pose_observer_count;
__declspec(dllexport) volatile PoseRecord clonewars_pose_observer_records[POSE_OBSERVER_CAPACITY];
static uint32_t word(const void *p){uint32_t value;memcpy(&value,p,4);return value;}
static uint32_t half(const void *p){uint16_t value;memcpy(&value,p,2);return value;}
static int readable(const void *p,SIZE_T n){
#ifdef POSE_OBSERVER_TEST
 extern int pose_test_readable(const void *,SIZE_T);return pose_test_readable(p,n);
#else
 MEMORY_BASIC_INFORMATION m;return p&&VirtualQuery(p,&m,sizeof(m))&&m.State==MEM_COMMIT&&!(m.Protect&(PAGE_NOACCESS|PAGE_GUARD))&&(uintptr_t)p+n>=(uintptr_t)p&&(uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;
#endif
}
static uint32_t clock_now(void){
#ifdef POSE_OBSERVER_TEST
 extern uint32_t pose_test_clock(void);return pose_test_clock();
#else
 return *(volatile uint32_t *)0xfb4b6c;
#endif
}
static void stamp(uint32_t q[2]){LARGE_INTEGER value;QueryPerformanceCounter(&value);q[0]=value.LowPart;q[1]=(uint32_t)value.HighPart;}
static void sample(PoseRecord *r,void *actor){
 unsigned char *p=actor;r->actor_local=(uint32_t)(uintptr_t)p;
 if(!readable(p,0x1440)){r->invalid_reason=1;return;}
 r->valid=1;r->flags50=word(p+0x50);r->character=(uint32_t)(int32_t)(int16_t)half(p+0xdc0);
 uint32_t slot=UINT32_MAX,generation=0;r->local_generation=entities_observed_generation(actor);
 if((r->flags50&3)==3&&entities_observed_identity(actor,&slot,&generation)&&generation&&r->local_generation){r->slot=slot;r->generation=generation;r->valid|=4;}else r->invalid_reason=2;
 memcpy(r->position24,p+0x24,12);r->heading6c=half(p+0x6c);r->headingf0c=half(p+0xf0c);memcpy(r->matrix_f90_xyz,p+0xf90,12);
 unsigned char *model=*(unsigned char **)(p+8);r->model_local=(uint32_t)(uintptr_t)model;r->model_valid=readable(model,0x43);if(r->model_valid)r->model40=half(model+0x40);
 r->actor_dda_raw=half(p+0xdda);unsigned char *resource=*(unsigned char **)(p+0xf08);r->resource_valid=readable(resource,0x18);if(r->resource_valid)r->resource14=word(resource+0x14);
 r->animation2e8=half(p+0x2e8);memcpy(r->raw_ee0_f03,p+0xee0,36);r->resource_f04_local=word(p+0xf04);
 unsigned char *controller=*(unsigned char **)(p+0x6cc);r->controller_local=(uint32_t)(uintptr_t)controller;
 if(readable(controller,0x2c)){r->valid|=2;r->controller26=half(controller+0x26);r->controller28=word(controller+0x28);}
 uint32_t slot_after=UINT32_MAX,generation_after=0;
 if((r->valid&4)&&readable(p,0x1440)&&entities_observed_identity(actor,&slot_after,&generation_after)&&slot_after==r->slot&&generation_after==r->generation&&entities_observed_generation(actor)==r->local_generation&&*(void **)(p+0x6cc)==controller&&half(p+0xdc0)==(uint16_t)r->character&&(word(p+0x50)&3)==3&&game_sync_pose_player(r->player)==actor)r->valid|=8;
 else if(r->valid&4){r->valid&=~4u;r->invalid_reason=3;}
}
__attribute__((used,noinline)) void pose_observer_record(uint32_t *saved){
 if(!clonewars_pose_observer_enabled)return;
 const SyncFrame *frame=(const SyncFrame *)(uintptr_t)saved[10];uint32_t stage=saved[11],lease=saved[12];
 if(!game_sync_pose_valid(lease)){++clonewars_pose_observer_debug[1];return;}
 if(stage<POSE_HOST_DISPATCH_COMPLETE||stage>POSE_CLIENT_POST_CORRECT||!readable(frame,16)){++clonewars_pose_observer_debug[2];return;}
 PoseRecord batch[2]={0};uint32_t epoch=frame->epoch,sequence=frame->sequence;
 for(unsigned role=0;role<2;++role){PoseRecord *r=batch+role;r->epoch=epoch;r->sequence=sequence;r->stage=stage;r->lease=lease;r->player=role;r->slot=UINT32_MAX;r->thread=GetCurrentThreadId();r->clock_before=clock_now();stamp(r->qpc_before);sample(r,game_sync_pose_player(role));r->clock_after=clock_now();stamp(r->qpc_after);}
 if(!game_sync_pose_valid(lease)){++clonewars_pose_observer_debug[1];return;}
 for(unsigned role=0;role<2;++role){PoseRecord *r=batch+role;uint32_t slot=UINT32_MAX,generation=0;void *p=(void *)(uintptr_t)r->actor_local;if((r->valid&4)&&(!readable(p,0x1440)||!entities_observed_identity(p,&slot,&generation)||slot!=r->slot||generation!=r->generation||entities_observed_generation(p)!=r->local_generation||half((unsigned char *)p+0xdc0)!=(uint16_t)r->character||(word((unsigned char *)p+0x50)&3)!=3||*(void **)((unsigned char *)p+0x6cc)!=(void *)(uintptr_t)r->controller_local||game_sync_pose_player(role)!=p)){r->valid&=~12u;r->invalid_reason=3;}if(!game_sync_pose_valid(lease)){++clonewars_pose_observer_debug[1];return;}r->id=(uint32_t)InterlockedIncrement(&clonewars_pose_observer_count);volatile PoseRecord *out=clonewars_pose_observer_records+(r->id-1)%POSE_OBSERVER_CAPACITY;out->committed=0;memcpy((void *)out,r,sizeof(*r));MemoryBarrier();out->committed=r->id;++clonewars_pose_observer_debug[0];}
}
__attribute__((naked)) void pose_observer_capture(const SyncFrame *frame __attribute__((unused)),uint32_t stage __attribute__((unused)),uint32_t lease __attribute__((unused))){__asm__ volatile(POSE_OBSERVER_THUNK_ASM);}
