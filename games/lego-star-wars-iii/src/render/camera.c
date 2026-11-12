#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include "overlay.h"
#include "../engine/game_state.h"
#include "../sync/game_sync.h"
#include "../sync/coherent_core_draft.h"
#include "../engine/core_main_boundary.h"
#include "../debug/camera_init_observer.h"
#include "../debug/diagnostics.h"
#include "../engine/loading.h"
#include "../net/lan.h"
#include "network_window.h"

typedef void (__attribute__((thiscall)) *Update)(void *, void *, void *, unsigned char);

static Update originals[3];
static const uintptr_t tables[3] = {0xc3de2c, 0xc3df2c, 0xc3e044};
static WNDPROC previous_proc;
static HMODULE camera_module;
static int camera_main_install_state;
__declspec(dllexport) volatile uint32_t clonewars_saber_pass[2][5];
__declspec(dllexport) volatile uint32_t clonewars_saber_list[2][3];
__declspec(dllexport) volatile uint32_t clonewars_saber_actor_batch[4];
__attribute__((used)) static const uintptr_t saber_draw_native=0x907470;
__attribute__((used)) static const uintptr_t saber_actor_batch_native=0x9b6c20;

__attribute__((naked)) static void saber_actor_batch_tap(void) {
    __asm__ volatile(
        "pushfl\n\tpushl %eax\n\t"
        "movl 0xfb4b6c,%eax\n\tmovl %eax,_clonewars_saber_actor_batch+4\n\t"
        "movzbl 0xfb2f51,%eax\n\tmovl %eax,_clonewars_saber_actor_batch+8\n\t"
        "incl _clonewars_saber_actor_batch\n\t"
        "popl %eax\n\tpopfl\n\tjmp *_saber_actor_batch_native\n\t");
}

#define SABER_PASS_TAP(offset, list_offset) \
    "pushfl\n\tpushl %eax\n\t" \
    "incl _clonewars_saber_pass+" #offset "\n\t" \
    "movl 0xeb8374,%eax\n\tmovl %eax,_clonewars_saber_pass+" #offset "+4\n\t" \
    "movl 0xf73afc,%eax\n\tmovl %eax,_clonewars_saber_pass+" #offset "+8\n\t" \
    "movl 12(%esp),%eax\n\tmovl %eax,_clonewars_saber_pass+" #offset "+12\n\t" \
    "movl 0xfb4b6c,%eax\n\tmovl %eax,_clonewars_saber_pass+" #offset "+16\n\t" \
    "movzbl 0xfb2f51,%eax\n\tmovl %eax,_clonewars_saber_actor_batch+12\n\t" \
    "movl 0xfbca90,%eax\n\tmovl %eax,_clonewars_saber_list+" #list_offset "\n\t" \
    "testl %eax,%eax\n\tjz 1f\n\t" \
    "movl 0x10(%eax),%eax\n\tmovl %eax,_clonewars_saber_list+" #list_offset "+4\n\t" \
    "incl _clonewars_saber_list+" #list_offset "+8\n\t1:\n\t" \
    "popl %eax\n\tpopfl\n\tjmp *_saber_draw_native\n\t"
__attribute__((naked)) static void saber_pass_first(void){__asm__ volatile(SABER_PASS_TAP(0,0));}
__attribute__((naked)) static void saber_pass_last(void){__asm__ volatile(SABER_PASS_TAP(20,12));}

__declspec(dllexport) volatile uint32_t clonewars_saber_submit[7][5];
__attribute__((used)) static const uintptr_t saber_submit_indexed=0x5be930;
__attribute__((used)) static const uintptr_t saber_submit_plain=0x5bee90;
__attribute__((used)) static const uintptr_t saber_submit_ribbon=0x5be910;

#define SABER_SUBMIT_TAP(offset, arg, target) \
    "pushfl\n\tpushl %eax\n\t" \
    "movl 0xeb8374,%eax\n\tmovl %eax,_clonewars_saber_submit+" #offset "+4\n\t" \
    "movl 0xf73afc,%eax\n\tmovl %eax,_clonewars_saber_submit+" #offset "+8\n\t" \
    "movl " #arg "(%esp),%eax\n\tmovl %eax,_clonewars_saber_submit+" #offset "+12\n\t" \
    "movl 0xfb4b6c,%eax\n\tmovl %eax,_clonewars_saber_submit+" #offset "+16\n\t" \
    "incl _clonewars_saber_submit+" #offset "\n\t" \
    "popl %eax\n\tpopfl\n\tjmp *_" #target "\n\t"
__attribute__((naked)) static void saber_submit_glow_indexed(void){__asm__ volatile(SABER_SUBMIT_TAP(0,24,saber_submit_indexed));}
__attribute__((naked)) static void saber_submit_glow_plain(void){__asm__ volatile(SABER_SUBMIT_TAP(20,20,saber_submit_plain));}
__attribute__((naked)) static void saber_submit_glow_repeat_indexed(void){__asm__ volatile(SABER_SUBMIT_TAP(40,24,saber_submit_indexed));}
__attribute__((naked)) static void saber_submit_glow_repeat_plain(void){__asm__ volatile(SABER_SUBMIT_TAP(60,20,saber_submit_plain));}
__attribute__((naked)) static void saber_submit_core_indexed(void){__asm__ volatile(SABER_SUBMIT_TAP(80,24,saber_submit_indexed));}
__attribute__((naked)) static void saber_submit_core_plain(void){__asm__ volatile(SABER_SUBMIT_TAP(100,20,saber_submit_plain));}
__attribute__((naked)) static void saber_submit_other(void){__asm__ volatile(SABER_SUBMIT_TAP(120,24,saber_submit_ribbon));}

static void install_saber_pass_tap(uintptr_t site,uintptr_t native,void *tap) {
    unsigned char *call=(unsigned char *)site;
    int32_t rel;
    memcpy(&rel,call+1,sizeof(rel));
    DWORD old;
    if (*call!=0xe8 || site+5+rel!=native ||
        !VirtualProtect(call,5,PAGE_EXECUTE_READWRITE,&old)) return;
    rel=(int32_t)((uintptr_t)tap-site-5);
    memcpy(call+1,&rel,sizeof(rel));
    FlushInstructionCache(GetCurrentProcess(),call,5);
    VirtualProtect(call,5,old,&old);
}

__declspec(dllexport) volatile uint32_t clonewars_saber_producer[17][9];

static void __cdecl saber_producer_tap(void *positions,float life,uint32_t color,
        void **handle,uint32_t mode,void *actor) {
    static const uintptr_t sites[]={0x7966e2,0x7c8286,0x7c82dd,0x8c9b6c,0x8cc0c2,
        0x906b95,0x97b532,0x97b697,0x99d59b,0x9aae7a,0x9b2b1d,0x9b2be5,
        0x9b5fdf,0x9b62ef,0x9b64c8};
    uintptr_t caller=(uintptr_t)__builtin_return_address(0)-5;
    unsigned index=0;
    while(index<sizeof(sites)/sizeof(*sites) && sites[index]!=caller) ++index;
    volatile uint32_t *r=clonewars_saber_producer[index];
    uint32_t life_raw;
    memcpy(&life_raw,&life,sizeof(life_raw));
    r[1]=*(volatile uint32_t *)0xfb4b6c;
    r[2]=(uintptr_t)actor;
    r[3]=(uintptr_t)handle;
    r[4]=color;
    r[5]=life_raw;
    r[6]=*(volatile uint32_t *)0xfbca90;
    ((void (__cdecl *)(void *,float,uint32_t,void **,uint32_t,void *))0x906b00)(
        positions,life,color,handle,mode,actor);
    r[7]=*(volatile uint32_t *)0xfbca90;
    r[8]=handle?(uintptr_t)*handle:0;
    ++r[0];
}

static void __cdecl saber_age_tap(float delta) {
    volatile uint32_t *r=clonewars_saber_producer[16];
    uint32_t delta_raw;
    memcpy(&delta_raw,&delta,sizeof(delta_raw));
    r[1]=*(volatile uint32_t *)0xfb4b6c;
    r[5]=delta_raw;
    r[6]=*(volatile uint32_t *)0xfbca90;
    ((void (__cdecl *)(float))0x906920)(delta);
    r[7]=*(volatile uint32_t *)0xfbca90;
    ++r[0];
}

static HWND game_window;
static volatile LONG selected = -1;
static void *manager;
static IDirect3DSurface9 *camera_surface;
static unsigned camera_width,camera_height;
static D3DFORMAT camera_format;
static IDirect3DSurface9 *selected_target;
static IDirect3DSurface9 *tap_surface;
static int selected_target_player=-1;
__declspec(dllexport) volatile uint32_t clonewars_camera_debug[8];
__declspec(dllexport) volatile uint32_t clonewars_camera_viewport[22];
__declspec(dllexport) volatile LONG clonewars_camera_gpu_observation_enabled;
__declspec(dllexport) volatile uint32_t clonewars_camera_gpu_observation[2][40];
static uint32_t gpu_observation_serial;
static uint32_t compositor_call_serial;
__declspec(dllexport) volatile LONG clonewars_camera_compositor_enabled;
__declspec(dllexport) volatile uint32_t clonewars_camera_compositor_version=2;
__declspec(dllexport) volatile uint32_t clonewars_camera_compositor_stride=320;
__declspec(dllexport) volatile uint32_t clonewars_camera_compositor_capacity=128;
__declspec(dllexport) volatile LONG clonewars_camera_compositor_count;
__declspec(dllexport) volatile uint32_t clonewars_camera_compositor_rows[128][80];
__declspec(dllexport) volatile uint32_t clonewars_camera_fullclip=84;
__declspec(dllexport) volatile uint32_t clonewars_camera_threads[3];
__declspec(dllexport) volatile LONG clonewars_camera_trace_count;
__declspec(dllexport) volatile uint32_t clonewars_camera_trace[512][12];
static uint32_t trace_frame,trace_target,trace_width,trace_height;
static IDirect3DSurface9 *trace_surfaces[8];
__declspec(dllexport) volatile uint32_t clonewars_camera_preview;
__declspec(dllexport) volatile uint32_t clonewars_camera_surfaces[8][6];
static void release_trace_surfaces(void) {
    for (int i=0;i<8;++i) if (trace_surfaces[i]) {
        IDirect3DSurface9_Release(trace_surfaces[i]); trace_surfaces[i]=NULL;
    }
    memset((void *)clonewars_camera_surfaces,0,sizeof(clonewars_camera_surfaces));
}

