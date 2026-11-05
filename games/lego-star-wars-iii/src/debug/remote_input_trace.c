#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "remote_input_trace.h"
#include "../sync/entity_sync.h"
typedef struct RemoteOwner { uint32_t slot,generation;int32_t character; } RemoteOwner;
typedef struct RemoteTracker { uint32_t valid,slot,generation,local_generation;int32_t character;uint32_t mask,timer,flags,held,pressed; } RemoteTracker;
typedef struct RemoteInputTrace {
    uint32_t committed,id,epoch,sequence,clock,raw_known,raw_held,raw_pressed,executed_held,executed_pressed,prep_calls,tag_mode,tag_callback,fault;
    RemoteOwner owner_before,owner_after;
    RemoteTracker before,after;
    uint32_t raw_axes,executed_axes;
} RemoteInputTrace;
typedef char RemoteInputTraceLayout[(sizeof(RemoteInputTrace)==168)?1:-1];
__declspec(dllexport) volatile LONG clonewars_remote_input_trace_count;
__declspec(dllexport) volatile uint32_t clonewars_remote_input_trace_version=2;
__declspec(dllexport) volatile uint32_t clonewars_remote_input_trace_stride=sizeof(RemoteInputTrace);
__declspec(dllexport) volatile uint32_t clonewars_remote_input_trace_capacity=REMOTE_INPUT_TRACE_CAPACITY;
__declspec(dllexport) volatile RemoteInputTrace clonewars_remote_input_trace[REMOTE_INPUT_TRACE_CAPACITY];
#ifndef CLONEWARS_REMOTE_INPUT_TRACE_DISABLED
static RemoteInputTrace current;
static int active;
#ifdef REMOTE_INPUT_TRACE_TEST
extern int remote_trace_test_valid(const void *,unsigned);
extern uint32_t remote_trace_test_word(uintptr_t);
#define valid(p,n) remote_trace_test_valid(p,n)
#define word(p) remote_trace_test_word(p)
#else
static int valid(const void *p,unsigned bytes) {
    MEMORY_BASIC_INFORMATION m;return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT && !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
        (uintptr_t)p+bytes>=(uintptr_t)p && (uintptr_t)p+bytes<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static uint32_t word(uintptr_t p) { return *(uint32_t *)p; }
#endif
static RemoteOwner owner(void *actor) {
    RemoteOwner value={UINT32_MAX,0,-1};
    if (valid(actor,0x1440)) { entities_observed_identity(actor,&value.slot,&value.generation);value.character=*(int16_t *)((char *)actor+0xdc0); }
    return value;
}
static void tracker(RemoteTracker *value,void *actor,uint32_t expected_generation) {
    memset(value,0,sizeof(*value));value->slot=UINT32_MAX;value->character=-1;
    if (!valid(actor,0x1440) || (*(uint32_t *)((char *)actor+0x50)&3)!=3) return;
    value->local_generation=entities_observed_generation(actor);
    if (expected_generation && value->local_generation!=expected_generation) return;
    char *controller=*(char **)((char *)actor+0x6cc);if (!valid(controller,12)) return;
    value->valid=1;entities_observed_identity(actor,&value->slot,&value->generation);value->character=*(int16_t *)((char *)actor+0xdc0);
    value->mask=*(uint32_t *)((char *)actor+0x128);value->timer=*(uint32_t *)((char *)actor+0x130);value->flags=*((unsigned char *)actor+0x134);
    value->held=*(uint32_t *)(controller+4);value->pressed=*(uint32_t *)(controller+8);
}
void remote_input_trace_reset(void) { if (active) remote_input_trace_finish(UINT32_MAX,NULL); }
void remote_input_trace_begin(const SyncFrame *frame,int host,const SyncInput *raw,void *actor) {
    memset(&current,0,sizeof(current));current.id=(uint32_t)InterlockedIncrement(&clonewars_remote_input_trace_count);
    current.epoch=frame->epoch;current.sequence=frame->sequence;current.clock=word(0xfb4b6c);current.raw_known=host!=0;
    current.raw_held=raw ? raw->held : UINT32_MAX;current.raw_pressed=raw ? raw->pressed : UINT32_MAX;
    current.executed_held=frame->inputs[1].held;current.executed_pressed=frame->inputs[1].pressed;
    current.raw_axes=host && raw ? (uint32_t)raw->analog_x|((uint32_t)raw->analog_y<<8)|((uint32_t)raw->aim_x<<16)|((uint32_t)raw->aim_y<<24) : UINT32_MAX;
    const SyncInput *executed=&frame->inputs[1];current.executed_axes=(uint32_t)executed->analog_x|((uint32_t)executed->analog_y<<8)|((uint32_t)executed->aim_x<<16)|((uint32_t)executed->aim_y<<24);
    current.tag_mode=word(0xfbd8ec);current.tag_callback=word(0xfb50b4);current.owner_before=owner(actor);active=1;
}
int remote_input_trace_before(void *actor,int is_remote_hero) {
    if (!active || !is_remote_hero) return 0;
    if (current.prep_calls++) return 0;
    tracker(&current.before,actor,0);return 1;
}
void remote_input_trace_after(void *actor,int sampled) {
    if (active && sampled && current.before.valid) tracker(&current.after,actor,current.before.local_generation);
}
void remote_input_trace_finish(unsigned fault,void *actor) {
    if (!active) return;
    active=0;current.fault=fault;current.owner_after=owner(actor);
    volatile RemoteInputTrace *row=clonewars_remote_input_trace+(current.id-1)%REMOTE_INPUT_TRACE_CAPACITY;
    row->committed=0;memcpy((void *)row,&current,sizeof(current));MemoryBarrier();row->committed=current.id;
}

#else
__declspec(dllexport) volatile uint32_t clonewars_remote_input_trace_disabled=1;
void remote_input_trace_reset(void) {}
void remote_input_trace_begin(const SyncFrame *f,int h,const SyncInput *r,void *a) {(void)f;(void)h;(void)r;(void)a;}
int remote_input_trace_before(void *a,int remote) {(void)a;(void)remote;return 0;}
void remote_input_trace_after(void *a,int sampled) {(void)a;(void)sampled;}
void remote_input_trace_finish(unsigned fault,void *a) {(void)fault;(void)a;}
#endif
