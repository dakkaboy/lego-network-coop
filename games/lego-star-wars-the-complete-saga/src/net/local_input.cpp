#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <bcrypt.h>

#include "local_input.hpp"
#include "session.hpp"

#include <cstdio>
#include <limits>
#include <mutex>

namespace saga::net {
namespace {

constexpr std::uint16_t lan_port = 34244;
constexpr std::uint64_t build = 0x085688e73561c61f;
constexpr ULONGLONG input_timeout = 250;

std::mutex pad_mutex;
RemoteState remote;
NativeScene pad_scene{};

struct Socket {
    SOCKET value{INVALID_SOCKET};
    ~Socket() {
        if (value != INVALID_SOCKET) closesocket(value);
        WSACleanup();
    }
};

std::optional<Peer> configured_host() {
    wchar_t name[16]{};
    SetLastError(ERROR_SUCCESS);
    const auto size = GetEnvironmentVariableW(L"COMPLETE_SAGA_LAN_ADDRESS", name, ARRAYSIZE(name));
    if (!size && GetLastError() == ERROR_ENVVAR_NOT_FOUND) return Peer{INADDR_LOOPBACK, lan_port};
    IN_ADDR parsed{};
    if (!size || size >= ARRAYSIZE(name) || InetPtonW(AF_INET, name, &parsed) != 1) {
        OutputDebugStringA("Saga LAN: invalid IPv4 address");
        return std::nullopt;
    }
    const auto ip = ntohl(parsed.s_addr);
    if (ip == 0 || ip >= 0xe0000000u) {
        OutputDebugStringA("Saga LAN: address must be unicast");
        return std::nullopt;
    }
    return Peer{ip, lan_port};
}

sockaddr_in address(Peer peer) {
    sockaddr_in result{};
    result.sin_family = AF_INET;
    result.sin_port = htons(peer.port);
    result.sin_addr.s_addr = htonl(peer.address);
    return result;
}

void transmit(SOCKET socket, Peer peer, const Packet& packet) {
    const auto bytes = encode(packet);
    const auto target = address(peer);
    sendto(socket, reinterpret_cast<const char*>(bytes.data()), static_cast<int>(bytes.size()),
           0, reinterpret_cast<const sockaddr*>(&target), sizeof(target));
}

std::uint64_t token() {
    std::uint64_t value{};
    if (BCryptGenRandom(nullptr, reinterpret_cast<PUCHAR>(&value), sizeof(value),
                        BCRYPT_USE_SYSTEM_PREFERRED_RNG) != 0) {
        return 0;
    }
    return value;
}

void set_remote(const std::optional<Input>& input, NativeScene local, std::optional<PlayerState> players = {},
                std::optional<Packet> story = {}, std::optional<CampaignProgress> campaign = {}, PosePackets poses = {}) {
    const std::lock_guard lock(pad_mutex);
    remote.pad = input ? std::optional{Pad{input->buttons, input->x, input->y}} : std::nullopt;
    remote.players = players;
    remote.story = story;
    remote.campaign = campaign;
    remote.poses = poses;
    pad_scene = local;
}

void trace(const char* action, Scene scene, std::uint32_t publication) {
    char line[160]{};
    std::snprintf(line, sizeof(line), "Saga LAN %s generation=%llu room=%016llx publication=%u",
                  action, scene.generation, scene.room, publication);
    OutputDebugStringA(line);
}

}

RemoteState remote_state(std::uint32_t loading, std::uint32_t publication) {
    const std::lock_guard lock(pad_mutex);
    if (loading != pad_scene.loading || publication != pad_scene.publication) {
        return {};
    }
    return remote;
}

void run_local_input(LocalRole role, InputSource source) {
    const auto id = token();
    WSADATA wsa{};
    if (id == 0 || WSAStartup(MAKEWORD(2, 2), &wsa) != 0) return;
    const Socket socket{::socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)};
    if (socket.value == INVALID_SOCKET) return;