typedef HRESULT (WINAPI *SetTarget)(IDirect3DDevice9 *,DWORD,IDirect3DSurface9 *);
typedef HRESULT (WINAPI *SetViewport)(IDirect3DDevice9 *,const D3DVIEWPORT9 *);
typedef HRESULT (WINAPI *SetScissor)(IDirect3DDevice9 *,const RECT *);
typedef HRESULT (WINAPI *SetState)(IDirect3DDevice9 *,D3DRENDERSTATETYPE,DWORD);
static SetTarget original_set_target;
static SetViewport original_set_viewport;
static SetScissor original_set_scissor;
static SetState original_set_state;
static FILE *log_file;
static DWORD menu_closed_at;
static const UINT menu_message = WM_APP + 0x342;
static const UINT window_message = WM_APP + 0x344;
static const UINT renderer_message = WM_APP + 0x345;
typedef HRESULT (WINAPI *Present)(IDirect3DDevice9 *, const RECT *, const RECT *, HWND, const RGNDATA *);
typedef HRESULT (WINAPI *Reset)(IDirect3DDevice9 *, D3DPRESENT_PARAMETERS *);
void capture_frame(IDirect3DDevice9 *device);
void capture_reset(void);
static int background_capture;
static Present original_present;
static Reset original_reset;
static IDirect3DDevice9 *game_device;
static HANDLE frame_timer;
static LARGE_INTEGER frequency, frame_deadline;

static POINT background_window_position(HWND window,int width,int height) {
    RECT bounds;
    if ((width<=0 || height<=0) && GetWindowRect(window,&bounds)) {
        width=bounds.right-bounds.left;
        height=bounds.bottom-bounds.top;
    }
    if (width<=0) width=GetSystemMetrics(SM_CXSCREEN);
    if (height<=0) height=GetSystemMetrics(SM_CYSCREEN);
    POINT position={GetSystemMetrics(SM_XVIRTUALSCREEN)-width-32,
                    GetSystemMetrics(SM_YVIRTUALSCREEN)-height-32};
    return position;
}

void camera_select(int player) {
    if (player >= -1 && player <= 1) InterlockedExchange(&selected, player);
}
int camera_selected(void) { return InterlockedCompareExchange(&selected, 0, 0); }
static int readable(void *pointer, SIZE_T size);
static void camera_render_reset_state(void);
static void log_line(const char *text);
static void install_renderer(void);
static int crop_camera(IDirect3DDevice9 *device);
static unsigned char __attribute__((fastcall)) camera_target_end(void *view,void *unused,void *parent);

static int personal_camera_allowed(char *parent);
static volatile uint32_t *trace_record(unsigned type) {
    if (!(clonewars_camera_fullclip&32) || !personal_camera_allowed(manager)) return NULL;
    LONG index=InterlockedIncrement(&clonewars_camera_trace_count)-1;
    if (index<0 || index>=512) return NULL;
    volatile uint32_t *record=clonewars_camera_trace[index];
    record[0]=type; record[1]=trace_frame;
    record[2]=*(uint32_t *)0xeb8374; record[3]=GetCurrentThreadId();
    record[4]=trace_target;
    return record;
}
static HRESULT WINAPI camera_set_target(IDirect3DDevice9 *device,DWORD index,IDirect3DSurface9 *surface) {
    HRESULT result=original_set_target(device,index,surface);
    if (device==game_device && index==0) {
        trace_target=(uint32_t)(uintptr_t)surface;
        volatile uint32_t *record=trace_record(1);
        if (record) {
            D3DSURFACE_DESC desc;
            record[5]=(uint32_t)result;
            if (surface && SUCCEEDED(IDirect3DSurface9_GetDesc(surface,&desc))) {
                record[6]=desc.Width; record[7]=desc.Height; record[8]=desc.Format;
                record[9]=desc.MultiSampleType; record[10]=desc.Usage; record[11]=desc.Pool;
                if (desc.Width==trace_width && desc.Height==trace_height) {
                    for (int i=0;i<8;++i) {
                        if (trace_surfaces[i]==surface) break;
                        if (!trace_surfaces[i]) {
                            IDirect3DSurface9_AddRef(surface); trace_surfaces[i]=surface;
                            clonewars_camera_surfaces[i][0]=(uint32_t)(uintptr_t)surface;
                            clonewars_camera_surfaces[i][1]=desc.Width; clonewars_camera_surfaces[i][2]=desc.Height;
                            clonewars_camera_surfaces[i][3]=desc.Format; clonewars_camera_surfaces[i][4]=desc.MultiSampleType;
                            clonewars_camera_surfaces[i][5]=*(uint32_t *)0xeb8374;
                            break;
                        }
                    }
                }
            }
        }
    }
    return result;
}
static HRESULT WINAPI camera_set_viewport(IDirect3DDevice9 *device,const D3DVIEWPORT9 *viewport) {
    HRESULT result=original_set_viewport(device,viewport);
    if (device==game_device) {
        volatile uint32_t *record=trace_record(2);
        if (record && viewport) {
            record[5]=viewport->X; record[6]=viewport->Y;
            record[7]=viewport->Width; record[8]=viewport->Height;
        }
    }
    return result;
}
static HRESULT WINAPI camera_set_scissor(IDirect3DDevice9 *device,const RECT *rectangle) {
    HRESULT result=original_set_scissor(device,rectangle);
    if (device==game_device) {
        volatile uint32_t *record=trace_record(4);
        if (record && rectangle) {
            record[5]=(uint32_t)rectangle->left; record[6]=(uint32_t)rectangle->top;
            record[7]=(uint32_t)rectangle->right; record[8]=(uint32_t)rectangle->bottom;
        }
    }
    return result;
}
static HRESULT WINAPI camera_set_state(IDirect3DDevice9 *device,D3DRENDERSTATETYPE state,DWORD value) {
    HRESULT result=original_set_state(device,state,value);
    if (device==game_device && (state==D3DRS_SCISSORTESTENABLE || state==D3DRS_CLIPPLANEENABLE ||
        state==D3DRS_STENCILENABLE || state==D3DRS_STENCILFUNC || state==D3DRS_STENCILREF ||
        state==D3DRS_COLORWRITEENABLE)) {
        volatile uint32_t *record=trace_record(3);
        if (record) { record[5]=state; record[6]=value; }
    }
    return result;
}

__attribute__((noinline)) static void present_added_work(IDirect3DDevice9 *device) {
    if (device == game_device) {
        clonewars_camera_threads[0]=GetCurrentThreadId();
        network_window_update();
        ++trace_frame;
        game_sync_inspect();
        crop_camera(device);
        unsigned preview=clonewars_camera_preview;
        if (preview>=1 && preview<=8 && trace_surfaces[preview-1] && personal_camera_allowed(manager)) {
            IDirect3DSurface9 *preview_backbuffer=NULL;
            if (SUCCEEDED(IDirect3DDevice9_GetBackBuffer(device,0,0,D3DBACKBUFFER_TYPE_MONO,&preview_backbuffer))) {
                clonewars_camera_debug[4]=(uint32_t)IDirect3DDevice9_StretchRect(device,trace_surfaces[preview-1],NULL,
                    preview_backbuffer,NULL,D3DTEXF_NONE);
                IDirect3DSurface9_Release(preview_backbuffer);
            }
        }
        IDirect3DStateBlock9 *saved = NULL;
        IDirect3DSurface9 *target = NULL, *backbuffer = NULL;
        if (SUCCEEDED(IDirect3DDevice9_CreateStateBlock(device, D3DSBT_ALL, &saved))) {
            IDirect3DStateBlock9_Capture(saved);
            IDirect3DDevice9_GetRenderTarget(device, 0, &target);
            if (SUCCEEDED(IDirect3DDevice9_GetBackBuffer(device, 0, 0, D3DBACKBUFFER_TYPE_MONO, &backbuffer))) {
                D3DSURFACE_DESC description;
                IDirect3DSurface9_GetDesc(backbuffer, &description);
                trace_width=description.Width; trace_height=description.Height;
                IDirect3DDevice9_SetRenderTarget(device, 0, backbuffer);
                D3DVIEWPORT9 viewport = {0,0,description.Width,description.Height,0,1};
                IDirect3DDevice9_SetViewport(device, &viewport);
                if (SUCCEEDED(IDirect3DDevice9_BeginScene(device))) {
                    CoopHudPlayer hud[2]={0};
                    coop_draw(device,hud);
                    IDirect3DDevice9_EndScene(device);
                }
                IDirect3DSurface9_Release(backbuffer);
            }
            if (target) {
                IDirect3DDevice9_SetRenderTarget(device, 0, target);
                IDirect3DSurface9_Release(target);
            }
            IDirect3DStateBlock9_Apply(saved);
            IDirect3DStateBlock9_Release(saved);
        }
        capture_frame(device);
        LARGE_INTEGER now;
        QueryPerformanceCounter(&now);
        if (frame_deadline.QuadPart > now.QuadPart && frame_timer) {
            LARGE_INTEGER due;
            due.QuadPart = -(frame_deadline.QuadPart-now.QuadPart)*10000000/frequency.QuadPart;
            if (due.QuadPart < 0 && SetWaitableTimer(frame_timer,&due,0,NULL,NULL,FALSE))
                WaitForSingleObject(frame_timer,100);
        }
        QueryPerformanceCounter(&now);
        frame_deadline.QuadPart = now.QuadPart + frequency.QuadPart/60;
        static DWORD rate_started;
        static unsigned int frames;
        DWORD tick = GetTickCount();
        if (!rate_started) rate_started = tick;
        ++frames;
        if (tick-rate_started >= 5000) {
            char rate[80];
            snprintf(rate,sizeof(rate),"present rate: %.1f FPS",frames*1000.0/(tick-rate_started));
            log_line(rate);
            frames = 0;
            rate_started = tick;
        }
    }
}

