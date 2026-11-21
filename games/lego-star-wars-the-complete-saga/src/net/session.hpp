#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>

namespace saga::net {

inline constexpr std::uint8_t protocol_version = 9;
inline constexpr std::size_t wire_size = 40;
using Wire = std::array<std::uint8_t, wire_size>;

enum class Kind : std::uint8_t { hello = 1, welcome, incompatible, input, scene, host_input, player_state, story, progress, first_pose, second_pose };

struct Scene {
    std::uint64_t generation{};
    std::uint64_t room{};
    bool operator==(const Scene&) const = default;
};

struct Input {
    std::uint32_t sequence{};
    std::uint16_t buttons{};
    std::int16_t x{};
    std::int16_t y{};
    bool operator==(const Input&) const = default;
};

struct PlayerState {
    std::uint32_t first{};
    std::uint32_t second{};
    std::array<std::uint8_t, 2> health{};
    std::array<std::uint16_t, 2> deaths{};
    bool operator==(const PlayerState&) const = default;
};

struct PlayerPose {
    std::array<float, 3> position{};
    std::uint16_t heading{};
};

struct CampaignProgress {
    std::uint64_t completed{};
    std::uint64_t unlocked{};
    std::uint16_t tail{};
    bool operator==(const CampaignProgress&) const = default;
};

struct Packet {
    Kind kind{};
    std::uint8_t version{protocol_version};
    std::uint64_t build{};
    std::uint64_t nonce{};
    std::uint64_t session{};
    Input input{};
    Scene scene{};
    PlayerState players{};
    bool operator==(const Packet&) const = default;
};

using PosePackets = std::array<std::optional<Packet>, 2>;

struct Peer {
    std::uint32_t address{};
    std::uint16_t port{};
    bool operator==(const Peer&) const = default;
};

PlayerPose player_pose(const Packet& packet);
Wire encode(const Packet& packet);
std::optional<Packet> decode(std::span<const std::uint8_t> bytes);

class HostSession {
public:
    HostSession(std::uint64_t build, std::uint64_t session);
    std::optional<Packet> receive(Peer sender, std::span<const std::uint8_t> bytes);
    bool publish_scene(std::uint64_t room);
    std::optional<Packet> scene_packet() const;
    std::optional<Packet> make_pose(std::size_t slot, PlayerPose pose);
    std::optional<Packet> make_progress(CampaignProgress progress);
    std::optional<Packet> make_story(std::uint64_t selection, std::uint16_t episode);
    std::optional<Packet> make_player_state(PlayerState value);
    std::optional<Packet> make_input(std::uint16_t buttons, std::int16_t x, std::int16_t y);
    const std::optional<Input>& latest_input() const { return input_; }

private:
    std::uint64_t build_{};
    std::uint64_t session_{};
    std::optional<Peer> peer_;
    std::uint64_t nonce_{};
    std::uint32_t sequence_{};
    std::optional<Input> input_;
    Scene scene_{};
};

enum class JoinState { waiting, connected, incompatible };

class ClientSession {
public:
    ClientSession(Peer host, std::uint64_t build, std::uint64_t nonce);
    Packet hello() const;
    JoinState receive(Peer sender, std::span<const std::uint8_t> bytes);
    Scene pending_scene() const { return scene_; }
    const PosePackets& latest_poses() const { return poses_; }
    const std::optional<Packet>& latest_progress() const { return progress_; }
    const std::optional<Packet>& latest_story() const { return story_; }
    const std::optional<Packet>& latest_player_state() const { return player_state_; }
    const std::optional<Input>& latest_input() const { return input_; }
    bool confirm_scene(Scene scene);
    std::optional<Packet> make_input(std::uint16_t buttons, std::int16_t x, std::int16_t y);

private:
    Peer host_{};
    std::uint64_t build_{};
    std::uint64_t nonce_{};
    std::uint64_t session_{};
    std::uint32_t sequence_{};
    Scene scene_{};
    std::optional<Input> input_;
    std::optional<Packet> player_state_;
    std::optional<Packet> story_;
    std::optional<Packet> progress_;
    PosePackets poses_;
    bool scene_ready_{};
    JoinState state_{JoinState::waiting};
};

}  // namespace saga::net