    const auto host_peer = configured_host();
    if (!host_peer) return;
    const auto is_host = role == LocalRole::host;
    const auto outgoing = host_peer->address == INADDR_LOOPBACK ? INADDR_LOOPBACK : INADDR_ANY;
    const auto bind_to = address(is_host ? *host_peer : Peer{outgoing, 0});
    constexpr int exclusive = 1;
    u_long nonblocking = 1;
    if (setsockopt(socket.value, SOL_SOCKET, SO_EXCLUSIVEADDRUSE,
                   reinterpret_cast<const char*>(&exclusive), sizeof(exclusive)) != 0
        || bind(socket.value, reinterpret_cast<const sockaddr*>(&bind_to), sizeof(bind_to)) != 0
        || ioctlsocket(socket.value, FIONBIO, &nonblocking) != 0) {
        return;
    }

    HostSession host(build, id);
    ClientSession client(*host_peer, build, id);
    std::optional<Peer> joined;
    auto join_state = JoinState::waiting;
    NativeScene previous{};
    Scene confirmed{};
    std::uint32_t confirmed_publication{}, confirmed_loading{};
    ULONGLONG last_received{}, last_players{}, next_announce{}, next_input{}, next_players{};
    bool applied{};
    std::optional<Packet> outgoing_story;
    std::optional<std::uint64_t> previous_story;
    ULONGLONG story_expiry{}, next_story{}, story_received{}, next_campaign{}, last_campaign{};
    std::optional<std::array<std::uint8_t, 2>> previous_health;
    std::array<std::uint16_t, 2> death_counts{};