static HRESULT WINAPI present_hook(IDirect3DDevice9 *device, const RECT *source, const RECT *dest,
                                    HWND window, const RGNDATA *dirty) {
    unsigned char incoming_fx[512] __attribute__((aligned(16)));
    __asm__ volatile("fxsave %0":"=m"(incoming_fx)::"memory");
    DWORD error=GetLastError();
    present_added_work(device);
    SetLastError(error);
    __asm__ volatile("fxrstor %0"::"m"(incoming_fx):"memory");
    return original_present(device,source,dest,window,dirty);
}

static HRESULT WINAPI reset_hook(IDirect3DDevice9 *device, D3DPRESENT_PARAMETERS *parameters) {
    unsigned char native_fx[512] __attribute__((aligned(16)));
    __asm__ volatile("fxsave %0":"=m"(native_fx)::"memory");
    DWORD error=GetLastError();
    camera_render_reset_state();
    capture_reset();
    release_trace_surfaces();
    if (selected_target) { IDirect3DSurface9_Release(selected_target); selected_target=NULL; }
    if (camera_surface) { IDirect3DSurface9_Release(camera_surface); camera_surface=NULL; }
    if (tap_surface) { IDirect3DSurface9_Release(tap_surface); tap_surface=NULL; }
    if (device == game_device) coop_fonts_lost();
    SetLastError(error);
    __asm__ volatile("fxrstor %0"::"m"(native_fx):"memory");
    HRESULT result = original_reset(device,parameters);
    __asm__ volatile("fxsave %0":"=m"(native_fx)::"memory");
    error=GetLastError();
    if (device == game_device && SUCCEEDED(result)) {
        coop_fonts_reset();
        install_renderer();
    }
    SetLastError(error);
    __asm__ volatile("fxrstor %0"::"m"(native_fx):"memory");
    return result;
}

static void install_renderer(void) {
    IDirect3DDevice9 *device = *(IDirect3DDevice9 **)0xf925d4;
    if (!device || !readable(device,sizeof(void *))) return;
    if (game_device && device != game_device) {
        camera_render_reset_state();
        capture_reset();
        coop_release_fonts();
        release_trace_surfaces();
        if (selected_target) { IDirect3DSurface9_Release(selected_target); selected_target=NULL; }
        if (camera_surface) { IDirect3DSurface9_Release(camera_surface); camera_surface=NULL; }
        if (tap_surface) { IDirect3DSurface9_Release(tap_surface); tap_surface=NULL; }
    }
    game_device = device;
    void **vtable = *(void ***)device;
    if (vtable[17] == (void *)present_hook) return;
    struct { size_t offset; void *hook; void **original; } trace_hooks[]={
        {offsetof(IDirect3DDevice9Vtbl,SetRenderTarget),(void *)camera_set_target,(void **)&original_set_target},
        {offsetof(IDirect3DDevice9Vtbl,SetViewport),(void *)camera_set_viewport,(void **)&original_set_viewport},
        {offsetof(IDirect3DDevice9Vtbl,SetScissorRect),(void *)camera_set_scissor,(void **)&original_set_scissor},
        {offsetof(IDirect3DDevice9Vtbl,SetRenderState),(void *)camera_set_state,(void **)&original_set_state}
    };
    for (unsigned i=0;i<sizeof(trace_hooks)/sizeof(trace_hooks[0]);++i) {
        void **entry=(void **)((char *)vtable+trace_hooks[i].offset);
        DWORD trace_protection;
        if (*entry!=trace_hooks[i].hook && VirtualProtect(entry,sizeof(void *),PAGE_READWRITE,&trace_protection)) {
            *trace_hooks[i].original=*entry;
            *entry=trace_hooks[i].hook;
            VirtualProtect(entry,sizeof(void *),trace_protection,&trace_protection);
        }
    }
    original_present = (Present)vtable[17];
    if (vtable[16] != (void *)reset_hook) original_reset = (Reset)vtable[16];
    QueryPerformanceFrequency(&frequency);
    if (!frame_timer) frame_timer = CreateWaitableTimerExW(NULL,NULL,0x2,TIMER_ALL_ACCESS);
    if (!frame_timer) frame_timer = CreateWaitableTimerW(NULL,FALSE,NULL);
    DWORD old;
    if (!VirtualProtect(&vtable[16],2*sizeof(void *),PAGE_READWRITE,&old)) return;
    InterlockedExchangePointer(&vtable[16],(void *)reset_hook);
    InterlockedExchangePointer(&vtable[17],(void *)present_hook);
    VirtualProtect(&vtable[16],2*sizeof(void *),old,&old);
    log_line("in-game LAN interface installed; frame limit 60 FPS");
}

static void log_line(const char *text) {
    if (log_file) {
        fprintf(log_file, "%s\n", text);
        fflush(log_file);
    }
}

static int readable(void *pointer, SIZE_T size) {
    MEMORY_BASIC_INFORMATION info;
    if (!pointer || !VirtualQuery(pointer, &info, sizeof(info))) return 0;
    if (info.State != MEM_COMMIT || info.Protect & (PAGE_GUARD | PAGE_NOACCESS)) return 0;
    return (uintptr_t)pointer + size <= (uintptr_t)info.BaseAddress + info.RegionSize;
}

__declspec(dllexport) volatile uint32_t clonewars_saber_host_repair[4];

__attribute__((used,noinline)) static int __cdecl saber_allow_host_weapon_fx(unsigned char *actor) {
    if (!lan_is_host() || lan_status()!=LAN_CONNECTED || game_sync_status()!=2 ||
        *(volatile unsigned char *)0xfbc161 || actor!=*(unsigned char **)0xfb4940 ||
        !readable(actor,0x1440) || *(uint16_t *)(actor+0xdc0)!=360 ||
        (*(uint32_t *)(actor+0x50)&3)!=3 || actor[0x54] || !actor[0x10ec] ||
        (int8_t)actor[0xdde]<=0) return 0;
    unsigned char *weapon=*(unsigned char **)(actor+0x528);
    if (!readable(weapon,0x4c) || (weapon[0x49]&8) || (weapon[0x4a]&0x40)) return 0;
    unsigned char *descriptor=*(unsigned char **)(weapon+8);
    if (!readable(descriptor,0xb0)) return 0;
    unsigned char *definition=*(unsigned char **)(descriptor+0xac);
    if (!readable(definition,0x12e) || (*(uint16_t *)(definition+0x12c)&0xe0)!=0x40 ||
        !(*(uint32_t *)(definition+0x38)&0x80000)) return 0;
    ++clonewars_saber_host_repair[0];
    clonewars_saber_host_repair[2]=*(uint32_t *)0xfb4b6c;
    return 1;
}

__attribute__((used)) static const uintptr_t saber_weapon_walk=0x7c7d82;
__attribute__((used)) static const uintptr_t saber_weapon_skip=0x7c7de9;

__attribute__((naked)) static void saber_weapon_visibility_gate(void) {
    __asm__ volatile(
        "cmpb $0,0x42(%eax)\n\t"
        "jne 1f\n\t"
        // The other caller equips weapons; only the native per-actor FX update can bypass visibility.
        "cmpl $0x9b6c10,4(%esp)\n\t"
        "jne 2f\n\t"
        "pushal\n\tpushl %ebx\n\tcall _saber_allow_host_weapon_fx\n\taddl $4,%esp\n\t"
        "testl %eax,%eax\n\tpopal\n\tjz 2f\n\t"
        "1: jmp *_saber_weapon_walk\n\t"
        "2: jmp *_saber_weapon_skip\n\t");
}

static void install_saber_weapon_visibility_gate(void) {
    unsigned char *site=(unsigned char *)0x7c7d7c;
    const unsigned char expected[]={0x80,0x78,0x42,0x00,0x74,0x67};
    DWORD old;
    if (memcmp(site,expected,sizeof(expected)) ||
        !VirtualProtect(site,sizeof(expected),PAGE_EXECUTE_READWRITE,&old)) return;
    int32_t rel=(int32_t)((uintptr_t)saber_weapon_visibility_gate-(uintptr_t)site-5);
    site[0]=0xe9;
    memcpy(site+1,&rel,4);
    site[5]=0x90;
    FlushInstructionCache(GetCurrentProcess(),site,sizeof(expected));
    VirtualProtect(site,sizeof(expected),old,&old);
    clonewars_saber_host_repair[1]=1;
}

static char *focus_manager;
static uintptr_t focus_state;
static int focus_player=-1;
static char *layout_cache_manager;
static int layout_cache_fullscreen=-1;

