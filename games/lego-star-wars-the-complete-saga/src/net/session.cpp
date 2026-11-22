#include "session.hpp"

#include <bit>
#include <limits>

namespace saga::net {
namespace {

struct WireFields {
    std::uint64_t context;
    std::uint64_t identity;
    std::uint64_t session;
    std::uint32_t sequence;
    std::uint16_t buttons;
    std::int16_t x;
    std::int16_t y;
    std::uint8_t version;
    std::uint8_t kind;
};

struct HostAdmission {
    std::uint64_t build;
    std::uint64_t nonce;
    std::uint64_t session;
    std::uint64_t generation;
    std::uint64_t room;
    std::uint32_t last_input;
    std::uint8_t version;
    bool has_peer;
    bool matching_peer;
};

struct ClientAdmission {
    std::uint64_t build;
    std::uint64_t nonce;
    std::uint64_t session;
    std::uint64_t generation;
    std::uint32_t last_sequence;
    std::uint8_t version;
    bool connected;
    bool scene_ready;
};

extern "C" bool saga_client_admit(const ClientAdmission* client, const WireFields* packet);
static_assert(offsetof(ClientAdmission, last_sequence) == 32);
static_assert(offsetof(ClientAdmission, scene_ready) == 38);

enum class HostDecision : std::uint8_t { ignore, incompatible, welcome, input };
extern "C" HostDecision saga_host_admit(const HostAdmission* host, const WireFields* packet);
static_assert(offsetof(HostAdmission, last_input) == 40);
static_assert(offsetof(HostAdmission, matching_peer) == 46);

static_assert(offsetof(WireFields, sequence) == 24);
static_assert(offsetof(WireFields, kind) == 35);

extern "C" void saga_encode_packet(Wire* bytes, const WireFields* fields);
extern "C" bool saga_decode_packet(const std::uint8_t* bytes, WireFields* fields);

}  // namespace

Wire encode(const Packet& packet) {
    const bool scene_context = packet.kind == Kind::input || packet.kind == Kind::scene || packet.kind == Kind::host_input || packet.kind == Kind::player_state || packet.kind == Kind::story || packet.kind == Kind::progress || packet.kind == Kind::first_pose || packet.kind == Kind::second_pose;
    const WireFields fields{
        scene_context ? packet.scene.generation : packet.build,
        packet.kind == Kind::player_state ? (std::uint64_t{packet.players.first} << 32) | packet.players.second
                                  : scene_context ? packet.scene.room : packet.nonce,
        packet.session,
        packet.input.sequence,
        packet.kind == Kind::player_state
            ? static_cast<std::uint16_t>((packet.players.health[0] << 8) | packet.players.health[1])
            : packet.input.buttons,
        packet.kind == Kind::player_state ? std::bit_cast<std::int16_t>(packet.players.deaths[0]) : packet.input.x,
        packet.kind == Kind::player_state ? std::bit_cast<std::int16_t>(packet.players.deaths[1]) : packet.input.y,
        packet.version,
        static_cast<std::uint8_t>(packet.kind),
    };
    Wire bytes;
    saga_encode_packet(&bytes, &fields);
    return bytes;
}

static Packet decode_fields(const WireFields& fields) {
    const auto kind = static_cast<Kind>(fields.kind);
    const bool scene_context = kind == Kind::input || kind == Kind::scene || kind == Kind::host_input || kind == Kind::player_state || kind == Kind::story || kind == Kind::progress || kind == Kind::first_pose || kind == Kind::second_pose;
    return Packet{
        .kind = kind,
        .version = fields.version,
        .build = scene_context ? 0 : fields.context,
        .nonce = scene_context ? 0 : fields.identity,
        .session = fields.session,
        .input = kind == Kind::player_state ? Input{.sequence = fields.sequence}
                                           : Input{fields.sequence, fields.buttons, fields.x, fields.y},
        .scene = scene_context ? Scene{fields.context, kind == Kind::player_state ? 0 : fields.identity} : Scene{},
        .players = kind == Kind::player_state ? PlayerState{static_cast<std::uint32_t>(fields.identity >> 32),
                                            static_cast<std::uint32_t>(fields.identity),
                                            {static_cast<std::uint8_t>(fields.buttons >> 8),
                                             static_cast<std::uint8_t>(fields.buttons)},
                                            {std::bit_cast<std::uint16_t>(fields.x),
                                             std::bit_cast<std::uint16_t>(fields.y)}} : PlayerState{},
    };
}


std::optional<Packet> decode(std::span<const std::uint8_t> bytes) {
    WireFields fields{};
    if (bytes.size() != wire_size || !saga_decode_packet(bytes.data(), &fields)) {
        return std::nullopt;
    }
    return decode_fields(fields);
}


HostSession::HostSession(std::uint64_t build, std::uint64_t session)
    : build_(build), session_(session) {}

bool HostSession::publish_scene(std::uint64_t room) {
    input_.reset();
    if (scene_.generation == std::numeric_limits<std::uint64_t>::max()) {
        scene_.room = 0;
        return false;
    }
    scene_ = {scene_.generation + 1, room};
    return true;
}

std::optional<Packet> HostSession::scene_packet() const {
    if (!peer_ || scene_.generation == 0) {
        return std::nullopt;
    }
    return Packet{.kind = Kind::scene, .session = session_, .scene = scene_};
}

std::optional<Packet> HostSession::receive(Peer sender, std::span<const std::uint8_t> bytes) {
    WireFields packet{};
    if (bytes.size() != wire_size || !saga_decode_packet(bytes.data(), &packet)) return {};
    const HostAdmission admission{build_, nonce_, session_, scene_.generation, scene_.room,
                                  input_ ? input_->sequence : 0, protocol_version,
                                  peer_.has_value(), peer_ == sender};
    switch (saga_host_admit(&admission, &packet)) {
    case HostDecision::incompatible:
        return Packet{.kind = Kind::incompatible, .build = build_, .nonce = packet.identity};
    case HostDecision::welcome:
        peer_ = sender;
        nonce_ = packet.identity;
        return Packet{.kind = Kind::welcome, .build = build_, .nonce = nonce_, .session = session_};
    case HostDecision::input:
        input_ = Input{packet.sequence, packet.buttons, packet.x, packet.y};
        break;
    case HostDecision::ignore:
        break;
    }
    return {};
}

std::optional<Packet> HostSession::make_input(std::uint16_t buttons, std::int16_t x, std::int16_t y) {
    if (!input_ || sequence_ == std::numeric_limits<std::uint32_t>::max()) {
        return std::nullopt;
    }
    return Packet{
        .kind = Kind::host_input,
        .session = session_,
        .input = {.sequence = ++sequence_, .buttons = buttons, .x = x, .y = y},
        .scene = {.generation = scene_.generation},
    };
}

PlayerPose player_pose(const Packet& packet) {
    const auto low = std::uint32_t(std::bit_cast<std::uint16_t>(packet.input.y));
    const auto high = std::uint32_t(std::bit_cast<std::uint16_t>(packet.input.x)) << 16;
    return {{std::bit_cast<float>(std::uint32_t(packet.scene.room >> 32)),
             std::bit_cast<float>(std::uint32_t(packet.scene.room)),
             std::bit_cast<float>(high | low)}, packet.input.buttons};
}

std::optional<Packet> HostSession::make_pose(std::size_t slot, PlayerPose pose) {
    if (slot >= 2 || !input_ || sequence_ == std::numeric_limits<std::uint32_t>::max()) return {};
    const auto z = std::bit_cast<std::uint32_t>(pose.position[2]);
    const auto xy = (std::uint64_t(std::bit_cast<std::uint32_t>(pose.position[0])) << 32)
        | std::bit_cast<std::uint32_t>(pose.position[1]);
    return Packet{
        .kind = slot == 0 ? Kind::first_pose : Kind::second_pose,
        .session = session_,
        .input = {++sequence_, pose.heading, std::bit_cast<std::int16_t>(std::uint16_t(z >> 16)),
                  std::bit_cast<std::int16_t>(std::uint16_t(z))},
        .scene = {scene_.generation, xy},
    };
}

std::optional<Packet> HostSession::make_progress(CampaignProgress progress) {
    if (!peer_ || sequence_ == std::numeric_limits<std::uint32_t>::max()) return {};
    return Packet{
        .kind = Kind::progress,
        .session = session_,
        .input = {.sequence = ++sequence_, .buttons = progress.tail},
        .scene = {progress.completed, progress.unlocked},
    };
}

std::optional<Packet> HostSession::make_story(std::uint64_t selection, std::uint16_t episode) {
    if (!peer_ || !scene_.generation || sequence_ == std::numeric_limits<std::uint32_t>::max()) return {};
    return Packet{
        .kind = Kind::story,
        .session = session_,
        .input = {.sequence = ++sequence_, .buttons = episode},
        .scene = {scene_.generation, selection},
    };
}

std::optional<Packet> HostSession::make_player_state(PlayerState value) {
    if (!input_ || sequence_ == std::numeric_limits<std::uint32_t>::max()) return std::nullopt;
    return Packet{
        .kind = Kind::player_state,
        .session = session_,
        .input = {.sequence = ++sequence_},
        .scene = {.generation = scene_.generation},
        .players = value,
    };
}

ClientSession::ClientSession(Peer host, std::uint64_t build, std::uint64_t nonce)
    : host_(host), build_(build), nonce_(nonce) {}

Packet ClientSession::hello() const {
    return Packet{.kind = Kind::hello, .build = build_, .nonce = nonce_};
}

JoinState ClientSession::receive(Peer sender, std::span<const std::uint8_t> bytes) {
    if (state_ == JoinState::incompatible || sender != host_) {
        return state_;
    }
    WireFields fields{};
    if (bytes.size() != wire_size || !saga_decode_packet(bytes.data(), &fields)) return state_;
    const auto packet = decode_fields(fields);
    const std::optional<Packet>* previous = nullptr;
    switch (packet.kind) {
    case Kind::player_state: previous = &player_state_; break;
    case Kind::story: previous = &story_; break;
    case Kind::progress: previous = &progress_; break;
    case Kind::first_pose: previous = &poses_[0]; break;
    case Kind::second_pose: previous = &poses_[1]; break;
    default: break;
    }
    std::uint32_t sequence{};
    if (previous && *previous) sequence = (*previous)->input.sequence;
    if (packet.kind == Kind::host_input && input_) sequence = input_->sequence;
    const ClientAdmission admission{build_, nonce_, session_, scene_.generation, sequence,
                                    protocol_version, state_ == JoinState::connected, scene_ready_};
    if (!saga_client_admit(&admission, &fields)) return state_;

    switch (packet.kind) {
    case Kind::incompatible:
        state_ = JoinState::incompatible;
        break;
    case Kind::welcome:
        session_ = packet.session;
        state_ = JoinState::connected;
        break;
    case Kind::scene:
        scene_ = packet.scene;
        scene_ready_ = false;
        input_.reset();
        player_state_.reset();
        poses_ = {};
        break;
    case Kind::host_input: input_ = packet.input; break;
    case Kind::player_state: player_state_ = packet; break;
    case Kind::first_pose: poses_[0] = packet; break;
    case Kind::second_pose: poses_[1] = packet; break;
    case Kind::story: story_ = packet; break;
    case Kind::progress: progress_ = packet; break;
    default: break;
    }
    return state_;
}

bool ClientSession::confirm_scene(Scene scene) {
    if (scene.room == 0 || scene != scene_) {
        return false;
    }
    scene_ready_ = true;
    return true;
}

std::optional<Packet> ClientSession::make_input(std::uint16_t buttons, std::int16_t x,
                                               std::int16_t y) {
    if (!scene_ready_ || sequence_ == std::numeric_limits<std::uint32_t>::max()) {
        return std::nullopt;
    }
    return Packet{
        .kind = Kind::input,
        .session = session_,
        .input = {.sequence = ++sequence_, .buttons = buttons, .x = x, .y = y},
        .scene = {.generation = scene_.generation},
    };
}

}  // namespace saga::net
