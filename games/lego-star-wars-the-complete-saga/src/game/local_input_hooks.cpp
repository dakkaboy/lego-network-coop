#define WIN32_LEAN_AND_MEAN
#define DIRECTINPUT_VERSION 0x0800
#include <windows.h>
#include <psapi.h>
#include <dinput.h>
#include <xinput.h>

#include "local_input_hooks.hpp"
#include "net/local_input.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <bit>
#include <cstdint>
#include <cmath>
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
constexpr std::uintptr_t player_slots = 0x53d7f0;
constexpr std::uintptr_t stud_first = 0x455f38;
constexpr std::uintptr_t stud_second = 0x455f48;
constexpr std::uintptr_t damage_entry = 0x38230;

INIT_ONCE init_once = INIT_ONCE_STATIC_INIT;
std::uintptr_t image_base{};
LocalRole local_role{};
std::atomic<std::uint64_t> host_keyboard{};
bool native_damage_verified{};
bool local_camera_installed{};
constexpr std::uintptr_t native_camera_focus = 0x3f3b14;
constexpr std::array<std::uintptr_t, 2> camera_follow_sites{0xb6d3, 0xb9fa};
alignas(4) volatile LONG camera_focus = -1;
using Damage = int (__cdecl*)(std::uintptr_t, std::uintptr_t, int, unsigned, int, int);
Damage damage_trampoline{};
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

extern "C" std::uint16_t saga_host_buttons(const std::uint8_t* keys);
extern "C" void saga_apply_remote_input(std::uint8_t* keys, std::uint16_t buttons,
                                         std::int16_t x, std::int16_t y, bool player_two, bool gameplay);
extern "C" std::uint64_t saga_room_key(const char* path);
extern "C" std::uint8_t saga_living_health_update(std::uint8_t current, std::uint8_t desired,
                                                  std::uint8_t maximum, std::uint32_t actor_flags);

constexpr std::uintptr_t current_area = 0x403784;
constexpr std::uintptr_t previous_area = 0x55121c;
constexpr std::uintptr_t requested_stage = 0x551b80;
constexpr std::uintptr_t stages = 0x551b78;
constexpr std::uintptr_t story_stage = 0x479588;
constexpr std::uintptr_t story_started = 0x47b2c0;
constexpr std::uintptr_t story_fade = 0x550780;
constexpr std::uintptr_t free_play = 0x53b2a4;
constexpr std::uintptr_t selected_episode = 0x402af4;
constexpr std::uintptr_t scene_transition = 0x402e14;
constexpr std::uintptr_t begin_story = 0x15c650;

std::uintptr_t stage_record(std::uint32_t target) {
    std::uintptr_t table{};
    std::uint16_t index{};
    if (target >= 0x16d || !read(image_base + stages, table) || !table) return 0;
    const auto record = table + target * 0x130;
    return read(record + 0x62, index) && index == target ? record : 0;
}

std::optional<std::uint64_t> story_selection(std::uint16_t& episode) {
    std::uint32_t starting{}, mode{}, source{}, target{}, episode_index{}, area{};
    if (!read(image_base + story_started, starting) || starting != 1
        || !read(image_base + free_play, mode) || mode
        || !read(image_base + previous_area, source) || source >= 0x48
        || !read(image_base + current_area, area) || area >= 0x48 || area == source
        || !read(image_base + story_stage, target)
        || !read(image_base + selected_episode, episode_index) || (episode_index >= 6 && episode_index != UINT32_MAX)) return {};
    const auto record = stage_record(target);
    std::uint8_t stage_area{};
    if (!record || !read(record + 0xa3, stage_area) || stage_area != area) return {};
    episode = static_cast<std::uint16_t>(episode_index);
    return (std::uint64_t{source} << 32) | target;
}