static char *current_camera_manager(void) {
    char *root=*(char **)0xe9018c;
    char *box=readable(root,0x2c) ? *(char **)(root+0x28) : NULL;
    char *camera=readable(box,0x2c) ? *(char **)(box+0x28) : NULL;
    return readable(camera,0x1420) && *(uintptr_t *)camera==0xc3e248 ? camera : NULL;
}
static int personal_camera_allowed(char *parent) {
    char *root=*(char **)0xfb2e60;
    return camera_selected()>=0 && lan_status()==LAN_CONNECTED &&
        readable(parent,0x1420) && parent==current_camera_manager() &&
        readable(root,0x1b7c) && *(int *)(root+0x1b78)==0xe &&
        !*(unsigned char *)0xfbc161 && *(int *)0xe6e61c<0 &&
        *(int *)0xfb11dc==2;
}
static int ordinary_camera_layout(char *parent) {
    if (!readable(parent,0x1420)) return 0;
    return *(uint32_t *)(parent+0xf20)<=2 &&
        *(int *)(parent+0x13c0)==-1 && *(uint32_t *)(parent+0x13d8)==0;
}
static int personal_hooks_ready;
extern __declspec(dllexport) volatile LONG clonewars_camera_native_order_enabled;
extern __declspec(dllexport) volatile LONG clonewars_camera_native_order_installed;
static int camera_order_pair(char *,char **,char **);
static int personal_fullscreen(char *parent) {
    char *views[2],*targets[2];
    return personal_hooks_ready && clonewars_camera_native_order_enabled &&
        clonewars_camera_native_order_installed==1 && (clonewars_camera_fullclip&64) && personal_camera_allowed(parent) &&
        ordinary_camera_layout(parent) && *(uint32_t *)(parent+0xf20)==2 &&
        *(uintptr_t *)(parent+0x1c)==0xe62090 && camera_order_pair(parent,views,targets);
}
#include "camera_native_order.inc"
#include "camera_order_install.h"

typedef void (__attribute__((thiscall)) *NativeModelRender)(void *, void *);
static void __attribute__((fastcall)) personal_model_render(void *scene,void *unused,void *event) {
    (void)unused;
    NativeModelRender render=(NativeModelRender)0x731d00;
    volatile uint16_t *motion_blur=(volatile uint16_t *)0xd78430;
    uint16_t enabled=*motion_blur;
    unsigned segment=*(const uint32_t *)0xeb8374;
    char *parent=camera_order_prepared_parent;
    DWORD error=GetLastError();
    int personal=enabled && segment>=1 && segment<=2 && (clonewars_camera_fullclip&16) &&
        GetCurrentThreadId()==clonewars_camera_threads[0] &&
        personal_fullscreen(parent) && camera_order_presentation_ready(parent);
    SetLastError(error);
    if (!personal) {
        render(scene,event);
        return;
    }

    // The native motion pass shares its screen history across the two world segments.
    *motion_blur=0;
    ++clonewars_camera_native_order_debug[8];
    __try {
        render(scene,event);
    } __finally {
        *motion_blur=enabled;
    }
}

static void camera_render_reset_state(void) {
    layout_cache_manager=NULL;layout_cache_fullscreen=-1;
    camera_order_prepared_parent=NULL;camera_order_prepared_role=-1;
    camera_order_prepared_views[0]=camera_order_prepared_views[1]=NULL;
}

static const float fullscreen_center[4]={0.5f,0.5f,0.0f,1.0f};
static const float fullscreen_polygon[16]={0,0,0,1, 1,0,0,1, 1,1,0,1, 0,1,0,1};

typedef unsigned char (__attribute__((thiscall)) *ClipOverride)(void *,void *,float *,void *,int);
static ClipOverride original_clip;
static unsigned char __attribute__((fastcall)) personal_clip(void *state,void *unused,
        void *parent,float *output,void *camera,int player) {
    (void)unused;
    if (personal_fullscreen(parent)) {
        memcpy(output,fullscreen_center,sizeof(fullscreen_center));
        ++clonewars_camera_debug[6];
        return 1;
    }
    return original_clip(state,parent,output,camera,player);
}

typedef void (__attribute__((thiscall)) *LayoutCenters)(void *,void *);
static LayoutCenters original_layout_centers;
static void __attribute__((fastcall)) personal_layout_centers(void *state,void *unused,void *parent) {
    (void)unused;
    original_layout_centers(state,parent);
    if (!personal_fullscreen(parent)) return;
    for (int i=0;i<4;++i) {
        char *view=((char **)((char *)parent+0xf24))[i];
        if (!readable(view,0xb4) || *(int *)(view+0x2c)!=1) continue;
        char *target=*(char **)(view+0xa8);
        if (readable(target,0x60)) memcpy(target+0x50,fullscreen_center,sizeof(fullscreen_center));
    }
}

typedef void (__attribute__((thiscall)) *RenderViews)(void *,void *,void *);
static RenderViews original_render_views;
static void __attribute__((fastcall)) personal_render_views(void *state,void *unused,void *parent,void *view) {
    (void)unused;
    if (!personal_fullscreen(parent)) {
        original_render_views(state,parent,view);
        return;
    }
    for (int i=0;i<4;++i) {
        char *candidate=((char **)((char *)parent+0xf24))[i];
        if (!readable(candidate,0xb4) || *(int *)(candidate+0x2c)!=1) continue;
        char *target=*(char **)(candidate+0xa8);
        if (!readable(target,0xe0)) continue;
        memcpy(target+0x70,fullscreen_polygon,sizeof(fullscreen_polygon));
        *(int *)(target+0xc0)=4;
        memcpy(target+0xd0,fullscreen_center,sizeof(fullscreen_center));
    }
    uint32_t separator=*(uint32_t *)((char *)parent+0x13bc);
    unsigned char composite=*(unsigned char *)0xe63007;
    *(float *)((char *)parent+0x13bc)=0.0f;
    /* The native split compositor would mix the other camera into the personal view. */
    *(unsigned char *)0xe63007=0;
    original_render_views(state,parent,view);
    *(uint32_t *)((char *)parent+0x13bc)=separator;
    *(unsigned char *)0xe63007=composite;
}
static void forget_camera_focus(void) {
    focus_manager=NULL; focus_player=-1; focus_state=0;
    layout_cache_manager=NULL; layout_cache_fullscreen=-1;
    clonewars_camera_debug[7]=0;
}
static void release_camera_focus(void) {
    if (readable(focus_manager,0x1420) && focus_manager==current_camera_manager() &&
        *(uintptr_t *)(focus_manager+0x1c)==0xe62090 && focus_state==0xe62070) {
        typedef void (__attribute__((thiscall)) *Transition)(void *,void *);
        ((Transition)0x77a550)(focus_manager,(void *)focus_state);
    }
    forget_camera_focus();
}
static void focus_camera(char *parent) {
    if (!ordinary_camera_layout(parent)) {
        /* Native modes3/4 own scripted focus and its blend; changing state here cancels that transition. */
        if (focus_manager && (focus_manager!=parent ||
            !readable(parent,0x1420) || *(uintptr_t *)(parent+0x1c)!=0xe62090))
            forget_camera_focus();
        return;
    }
    char *views[2],*targets[2];
    if (!personal_camera_allowed(parent) || !camera_order_pair(parent,views,targets)) { release_camera_focus(); return; }
    uintptr_t state=*(uintptr_t *)(parent+0x1c);
    if (focus_manager && (focus_manager!=parent || state!=0xe62090)) release_camera_focus();
    if (state==0xe62070) {
        typedef void (__attribute__((thiscall)) *Transition)(void *,void *);
        focus_manager=parent; focus_state=state;
        ((Transition)0x77a550)(parent,(void *)0xe62090);
    }
    if (focus_manager==parent && *(uintptr_t *)(parent+0x1c)==0xe62090) {
        focus_player=camera_selected();
        clonewars_camera_debug[7]=(uint32_t)focus_player+1;
    }
}

static void __attribute__((fastcall)) update_hook(void *state, void *unused, void *parent,
                                                 void *delta, unsigned char flag) {
    (void)unused;
    uintptr_t table=*(uintptr_t *)state;
    int slot=table==tables[0] ? 0 : table==tables[1] ? 1 : 2;
    int observed_parent=parent==current_camera_manager();
    if (observed_parent) {
        manager=parent;
        camera_init_observer_snapshot(parent,1,camera_selected());
        focus_camera(parent);
        camera_init_observer_snapshot(parent,2,camera_selected());
        char *views[2],*targets[2];
        if (focus_manager==parent && ordinary_camera_layout(parent) && camera_order_pair(parent,views,targets) &&
            *(uintptr_t *)((char *)parent+0x1c)==0xe62090) {
            int full=personal_fullscreen(parent)!=0;
            if (layout_cache_manager!=parent || layout_cache_fullscreen!=full) {
                /* One native update branch reuses the previous split normal until this cache is invalidated. */
                *(uint32_t *)0xfb11d8=0;
                layout_cache_manager=parent;
                layout_cache_fullscreen=full;
            }
            originals[2]((void *)0xe62090,parent,delta,flag);
            camera_init_observer_snapshot(parent,3,camera_selected());
            return;
        }
        void *active=*(void **)((char *)parent+0x1c);
        if (active!=state && readable(active,sizeof(void *))) {
            uintptr_t active_table=*(uintptr_t *)active;
            for (int i=0;i<3;++i) if (active_table==tables[i]) {
                originals[i](active,parent,delta,flag);
                camera_init_observer_snapshot(parent,3,camera_selected());
                return;
            }
        }
    }
    originals[slot](state,parent,delta,flag);
    if (observed_parent) camera_init_observer_snapshot(parent,3,camera_selected());
}

