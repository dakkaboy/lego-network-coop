#define WIN32_LEAN_AND_MEAN
#define DIRECTINPUT_VERSION 0x0800
#include <windows.h>
#include <psapi.h>
#include <dinput.h>
#include <xinput.h>

#include "local_input_hooks.hpp"
#include "net/local_input.hpp"

#include <array>
#include <bit>
#include <cstdint>
#include <cstring>
#include <span>
#include <string_view>

namespace saga::game {
namespace {

using namespace saga::net;

constexpr std::uintptr_t loading_site = 0x15f4a7;
constexpr std::uintptr_t publish_site = 0x160aa6;
constexpr std::uintptr_t scene_slot = 0x402c54;
constexpr std::uintptr_t keyboard_site = 0x2d5a0d;
constexpr std::uintptr_t state_thunk = 0x340a64;

INIT_ONCE init_once = INIT_ONCE_STATIC_INIT;
std::uintptr_t image_base{};
LocalRole local_role{};
volatile LONG scene_revision{};
volatile LONG loading_count{};
volatile LONG publish_count{};
volatile LONG published_loading{};

template <typename T>
bool read(std::uintptr_t address, T& result) {
    SIZE_T count{};
    return ReadProcessMemory(GetCurrentProcess(), reinterpret_cast<const void*>(address),
                             &result, sizeof(result), &count) && count == sizeof(result);
}

LONG load_counter(volatile LONG& value) {
    return InterlockedCompareExchange(&value, 0, 0);
}

std::uint64_t room_key(const std::array<char, 128>& path) {
    if (path.front() == 0) return 0;
    std::uint64_t hash = 14695981039346656037ull;
    for (auto c : path) {
        if (c == 0) return hash;
        if (c < ' ' || c > '~') return 0;
        if (c == '\\') c = '/';
        if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
        hash = (hash ^ static_cast<std::uint8_t>(c)) * 1099511628211ull;
    }
    return 0;
}

NativeScene scene() {
    static NativeScene previous;
    const auto before = load_counter(scene_revision);
    if ((before & 1) != 0) return previous;

    const auto load = load_counter(loading_count);
    const auto published = load_counter(publish_count);
    NativeScene current{static_cast<std::uint32_t>(load), static_cast<std::uint32_t>(published)};
    if (published != 0 && load == load_counter(published_loading)) {
        std::uintptr_t record{};
        std::array<char, 128> path{};
        if (read(image_base + scene_slot, record) && record && read(record + 0x80, path)) {
            current.room = room_key(path);
        }
    }
    if (before == load_counter(scene_revision)) previous = current;
    return previous;
}

HRESULT WINAPI keyboard_state(void* device, DWORD size, void* data) {
    using GetState = HRESULT (WINAPI*)(void*, DWORD, void*);
    const auto* vtable = *static_cast<void***>(device);
    const auto original = std::bit_cast<GetState>(vtable[9]);
    const auto result = original(device, size, data);
    if (result != DI_OK || size != 256 || !data) return result;

    const auto pad = remote_pad(static_cast<std::uint32_t>(load_counter(loading_count)),
                                static_cast<std::uint32_t>(load_counter(publish_count)));
    auto* keys = static_cast<std::uint8_t*>(data);
    constexpr std::int16_t threshold = 12000;
    if ((pad.buttons & XINPUT_GAMEPAD_START) != 0) keys[DIK_F2] = 0x80;
    if (pad.x < -threshold || (pad.buttons & XINPUT_GAMEPAD_DPAD_LEFT) != 0) keys[DIK_LEFT] = 0x80;
    if (pad.x > threshold || (pad.buttons & XINPUT_GAMEPAD_DPAD_RIGHT) != 0) keys[DIK_RIGHT] = 0x80;
    if (pad.y > threshold || (pad.buttons & XINPUT_GAMEPAD_DPAD_UP) != 0) keys[DIK_UP] = 0x80;
    if (pad.y < -threshold || (pad.buttons & XINPUT_GAMEPAD_DPAD_DOWN) != 0) keys[DIK_DOWN] = 0x80;
    return result;
}

Pad local_pad() {
    const auto original = std::bit_cast<decltype(&XInputGetState)>(image_base + state_thunk);
    XINPUT_STATE state{};
    if (original(0, &state) != ERROR_SUCCESS) return {};
    return {state.Gamepad.wButtons, state.Gamepad.sThumbLX, state.Gamepad.sThumbLY};
}

using Instruction = std::array<std::uint8_t, 5>;

Instruction operand(std::uint8_t opcode, std::uintptr_t value) {
    Instruction bytes{opcode};
    std::memcpy(bytes.data() + 1, &value, sizeof(value));
    return bytes;
}

Instruction call(std::uintptr_t site, std::uintptr_t target) {
    return operand(0xe8, target - (site + 5));
}

struct Patch {
    std::uintptr_t address;
    std::span<const std::uint8_t> original;
    std::span<const std::uint8_t> replacement;
};

bool replace(const Patch& patch, bool restore = false) {
    auto* address = reinterpret_cast<void*>(patch.address);
    DWORD protection{};
    if (!VirtualProtect(address, patch.original.size(), PAGE_EXECUTE_READWRITE, &protection)) {
        return false;
    }
    const auto bytes = restore ? patch.original : patch.replacement;
    std::memcpy(address, bytes.data(), bytes.size());
    FlushInstructionCache(GetCurrentProcess(), address, bytes.size());
    DWORD ignored{};
    VirtualProtect(address, bytes.size(), protection, &ignored);
    return true;
}

void scene_stub(std::uint8_t* code, const Instruction& original, bool publication) {
    const auto byte = [&](std::uint8_t value) { *code++ = value; };
    const auto address = [&](volatile LONG& value) {
        const auto pointer = reinterpret_cast<std::uintptr_t>(&value);
        std::memcpy(code, &pointer, sizeof(pointer));
        code += sizeof(pointer);
    };
    const auto increment = [&](volatile LONG& counter) {
        byte(0xf0); byte(0xff); byte(0x05);
        address(counter);
    };

    // Each replaced instruction stores EAX without changing registers or flags.
    byte(0x9c);
    increment(scene_revision);
    std::memcpy(code, original.data(), original.size());
    code += original.size();
    if (publication) {
        byte(0x50);
        byte(0xa1); address(loading_count);
        byte(0xa3); address(published_loading);
        byte(0x58);
        increment(publish_count);
    } else {
        increment(loading_count);
    }
    increment(scene_revision);
    byte(0x9d);
    byte(0xc3);
}

DWORD WINAPI input_thread(void*) {
    run_local_input(local_role, {scene, local_pad});
    return 0;
}

BOOL CALLBACK install(PINIT_ONCE, PVOID, PVOID*) {
    wchar_t config[8]{};
    const auto length = GetEnvironmentVariableW(L"COMPLETE_SAGA_LOCAL_INPUT", config, ARRAYSIZE(config));
    if (length != 4 && length != 6) return TRUE;
    const std::wstring_view role(config, length);
    if (role != L"host" && role != L"client") return TRUE;

    MODULEINFO info{};
    if (!K32GetModuleInformation(GetCurrentProcess(), GetModuleHandleW(nullptr), &info, sizeof(info))
        || info.SizeOfImage != 0x268e000) return TRUE;
    image_base = reinterpret_cast<std::uintptr_t>(info.lpBaseOfDll);
    local_role = role == L"host" ? LocalRole::host : LocalRole::client;

    const auto mov = operand(0xa3, image_base + scene_slot);
    constexpr std::array<std::uint8_t, 6> keyboard_original{0x8b, 0x41, 0x24, 0x56, 0xff, 0xd0};
    const auto loading_address = image_base + loading_site;
    const auto publish_address = image_base + publish_site;
    const auto keyboard_address = image_base + keyboard_site;
    Instruction loading_bytes{}, publish_bytes{};
    std::array<std::uint8_t, 6> keyboard_bytes{};
    if (!read(loading_address, loading_bytes) || loading_bytes != mov
        || !read(publish_address, publish_bytes) || publish_bytes != mov
        || !read(keyboard_address, keyboard_bytes) || keyboard_bytes != keyboard_original) {
        return TRUE;
    }
    std::array<std::uint8_t, 2> thunk{};
    if (!read(image_base + state_thunk, thunk) || thunk != std::array<std::uint8_t, 2>{0xff, 0x25}) {
        return TRUE;
    }

    auto* stubs = static_cast<std::uint8_t*>(VirtualAlloc(nullptr, 128, MEM_RESERVE | MEM_COMMIT,
                                                         PAGE_READWRITE));
    if (!stubs) return TRUE;
    scene_stub(stubs, mov, false);
    scene_stub(stubs + 64, mov, true);
    const auto loading_call = call(loading_address, reinterpret_cast<std::uintptr_t>(stubs));
    const auto publish_call = call(publish_address, reinterpret_cast<std::uintptr_t>(stubs + 64));
    const auto keyboard_call = call(keyboard_address + 1, std::bit_cast<std::uintptr_t>(&keyboard_state));
    std::array<std::uint8_t, 6> keyboard_replacement{0x56};
    std::memcpy(keyboard_replacement.data() + 1, keyboard_call.data(), keyboard_call.size());
    const std::array patches{
        Patch{loading_address, mov, loading_call},
        Patch{publish_address, mov, publish_call},
        Patch{keyboard_address, keyboard_original, keyboard_replacement},
    };
    DWORD ignored{};
    if (!VirtualProtect(stubs, 128, PAGE_EXECUTE_READ, &ignored)) {
        VirtualFree(stubs, 0, MEM_RELEASE);
        return TRUE;
    }
    FlushInstructionCache(GetCurrentProcess(), stubs, 128);

    const std::size_t count = local_role == LocalRole::host ? patches.size() : 2;
    std::size_t installed{};
    while (installed < count && replace(patches[installed])) ++installed;
    HMODULE self{};
    if (installed == count
        && GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
                              std::bit_cast<LPCWSTR>(&input_thread), &self)) {
        if (const auto thread = CreateThread(nullptr, 0, input_thread, nullptr, 0, nullptr)) {
            CloseHandle(thread);
            return TRUE;
        }
    }
    bool restored = true;
    while (installed != 0) restored = replace(patches[--installed], true) && restored;
    if (restored) VirtualFree(stubs, 0, MEM_RELEASE);
    return TRUE;
}

}

void enable_local_input() {
    InitOnceExecuteOnce(&init_once, install, nullptr, nullptr);
}

}
