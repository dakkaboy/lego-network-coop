#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <intrin.h>
#include <psapi.h>

#include "event_isolation.hpp"

#include <array>
#include <atomic>
#include <bit>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <utility>

namespace saga::game {
namespace {

constexpr std::uintptr_t event_import = 0x3510cc;
constexpr std::array event_sites{
    std::pair{0x297e28u, "SpotManager Event"},
    std::pair{0xfef3au, "BGWorkToDo"},
    std::pair{0xfef4cu, "BGFreeze"},
};

INIT_ONCE isolation_once = INIT_ONCE_STATIC_INIT;
std::atomic<std::uintptr_t> image_base{};

HANDLE WINAPI create_isolated_event(LPSECURITY_ATTRIBUTES attributes, BOOL manual_reset,
                                    BOOL initial_state, LPCSTR name) {
    const auto caller = reinterpret_cast<std::uintptr_t>(_ReturnAddress());
    const auto base = image_base.load();
    std::array<char, 64> private_name{};
    for (const auto& [rva, expected] : event_sites) {
        if (caller == base + rva && name && std::strcmp(name, expected) == 0) {
            std::snprintf(private_name.data(), private_name.size(), "SagaAudit.%lu.%s",
                          GetCurrentProcessId(), name);
            name = private_name.data();
            break;
        }
    }
    return CreateEventA(attributes, manual_reset, initial_state, name);
}

bool matches_sites(std::uintptr_t base) {
    // Check the unpacked call sites before touching the executable's import slot.
    const auto import_address = static_cast<std::uint32_t>(base + event_import);
    const auto work_name = static_cast<std::uint32_t>(base + 0x35eca4);
    const auto work_handle = static_cast<std::uint32_t>(base + 0x51f1a8);
    std::array<std::array<std::uint8_t, 12>, 3> expected{{
        {0x6a, 0, 0x6a, 0, 0x6a, 0, 0xff, 0x15, 0, 0, 0, 0},
        {0, 0, 0, 0, 0x6a, 0, 0x6a, 0, 0x6a, 0, 0xff, 0xd6},
        {1, 0x6a, 1, 0x6a, 0, 0xa3, 0, 0, 0, 0, 0xff, 0xd6},
    }};
    std::memcpy(expected[0].data() + 8, &import_address, sizeof(import_address));
    std::memcpy(expected[1].data(), &work_name, sizeof(work_name));
    std::memcpy(expected[2].data() + 6, &work_handle, sizeof(work_handle));
    for (std::size_t i = 0; i < event_sites.size(); ++i) {
        const auto* call = reinterpret_cast<const void*>(base + event_sites[i].first - 12);
        std::array<std::uint8_t, 12> actual{};
        SIZE_T bytes{};
        if (!ReadProcessMemory(GetCurrentProcess(), call, actual.data(), actual.size(), &bytes)
            || bytes != actual.size() || actual != expected[i]) {
            return false;
        }
    }
    return true;
}

BOOL CALLBACK install_isolation(PINIT_ONCE, PVOID, PVOID*) {
    wchar_t enabled[2]{};
    if (GetEnvironmentVariableW(L"COMPLETE_SAGA_ISOLATE_TEST_EVENTS", enabled, ARRAYSIZE(enabled)) != 1
        || enabled[0] != L'1') {
        return TRUE;
    }

    const auto module = GetModuleHandleW(nullptr);
    MODULEINFO info{};
    if (!K32GetModuleInformation(GetCurrentProcess(), module, &info, sizeof(info))
        || info.SizeOfImage != 0x268e000) {
        return TRUE;
    }
    const auto base = reinterpret_cast<std::uintptr_t>(info.lpBaseOfDll);
    if (!matches_sites(base)) {
        return TRUE;
    }

    auto* slot = reinterpret_cast<PVOID volatile*>(base + event_import);
    const auto kernel = GetModuleHandleW(L"kernel32.dll");
    const auto original = std::bit_cast<PVOID>(GetProcAddress(kernel, "CreateEventA"));
    if (!original || *slot != original) {
        return TRUE;
    }
    DWORD old_protection{};
    auto* page = const_cast<PVOID*>(slot);
    if (VirtualProtect(page, sizeof(PVOID), PAGE_READWRITE, &old_protection)) {
        image_base.store(base);
        InterlockedCompareExchangePointer(slot, std::bit_cast<PVOID>(&create_isolated_event), original);
        DWORD ignored{};
        VirtualProtect(page, sizeof(PVOID), old_protection, &ignored);
    }
    return TRUE;
}

}

void enable_test_event_isolation() {
    InitOnceExecuteOnce(&isolation_once, install_isolation, nullptr, nullptr);
}

}