bool apply_story(const Packet& request) {
    std::uintptr_t queued{};
    std::uint32_t area{}, starting{};
    float fade{};
    if (!read(image_base + current_area, area) || area != request.scene.room >> 32
        || !read(image_base + story_started, starting) || starting
        || !read(image_base + requested_stage, queued) || queued
        || !read(image_base + story_fade, fade) || fade != 0.0f) return false;
    const auto target = stage_record(static_cast<std::uint32_t>(request.scene.room));
    std::uint8_t target_area{};
    if (!target || !read(target + 0xa3, target_area) || target_area >= 0x48 || target_area == area) return false;
    constexpr std::array<std::uint8_t, 6> signature{0xd9, 0xee, 0x8b, 0x44, 0x24, 0x04};
    std::array<std::uint8_t, signature.size()> raw{};
    if (!read(image_base + begin_story, raw) || raw != signature) return false;
    using BeginStory = void (__cdecl*)(std::uint32_t);
    const auto episode = static_cast<std::uint32_t>(std::bit_cast<std::int16_t>(request.input.buttons));
    std::bit_cast<BeginStory>(image_base + begin_story)(episode);
    *reinterpret_cast<volatile float*>(image_base + story_fade) = 1.0f;
    *reinterpret_cast<volatile std::uint32_t*>(image_base + scene_transition) = 0;
    *reinterpret_cast<volatile std::uintptr_t*>(image_base + requested_stage) = target;
    *reinterpret_cast<volatile std::uint32_t*>(image_base + story_started) = 1;
    OutputDebugStringA("Saga LAN client queued host Story mission");
    return true;
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
            current.room = saga_room_key(path.data());
            if (current.room) {
                for (auto& c : path) {
                    if (c == '\\') c = '/';
                    if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
                }
                const std::string_view name(path.data());
                current.hub = name.starts_with("levels/map/");
                current.mission = name.starts_with("levels/episode_") &&
                    name.find("_intro") == name.npos && name.find("_outro") == name.npos;
            }
        }
    }
    if (local_role == LocalRole::host) current.story = story_selection(current.story_episode);
    if (before == load_counter(scene_revision)) previous = current;
    return previous;
}

constexpr std::uintptr_t campaign_slot = 0x55136c;
constexpr std::uintptr_t campaign_storage = 0x46e0f4;
using CampaignTable = std::array<std::uint8_t, 72 * 12>;

extern "C" void saga_read_campaign(const std::uint8_t* table, CampaignProgress* progress);
extern "C" bool saga_merge_campaign(std::uint8_t* table, const CampaignProgress* progress);
static_assert(offsetof(CampaignProgress, tail) == 16);

std::uint8_t* campaign_table() {
    std::uintptr_t ptr{};
    if (!read(image_base + campaign_slot, ptr) || ptr != image_base + campaign_storage) return nullptr;
    return reinterpret_cast<std::uint8_t*>(ptr);
}

std::optional<CampaignProgress> current_campaign() {
    CampaignTable snapshot;
    const auto table = campaign_table();
    if (!table || !read(reinterpret_cast<std::uintptr_t>(table), snapshot)) return {};
    CampaignProgress progress;
    saga_read_campaign(snapshot.data(), &progress);
    return progress;
}

void apply_campaign(const CampaignProgress& progress) {
    if (const auto table = campaign_table(); table && saga_merge_campaign(table, &progress)) {
        OutputDebugStringA("Saga LAN client campaign flags applied");
    }
}

constexpr std::uintptr_t max_health = 0x107e;
constexpr std::uintptr_t health = 0x107f;
using Actors = std::array<std::uintptr_t, 2>;

std::optional<Actors> active_players() {
    constexpr std::array offsets{stud_first, stud_second};
    Actors players{};
    for (std::size_t i = 0; i < offsets.size(); ++i) {
        std::uintptr_t current{};
        if (!read(image_base + player_slots + i * sizeof(players[i]), players[i]) || players[i] == 0
            || !read(players[i] + 0x7fc, current) || current != image_base + offsets[i]) return {};
    }
    return players;
}

constexpr std::uintptr_t character_position = 0x5c;
constexpr std::uintptr_t character_heading = 0x58;
constexpr std::uintptr_t reset_character_position = 0x15d720;
constexpr std::uintptr_t rebuild_character_collision = 0x15d2b0;