static int copy_native_view(IDirect3DDevice9 *device,char *parent) {
    int player=camera_selected();
    if (!personal_fullscreen(parent) || !camera_order_presentation_ready(parent)) return 0;
    char *view=NULL;
    for (int i=0;i<4;++i) {
        char *candidate=((char **)(parent+0xf24))[i];
        if (readable(candidate,0xb4) && *(int *)(candidate+0x2c)==1 &&
            *(short *)(candidate+0xac)==player) view=candidate;
    }
    if (!view || *(uint32_t *)(view+0x34)!=1) return 0;
    char *target=*(char **)(view+0xa8);
    if (!readable(target,0x3c)) return 0;
    unsigned id=*(unsigned *)(target+0x38);
    char **registry=*(char ***)0xec07c0;
    if (!id || id>*(unsigned *)0xec07d0 || !readable(registry+id-1,sizeof(void *))) return 0;
    char *entry=registry[id-1];
    if (!readable(entry,0x58)) return 0;
    char *texture=*(char **)(entry+0x54);
    if (!readable(texture,0x30)) return 0;
    IDirect3DTexture9 *native=*(IDirect3DTexture9 **)(texture+0x2c);
    if (!readable(native,sizeof(void *)) || !readable(*(void **)native,22*sizeof(void *)) ||
        IDirect3DTexture9_GetType(native)!=D3DRTYPE_TEXTURE) return 0;
    IDirect3DSurface9 *surface=NULL,*backbuffer=NULL;
    if (FAILED(IDirect3DTexture9_GetSurfaceLevel(native,0,&surface))) return 0;
    HRESULT copied=E_FAIL;
    if (SUCCEEDED(IDirect3DDevice9_GetBackBuffer(device,0,0,D3DBACKBUFFER_TYPE_MONO,&backbuffer))) {
        D3DSURFACE_DESC source,destination;
        IDirect3DSurface9_GetDesc(surface,&source); IDirect3DSurface9_GetDesc(backbuffer,&destination);
        clonewars_camera_debug[0]=(uint32_t)(uintptr_t)surface;
        clonewars_camera_debug[1]=id;
        clonewars_camera_debug[2]=source.Width; clonewars_camera_debug[3]=source.Height;
        if (source.Width==destination.Width && source.Height==destination.Height)
            copied=IDirect3DDevice9_StretchRect(device,surface,NULL,backbuffer,NULL,D3DTEXF_NONE);
        IDirect3DSurface9_Release(backbuffer);
    }
    IDirect3DSurface9_Release(surface);
    clonewars_camera_debug[4]=(uint32_t)copied;
    if (SUCCEEDED(copied)) ++clonewars_camera_debug[5];
    return SUCCEEDED(copied);
}

static int crop_camera(IDirect3DDevice9 *device) {
    /* Segment preparation can use a split state the engine entered on its own. */
    if ((clonewars_camera_fullclip&16) && copy_native_view(device,current_camera_manager())) return 1;
    if (!personal_camera_allowed(manager) || !ordinary_camera_layout(manager) ||
        *(uint32_t *)((char *)manager+0xf20)!=2 || focus_manager!=manager ||
        *(uintptr_t *)(manager+0x1c)!=0xe62090) {
        if (selected_target) { IDirect3DSurface9_Release(selected_target); selected_target=NULL; }
        return 0;
    }

    if (personal_fullscreen(manager) && camera_order_presentation_ready(manager)) return 0;
    if (selected_target && selected_target_player!=camera_selected()) {
        IDirect3DSurface9_Release(selected_target); selected_target=NULL;
    }
    if (selected_target) {
        IDirect3DSurface9 *backbuffer=NULL;
        HRESULT copied=E_FAIL;
        if (SUCCEEDED(IDirect3DDevice9_GetBackBuffer(device,0,0,D3DBACKBUFFER_TYPE_MONO,&backbuffer))) {
            copied=backbuffer==selected_target ? S_OK : IDirect3DDevice9_StretchRect(device,selected_target,NULL,backbuffer,NULL,D3DTEXF_LINEAR);
            IDirect3DSurface9_Release(backbuffer);
        }
        IDirect3DSurface9_Release(selected_target); selected_target=NULL;
        clonewars_camera_debug[4]=(uint32_t)copied;
        if (SUCCEEDED(copied)) return 0;
    }
    int player=camera_selected();
    char *base=manager;
    if (player<0 || !readable(base,0x1420) || *(uintptr_t *)base!=0xc3e248) return 0;
    char *chosen=NULL;
    for (int i=0;i<4;++i) {
        char *view=((char **)(base+0xf24))[i];
        if (readable(view,0xb4) && *(uintptr_t *)view==0xc3dc94 &&
            *(int *)(view+0x2c)==1 && *(short *)(view+0xac)==player) chosen=view;
    }
    if (!chosen) return 0;
    float *r=(float *)(chosen+4);
    if (r[0]<0 || r[1]<0 || r[2]>1 || r[3]>1 || r[2]<=0 || r[3]<=0 ||
        (r[0]==0 && r[1]==0 && r[2]==1 && r[3]==1)) return 0;
    IDirect3DSurface9 *backbuffer=NULL;
    if (FAILED(IDirect3DDevice9_GetBackBuffer(device,0,0,D3DBACKBUFFER_TYPE_MONO,&backbuffer))) return 0;
    D3DSURFACE_DESC description;
    IDirect3DSurface9_GetDesc(backbuffer,&description);
    if (camera_surface && (camera_width!=description.Width || camera_height!=description.Height || camera_format!=description.Format)) {
        IDirect3DSurface9_Release(camera_surface); camera_surface=NULL;
    }
    if (!camera_surface && SUCCEEDED(IDirect3DDevice9_CreateRenderTarget(device,description.Width,description.Height,
            description.Format,D3DMULTISAMPLE_NONE,0,FALSE,&camera_surface,NULL))) {
        camera_width=description.Width; camera_height=description.Height; camera_format=description.Format;
    }
    RECT source={(LONG)(r[0]*description.Width),(LONG)(r[1]*description.Height),
                 (LONG)((r[0]+r[2])*description.Width),(LONG)((r[1]+r[3])*description.Height)};
    if (source.right>(LONG)description.Width) source.right=(LONG)description.Width;
    if (source.bottom>(LONG)description.Height) source.bottom=(LONG)description.Height;
    if (camera_surface && source.right>source.left && source.bottom>source.top &&
        SUCCEEDED(IDirect3DDevice9_StretchRect(device,backbuffer,&source,camera_surface,NULL,D3DTEXF_LINEAR)))
        IDirect3DDevice9_StretchRect(device,camera_surface,NULL,backbuffer,NULL,D3DTEXF_NONE);
    IDirect3DSurface9_Release(backbuffer);
    return 0;
}

static void observe_view_gpu_impl(void *view,void *parent,int role,DWORD thread,int forced) {
    if (!(forced || clonewars_camera_gpu_observation_enabled) || !game_device || role<0 || role>1 ||
        thread!=clonewars_camera_threads[0]) return;
    __attribute__((aligned(16))) unsigned char fx[512];
    __asm__ volatile("fxsave %0" : "=m"(fx));
    DWORD error=GetLastError();
    uint32_t default_mxcsr=0x1f80;
    __asm__ volatile("fninit; ldmxcsr %0" : : "m"(default_mxcsr));
    uint32_t row[40]={0};
    row[11]=row[13]=row[18]=row[25]=row[30]=(uint32_t)E_PENDING;row[1]=1;row[2]=(uint32_t)role;row[3]=(uint32_t)(uintptr_t)view;
    row[4]=(uint32_t)(uintptr_t)parent;row[5]=thread;row[6]=*(uint32_t *)0xfb4b6c;row[7]=*(uint32_t *)0xfb4b74;
    char *engine=*(char **)0xfb0afc;if(readable(engine,0xe10))row[8]=*(uint32_t *)(engine+0xe0c);
    LARGE_INTEGER q;QueryPerformanceCounter(&q);row[9]=q.LowPart;row[10]=(uint32_t)q.HighPart;
    IDirect3DSurface9 *target=NULL;row[11]=(uint32_t)IDirect3DDevice9_GetRenderTarget(game_device,0,&target);
    if (SUCCEEDED((HRESULT)row[11]) && target) {
        row[12]=(uint32_t)(uintptr_t)target;D3DSURFACE_DESC d;
        row[13]=(uint32_t)IDirect3DSurface9_GetDesc(target,&d);
        if(SUCCEEDED((HRESULT)row[13])){row[14]=d.Width;row[15]=d.Height;row[16]=d.Format;row[17]=d.MultiSampleType;}
        IDirect3DSurface9_Release(target);
    }
    D3DVIEWPORT9 v;row[18]=(uint32_t)IDirect3DDevice9_GetViewport(game_device,&v);
    if(SUCCEEDED((HRESULT)row[18])){row[19]=v.X;row[20]=v.Y;row[21]=v.Width;row[22]=v.Height;memcpy(row+23,&v.MinZ,4);memcpy(row+24,&v.MaxZ,4);}
    RECT r;row[25]=(uint32_t)IDirect3DDevice9_GetScissorRect(game_device,&r);
    if(SUCCEEDED((HRESULT)row[25]))memcpy(row+26,&r,16);
    DWORD enabled=0;row[30]=(uint32_t)IDirect3DDevice9_GetRenderState(game_device,D3DRS_SCISSORTESTENABLE,&enabled);row[31]=enabled;
    row[32]=clonewars_camera_fullclip;row[33]=(uint32_t)camera_selected();row[34]=UINT32_MAX;
    if(readable(parent,0xf24)){row[34]=*(uint32_t *)((char *)parent+0xf20);row[35]|=1;}
    volatile uint32_t *destination=clonewars_camera_gpu_observation[role];destination[0]=0;
    memcpy((void *)(destination+1),row+1,39*4);MemoryBarrier();
    if(!++gpu_observation_serial)++gpu_observation_serial;destination[0]=gpu_observation_serial;
    SetLastError(error);__asm__ volatile("fxrstor %0" : : "m"(fx));
}