    for (;;) {
        const auto now = GetTickCount64();
        const auto local = source.scene();
        const auto publish = [&](std::uint64_t room) {
            if (!host.publish_scene(room)) return;
            previous_health.reset();
            death_counts = {};
            set_remote(std::nullopt, local);
            if (const auto announcement = host.scene_packet()) {
                transmit(socket.value, *joined, *announcement);
                trace(room ? "host publish" : "host loading", announcement->scene, local.publication);
            }
        };
        if (is_host) {
            if (local.loading != previous.loading || (local.room == 0 && previous.room != 0)) {
                publish(0);
            }
            if (local.room != 0 && (local.publication != previous.publication || previous.room == 0)) {
                publish(local.room);
            }
        }
        previous = local;

        for (int count = 0; count < 32; ++count) {
            std::array<std::uint8_t, wire_size + 1> bytes{};
            sockaddr_in from{};
            int from_size = sizeof(from);
            const auto received = recvfrom(socket.value, reinterpret_cast<char*>(bytes.data()),
                                           static_cast<int>(bytes.size()), 0,
                                           reinterpret_cast<sockaddr*>(&from), &from_size);
            if (received == SOCKET_ERROR) break;
            const auto data = std::span(bytes).first(static_cast<std::size_t>(received));
            const Peer sender{ntohl(from.sin_addr.s_addr), ntohs(from.sin_port)};
            if (!is_host) {
                const auto before = client.latest_input();
                const auto prior_story = client.latest_story();
                const auto prior_campaign = client.latest_progress();
                const auto previous_players = client.latest_player_state();
                join_state = client.receive(sender, data);
                if (client.latest_progress() && client.latest_progress() != prior_campaign) last_campaign = now;
                if (client.latest_story() && client.latest_story() != prior_story) story_received = now;
                if (client.latest_player_state() && client.latest_player_state() != previous_players) last_players = now;
                if (client.latest_input() && client.latest_input() != before) last_received = now;
                continue;
            }
            const auto before = host.latest_input();
            if (const auto reply = host.receive(sender, data)) {
                transmit(socket.value, sender, *reply);
                if (reply->kind == Kind::welcome) {
                    joined = sender;
                    next_announce = 0;
                }
            }
            if (host.latest_input() && host.latest_input() != before) {
                last_received = now;
            }
        }

        if (is_host) {
            if (local.story && !previous_story && joined) {
                outgoing_story = host.make_story(*local.story, local.story_episode);
                story_expiry = now + 8000;
                next_story = now;
                if (outgoing_story) trace("host Story selected", outgoing_story->scene, local.publication);
            }
            previous_story = local.story;
            if (outgoing_story && now < story_expiry && now >= next_story) {
                transmit(socket.value, *joined, *outgoing_story);
                next_story = now + 100;
            }
            if (local.hub && joined && now >= next_campaign) {
                if (const auto value = source.campaign()) {
                    if (const auto update = host.make_progress(*value)) transmit(socket.value, *joined, *update);
                }
                next_campaign = now + 500;
            }
            if (now >= next_announce) {
                if (const auto announcement = host.scene_packet()) {
                    transmit(socket.value, *joined, *announcement);
                }
                next_announce = now + 100;
            }
            const bool ready = host.latest_input() && now - last_received < input_timeout;
            set_remote(ready ? host.latest_input() : std::nullopt, local);
            if (ready && now >= next_input) {
                const auto pad = source.pad();
                if (const auto input = host.make_input(pad.buttons, pad.x, pad.y)) {
                    transmit(socket.value, *joined, *input);
                }
                next_input = now + 16;
            }
            if (ready && local.mission && now >= next_players) {
                if (auto value = source.players()) {
                    if (previous_health) {
                        for (std::size_t i = 0; i < death_counts.size(); ++i) {
                            if ((*previous_health)[i] && !value->health[i]
                                && death_counts[i] != std::numeric_limits<std::uint16_t>::max()) ++death_counts[i];
                        }
                    }
                    previous_health = value->health;
                    value->deaths = death_counts;
                    if (const auto packet = host.make_player_state(*value)) transmit(socket.value, *joined, *packet);
                }
                if (const auto poses = source.poses()) {
                    for (std::size_t slot = 0; slot < poses->size(); ++slot) {
                        if (const auto packet = host.make_pose(slot, (*poses)[slot])) {
                            transmit(socket.value, *joined, *packet);
                        }
                    }
                }
                next_players = now + 50;
            }
            if (ready != applied) {
                if (const auto scene = host.scene_packet()) {
                    trace(ready ? "host input ready" : "host input cleared", scene->scene,
                          local.publication);
                }
                applied = ready;
            }
        } else {
            if (join_state == JoinState::waiting && now >= next_announce) {
                transmit(socket.value, *host_peer, client.hello());
                next_announce = now + 250;
            }
            const auto pending = client.pending_scene();
            if (local.room != 0 && local.room == pending.room && pending != confirmed
                && local.publication != confirmed_publication && client.confirm_scene(pending)) {
                confirmed = pending;
                confirmed_publication = local.publication;
                confirmed_loading = local.loading;
                trace("client confirmed", confirmed, confirmed_publication);
            }
            const bool same_scene = local.room != 0 && local.room == confirmed.room
                && pending == confirmed && local.loading == confirmed_loading
                && local.publication == confirmed_publication;
            const bool ready = same_scene && client.latest_input() && now - last_received < input_timeout;
            const auto& snapshot = client.latest_player_state();
            const auto players = ready && local.mission && snapshot && now - last_players < input_timeout
                ? std::optional{snapshot->players} : std::nullopt;
            const auto& story = client.latest_story();
            const auto launch = story && now - story_received < 8000 ? story : std::nullopt;
            const auto& progress = client.latest_progress();
            const auto campaign = local.hub && progress && now - last_campaign < 1500
                ? std::optional{CampaignProgress{progress->scene.generation, progress->scene.room,
                                                progress->input.buttons}} : std::nullopt;
            set_remote(ready ? client.latest_input() : std::nullopt, local, players, launch, campaign, players ? client.latest_poses() : PosePackets{});
            if (ready != applied) {
                trace(ready ? "client input ready" : "client input cleared", pending, local.publication);
                applied = ready;
            }
            if (same_scene && now >= next_input) {
                const auto pad = source.pad();
                if (const auto input = client.make_input(pad.buttons, pad.x, pad.y)) {
                    transmit(socket.value, *host_peer, *input);
                }
                next_input = now + 16;
            }
        }
        Sleep(4);
    }
}

}
