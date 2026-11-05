#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "pool_birth_observer.h"
#ifndef POOL_BIRTH_TEST
#include "../sync/game_sync.h"
#endif
_Static_assert(sizeof(PoolBirthRecord)==924,"pool record stride");
_Static_assert(__builtin_offsetof(PoolBirthRecord,descriptor)==80,"descriptor offset");
_Static_assert(__builtin_offsetof(PoolBirthRecord,pool_before)==332,"pool offset");
_Static_assert(__builtin_offsetof(PoolBirthRecord,payload)==372,"payload offset");
typedef void *(__attribute__((cdecl)) *PoolBirth)(void *,uint32_t);
static PoolBirth original_birth;
static __thread uint32_t active_birth;
__declspec(dllexport) volatile LONG clonewars_pool_birth_enabled,clonewars_pool_birth_installed,clonewars_pool_birth_count;
__declspec(dllexport) volatile uint32_t clonewars_pool_birth_version=1,clonewars_pool_birth_stride=sizeof(PoolBirthRecord),clonewars_pool_birth_capacity=POOL_BIRTH_CAPACITY;
__declspec(dllexport) volatile PoolBirthRecord clonewars_pool_birth_records[POOL_BIRTH_CAPACITY];
#ifdef POOL_BIRTH_TEST
extern int pool_birth_test_read(uint32_t,void *,unsigned);
extern uint32_t game_sync_epoch(void),game_sync_sequence(void);
#define local_read pool_birth_test_read
#else
static int local_read(uint32_t p,void *out,unsigned n){MEMORY_BASIC_INFORMATION m;
 if(!p || !VirtualQuery((void *)(uintptr_t)p,&m,sizeof(m)) || m.State!=MEM_COMMIT || (m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) ||
 (uint64_t)p+n>(uintptr_t)m.BaseAddress+m.RegionSize)return 0;
 memcpy(out,(void *)(uintptr_t)p,n);return 1;}
#endif
static uint32_t word(uint32_t p){uint32_t v=0;local_read(p,&v,4);return v;}
static void stamp(uint32_t *clock,uint32_t *game,uint32_t *engine,uint32_t qpc[2]){LARGE_INTEGER q;*clock=word(0xfb4b6c);*game=word(0xe637b4);*engine=word(0xea178c);QueryPerformanceCounter(&q);qpc[0]=q.LowPart;qpc[1]=q.HighPart;}
static void pool(uint32_t *base,uint32_t *count,uint32_t *cursor){*base=word(0xfa3d38);*count=word(0xe5f480);*cursor=word(0xe5f488);}
__attribute__((noinline)) static void *observed_birth(void *descriptor,uint32_t second,uint32_t caller){
 unsigned char fx[512] __attribute__((aligned(16))); DWORD error=GetLastError();
 __asm__ volatile("fxsave %0; fninit" : "=m"(fx));
 PoolBirthRecord r;memset(&r,0,sizeof(r));r.id=InterlockedIncrement(&clonewars_pool_birth_count);r.parent=active_birth;
 r.thread=GetCurrentThreadId();r.caller=caller;r.epoch=game_sync_epoch();r.sequence=game_sync_sequence();
 r.descriptor_local=(uint32_t)(uintptr_t)descriptor;r.second_raw=second;r.descriptor_valid=local_read(r.descriptor_local,r.descriptor,POOL_DESCRIPTOR_BYTES);
 pool(&r.pool_before,&r.capacity_before,&r.cursor_before);stamp(&r.clock_before,&r.rng_game_before,&r.rng_engine_before,r.qpc_before);
 uint32_t previous=active_birth;active_birth=r.id;SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx));
 void *result=original_birth(descriptor,second);
 __asm__ volatile("fxsave %0; fninit" : "=m"(fx));error=GetLastError();active_birth=previous;
 r.result_local=(uint32_t)(uintptr_t)result;pool(&r.pool_after,&r.capacity_after,&r.cursor_after);
 if(r.pool_after && r.capacity_after && r.result_local>=r.pool_after){uint32_t offset=r.result_local-r.pool_after;
 if(offset%POOL_PAYLOAD_BYTES==0 && offset/POOL_PAYLOAD_BYTES<r.capacity_after){r.pool_index_valid=1;r.pool_index=offset/POOL_PAYLOAD_BYTES;}}
 r.payload_valid=local_read(r.result_local,r.payload,sizeof(r.payload));stamp(&r.clock_after,&r.rng_game_after,&r.rng_engine_after,r.qpc_after);
 volatile PoolBirthRecord *dst=clonewars_pool_birth_records+(r.id-1)%POOL_BIRTH_CAPACITY;
 dst->committed=0;memcpy((void *)dst,&r,sizeof(r));MemoryBarrier();dst->committed=r.id;
 SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx));return result;
}
static void *__attribute__((cdecl,noinline)) birth_hook(void *descriptor,uint32_t second){
 if(!clonewars_pool_birth_enabled)return original_birth(descriptor,second);
 return observed_birth(descriptor,second,(uint32_t)(uintptr_t)__builtin_return_address(0));
}
int pool_birth_observer_install(void){
#ifdef POOL_BIRTH_TEST
 return original_birth!=0;
#else
 unsigned char *entry=(unsigned char *)0x741f90;const unsigned char expected[]={0x6a,0xff,0x68,0x76,0xcf,0xaa,0x00};DWORD old;
 if(memcmp(entry,expected,7)){clonewars_pool_birth_installed=-1;return 0;}
 unsigned char *bridge=VirtualAlloc(0,12,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);
 if(!bridge){clonewars_pool_birth_installed=-1;return 0;}
 if(!VirtualProtect(entry,7,PAGE_EXECUTE_READWRITE,&old)){VirtualFree(bridge,0,MEM_RELEASE);clonewars_pool_birth_installed=-1;return 0;}
 memcpy(bridge,entry,7);bridge[7]=0xe9;*(int32_t *)(bridge+8)=(int32_t)((uintptr_t)entry+7-(uintptr_t)bridge-12);original_birth=(PoolBirth)bridge;
 entry[0]=0xe9;*(int32_t *)(entry+1)=(int32_t)((uintptr_t)birth_hook-(uintptr_t)entry-5);memset(entry+5,0x90,2);
 FlushInstructionCache(GetCurrentProcess(),bridge,12);FlushInstructionCache(GetCurrentProcess(),entry,7);VirtualProtect(entry,7,old,&old);
 clonewars_pool_birth_installed=1;return 1;
#endif
}