bool current_pose(std::uintptr_t actor, PlayerPose& pose) {
    std::uint8_t flags{}, health_value{}, blocked{};
    return read(actor + 0x1fc, flags) && (flags & 0x80) &&
        read(actor + health, health_value) && health_value &&
        read(actor + 0x28b, blocked) && !blocked &&
        read(actor + character_position, pose.position) &&
        read(actor + character_heading, pose.heading);
}

std::optional<std::array<PlayerPose, 2>> current_poses() {
    const auto actors = active_players();
    if (!actors) return {};
    std::array<PlayerPose, 2> poses{};
    for (std::size_t slot = 0; slot < poses.size(); ++slot) {
        if (!current_pose((*actors)[slot], poses[slot])) return {};
    }
    return poses;
}

void apply_poses(const PosePackets& packets) {
    static std::array<std::uint32_t, 2> applied{};
    const auto actors = active_players();
    if (!actors) return;
    std::uintptr_t scene_record{}, collision{};
    if (!read(image_base + scene_slot, scene_record) || !scene_record ||
        !read(scene_record + 0x2ae8, collision) || !collision) return;
    constexpr std::array<std::uint8_t, 11> signature{
        0x8b, 0x44, 0x24, 0x08, 0x8b, 0x08, 0x56, 0x8b, 0x74, 0x24, 0x08};
    std::array<std::uint8_t, signature.size()> bytes{};
    if (!read(image_base + reset_character_position, bytes) || bytes != signature) return;
    using Reset = void (__cdecl*)(std::uintptr_t, const float*, std::uint16_t, const void*, int);
    const auto reset = std::bit_cast<Reset>(image_base + reset_character_position);
    constexpr std::array<std::uint8_t, 8> collision_signature{
        0x83, 0xec, 0x08, 0x56, 0x8b, 0x74, 0x24, 0x10};
    std::array<std::uint8_t, collision_signature.size()> collision_bytes{};
    if (!read(image_base + rebuild_character_collision, collision_bytes)
        || collision_bytes != collision_signature) return;
    using RebuildCollision = void (__cdecl*)(std::uintptr_t);
    const auto rebuild = std::bit_cast<RebuildCollision>(image_base + rebuild_character_collision);
    for (std::size_t slot = 0; slot < packets.size(); ++slot) {
        const auto& packet = packets[slot];
        if (!packet || packet->input.sequence <= applied[slot]) continue;
        applied[slot] = packet->input.sequence;
        const auto actor = (*actors)[slot];
        PlayerPose local{};
        if (!current_pose(actor, local)) continue;
        const auto host = player_pose(*packet);
        const auto dx = host.position[0] - local.position[0];
        const auto dy = host.position[1] - local.position[1];
        const auto dz = host.position[2] - local.position[2];
        const auto horizontal = dx * dx + dz * dz;
        if (!(horizontal > 0.04f && horizontal < 4.0f && std::abs(dy) < 0.1f)) continue;
        reset(actor, host.position.data(), host.heading, nullptr, 0);
        // Native placement initially puts the collision center at the character's feet.
        rebuild(actor);
        OutputDebugStringA("Saga LAN client applied host position");
    }
}

bool __cdecl suppress_local_damage(std::uintptr_t actor, int amount) {
    if (amount <= 0) return false;
    const auto state = remote_state(
        static_cast<std::uint32_t>(load_counter(loading_count)),
        static_cast<std::uint32_t>(load_counter(publish_count)));
    if (!state.players) return false;
    const auto players = active_players();
    if (!players || ((*players)[0] != actor && (*players)[1] != actor)) return false;
    OutputDebugStringA("Saga LAN client local damage suppressed");
    return true;
}

__declspec(naked) void damage_hook() {
    __asm {
        pushfd
        pushad
        mov eax, [esp + 44]
        mov ecx, [esp + 48]
        push ecx
        push eax
        call suppress_local_damage
        add esp, 8
        test al, al
        jnz suppressed
        popad
        popfd
        jmp dword ptr [damage_trampoline]
    suppressed:
        popad
        popfd
        mov eax, 0
        ret
    }
}

