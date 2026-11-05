#define WIN32_LEAN_AND_MEAN
#define COBJMACROS
#include <windows.h>
#include <d3d9.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
static IDirect3DSurface9 *gpu,*cpu;
static unsigned char *shared;
static HANDLE capture_mapping;
static int enabled=-1;
static unsigned width=1280,height=720,fps=15;
static LARGE_INTEGER capture_frequency,last_capture;
__declspec(dllexport) volatile uint32_t clonewars_capture_info[8];
static IDirect3DDevice9 *capture_device;
void capture_reset(void) {
    if (gpu) IDirect3DSurface9_Release(gpu);
    if (cpu) IDirect3DSurface9_Release(cpu);
    gpu=cpu=NULL;
}
static unsigned setting(const char *name,unsigned fallback,unsigned low,unsigned high) {
    char value[24];DWORD n=GetEnvironmentVariableA(name,value,sizeof(value));
    if (!n || n>=sizeof(value)) return fallback;
    char *end;unsigned long v=strtoul(value,&end,10);
    return !*end && v>=low && v<=high ? (unsigned)v : fallback;
}
void capture_frame(IDirect3DDevice9 *device) {
    if (enabled<0) {
        char value[8];enabled=GetEnvironmentVariableA("CLONEWARS_BACKGROUND_CAPTURE",value,8)>0 && value[0]=='1';
        width=setting("CLONEWARS_CAPTURE_WIDTH",1280,640,3840);
        height=setting("CLONEWARS_CAPTURE_HEIGHT",720,360,2160);
        fps=setting("CLONEWARS_CAPTURE_FPS",15,1,60);
        QueryPerformanceFrequency(&capture_frequency);
        clonewars_capture_info[0]=width;clonewars_capture_info[1]=height;clonewars_capture_info[2]=fps;
    }
    if (!enabled) return;
    LARGE_INTEGER now;QueryPerformanceCounter(&now);
    LONGLONG elapsed=now.QuadPart-last_capture.QuadPart;
    if (last_capture.QuadPart && elapsed*fps<capture_frequency.QuadPart) return;
    if (!last_capture.QuadPart || elapsed*fps>2*capture_frequency.QuadPart) last_capture=now;
    else last_capture.QuadPart+=capture_frequency.QuadPart/fps;
    if (capture_device!=device) { capture_reset(); capture_device=device; }
    if (!shared) {
        char name[80];snprintf(name,sizeof(name),"Local\\CloneWarsCapture%lu",GetCurrentProcessId());
        HANDLE map=CreateFileMappingA(INVALID_HANDLE_VALUE,NULL,PAGE_READWRITE,0,24+width*height*4,name);
        if (!map) return;
        shared=MapViewOfFile(map,FILE_MAP_ALL_ACCESS,0,0,0);
        if (shared) capture_mapping=map; else CloseHandle(map);
        if (!shared) return;
    }
    IDirect3DSurface9 *back=NULL;
    HRESULT hr=IDirect3DDevice9_GetBackBuffer(device,0,0,D3DBACKBUFFER_TYPE_MONO,&back);
    if (SUCCEEDED(hr)) {
        D3DSURFACE_DESC d;IDirect3DSurface9_GetDesc(back,&d);
        clonewars_capture_info[3]=d.Width;clonewars_capture_info[4]=d.Height;
        if (d.Format!=D3DFMT_X8R8G8B8 && d.Format!=D3DFMT_A8R8G8B8) {
            IDirect3DSurface9_Release(back);((uint32_t *)shared)[3]=(uint32_t)E_NOTIMPL;return;
        }
        if (!gpu) hr=IDirect3DDevice9_CreateRenderTarget(device,width,height,d.Format,D3DMULTISAMPLE_NONE,0,FALSE,&gpu,NULL);
        if (SUCCEEDED(hr) && !cpu) hr=IDirect3DDevice9_CreateOffscreenPlainSurface(device,width,height,d.Format,D3DPOOL_SYSTEMMEM,&cpu,NULL);
        if (SUCCEEDED(hr)) hr=IDirect3DDevice9_StretchRect(device,back,NULL,gpu,NULL,D3DTEXF_LINEAR);
        if (SUCCEEDED(hr)) hr=IDirect3DDevice9_GetRenderTargetData(device,gpu,cpu);
        if (SUCCEEDED(hr)) {
            D3DLOCKED_RECT r;hr=IDirect3DSurface9_LockRect(cpu,&r,NULL,D3DLOCK_READONLY);
            if (SUCCEEDED(hr)) {
                InterlockedIncrement((LONG *)shared);
                ((uint32_t *)shared)[1]=width;((uint32_t *)shared)[2]=height;((uint32_t *)shared)[5]=fps;
                for (unsigned y=0;y<height;++y) memcpy(shared+24+y*width*4,(char *)r.pBits+y*r.Pitch,width*4);
                ((uint32_t *)shared)[4]=GetTickCount();
                ++clonewars_capture_info[5];
                MemoryBarrier();InterlockedIncrement((LONG *)shared);
                IDirect3DSurface9_UnlockRect(cpu);
            }
        }
        IDirect3DSurface9_Release(back);
    }
    ((uint32_t *)shared)[3]=(uint32_t)hr;clonewars_capture_info[6]=(uint32_t)hr;
}
