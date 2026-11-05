#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>
#include <string.h>
#include "constructor_observer.h"
#include "constructor_observer_thunk.h"
#include "../sync/entity_sync.h"
_Static_assert(sizeof(ConstructorInput)==264,"constructor input");
_Static_assert(sizeof(ConstructorRecord)==1232,"constructor record");
__declspec(dllexport) volatile LONG clonewars_constructor_observer_enabled,clonewars_constructor_observer_count;
__declspec(dllexport) volatile uint32_t clonewars_constructor_observer_version=1,clonewars_constructor_observer_stride=sizeof(ConstructorRecord),clonewars_constructor_observer_capacity=CONSTRUCTOR_CAPACITY,clonewars_constructor_observer_installed;
__declspec(dllexport) volatile uint32_t clonewars_constructor_observer_debug[8];
__declspec(dllexport) volatile ConstructorRecord clonewars_constructor_observer_records[CONSTRUCTOR_CAPACITY];
static int readable(const void *p,SIZE_T n){
#ifdef CONSTRUCTOR_OBSERVER_TEST
 extern int constructor_test_readable(const void *,SIZE_T);return constructor_test_readable(p,n);
#else
 MEMORY_BASIC_INFORMATION m;return p&&VirtualQuery(p,&m,sizeof(m))&&m.State==MEM_COMMIT&&!(m.Protect&(PAGE_NOACCESS|PAGE_GUARD))&&(uintptr_t)p+n>=(uintptr_t)p&&(uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;
#endif
}
static uint32_t word(const void *p){uint32_t v;memcpy(&v,p,4);return v;}
static uint32_t half(const void *p){uint16_t v;memcpy(&v,p,2);return v;}
static uintptr_t global_address(uintptr_t p){
#ifdef CONSTRUCTOR_OBSERVER_TEST
 extern uintptr_t constructor_test_global(uintptr_t);return constructor_test_global(p);
#else
 return p;
#endif
}
static void context(uint32_t out[4]){const uintptr_t a[]={0xfb4b6c,0xe637b4,0xea178c,0xfb4b74};for(unsigned i=0;i<4;++i){uintptr_t p=global_address(a[i]);if(readable((void*)p,4))out[i]=word((void*)p);}}
static void timestamp(uint32_t out[2]){LARGE_INTEGER q;QueryPerformanceCounter(&q);out[0]=q.LowPart;out[1]=(uint32_t)q.HighPart;}
static int scope_context_valid(const ConstructorScope*s,const ConstructorLease*l){if(s->capability==CONSTRUCTOR_CAP_REJECTED)return 0;if(s->capability==CONSTRUCTOR_CAP_CONTROL)return projectiles_constructor_control_valid(l,&s->control,&s->control_session,s->reset_generation);return projectiles_constructor_cohort_valid(l,&s->cohort);}
__attribute__((used,noinline)) void constructor_begin_impl(ConstructorScope *s,const ConstructorCall *c){
 s->ready=0;s->cohort=c->cohort;s->control=c->control;s->control_session=c->control_session;s->reset_generation=c->reset_generation;s->capability=c->capability;if(!clonewars_constructor_observer_enabled||!clonewars_constructor_observer_installed)return;
 if(!scope_context_valid(s,&c->lease)){++clonewars_constructor_observer_debug[0];return;}
 ConstructorRecord *r=&s->record;memset(r,0,sizeof(*r));r->version=1;r->thread=GetCurrentThreadId();timestamp(r->qpc_before);context(r->before);
 ConstructorInput *in=&r->input;in->lease=c->lease;in->kind=c->kind;in->caller=c->caller;in->manager_local=(uint32_t)(uintptr_t)c->manager;in->owner_local=(uint32_t)(uintptr_t)c->owner;in->target_local=(uint32_t)(uintptr_t)c->target;in->flags=c->flags;in->origin_local=(uint32_t)(uintptr_t)c->origin;in->transform_local=(uint32_t)(uintptr_t)c->transform;in->weapon_local=(uint32_t)(uintptr_t)c->weapon;
 if(s->capability!=CONSTRUCTOR_CAP_CONTROL&&readable(c->birth,sizeof(SyncShot))){in->birth=*c->birth;in->birth_known=1;}
 if(readable(c->origin,12)){memcpy(in->origin,c->origin,12);in->input_valid|=1;}
 if(readable(c->transform,64)){memcpy(in->transform,c->transform,64);in->input_valid|=2;}
 if(readable(c->weapon,1)){in->weapon=(uint32_t)(int32_t)*c->weapon;in->input_valid|=4;}
 r->owner_slot=r->resolved_slot=UINT32_MAX;
 if(readable(c->owner,0x1440)){
  r->owner_local_generation=entities_observed_generation(c->owner);r->owner_character=half((char*)c->owner+0xdc0);
  if(r->owner_local_generation&&entities_allocation_live(c->owner,r->owner_local_generation)&&entities_observed_identity(c->owner,&r->owner_slot,&r->owner_generation)&&(!in->birth_known||(in->birth.owner==(int32_t)r->owner_slot&&in->birth.owner_generation==r->owner_generation)))r->valid|=1;
 }
 if(in->birth_known&&in->birth.owner>=0&&!(r->valid&1)){++clonewars_constructor_observer_debug[5];return;}
 if(!scope_context_valid(s,&in->lease)){++clonewars_constructor_observer_debug[1];return;}
 s->ready=1;
}
__attribute__((used,noinline)) void constructor_end_impl(ConstructorScope *s,void *object){
 if(!clonewars_constructor_observer_enabled||!s->ready)return;s->ready=0;ConstructorRecord *r=&s->record;
 if(!scope_context_valid(s,&r->input.lease)){++clonewars_constructor_observer_debug[2];return;}
 r->returned_local=(uint32_t)(uintptr_t)object;context(r->after);timestamp(r->qpc_after);
 if(readable(object,0x210)){
  memcpy(r->object_raw,object,0x210);r->valid|=2;r->resource_local=word((char*)object+0x14);r->descriptor_local=word((char*)object+0x20c);
  const char *resource=(void*)(uintptr_t)r->resource_local;if(readable(resource,0x78)){r->resource20=word(resource+0x20);r->resource70=word(resource+0x70);r->resource74=word(resource+0x74);r->valid|=4;}
  const char *d=(void*)(uintptr_t)r->descriptor_local;if(readable(d,0xa0)){memcpy(r->descriptor_raw,d,0xa0);r->descriptor_type=(unsigned char)d[0x18];r->valid|=8;
   if(r->descriptor_type==2&&word(d+0x94)==1){const char *model=(void*)(uintptr_t)word(d+0x28);if(readable(model,0x34)){const char *user=(void*)(uintptr_t)word(model+0x30);if(readable(user,8)&&!*(const unsigned char*)user){const char *actor=(void*)(uintptr_t)word(user+4);uint32_t observed=readable(actor,0x1440)?entities_observed_generation(actor):0;if(observed&&word(actor+8)==(uint32_t)(uintptr_t)model&&entities_allocation_live(actor,observed)&&entities_observed_identity(actor,&r->resolved_slot,&r->resolved_generation)){r->resolved_actor_local=(uint32_t)(uintptr_t)actor;r->valid|=16;}}}}
  }
 }
 uintptr_t gp=global_address(0xe9019c);if(readable((void*)gp,4)){r->wrapper_local=word((void*)gp);const char*w=(void*)(uintptr_t)r->wrapper_local;if(readable(w,0x48)){r->wrapper40=word(w+0x40);r->wrapper44=word(w+0x44);r->valid|=32;}}
 uintptr_t ray=global_address(0xfb9770);if(readable((void*)ray,sizeof(r->ray_raw))){memcpy(r->ray_raw,(void*)ray,sizeof(r->ray_raw));r->valid|=64;}
 uintptr_t category=global_address(0xfb97f1);if(readable((void*)category,1)){r->query_category=*(const unsigned char*)category;r->valid|=128;}
 uintptr_t normal=global_address(0xfb9810);if(readable((void*)normal,12)){memcpy(r->query_normal_raw,(void*)normal,12);r->valid|=256;}
 if(!scope_context_valid(s,&r->input.lease)){++clonewars_constructor_observer_debug[3];return;}
 if(r->valid&1){const char*owner=(void*)(uintptr_t)r->input.owner_local;uint32_t slot=UINT32_MAX,generation=0;if(!readable(owner,0x1440)||!entities_allocation_live(owner,r->owner_local_generation)||entities_observed_generation(owner)!=r->owner_local_generation||half(owner+0xdc0)!=r->owner_character||!entities_observed_identity(owner,&slot,&generation)||slot!=r->owner_slot||generation!=r->owner_generation){++clonewars_constructor_observer_debug[4];return;}}
 if(!scope_context_valid(s,&r->input.lease)){++clonewars_constructor_observer_debug[3];return;}
 r->id=(uint32_t)InterlockedIncrement(&clonewars_constructor_observer_count);volatile ConstructorRecord*out=clonewars_constructor_observer_records+(r->id-1)%CONSTRUCTOR_CAPACITY;out->committed=0;memcpy((void*)out,r,sizeof(*r));MemoryBarrier();out->committed=r->id;
}
__attribute__((naked)) void constructor_observer_begin(ConstructorScope*s,const ConstructorCall*c){__asm__ volatile(CONSTRUCTOR_OBSERVER_THUNK_ASM("_constructor_begin_impl"));}
__attribute__((naked)) void constructor_observer_end(ConstructorScope*s,void*object){__asm__ volatile(CONSTRUCTOR_OBSERVER_THUNK_ASM("_constructor_end_impl"));}
int constructor_observer_install(void){clonewars_constructor_observer_installed=projectiles_constructor_hooks_ready()!=0;return clonewars_constructor_observer_installed!=0;}
