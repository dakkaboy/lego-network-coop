#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "native_roster_source.h"
extern "C" {
#include "game_state.h"
}

namespace {
bool readable(const void *pointer, size_t bytes) {
    MEMORY_BASIC_INFORMATION memory;
    const auto address = reinterpret_cast<uintptr_t>(pointer);
    return pointer && address + bytes >= address && VirtualQuery(pointer, &memory, sizeof memory) &&
        memory.State == MEM_COMMIT && !(memory.Protect & (PAGE_NOACCESS | PAGE_GUARD)) &&
        address + bytes <= reinterpret_cast<uintptr_t>(memory.BaseAddress) + memory.RegionSize;
}
template<class T> T get(const void *pointer, size_t offset = 0) {
    T value;
    std::memcpy(&value, static_cast<const uint8_t *>(pointer) + offset, sizeof value);
    return value;
}
bool snapshot(void *record_plus_28, const void *linked_actor, NativeRosterSource &out) {
    NativeRosterSource candidate{};
    candidate.count = get<uint32_t>(reinterpret_cast<void *>(0xfb4f18));
    const auto address = reinterpret_cast<uintptr_t>(record_plus_28);
    if (!candidate.count || candidate.count > NATIVE_SAVED_ROSTER_CAPACITY || address < 0xfb4f48 ||
        (address - 0xfb4f48) % 0x2c || (address - 0xfb4f48) / 0x2c >= candidate.count ||
        !readable(reinterpret_cast<void *>(0xfb4f20), candidate.count * 0x2c)) return false;
    candidate.ordinal = static_cast<uint32_t>((address - 0xfb4f48) / 0x2c);
    candidate.record = reinterpret_cast<void *>(address - 0x28);
    if (get<void *>(candidate.record) != linked_actor) return false;
    candidate.world = get<void *>(reinterpret_cast<void *>(0xfb4a20));
    candidate.profile = get<void *>(reinterpret_cast<void *>(0xfbd8bc));
    candidate.provider = get<void *>(reinterpret_cast<void *>(0xe90218));
    if (!readable(candidate.world, 0x224) || !readable(candidate.provider, 4) ||
        !readable(candidate.profile, 4) || get<uint32_t>(candidate.profile) != 0x500 ||
        !game_native_profile_storage_ready()) return false;
    candidate.provider_class = get<void *>(candidate.provider);
    if (!readable(candidate.provider_class, 0x7c)) return false;
    candidate.definition = get<void *>(candidate.world, 0x220);
    if (!readable(candidate.definition, 0x1b0)) return false;
    candidate.level = get<int16_t>(candidate.definition, 0x94);
    const auto catalog = get<uintptr_t>(reinterpret_cast<void *>(0xfb8404));
    const auto levels = get<uint32_t>(reinterpret_cast<void *>(0xfb8410));
    if (!catalog || !levels || levels > 4096 || candidate.level < 0 ||
        static_cast<uint32_t>(candidate.level) >= levels ||
        catalog + static_cast<uintptr_t>(candidate.level) * 0x1b0 != reinterpret_cast<uintptr_t>(candidate.definition) ||
        (get<uint32_t>(candidate.definition, 0x50) & 0x40000000u)) return false;
    std::memcpy(candidate.record_data, static_cast<uint8_t *>(candidate.record) + 4, sizeof candidate.record_data);
    if (candidate.record_data[0x24] != get<uint8_t>(candidate.definition, 0x130)) return false;
    out = candidate;
    return true;
}
bool resolve(void *record_plus_28, const uint32_t arguments[12], NativeRosterSource &out) {
    NativeRosterSource first{}, second{};
    if (!arguments || !snapshot(record_plus_28, nullptr, first)) return false;
    const auto record = reinterpret_cast<uintptr_t>(first.record);
    if (arguments[0] != get<uint16_t>(first.record, 0x24) || arguments[0] > 0x257 ||
        arguments[1] != record + 4 || arguments[2] != get<uint32_t>(first.record, 0x10) ||
        arguments[3] != record + 0x14 || arguments[4] || arguments[5] != 1 ||
        arguments[6] || arguments[7] || arguments[8] || arguments[9] || arguments[10] ||
        arguments[11] != UINT32_MAX || !snapshot(record_plus_28, nullptr, second) ||
        std::memcmp(&first, &second, sizeof first)) return false;
    out = first;
    return true;
}
}

int native_roster_source_resolve(void *record_plus_28, const uint32_t arguments[12], NativeRosterSource *out) {
    const DWORD error = GetLastError();
    int result = 0;
    __try { if (out) result = resolve(record_plus_28, arguments, *out); }
    __except(EXCEPTION_EXECUTE_HANDLER) { result = 0; }
    SetLastError(error);
    return result;
}
int native_roster_source_revalidate(const NativeRosterSource *source, const void *linked_actor) {
    const DWORD error = GetLastError();
    int result = 0;
    __try {
        NativeRosterSource current{};
        if (source && snapshot(static_cast<uint8_t *>(source->record) + 0x28, linked_actor, current))
            result = !std::memcmp(source, &current, sizeof current);
    } __except(EXCEPTION_EXECUTE_HANDLER) { result = 0; }
    SetLastError(error);
    return result;
}
