#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "camera_init_observer.h"
#include "../sync/game_sync.h"
_Static_assert(sizeof(void *)==4,"camera init observer targets x86 only");
_Static_assert(sizeof(CameraInitView)==428,"camera view reader layout");
_Static_assert(sizeof(CameraInitRole)==132,"camera role reader layout");
_Static_assert(sizeof(CameraInitRecord)==2072,"camera record reader layout");
__declspec(dllexport) volatile LONG clonewars_camera_init_enabled;
__declspec(dllexport) volatile uint32_t clonewars_camera_init_version=1;
__declspec(dllexport) volatile uint32_t clonewars_camera_init_stride=sizeof(CameraInitRecord);
__declspec(dllexport) volatile uint32_t clonewars_camera_init_capacity=CAMERA_INIT_CAPACITY;
__declspec(dllexport) volatile uint32_t clonewars_camera_init_count;
__declspec(dllexport) volatile CameraInitRecord clonewars_camera_init_records[CAMERA_INIT_CAPACITY];
__declspec(dllexport) volatile uint32_t clonewars_camera_late_count;
__declspec(dllexport) volatile uint32_t clonewars_camera_late_capacity=CAMERA_LATE_CAPACITY;
__declspec(dllexport) volatile CameraInitRecord clonewars_camera_late_records[CAMERA_LATE_CAPACITY];
static volatile LONG observing;
static DWORD late_tick;
static int late_started;
#ifdef CAMERA_INIT_TEST
extern int camera_init_test_read(uint32_t,void *,unsigned);
extern DWORD camera_init_test_tick(void);
#define read_local camera_init_test_read
#define read_tick camera_init_test_tick
#else
#define read_tick GetTickCount
static int read_local(uint32_t address,void *out,unsigned size) {
    MEMORY_BASIC_INFORMATION m;
    uintptr_t end=(uintptr_t)address+size;
    if(!address || end<(uintptr_t)address || !VirtualQuery((void *)(uintptr_t)address,&m,sizeof(m)) ||
       m.State!=MEM_COMMIT || (m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) ||
       !(m.Protect&(PAGE_READONLY|PAGE_READWRITE|PAGE_WRITECOPY|PAGE_EXECUTE_READ|PAGE_EXECUTE_READWRITE|PAGE_EXECUTE_WRITECOPY)) ||
       end>(uintptr_t)m.BaseAddress+m.RegionSize)return 0;
    memcpy(out,(const void *)(uintptr_t)address,size);return 1;
}
#endif
static uint32_t word(uint32_t address) {uint32_t value=0;read_local(address,&value,4);return value;}
static uint32_t offset_word(uint32_t base,unsigned offset) {
    return base && base<=UINT32_MAX-offset ? word(base+offset) : 0;
}
void camera_init_observer_snapshot(const void *parent,uint32_t stage,int selected_role) {
    if(!clonewars_camera_init_enabled)return;
    unsigned char fx[512] __attribute__((aligned(16)));
    __asm__ volatile("fxsave %0":"=m"(fx)::"memory");
    DWORD saved_error=GetLastError();
    if(stage<1 || stage>3)goto finish;
    int late=clonewars_camera_init_count>=CAMERA_INIT_CAPACITY;
    DWORD tick=0;
    if(late) {
        if(stage!=3 || clonewars_camera_late_count==UINT32_MAX)goto finish;
        tick=read_tick();
        if(late_started && (DWORD)(tick-late_tick)<500)goto finish;
    }
    uint32_t root=word(0xfb2e60),phase=offset_word(root,0x1b78);
    if(phase!=14 || InterlockedCompareExchange(&observing,1,0))goto finish;
    if(late && late_started && (DWORD)(tick-late_tick)<500)goto unlock;
    uint32_t index=late ? clonewars_camera_late_count : clonewars_camera_init_count;
    if(late || index<CAMERA_INIT_CAPACITY) {
        CameraInitRecord r;memset(&r,0,sizeof(r));
        LARGE_INTEGER q={0};r.globals_valid=QueryPerformanceCounter(&q)?128:0;
        r.id=index+1;r.stage=stage;r.thread=GetCurrentThreadId();r.qpc_low=q.LowPart;r.qpc_high=(uint32_t)q.HighPart;
        if(read_local(0xfb4b6c,&r.clock,4))r.globals_valid|=1;
        r.epoch=game_sync_epoch();r.sequence=game_sync_sequence();
        r.phase=phase;r.parent_local=(uint32_t)(uintptr_t)parent;
        unsigned char parent_raw[0x1420];r.parent_valid=read_local(r.parent_local,parent_raw,sizeof(parent_raw));
        if(r.parent_valid) {
            memcpy(&r.state_local,parent_raw+0x1c,4);memcpy(&r.mode_raw,parent_raw+0xf20,4);
            memcpy(&r.focus_raw,parent_raw+0x13c0,4);memcpy(&r.script_phase_raw,parent_raw+0x13d8,4);
        }
        r.selected_role_raw=(uint32_t)selected_role;uint8_t value=0;
        if(read_local(0xfbc161,&value,1)){r.cinematic_raw=value;r.globals_valid|=2;}
        if(read_local(0xe6e61c,&r.pending_level_raw,4))r.globals_valid|=4;
        if(read_local(0xfb11dc,&r.native_view_count_raw,4))r.globals_valid|=8;
        if(read_local(0xeb1a78,&r.user1_device_raw,4))r.globals_valid|=16;
        if(read_local(0xeb1a7c,&r.user1_flags_raw,4))r.globals_valid|=32;
        if(read_local(0xead928+13*0x90,&value,1)){r.device13_available_raw=value;r.globals_valid|=64;}
        for(unsigned i=0;i<4;++i) {
            CameraInitView *v=r.views+i;
            if(r.parent_valid)memcpy(&v->pointer_local,parent_raw+0xf24+i*4,4);
            v->raw_valid=read_local(v->pointer_local,v->raw,sizeof(v->raw));
            if(v->raw_valid) {
                memcpy(&v->type_raw,v->raw+0x2c,4);uint16_t role;memcpy(&role,v->raw+0xac,2);v->role_raw=role;
                memcpy(&v->target_local,v->raw+0xa8,4);
                v->target_raw_valid=read_local(v->target_local,v->target_raw,sizeof(v->target_raw));
            }
        }
        for(unsigned i=0;i<2;++i) {
            CameraInitRole *v=r.roles+i;
            if(r.parent_valid){memcpy(&v->wrapper_local,parent_raw+0x13a4+i*4,4);v->fields_valid|=32;}
            v->wrapper_raw_valid=read_local(v->wrapper_local,v->wrapper_raw,sizeof(v->wrapper_raw));
            if(read_local(0xfb4940+i*4,&v->actor_local,4))v->fields_valid|=1;
            if(v->actor_local && v->actor_local<=UINT32_MAX-0x6cc) {
                if(read_local(v->actor_local+0x50,&v->actor_flags_raw,4))v->fields_valid|=2;
                if(read_local(v->actor_local+0x6cc,&v->controller_local,4))v->fields_valid|=4;
            }
            if(read_local(v->controller_local,&v->device_local,4))v->fields_valid|=8;
            if(read_local(0xfb484d+i*0x20,&value,1)){v->join_raw=value;v->fields_valid|=16;}
        }
        volatile CameraInitRecord *out=late ? clonewars_camera_late_records+index%CAMERA_LATE_CAPACITY : clonewars_camera_init_records+index;
        out->committed=0;MemoryBarrier();memcpy((void *)out,&r,sizeof(r));MemoryBarrier();out->committed=r.id;
        MemoryBarrier();
        if(late){clonewars_camera_late_count=index+1;late_tick=tick;late_started=1;}
        else clonewars_camera_init_count=index+1;
    }
unlock:
    InterlockedExchange(&observing,0);
finish:
    SetLastError(saved_error);
    __asm__ volatile("fxrstor %0"::"m"(fx):"memory","xmm0","xmm1","xmm2","xmm3","xmm4","xmm5","xmm6","xmm7");
}