std::optional<PlayerState> current_player_state() {
    PlayerState value;
    const auto players = active_players();
    if (!players || !read(image_base + stud_first, value.first)
        || !read(image_base + stud_second, value.second)) return {};
    for (std::size_t i = 0; i < players->size(); ++i) {
        std::uint8_t maximum{};
        const auto actor = (*players)[i];
        if (!read(actor + max_health, maximum) || !read(actor + health, value.health[i])
            || maximum > 127 || value.health[i] > maximum) return {};
    }
    return value;
}

void apply_player_state(PlayerState value, std::uint32_t loading, std::uint32_t publication) {
    static std::array<std::uint16_t, 2> applied_deaths{};
    static std::uint32_t last_loading{}, last_publication{};
    if (last_loading != loading || last_publication != publication) {
        applied_deaths = {};
        last_loading = loading;
        last_publication = publication;
    }
    const auto players = active_players();
    if (!players) return;
    for (std::size_t i = 0; i < players->size(); ++i) {
        std::uint8_t local{}, maximum{};
        std::uint32_t flags{};
        const auto actor = (*players)[i];
        if (!read(actor + health, local) || !read(actor + max_health, maximum)
            || !read(actor + 0x1fc, flags)) continue;
        if (value.deaths[i] > applied_deaths[i]) {
            if (!damage_trampoline || (flags & 0x1001) != 0x1001) continue;
            if (!local) {
                applied_deaths[i] = value.deaths[i];
                continue;
            }
            if (local > maximum) continue;
            std::uint8_t blocked{};
            float immunity{};
            if (!read(actor + 0x28b, blocked) || blocked || !read(actor + 0x1010, immunity)
                || immunity > 0.0f) continue;
            // The game uses this damage form for forced deaths, including its drop and respawn logic.
            const auto damage = damage_trampoline;
            applied_deaths[i] = value.deaths[i];
            damage(0, actor, -1, 0, 0, 1);
            std::uint8_t after{};
            if (read(actor + health, after) && !after) {
                OutputDebugStringA("Saga LAN client native death applied");
            } else {
                OutputDebugStringA("Saga LAN client native death was not observed");
            }
            continue;
        }
        const auto corrected = saga_living_health_update(local, value.health[i], maximum, flags);
        if (!corrected) continue;
        if (corrected < local && damage_trampoline) {
            damage_trampoline(0, actor, local - corrected, 0, 0, 1);
            std::uint8_t after{};
            if (read(actor + health, after) && after < local) {
                OutputDebugStringA("Saga LAN client native damage applied");
            }
            continue;
        }
        *reinterpret_cast<volatile std::uint8_t*>(actor + health) = corrected;
        OutputDebugStringA("Saga LAN client health corrected");
    }

    std::uint32_t first{}, second{};
    if (read(image_base + stud_first, first) && read(image_base + stud_second, second)
        && (first != value.first || second != value.second)) {
        *reinterpret_cast<volatile std::uint32_t*>(image_base + stud_first) = value.first;
        *reinterpret_cast<volatile std::uint32_t*>(image_base + stud_second) = value.second;
        OutputDebugStringA("Saga LAN client studs corrected");
    }
}

Pad controller_pad() {
    const auto original = std::bit_cast<decltype(&XInputGetState)>(image_base + state_thunk);
    XINPUT_STATE state{};
    if (original(0, &state) != ERROR_SUCCESS) return {};
    return {state.Gamepad.wButtons, state.Gamepad.sThumbLX, state.Gamepad.sThumbLY};
}

Pad local_pad() {
    if (local_role == LocalRole::client) return controller_pad();
    const auto value = host_keyboard.load(std::memory_order_relaxed);
    if (GetTickCount64() - (value >> 16) >= 250) return {};
    return {static_cast<std::uint16_t>(value)};
}

void apply_remote_input(std::uint8_t* keys, Pad pad, bool player_two, bool gameplay) {
    saga_apply_remote_input(keys, pad.buttons, pad.x, pad.y, player_two, gameplay);
}

