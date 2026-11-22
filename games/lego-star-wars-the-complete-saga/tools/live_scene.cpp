#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tlhelp32.h>

#include "live_scene.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <stdexcept>

namespace {

constexpr std::uintptr_t scene_global_rva = 0x402c54;
constexpr std::uintptr_t scene_caller_rva = 0x93565;
constexpr std::uintptr_t scene_path_offset = 0x80;

struct Handle {
    HANDLE value;
    ~Handle() {
        if (value && value != INVALID_HANDLE_VALUE) {
            CloseHandle(value);
        }
    }
};

template <class T>
bool read(HANDLE process, std::uintptr_t address, T& result) {
    SIZE_T bytes{};
    return ReadProcessMemory(process, reinterpret_cast<const void*>(address), &result,
                             sizeof(result), &bytes) && bytes == sizeof(result);
}

}  // namespace

std::optional<std::string> read_live_scene(unsigned long pid) {
    const Handle modules{CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, pid)};
    MODULEENTRY32W module{};
    module.dwSize = sizeof(module);
    if (modules.value == INVALID_HANDLE_VALUE || !Module32FirstW(modules.value, &module)
        || _wcsicmp(module.szModule, L"LEGOStarWarsSaga.exe") != 0
        || module.modBaseSize < scene_global_rva + sizeof(std::uint32_t)) {
        throw std::runtime_error("PID is not a supported Saga process");
    }

    const Handle process{OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid)};
    const auto base = reinterpret_cast<std::uintptr_t>(module.modBaseAddr);
    std::array<std::uint8_t, 11> actual{};
    std::array<std::uint8_t, 11> expected{0x8b, 0x35, 0, 0, 0, 0, 0xe8, 0x80, 0xf2, 0xff, 0xff};
    const auto scene_global = static_cast<std::uint32_t>(base + scene_global_rva);
    std::memcpy(expected.data() + 2, &scene_global, sizeof(scene_global));
    if (!process.value || !read(process.value, base + scene_caller_rva, actual)
        || actual != expected) {
        throw std::runtime_error("Saga scene signature is unavailable");
    }

    std::uint32_t scene{};
    std::array<char, 128> path{};
    std::array<char, 128> path_check{};
    std::uint32_t confirmed{};
    if (!read(process.value, scene_global, scene) || scene == 0
        || !read(process.value, scene + scene_path_offset, path)
        || !read(process.value, scene + scene_path_offset, path_check) || path != path_check
        || !read(process.value, scene_global, confirmed) || scene != confirmed) {
        return std::nullopt;
    }
    const auto end = std::ranges::find(path, '\0');
    if (end == path.begin() || end == path.end()
        || !std::all_of(path.begin(), end, [](char c) { return c >= ' ' && c <= '~'; })) {
        return std::nullopt;
    }
    return std::string(path.begin(), end);
}
