#include "session.hpp"

#include <algorithm>
#include <bit>
#include <limits>

namespace saga::net {
namespace {

constexpr std::array<std::uint8_t, 4> magic{'L', 'S', 'C', 'S'};

template <class T>
void write(Wire& bytes, std::size_t offset, T value) {
    for (std::size_t i = sizeof(T); i > 0; --i) {
        bytes[offset + i - 1] = static_cast<std::uint8_t>(value);
        value = static_cast<T>(value >> 8);
    }
}

template <class T>
T read(std::span<const std::uint8_t> bytes, std::size_t offset) {
    T value{};
    for (std::size_t i = 0; i < sizeof(T); ++i) {
        value = static_cast<T>((value << 8) | bytes[offset + i]);
    }
    return value;
}

}  // namespace

Wire encode(const Packet& packet) {
    Wire bytes{};
    std::ranges::copy(magic, bytes.begin());
    bytes[4] = packet.version;
    bytes[5] = static_cast<std::uint8_t>(packet.kind);
    write(bytes, 6, packet.input.buttons);
    write(bytes, 8, packet.build);
    write(bytes, 16, packet.nonce);
    write(bytes, 24, packet.session);
    write(bytes, 32, packet.input.sequence);
    write(bytes, 36, std::bit_cast<std::uint16_t>(packet.input.x));
    write(bytes, 38, std::bit_cast<std::uint16_t>(packet.input.y));
    return bytes;
}

std::optional<Packet> decode(std::span<const std::uint8_t> bytes) {
    if (bytes.size() != wire_size || !std::ranges::equal(magic, bytes.first(magic.size()))
        || bytes[4] == 0) {
        return std::nullopt;
    }

    Packet packet{
        .kind = static_cast<Kind>(bytes[5]),
        .version = bytes[4],
        .build = read<std::uint64_t>(bytes, 8),
        .nonce = read<std::uint64_t>(bytes, 16),
        .session = read<std::uint64_t>(bytes, 24),
        .input = {
            .sequence = read<std::uint32_t>(bytes, 32),
            .buttons = read<std::uint16_t>(bytes, 6),
            .x = std::bit_cast<std::int16_t>(read<std::uint16_t>(bytes, 36)),
            .y = std::bit_cast<std::int16_t>(read<std::uint16_t>(bytes, 38)),
        },
    };

    switch (packet.kind) {
    case Kind::hello:
    case Kind::incompatible:
    case Kind::welcome:
        if (packet.build != 0 && packet.nonce != 0 && packet.input == Input{}
            && (packet.session != 0) == (packet.kind == Kind::welcome)) {
            return packet;
        }
        break;
    case Kind::input:
        if (packet.build == 0 && packet.nonce == 0 && packet.session != 0
            && packet.input.sequence != 0) {
            return packet;
        }
        break;
    }
    return std::nullopt;
}

HostSession::HostSession(std::uint64_t build, std::uint64_t session)
    : build_(build), session_(session) {}

std::optional<Packet> HostSession::receive(Peer sender, std::span<const std::uint8_t> bytes) {
    const auto packet = decode(bytes);
    if (!packet || build_ == 0 || session_ == 0) {
        return std::nullopt;
    }
    if (packet->kind == Kind::hello) {
        if (packet->version != protocol_version || packet->build != build_) {
            return Packet{.kind = Kind::incompatible, .build = build_, .nonce = packet->nonce};
        }
        if (peer_ && (*peer_ != sender || nonce_ != packet->nonce)) {
            return std::nullopt;
        }
        peer_ = sender;
        nonce_ = packet->nonce;
        return Packet{.kind = Kind::welcome, .build = build_, .nonce = nonce_, .session = session_};
    }
    if (packet->kind == Kind::input && packet->version == protocol_version
        && peer_ == sender && packet->session == session_
        && (!input_ || packet->input.sequence > input_->sequence)) {
        input_ = packet->input;
    }
    return std::nullopt;
}

ClientSession::ClientSession(Peer host, std::uint64_t build, std::uint64_t nonce)
    : host_(host), build_(build), nonce_(nonce) {}

Packet ClientSession::hello() const {
    return Packet{.kind = Kind::hello, .build = build_, .nonce = nonce_};
}

JoinState ClientSession::receive(Peer sender, std::span<const std::uint8_t> bytes) {
    if (state_ != JoinState::waiting || sender != host_) {
        return state_;
    }
    const auto packet = decode(bytes);
    if (!packet || packet->nonce != nonce_) {
        return state_;
    }
    if (packet->kind == Kind::incompatible) {
        state_ = JoinState::incompatible;
    } else if (packet->kind == Kind::welcome && packet->build == build_
               && packet->version == protocol_version) {
        session_ = packet->session;
        state_ = JoinState::connected;
    }
    return state_;
}

std::optional<Packet> ClientSession::make_input(std::uint16_t buttons, std::int16_t x,
                                               std::int16_t y) {
    if (state_ != JoinState::connected || sequence_ == std::numeric_limits<std::uint32_t>::max()) {
        return std::nullopt;
    }
    return Packet{
        .kind = Kind::input,
        .session = session_,
        .input = {.sequence = ++sequence_, .buttons = buttons, .x = x, .y = y},
    };
}

}  // namespace saga::net