HRESULT WINAPI keyboard_state(void* device, DWORD size, void* data) {
    using GetState = HRESULT (WINAPI*)(void*, DWORD, void*);
    const auto* vtable = *static_cast<void***>(device);
    const auto original = std::bit_cast<GetState>(vtable[9]);
    const auto result = original(device, size, data);
    if (result != DI_OK || size != 256 || !data) return result;

    const auto loading = static_cast<std::uint32_t>(load_counter(loading_count));
    const auto publication = static_cast<std::uint32_t>(load_counter(publish_count));
    const auto state = remote_state(loading, publication);
    const auto& pad = state.pad;
    if (local_camera_installed) {
        LONG native_focus = -1;
        read(image_base + native_camera_focus, native_focus);
        auto focus = native_focus;
        if (native_focus == -1 && pad) {
            if (const auto players = active_players()) {
                const auto slot = local_role == LocalRole::host ? 0 : 1;
                std::uint8_t flags{};
                if (read((*players)[slot] + 0x1fc, flags) && (flags & 0x80)) focus = slot;
            }
        }
        InterlockedExchange(&camera_focus, focus);
    }
    auto* keys = static_cast<std::uint8_t*>(data);
    if (local_role == LocalRole::client && state.campaign) apply_campaign(*state.campaign);
    if (local_role == LocalRole::client && state.story) {
        static std::uint32_t dispatched_story{};
        const auto sequence = state.story->input.sequence;
        if (sequence > dispatched_story && apply_story(*state.story)) dispatched_story = sequence;
    }
    if (local_role == LocalRole::host) {
        const auto buttons = saga_host_buttons(keys);
        host_keyboard.store((GetTickCount64() << 16) | buttons, std::memory_order_relaxed);
        if (pad) apply_remote_input(keys, *pad, true, false);
    } else if (pad) {
        if (state.players) {
            apply_player_state(*state.players, loading, publication);
            apply_poses(state.poses);
        }
        apply_remote_input(keys, *pad, false, state.players.has_value());
        apply_remote_input(keys, controller_pad(), true, false);
    }
    return result;
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
    run_local_input(local_role, {scene, local_pad, current_player_state, current_campaign, current_poses});
    return 0;
}

