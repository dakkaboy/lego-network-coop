#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d9.h>
#include <shlobj.h>
#include <string.h>
#include <stdint.h>
#include <wchar.h>

static HMODULE real_d3d9;
static HMODULE proxy_module;
static INIT_ONCE once = INIT_ONCE_STATIC_INIT;
static char profile[MAX_PATH];
typedef HRESULT (WINAPI *FolderPath)(HWND,int,HANDLE,DWORD,LPSTR);
static FolderPath original_folder;

static HRESULT WINAPI folder_path(HWND owner, int folder, HANDLE token, DWORD flags, LPSTR path) {
    if ((folder & 0xff) == CSIDL_APPDATA && profile[0]) {
        strcpy(path,profile);
        return S_OK;
    }
    return original_folder(owner,folder,token,flags,path);
}

static BOOL CALLBACK load_real(PINIT_ONCE ignored, void *parameter, void **context) {
    (void)ignored; (void)parameter; (void)context;
    wchar_t path[MAX_PATH];
    UINT length = GetSystemDirectoryW(path,MAX_PATH);
    if (!length || length + 10 >= MAX_PATH) return FALSE;
    wcscpy(path+length,L"\\d3d9.dll");
    real_d3d9 = LoadLibraryW(path);
    return real_d3d9 != NULL;
}

static FARPROC resolve(const char *name) {
    if (!InitOnceExecuteOnce(&once,load_real,NULL,NULL)) return NULL;
    return GetProcAddress(real_d3d9,name);
}

static void prepare_game(void) {
    static LONG prepared;
    if (InterlockedExchange(&prepared,1)) return;
    unsigned char *base = (unsigned char *)GetModuleHandleW(NULL);
    IMAGE_DOS_HEADER *dos = (IMAGE_DOS_HEADER *)base;
    IMAGE_NT_HEADERS32 *headers = (IMAGE_NT_HEADERS32 *)(base+dos->e_lfanew);
    if ((uintptr_t)base != 0x400000 || headers->FileHeader.TimeDateStamp != 0x4d5abe1c ||
        headers->FileHeader.Machine != IMAGE_FILE_MACHINE_I386) return;
    *(LONG *)0xf92280 = 1;
    unsigned char *assignment=(unsigned char *)0x63d633;
    const unsigned char expected[]={0x3b,0x05,0x04,0xf0,0xfd,0x00};
    const unsigned char primary[]={0x83,0xf8,0x01,0x90,0x90,0x90};
    DWORD protection;
    if (!memcmp(assignment,expected,sizeof(expected)) &&
        VirtualProtect(assignment,sizeof(primary),PAGE_EXECUTE_READWRITE,&protection)) {
        /* Each network instance owns player one's local devices; the native
           shared instance counter would assign later instances other keyboards. */
        memcpy(assignment,primary,sizeof(primary));
        FlushInstructionCache(GetCurrentProcess(),assignment,sizeof(primary));
        VirtualProtect(assignment,sizeof(primary),protection,&protection);
    }
    DWORD length = GetEnvironmentVariableA("CLONEWARS_PROFILE",profile,MAX_PATH);
    if (length >= MAX_PATH) profile[0] = 0;
    if (profile[0]) {
        void **entry = (void **)0xabf25c;
        DWORD old;
        original_folder = (FolderPath)*entry;
        if (VirtualProtect(entry,sizeof(void *),PAGE_READWRITE,&old)) {
            InterlockedExchangePointer(entry,(void *)folder_path);
            VirtualProtect(entry,sizeof(void *),old,&old);
        }
    }
    wchar_t path[MAX_PATH];
    GetModuleFileNameW(proxy_module,path,MAX_PATH);
    wchar_t *last = wcsrchr(path,L'\\');
    if (last && last-path+23 < MAX_PATH) {
        wcscpy(last+1,L"clonewars-camera.dll");
        LoadLibraryW(path);
    }
}

