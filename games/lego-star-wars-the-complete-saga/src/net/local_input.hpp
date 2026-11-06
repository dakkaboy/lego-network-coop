#pragma once

#include <cstdint>

namespace saga::net {

enum class LocalRole { host, client };

struct NativeScene {
    std::uint32_t loading{};
    std::uint32_t publication{};
    std::uint64_t room{};
};

struct Pad {
    std::uint16_t buttons{};
    std::int16_t x{};
    std::int16_t y{};
};

struct InputSource {
    NativeScene (*scene)();
    Pad (*pad)();
};

void run_local_input(LocalRole role, InputSource source);
Pad remote_pad(std::uint32_t loading, std::uint32_t publication);

}