bool install_client_mission_gate() {
    // The episode, chapter and doorway menus branch here when native input has no confirmation.
    constexpr std::array<std::uint8_t, 6> episode_original{0x0f, 0x84, 0xd6, 0, 0, 0};
    constexpr std::array<std::uint8_t, 6> chapter_original{0x0f, 0x84, 0x15, 0x02, 0, 0};
    constexpr std::array<std::uint8_t, 6> episode_jump{0xe9, 0xd7, 0, 0, 0, 0x90};
    constexpr std::array<std::uint8_t, 6> chapter_jump{0xe9, 0x16, 0x02, 0, 0, 0x90};
    constexpr std::array<std::uint8_t, 6> doorway_original{0x0f, 0x84, 0x18, 0x01, 0, 0};
    constexpr std::array<std::uint8_t, 6> doorway_jump{0xe9, 0x19, 0x01, 0, 0, 0x90};
    constexpr std::array<std::uint8_t, 6> commit_original{0x0f, 0x8a, 0xd9, 0xfd, 0xff, 0xff};
    constexpr std::array<std::uint8_t, 6> commit_jump{0xe9, 0xda, 0xfd, 0xff, 0xff, 0x90};
    const std::array patches{
        Patch{image_base + 0x7eb6d, commit_original, commit_jump},
        Patch{image_base + 0x7ef8e, episode_original, episode_jump},
        Patch{image_base + 0x7f1a2, chapter_original, chapter_jump},
        Patch{image_base + 0x7e90f, doorway_original, doorway_jump},
    };
    for (const auto& patch : patches) {
        std::array<std::uint8_t, 6> bytes{};
        if (!read(patch.address, bytes) || !std::ranges::equal(bytes, patch.original)) return false;
    }
    std::size_t installed{};
    while (installed < patches.size() && replace(patches[installed])) ++installed;
    if (installed == patches.size()) return true;
    while (installed != 0) replace(patches[--installed], true);
    return false;
}
bool install_local_camera() {
    // Redirect only the two target-selection reads. The original selector also controls gameplay.
    const auto original = operand(0xa1, image_base + native_camera_focus);
    const auto redirected = operand(0xa1, reinterpret_cast<std::uintptr_t>(&camera_focus));
    const Patch first{image_base + camera_follow_sites[0], original, redirected};
    const Patch second{image_base + camera_follow_sites[1], original, redirected};
    Instruction bytes{};
    if (!read(first.address, bytes) || bytes != original
        || !read(second.address, bytes) || bytes != original || !replace(first)) return false;
    if (replace(second)) return true;
    replace(first, true);
    return false;
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
    const auto cookie_address = operand(0xa1, image_base + 0x429570);
    std::array<std::uint8_t, 8> damage_bytes{};
    native_damage_verified = read(image_base + damage_entry, damage_bytes) &&
        damage_bytes[0] == 0x83 && damage_bytes[1] == 0xec && damage_bytes[2] == 0x4c &&
        std::memcmp(damage_bytes.data() + 3, cookie_address.data(), cookie_address.size()) == 0;

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

    auto* stubs = static_cast<std::uint8_t*>(VirtualAlloc(nullptr, 192, MEM_RESERVE | MEM_COMMIT,
                                                         PAGE_READWRITE));
    if (!stubs) return TRUE;
    scene_stub(stubs, mov, false);
    scene_stub(stubs + 64, mov, true);
    const auto loading_call = call(loading_address, reinterpret_cast<std::uintptr_t>(stubs));
    const auto publish_call = call(publish_address, reinterpret_cast<std::uintptr_t>(stubs + 64));
    const auto keyboard_call = call(keyboard_address + 1, std::bit_cast<std::uintptr_t>(&keyboard_state));
    std::array<std::uint8_t, 6> keyboard_replacement{0x56};
    std::memcpy(keyboard_replacement.data() + 1, keyboard_call.data(), keyboard_call.size());
    std::array<std::uint8_t, 8> damage_patch{0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90};
    if (native_damage_verified && local_role == LocalRole::client) {
        auto* trampoline = stubs + 128;
        std::memcpy(trampoline, damage_bytes.data(), damage_bytes.size());
        const auto next = operand(0xe9, image_base + damage_entry + damage_bytes.size() -
            (reinterpret_cast<std::uintptr_t>(trampoline) + damage_bytes.size() + 5));
        std::memcpy(trampoline + damage_bytes.size(), next.data(), next.size());
        damage_trampoline = std::bit_cast<Damage>(trampoline);
        const auto jump = operand(0xe9, std::bit_cast<std::uintptr_t>(&damage_hook) -
            (image_base + damage_entry + 5));
        std::memcpy(damage_patch.data(), jump.data(), jump.size());
    }
    const std::array patches{
        Patch{loading_address, mov, loading_call},
        Patch{publish_address, mov, publish_call},
        Patch{keyboard_address, keyboard_original, keyboard_replacement},
        Patch{image_base + damage_entry, damage_bytes, damage_patch},
    };
    DWORD ignored{};
    if (!VirtualProtect(stubs, 192, PAGE_EXECUTE_READ, &ignored)) {
        VirtualFree(stubs, 0, MEM_RELEASE);
        return TRUE;
    }
    FlushInstructionCache(GetCurrentProcess(), stubs, 192);

    const auto count = damage_trampoline ? patches.size() : patches.size() - 1;
    std::size_t installed{};
    while (installed < count && replace(patches[installed])) ++installed;
    HMODULE self{};
    if (installed == count
        && GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
                              std::bit_cast<LPCWSTR>(&input_thread), &self)) {
        if (const auto thread = CreateThread(nullptr, 0, input_thread, nullptr, 0, nullptr)) {
            if (local_role == LocalRole::client && !install_client_mission_gate()) {
                OutputDebugStringA("Saga LAN client mission menu signature mismatch");
            }
            local_camera_installed = install_local_camera();
            CloseHandle(thread);
            return TRUE;
        }
    }
    bool restored = true;
    while (installed != 0) restored = replace(patches[--installed], true) && restored;
    if (restored) {
        damage_trampoline = nullptr;
        VirtualFree(stubs, 0, MEM_RELEASE);
    }
    return TRUE;
}

}

void enable_local_input() {
    InitOnceExecuteOnce(&init_once, install, nullptr, nullptr);
}

}
