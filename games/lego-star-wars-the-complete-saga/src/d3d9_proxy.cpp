#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d9.h>
#include <bit>

namespace {

using Create9 = decltype(&Direct3DCreate9);
using BeginEvent = decltype(&D3DPERF_BeginEvent);
using EndEvent = decltype(&D3DPERF_EndEvent);

INIT_ONCE init_once = INIT_ONCE_STATIC_INIT;
Create9 create9 = nullptr;
BeginEvent begin_event = nullptr;
EndEvent end_event = nullptr;

BOOL CALLBACK load_system_d3d9(PINIT_ONCE, PVOID, PVOID*) {
    constexpr wchar_t suffix[] = L"\\d3d9.dll";
    wchar_t path[MAX_PATH];
    const UINT length = GetSystemDirectoryW(path, ARRAYSIZE(path));
    if (length == 0 || length > ARRAYSIZE(path) - ARRAYSIZE(suffix)) {
        return TRUE;
    }
    for (unsigned int i = 0; i < ARRAYSIZE(suffix); ++i) {
        path[length + i] = suffix[i];
    }

    HMODULE module = LoadLibraryExW(path, nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (module) {
        create9 = std::bit_cast<Create9>(GetProcAddress(module, "Direct3DCreate9"));
        begin_event = std::bit_cast<BeginEvent>(GetProcAddress(module, "D3DPERF_BeginEvent"));
        end_event = std::bit_cast<EndEvent>(GetProcAddress(module, "D3DPERF_EndEvent"));
    }
    return TRUE;
}

}  // namespace

extern "C" IDirect3D9* WINAPI saga_create9(UINT sdk_version) {
    InitOnceExecuteOnce(&init_once, load_system_d3d9, nullptr, nullptr);
    return create9 ? create9(sdk_version) : nullptr;
}

extern "C" int WINAPI saga_begin_event(D3DCOLOR color, LPCWSTR name) {
    InitOnceExecuteOnce(&init_once, load_system_d3d9, nullptr, nullptr);
    return begin_event ? begin_event(color, name) : -1;
}

extern "C" int WINAPI saga_end_event() {
    InitOnceExecuteOnce(&init_once, load_system_d3d9, nullptr, nullptr);
    return end_event ? end_event() : -1;
}