static void observe_view_gpu(void *view,void *parent,int role,DWORD thread) {
    observe_view_gpu_impl(view,parent,role,thread,0);
}

__attribute__((used,noinline)) static void camera_compositor_sample(void *view,void *parent,uint32_t native_result,uint32_t phase,uint32_t *call_id) {
    if (!clonewars_camera_compositor_enabled || clonewars_camera_compositor_count>=128) return;
    DWORD thread=GetCurrentThreadId();
    if(thread!=clonewars_camera_threads[0] || !readable(view,0xb4) || !readable(parent,0x13c8)) return;
    char *v=view,*m=parent;
    if(*(uint32_t *)v!=0xc3dc94 || *(uint32_t *)m!=0xc3e248) return;
    int role=*(short *)(v+0xac);if(role<0 || role>1)return;
    if(phase>1 || !call_id)return;
    if(!phase){if(compositor_call_serial==UINT32_MAX)return;*call_id=++compositor_call_serial;}
    if(!*call_id)return;
    uint32_t row[80]={0};uint32_t valid=3;
    row[1]=2;row[2]=(uint32_t)clonewars_camera_compositor_count+1;row[3]=thread;
    row[4]=*(uint32_t *)0xfb4b6c;row[5]=*(uint32_t *)0xfb4b74;
    LARGE_INTEGER q;QueryPerformanceCounter(&q);row[6]=q.LowPart;row[7]=(uint32_t)q.HighPart;
    row[8]=(uint32_t)(uintptr_t)view;row[9]=(uint32_t)(uintptr_t)parent;row[10]=(uint32_t)role;
    row[11]=*(uint32_t *)(v+0x34);row[12]=*(uint32_t *)0xeb8374;row[13]=*(uint32_t *)(m+0x13c4);
    row[14]=*(unsigned char *)0xe63007|((uint32_t)*(unsigned char *)0xe63008<<8)|((uint32_t)*(unsigned char *)0xe63009<<16);
    char *gate=*(char **)0xf9c80c;row[15]=(uint32_t)(uintptr_t)gate;row[16]=UINT32_MAX;
    if(readable(gate,0x24)){row[16]=*(uint32_t *)(gate+0x20);valid|=4;}
    row[17]=*(uint32_t *)0xfb2e6c;row[18]=*(uint32_t *)0xfb11dc;
    row[19]=*(uint32_t *)0xfb11fc;row[20]=*(uint32_t *)0xfb1200;
    char *target=*(char **)(v+0xa8);row[21]=(uint32_t)(uintptr_t)target;
    if(readable(target,0x3c)){
        valid|=8;char *object=*(char **)(target+0x30);row[22]=(uint32_t)(uintptr_t)object;row[23]=*(uint32_t *)(target+0x38);
        if(readable(object,0xd80)){valid|=16;char *pair=*(char **)(object+0xd7c);row[24]=(uint32_t)(uintptr_t)pair;
            if(readable(pair,8)){valid|=32;memcpy(row+25,pair,8);}}
    }
    row[27]=valid;row[28]=native_result&255;row[29]=clonewars_camera_fullclip;row[30]=(uint32_t)camera_selected();
    row[32]=phase;row[33]=*call_id;row[34]=phase==1;
    uint32_t before_gpu=gpu_observation_serial;
    observe_view_gpu_impl(view,parent,role,thread,1);
    if(gpu_observation_serial!=before_gpu){row[31]=1;memcpy(row+40,(const void *)clonewars_camera_gpu_observation[role],160);}
    uint32_t index=(uint32_t)clonewars_camera_compositor_count;
    if(index>=128)return;
    volatile uint32_t *out=clonewars_camera_compositor_rows[index];out[0]=0;
    memcpy((void *)(out+1),row+1,79*4);MemoryBarrier();out[0]=index+1;MemoryBarrier();
    clonewars_camera_compositor_count=(LONG)(index+1);
}

__attribute__((noinline)) static void capture_view_frame_impl(void *view,void *parent) {
    char *v=view;
    if (!readable(v,0xb4) || *(uintptr_t *)v!=0xc3dc94) return;
    int view_player=*(short *)(v+0xac);
    DWORD thread=GetCurrentThreadId();
    if (view_player>=0 && view_player<2) clonewars_camera_threads[view_player+1]=thread;
    observe_view_gpu(view,parent,view_player,thread);
    if (thread!=clonewars_camera_threads[0] || (clonewars_camera_fullclip&4)) return;
    if (personal_camera_allowed(parent) && ordinary_camera_layout(parent) &&
        *(uint32_t *)((char *)parent+0xf20)==2 && focus_manager==parent &&
        *(uintptr_t *)((char *)parent+0x1c)==0xe62090 &&
        readable(v,0xb4) && *(uintptr_t *)v==0xc3dc94 && game_device) {
        IDirect3DSurface9 *surface=NULL;
        if (SUCCEEDED(IDirect3DDevice9_GetRenderTarget(game_device,0,&surface))) {
            int player=*(short *)(v+0xac);
            if (player>=0 && player<2) clonewars_camera_debug[player]=(uint32_t)(uintptr_t)surface;
            if (player>=0 && player<2) {
                D3DVIEWPORT9 viewport;
                if (SUCCEEDED(IDirect3DDevice9_GetViewport(game_device,&viewport))) {
                    clonewars_camera_viewport[player*6]=viewport.X;
                    clonewars_camera_viewport[player*6+1]=viewport.Y;
                    clonewars_camera_viewport[player*6+2]=viewport.Width;
                    clonewars_camera_viewport[player*6+3]=viewport.Height;
                    D3DSURFACE_DESC target_description;
                    IDirect3DSurface9_GetDesc(surface,&target_description);
                    clonewars_camera_viewport[player*6+4]=target_description.Width;
                    clonewars_camera_viewport[player*6+5]=target_description.Height;
                    RECT scissor;
                    DWORD enabled=0;
                    if (SUCCEEDED(IDirect3DDevice9_GetScissorRect(game_device,&scissor))) {
                        clonewars_camera_viewport[12+player*5]=(uint32_t)scissor.left;
                        clonewars_camera_viewport[13+player*5]=(uint32_t)scissor.top;
                        clonewars_camera_viewport[14+player*5]=(uint32_t)scissor.right;
                        clonewars_camera_viewport[15+player*5]=(uint32_t)scissor.bottom;
                    }
                    IDirect3DDevice9_GetRenderState(game_device,D3DRS_SCISSORTESTENABLE,&enabled);
                    clonewars_camera_viewport[16+player*5]=enabled;
                }
            }
            if (player==camera_selected()) {
                D3DSURFACE_DESC desc;
                IDirect3DSurface9_GetDesc(surface,&desc);
                clonewars_camera_debug[2]=desc.Width; clonewars_camera_debug[3]=desc.Height;
                ++clonewars_camera_debug[5];
                if (tap_surface) {
                    D3DSURFACE_DESC stored;
                    IDirect3DSurface9_GetDesc(tap_surface,&stored);
                    if (stored.Width!=desc.Width || stored.Height!=desc.Height || stored.Format!=desc.Format) {
                        IDirect3DSurface9_Release(tap_surface); tap_surface=NULL;
                    }
                }
                if (!tap_surface) IDirect3DDevice9_CreateRenderTarget(game_device,desc.Width,desc.Height,
                    desc.Format,D3DMULTISAMPLE_NONE,0,FALSE,&tap_surface,NULL);
                if (tap_surface && SUCCEEDED(IDirect3DDevice9_StretchRect(game_device,surface,NULL,tap_surface,NULL,D3DTEXF_NONE))) {
                    if (selected_target) IDirect3DSurface9_Release(selected_target);
                    IDirect3DSurface9_AddRef(tap_surface); selected_target=tap_surface;
                    selected_target_player=player;
                }
            }
            IDirect3DSurface9_Release(surface);
        }
    }
 }
static void capture_view_frame(void *view,void *parent) {
    unsigned char native_fx[512] __attribute__((aligned(16)));
    __asm__ volatile("fxsave %0":"=m"(native_fx)::"memory");
    DWORD error=GetLastError();
    capture_view_frame_impl(view,parent);
    SetLastError(error);
    __asm__ volatile("fxrstor %0"::"m"(native_fx):"memory");
}
static void (__attribute__((cdecl)) *original_view_finish)(void *);
static void __attribute__((cdecl)) camera_view_finish(void *view) {
    original_view_finish(view);
    capture_view_frame(view,current_camera_manager());
}
#include "camera_compositor_thunk.h"
__attribute__((used)) static const uintptr_t camera_original_target_end=0x77afa0;
static unsigned char __attribute__((fastcall,naked)) camera_target_end(void *view,void *unused,void *parent) {
    __asm__ volatile(CAMERA_COMPOSITOR_THUNK_ASM("_camera_original_target_end","_camera_compositor_sample"));
}

