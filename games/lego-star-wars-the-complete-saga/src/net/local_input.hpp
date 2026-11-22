#pragma once

#include <cstdint>
#include <optional>

#include "session.hpp"

namespace saga::net {

enum class LocalRole { host, client };

struct NativeScene {
    std::uint32_t loading{};
    std::uint32_t publication{};
    std::uint64_t room{};
    bool mission{};
    bool hub{};
    std::optional<std::uint64_t> story;
    std::uint16_t story_episode{};
};

struct Pad {
    std::uint16_t buttons{};
    std::int16_t x{};
    std::int16_t y{};
};

struct InputSource {
    NativeScene (*scene)();
    Pad (*pad)();
    std::optional<PlayerState> (*players)();
    std::optional<CampaignProgress> (*campaign)();
    std::optional<std::array<PlayerPose, 2>> (*poses)();
};

void run_local_input(LocalRole role, InputSource source);
struct RemoteState {
    std::optional<Pad> pad;
    std::optional<PlayerState> players;
    std::optional<Packet> story;
    std::optional<CampaignProgress> campaign;
    PosePackets poses;
};

RemoteState remote_state(std::uint32_t loading, std::uint32_t publication);

}