typedef HRESULT (WINAPI *CreateDevice)(IDirect3D9 *,UINT,D3DDEVTYPE,HWND,DWORD,D3DPRESENT_PARAMETERS *,IDirect3DDevice9 **);
static CreateDevice original_create_device;
static HRESULT WINAPI create_device(IDirect3D9 *api,UINT adapter,D3DDEVTYPE type,HWND window,DWORD flags,
                                    D3DPRESENT_PARAMETERS *parameters,IDirect3DDevice9 **device) {
    parameters->Windowed=TRUE;
    parameters->FullScreen_RefreshRateInHz=0;
    *(LONG *)0xf92730=1;
    return original_create_device(api,adapter,type,window,flags,parameters,device);
}
static void background_device(IDirect3D9 *api) {
    char value[8];
    if (!api) return;
    int windowed=GetEnvironmentVariableA("CLONEWARS_BACKGROUND_CAPTURE",value,sizeof(value))==1 && value[0]=='1';
    wchar_t config[MAX_PATH];GetModuleFileNameW(proxy_module,config,MAX_PATH);
    wchar_t *name=wcsrchr(config,L'\\');
    if (name && name-config+23<MAX_PATH) {
        wcscpy(name+1,L"clonewars-display.ini");
        windowed|=GetPrivateProfileIntW(L"Display",L"Windowed",-1,config)==1;
    }
    if (!windowed) return;
    void **vtable=*(void ***)api;
    if (vtable[16]==(void *)create_device) return;
    DWORD old;
    if (!VirtualProtect(vtable+16,sizeof(void *),PAGE_READWRITE,&old)) return;
    original_create_device=(CreateDevice)vtable[16];
    vtable[16]=(void *)create_device;
    VirtualProtect(vtable+16,sizeof(void *),old,&old);
}

IDirect3D9 *WINAPI Direct3DCreate9(UINT version) {
    typedef IDirect3D9 *(WINAPI *Function)(UINT);
    Function function = (Function)resolve("Direct3DCreate9");
    prepare_game();
    IDirect3D9 *api=function ? function(version) : NULL;
    background_device(api);
    return api;
}

HRESULT WINAPI Direct3DCreate9Ex(UINT version, IDirect3D9Ex **device) {
    typedef HRESULT (WINAPI *Function)(UINT,IDirect3D9Ex **);
    Function function = (Function)resolve("Direct3DCreate9Ex");
    return function ? function(version,device) : E_NOTIMPL;
}

int WINAPI D3DPERF_BeginEvent(D3DCOLOR color, LPCWSTR name) {
    typedef int (WINAPI *Function)(D3DCOLOR,LPCWSTR);
    Function function = (Function)resolve("D3DPERF_BeginEvent");
    return function ? function(color,name) : -1;
}
int WINAPI D3DPERF_EndEvent(void) {
    typedef int (WINAPI *Function)(void);
    Function function = (Function)resolve("D3DPERF_EndEvent");
    return function ? function() : -1;
}
void WINAPI D3DPERF_SetMarker(D3DCOLOR color, LPCWSTR name) {
    typedef void (WINAPI *Function)(D3DCOLOR,LPCWSTR);
    Function function = (Function)resolve("D3DPERF_SetMarker");
    if (function) function(color,name);
}
void WINAPI D3DPERF_SetRegion(D3DCOLOR color, LPCWSTR name) {
    typedef void (WINAPI *Function)(D3DCOLOR,LPCWSTR);
    Function function = (Function)resolve("D3DPERF_SetRegion");
    if (function) function(color,name);
}
void WINAPI D3DPERF_SetOptions(DWORD options) {
    typedef void (WINAPI *Function)(DWORD);
    Function function = (Function)resolve("D3DPERF_SetOptions");
    if (function) function(options);
}
DWORD WINAPI D3DPERF_GetStatus(void) {
    typedef DWORD (WINAPI *Function)(void);
    Function function = (Function)resolve("D3DPERF_GetStatus");
    return function ? function() : 0;
}
BOOL WINAPI D3DPERF_QueryRepeatFrame(void) {
    typedef BOOL (WINAPI *Function)(void);
    Function function = (Function)resolve("D3DPERF_QueryRepeatFrame");
    return function ? function() : FALSE;
}
void WINAPI DebugSetMute(void) {
    typedef void (WINAPI *Function)(void);
    Function function = (Function)resolve("DebugSetMute");
    if (function) function();
}

BOOL WINAPI DllMain(HINSTANCE module, DWORD reason, void *reserved) {
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        proxy_module = module;
        DisableThreadLibraryCalls(module);
    }
    return TRUE;
}
