#pragma once

#include <cstdint>

namespace lego::net {

constexpr void latch_pressed(std::uint32_t& pending, std::uint32_t pressed) {
    pending |= pressed;
}

constexpr std::uint32_t take_pressed(std::uint32_t& pending) {
    const auto pressed = pending;
    pending = 0;
    return pressed;
}

constexpr std::uint32_t replay_held(std::uint32_t held, std::uint32_t pressed,
                                    std::uint32_t& carry) {
    // A press must remain held through the following simulation step.
    const auto executed = held | pressed | carry;
    carry = pressed;
    return executed;
}

} // namespace lego::net
