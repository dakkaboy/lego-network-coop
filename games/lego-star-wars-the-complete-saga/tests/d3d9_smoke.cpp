#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d9.h>
#include <bit>
#include <cstdio>

int wmain(int argc, wchar_t** argv) {
    if (argc != 2) {
        return 1;
    }

    HMODULE proxy = LoadLibraryW(argv[1]);
    if (!proxy) {
        return 2;
    }
    const auto create = std::bit_cast<decltype(&Direct3DCreate9)>(
        GetProcAddress(proxy, "Direct3DCreate9"));
    const auto begin = std::bit_cast<decltype(&D3DPERF_BeginEvent)>(
        GetProcAddress(proxy, "D3DPERF_BeginEvent"));
    const auto end = std::bit_cast<decltype(&D3DPERF_EndEvent)>(
        GetProcAddress(proxy, "D3DPERF_EndEvent"));
    if (!create || !begin || !end) {
        return 3;
    }

    begin(0, L"Saga proxy smoke test");
    end();
    IDirect3D9* d3d9 = create(D3D_SDK_VERSION);
    if (!d3d9) {
        return 4;
    }
    const UINT adapters = d3d9->GetAdapterCount();
    d3d9->Release();
    std::printf("Direct3D 9 adapters: %u\n", adapters);
    return adapters ? 0 : 5;
}