__declspec(dllexport) volatile uint32_t clonewars_background_window_version=1;
__declspec(dllexport) volatile uint32_t clonewars_background_window_stride=64;
__declspec(dllexport) volatile LONG clonewars_background_window_commit;
__declspec(dllexport) volatile uint32_t clonewars_background_window_state[16];
static LRESULT CALLBACK window_proc(HWND window, UINT message, WPARAM wp, LPARAM lp);
static void observe_background_window(HWND window,UINT message,int clamped) {
    uint32_t values[16]={0};DWORD pid=0,thread=GetWindowThreadProcessId(window,&pid),observing=GetCurrentThreadId();
    values[0]=(uint32_t)(uintptr_t)window;values[1]=observing;values[2]=thread;values[3]=pid;
    values[5]=(uint32_t)(uintptr_t)window_proc;values[6]=(uint32_t)background_capture;
    if (thread==observing && pid==GetCurrentProcessId()) {
        values[7]|=1;SetLastError(0);
        LONG_PTR current=GetWindowLongPtrW(window,GWLP_WNDPROC);DWORD error=GetLastError();
        values[4]=(uint32_t)(uintptr_t)current;values[12]=error;
        if (current || !error) values[7]|=2;
        if (current==(LONG_PTR)window_proc) values[7]|=8;
        RECT bounds;
        if (GetWindowRect(window,&bounds)) {
            values[7]|=4;values[8]=(uint32_t)bounds.left;values[9]=(uint32_t)bounds.top;
            values[10]=(uint32_t)bounds.right;values[11]=(uint32_t)bounds.bottom;
        }
    }
    values[13]=message;values[14]=GetTickCount();values[15]=(uint32_t)clamped;
    InterlockedIncrement(&clonewars_background_window_commit);
    memcpy((void *)clonewars_background_window_state,values,sizeof(values));
    InterlockedIncrement(&clonewars_background_window_commit);
}
static LRESULT background_window_position_message(HWND window,UINT message,WPARAM wp,LPARAM lp) {
    LRESULT result=CallWindowProcW(previous_proc,window,message,wp,lp);
    if (!background_capture) return result;
    unsigned char outgoing_fx[512] __attribute__((aligned(16)));
    __asm__ volatile("fxsave %0":"=m"(outgoing_fx));DWORD error=GetLastError();int clamped=0;
    if (message==WM_WINDOWPOSCHANGING && lp) {
        WINDOWPOS *position=(WINDOWPOS *)lp;
        POINT offscreen=background_window_position(window,(position->flags&SWP_NOSIZE)?0:position->cx,(position->flags&SWP_NOSIZE)?0:position->cy);
        position->x=offscreen.x;position->y=offscreen.y;position->hwndInsertAfter=HWND_BOTTOM;
        position->flags=(position->flags|SWP_NOACTIVATE)&~(SWP_NOMOVE|SWP_NOZORDER);clamped=1;
    }
    observe_background_window(window,message,clamped);
    SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(outgoing_fx));return result;
}

static LRESULT CALLBACK window_proc(HWND window, UINT message, WPARAM wp, LPARAM lp) {
    if (network_window_message(window,message,wp,lp)) return 0;
    if (message==WM_WINDOWPOSCHANGING || message==WM_WINDOWPOSCHANGED)
        return background_window_position_message(window,message,wp,lp);
    if (message == WM_GETMINMAXINFO) {
        LRESULT result=CallWindowProcW(previous_proc,window,message,wp,lp);
        MINMAXINFO *limits=(MINMAXINFO *)lp;
        limits->ptMaxTrackSize.x=8192;
        limits->ptMaxTrackSize.y=8192;
        return result;
    }
    if (message == WM_APP+0x350) {
        if (lp==1) game_request_reload((int)wp);
        else game_request_level((int)wp);
        return 0;
    }
    if (message == renderer_message) { install_renderer(); return 0; }
    if (message == window_message) {
        typedef void (__attribute__((thiscall)) *SetMode)(void *, unsigned int, unsigned int,
                                                        unsigned int, unsigned char, unsigned char);
        wchar_t config[MAX_PATH];
        GetModuleFileNameW(NULL,config,MAX_PATH);
        wchar_t *name=wcsrchr(config,L'\\');
        if (name) wcscpy(name+1,L"clonewars-display.ini");
        unsigned width=GetPrivateProfileIntW(L"Display",L"Width",2560,config);
        unsigned height=GetPrivateProfileIntW(L"Display",L"Height",1440,config);
        if (width<640 || width>7680 || height<480 || height>4320) { width=2560; height=1440; }
        ((SetMode)0x63f370)((void *)0xf925d0, width, height, 0, 1, 0);
        LONG style = (GetWindowLongW(window, GWL_STYLE) & ~WS_POPUP) | WS_OVERLAPPEDWINDOW;
        SetWindowLongW(window, GWL_STYLE, style);
        RECT rectangle = {0, 0, (LONG)width, (LONG)height};
        AdjustWindowRect(&rectangle, style, FALSE);
        int window_width=rectangle.right-rectangle.left,window_height=rectangle.bottom-rectangle.top;
        POINT position=background_capture ? background_window_position(window,window_width,window_height) : (POINT){80,80};
        if (!background_capture) ShowWindow(window,SW_RESTORE);
        SetWindowPos(window, background_capture?HWND_BOTTOM:HWND_NOTOPMOST,
                     position.x,position.y,window_width,window_height,
                     SWP_FRAMECHANGED|(background_capture?SWP_NOACTIVATE:SWP_SHOWWINDOW));
        if (background_capture) ShowWindow(window,SW_SHOWNOACTIVATE);
        log_line(*(int *)0xf92730 == 1 ? "windowed mode enabled from display config" : "windowed mode request failed");
        install_renderer();
        return 0;
    }
    if ((message == WM_KEYUP || message == WM_SYSKEYUP) && wp == VK_F12) return 0;
    if (message == WM_SYSCOMMAND && (wp & 0xfff0) == SC_KEYMENU) return 0;
    if (((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) && wp == VK_F12 &&
         !(lp & (1L << 30))) || message == menu_message) {
        if (menu_closed_at && GetTickCount() - menu_closed_at < 350) return 0;
        coop_toggle();
        log_line("in-game LAN screen toggled");
        menu_closed_at = GetTickCount();
        return 0;
    }
    int input_handled=coop_input(window,message,wp,lp);
    network_window_update();
    if (input_handled) return 0;
    return CallWindowProcW(previous_proc, window, message, wp, lp);
}

static BOOL CALLBACK find_window(HWND window, LPARAM ignored) {
    (void)ignored;
    DWORD pid;
    GetWindowThreadProcessId(window, &pid);
    wchar_t window_class[64]={0};
    int hidden_owned=background_capture && GetClassNameW(window,window_class,64) && !wcscmp(window_class,L"TTalesWindow");
    if (pid == GetCurrentProcessId() && (IsWindowVisible(window)||hidden_owned) && !GetWindow(window, GW_OWNER)) {
        game_window = window;
        return FALSE;
    }
    return TRUE;
}

