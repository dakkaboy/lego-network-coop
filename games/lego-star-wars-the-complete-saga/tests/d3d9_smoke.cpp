#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d9.h>
#include <bit>
#include <cstdio>

namespace {

bool has_expected_export_table(HMODULE proxy) {
    const auto* base = reinterpret_cast<const unsigned char*>(proxy);
    const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(base);
    const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS32*>(base + dos->e_lfanew);
    const DWORD exports_rva = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress;
    if (nt->FileHeader.Machine != IMAGE_FILE_MACHINE_I386 || exports_rva == 0) {
        return false;
    }

    const auto* exports = reinterpret_cast<const IMAGE_EXPORT_DIRECTORY*>(base + exports_rva);
    return exports->NumberOfFunctions == 3 && exports->NumberOfNames == 3;
}

}  // namespace

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
    if (!has_expected_export_table(proxy) || !create || !begin || !end) {
        std::fputs("Expected exactly three named x86 Direct3D 9 exports.\n", stderr);
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
