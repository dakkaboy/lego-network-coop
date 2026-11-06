#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>

namespace saga::net {

inline constexpr std::uint8_t protocol_version = 2;
inline constexpr std::size_t wire_size = 40;
using Wire = std::array<std::uint8_t, wire_size>;

enum class Kind : std::uint8_t { hello = 1, welcome, incompatible, input, scene };

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

struct Packet {
    Kind kind{};
    std::uint8_t version{protocol_version};
    std::uint64_t build{};
    std::uint64_t nonce{};
    std::uint64_t session{};
    Input input{};
    Scene scene{};
    bool operator==(const Packet&) const = default;
};

struct Peer {
    std::uint32_t address{};
    std::uint16_t port{};
    bool operator==(const Peer&) const = default;
};

Wire encode(const Packet& packet);
std::optional<Packet> decode(std::span<const std::uint8_t> bytes);

class HostSession {
public:
    HostSession(std::uint64_t build, std::uint64_t session);
    std::optional<Packet> receive(Peer sender, std::span<const std::uint8_t> bytes);
    bool publish_scene(std::uint64_t room);
    std::optional<Packet> scene_packet() const;
    const std::optional<Input>& latest_input() const { return input_; }

private:
    std::uint64_t build_{};
    std::uint64_t session_{};
    std::optional<Peer> peer_;
    std::uint64_t nonce_{};
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
    bool confirm_scene(Scene scene);
    std::optional<Packet> make_input(std::uint16_t buttons, std::int16_t x, std::int16_t y);

private:
    Peer host_{};
    std::uint64_t build_{};
    std::uint64_t nonce_{};
    std::uint64_t session_{};
    std::uint32_t sequence_{};
    Scene scene_{};
    bool scene_ready_{};
    JoinState state_{JoinState::waiting};
};

}  // namespace saga::net