static int camera_install_main_impl(HMODULE module){
    diagnostics_install(module);
    for (int i = 0; i < 3; ++i) {
        void **target = (void **)(tables[i] + 8);
        DWORD old;
        if (!VirtualProtect(target, sizeof(void *), PAGE_READWRITE, &old)) {
            log_line("VirtualProtect failed");
            return 0;
        }
        originals[i] = (Update)*target;
        InterlockedExchangePointer(target, (void *)update_hook);
        VirtualProtect(target, sizeof(void *), old, &old);
    }
    previous_proc = (WNDPROC)GetWindowLongPtrW(game_window, GWLP_WNDPROC);
    SetLastError(0);
    LONG_PTR replaced = SetWindowLongPtrW(game_window, GWLP_WNDPROC, (LONG_PTR)window_proc);
    if (!replaced && GetLastError()) previous_proc = NULL;
    log_line(previous_proc ? "F12 menu installed; camera override off" : "window hook failed");
    if (!previous_proc) return 0;
    network_window_configure(game_window);
    int loading_ready=loading_install();
    log_line(loading_ready ? "loading completion and intro synchronization installed" : "loading hook validation failed");
    void **layout_entry=(void **)(tables[2]+0x48);
    DWORD layout_protection;
    if (*layout_entry==(void *)0x775360 && VirtualProtect(layout_entry,sizeof(void *),PAGE_READWRITE,&layout_protection)) {
        original_layout_centers=(LayoutCenters)*layout_entry;
        *layout_entry=(void *)personal_layout_centers;
        VirtualProtect(layout_entry,sizeof(void *),layout_protection,&layout_protection);
    }
    void **clip_entry=(void **)(tables[0]+0x24);
    DWORD clip_protection;
    if (*clip_entry==(void *)0x775020 && VirtualProtect(clip_entry,sizeof(void *),PAGE_READWRITE,&clip_protection)) {
        original_clip=(ClipOverride)*clip_entry;
        *clip_entry=(void *)personal_clip;
        VirtualProtect(clip_entry,sizeof(void *),clip_protection,&clip_protection);
    }
    unsigned char *render=(unsigned char *)0x7815f0;
    const unsigned char render_prefix[6]={0x55,0x8b,0xec,0x83,0xe4,0xf0};
    if (!memcmp(render,render_prefix,sizeof(render_prefix))) {
        unsigned char *bridge=VirtualAlloc(NULL,11,MEM_RESERVE|MEM_COMMIT,PAGE_EXECUTE_READWRITE);
        DWORD protection;
        if (bridge && VirtualProtect(render,6,PAGE_EXECUTE_READWRITE,&protection)) {
            memcpy(bridge,render,6); bridge[6]=0xe9;
            *(int32_t *)(bridge+7)=(int32_t)((uintptr_t)render+6-(uintptr_t)bridge-11);
            original_render_views=(RenderViews)bridge;
            render[0]=0xe9;
            *(int32_t *)(render+1)=(int32_t)((uintptr_t)personal_render_views-(uintptr_t)render-5);
            render[5]=0x90;
            FlushInstructionCache(GetCurrentProcess(),bridge,11);
            FlushInstructionCache(GetCurrentProcess(),render,6);
            VirtualProtect(render,6,protection,&protection);
        } else if (bridge) VirtualFree(bridge,0,MEM_RELEASE);
    }
    personal_hooks_ready=original_layout_centers && original_clip && original_render_views;
    if(!clonewars_camera_native_order_installed){
        int order_result=camera_order_install_at((unsigned char *)0x7834ed,(const unsigned char *)0x77fe40,(void *)camera_order_hook,
            GetCurrentThreadId()==GetWindowThreadProcessId(game_window,NULL));
        clonewars_camera_native_order_installed=order_result==1?1:-1;
    }
    static const unsigned char model_render_prefix[]={0x55,0x8b,0xec,0x83,0xe4,0xf0,0x6a,0xff};
    camera_install_call_at((unsigned char *)0x732bd9,(const unsigned char *)0x731d00,(void *)personal_model_render,
        clonewars_camera_native_order_installed==1,model_render_prefix,sizeof(model_render_prefix));
    log_line(personal_hooks_ready ? "native fullscreen camera hooks installed" : "native fullscreen camera hooks incomplete");
    install_saber_weapon_visibility_gate();
    char saber_trace[2];
    if (GetEnvironmentVariableA("CLONEWARS_SABER_PASS_TRACE",saber_trace,sizeof(saber_trace))==1 && saber_trace[0]=='1') {
        install_saber_pass_tap(0x7add49,saber_actor_batch_native,(void *)saber_actor_batch_tap);
        static const uintptr_t producers[]={0x7966e2,0x7c8286,0x7c82dd,0x8c9b6c,0x8cc0c2,
            0x906b95,0x97b532,0x97b697,0x99d59b,0x9aae7a,0x9b2b1d,0x9b2be5,
            0x9b5fdf,0x9b62ef,0x9b64c8};
        for(unsigned i=0;i<sizeof(producers)/sizeof(*producers);++i)
            install_saber_pass_tap(producers[i],0x906b00,(void *)saber_producer_tap);
        install_saber_pass_tap(0x888549,0x906920,(void *)saber_age_tap);
        install_saber_pass_tap(0x8447b5,saber_draw_native,(void *)saber_pass_first);
        install_saber_pass_tap(0x8447f4,saber_draw_native,(void *)saber_pass_last);
        install_saber_pass_tap(0x5c0f45,saber_submit_indexed,(void *)saber_submit_glow_indexed);
        install_saber_pass_tap(0x5c0f58,saber_submit_plain,(void *)saber_submit_glow_plain);
        install_saber_pass_tap(0x5c1039,saber_submit_indexed,(void *)saber_submit_glow_repeat_indexed);
        install_saber_pass_tap(0x5c104c,saber_submit_plain,(void *)saber_submit_glow_repeat_plain);
        install_saber_pass_tap(0x5c1078,saber_submit_indexed,(void *)saber_submit_core_indexed);
        install_saber_pass_tap(0x5c109e,saber_submit_plain,(void *)saber_submit_core_plain);
        install_saber_pass_tap(0x907c2b,saber_submit_ribbon,(void *)saber_submit_other);
    }
    unsigned char *finish=(unsigned char *)0x756080;
    const unsigned char finish_prefix[9]={0x8b,0x4c,0x24,0x04,0xa1,0x14,0x0b,0xfb,0x00};
    if (!memcmp(finish,finish_prefix,sizeof(finish_prefix))) {
        unsigned char *bridge=VirtualAlloc(NULL,14,MEM_RESERVE|MEM_COMMIT,PAGE_EXECUTE_READWRITE);
        DWORD protection;
        if (bridge && VirtualProtect(finish,9,PAGE_EXECUTE_READWRITE,&protection)) {
            memcpy(bridge,finish,9); bridge[9]=0xe9;
            *(int32_t *)(bridge+10)=(int32_t)((uintptr_t)(finish+9)-(uintptr_t)(bridge+14));
            FlushInstructionCache(GetCurrentProcess(),bridge,14);
            original_view_finish=(void *)bridge;
            finish[0]=0xe9;
            *(int32_t *)(finish+1)=(int32_t)((uintptr_t)camera_view_finish-(uintptr_t)(finish+5));
            memset(finish+5,0x90,4);
            FlushInstructionCache(GetCurrentProcess(),finish,9);
            VirtualProtect(finish,9,protection,&protection);
            log_line("native view finish capture hook installed");
        } else if (bridge) VirtualFree(bridge,0,MEM_RELEASE);
    }
    unsigned char *target_end=(unsigned char *)0x781659;
    DWORD target_protection;
    if (*target_end==0xe8 && (uintptr_t)target_end+5+*(int32_t *)(target_end+1)==0x77afa0 &&
        VirtualProtect(target_end,5,PAGE_EXECUTE_READWRITE,&target_protection)) {
        int32_t displacement=(int32_t)((uintptr_t)camera_target_end-(uintptr_t)(target_end+5));
        memcpy(target_end+1,&displacement,4);
        FlushInstructionCache(GetCurrentProcess(),target_end,5);
        VirtualProtect(target_end,5,target_protection,&target_protection);
        log_line("native camera surface tap installed");
    }
    return personal_hooks_ready && loading_ready;
}
int camera_install_qualified_main(void){
 if(!game_window||GetCurrentThreadId()!=GetWindowThreadProcessId(game_window,NULL))return 0;
 if(camera_main_install_state<0)return 0;
 if(!camera_main_install_state){camera_main_install_state=-1;if(!camera_install_main_impl(camera_module))return 0;camera_main_install_state=1;}
 install_renderer();return 1;
}
static DWORD WINAPI initialize(void *module) {
    camera_module=(HMODULE)module;
    char path[MAX_PATH];
    GetModuleFileNameA((HMODULE)module, path, MAX_PATH);
    char *last = strrchr(path, '\\');
    if (last) snprintf(last+1,MAX_PATH-(last+1-path),"camera-%lu.log",GetCurrentProcessId());
    log_file = fopen(path, "a");
    /* Diagnostics byte hooks also await the qualified-main installation cohort. */
    log_line("camera build 5: persistent D3D hook, in-game LAN screen, 60 FPS");
    if ((uintptr_t)GetModuleHandleW(NULL) != 0x400000 ||
        !readable((void *)tables[0], 0x74) ||
        *(uintptr_t *)(tables[0] + 8) != 0x784ec0 ||
        *(uintptr_t *)(tables[1] + 8) != 0x7751b0 ||
        *(uintptr_t *)(tables[2] + 8) != 0x785340) {
        log_line("unsupported executable; hooks not installed");
        return 1;
    }
    char capture_setting[8];
    background_capture=GetEnvironmentVariableA("CLONEWARS_BACKGROUND_CAPTURE",capture_setting,8)>0 && capture_setting[0]=='1';
    for (int attempt = 0; attempt < 400 && !game_window; ++attempt) {
        EnumWindows(find_window, 0);
        if (!game_window) Sleep(50);
    }
    if (!game_window) {
        log_line("game window not found; hooks not installed");
        return 1;
    }
    if (background_capture) {
        POINT position=background_window_position(game_window,0,0);
        SetWindowPos(game_window,HWND_BOTTOM,position.x,position.y,0,0,SWP_NOSIZE|SWP_NOACTIVATE);
    }
    coop_set_window(game_window);
    game_sync_prepare_worker(GetWindowThreadProcessId(game_window,NULL));
    wchar_t display_config[MAX_PATH];
    GetModuleFileNameW(NULL,display_config,MAX_PATH);
    wchar_t *display_name=wcsrchr(display_config,L'\\');
    if (display_name) wcscpy(display_name+1,L"clonewars-display.ini");
    int apply_display=!background_capture && GetPrivateProfileIntW(L"Display",L"Windowed",0,display_config)==1;
    DWORD display_started=GetTickCount();
    int was_down = 0;
    DWORD renderer_checked = 0;
    while (IsWindow(game_window)) {
        DWORD tick = GetTickCount();
        if (apply_display && tick-display_started>=5000 && game_current_level()>=0 &&
            readable(*(void **)0xf925d4,sizeof(void *))) {
            apply_display=0;
            PostMessageW(game_window,window_message,0,0);
        }
        if (tick - renderer_checked >= 500) {
            void *device = *(void **)0xf925d4;
            if (readable(device,sizeof(void *))) {
                void **vtable = *(void ***)device;
                if (readable(vtable,18*sizeof(void *)) && vtable[17] != (void *)present_hook)
                    (void)0; /* Renderer COM hooks remain pending qualified-main review. */
            }
            renderer_checked = tick;
        }
        DWORD foreground_pid = 0;
        GetWindowThreadProcessId(GetForegroundWindow(), &foreground_pid);
        int down = (GetAsyncKeyState(VK_F12) & 0x8000) != 0;
        if (down && !was_down && foreground_pid == GetCurrentProcessId()) {
            PostMessageW(game_window, menu_message, 0, 0);
        }
        was_down = down;
        Sleep(12);
    }
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE module, DWORD reason, void *reserved) {
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(module);
        HANDLE thread = CreateThread(NULL, 0, initialize, module, 0, NULL);
        if (thread) CloseHandle(thread);
    }
    return TRUE;
}

