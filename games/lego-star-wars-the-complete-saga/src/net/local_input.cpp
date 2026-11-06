#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <windows.h>
#include <bcrypt.h>

#include "local_input.hpp"
#include "session.hpp"

#include <cstdio>
#include <mutex>

namespace saga::net {
namespace {

constexpr Peer host_peer{INADDR_LOOPBACK, 34244};
constexpr std::uint64_t build = 0x085688e73561c61f;
constexpr ULONGLONG input_timeout = 250;

std::mutex pad_mutex;
Pad pad_state{};
NativeScene pad_scene{};

struct Socket {
    SOCKET value{INVALID_SOCKET};
    ~Socket() {
        if (value != INVALID_SOCKET) closesocket(value);
        WSACleanup();
    }
};

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

void set_pad(const std::optional<Input>& input, NativeScene local) {
    const std::lock_guard lock(pad_mutex);
    pad_state = input ? Pad{input->buttons, input->x, input->y} : Pad{};
    pad_scene = local;
}

void trace(const char* action, Scene scene, std::uint32_t publication) {
    char line[160]{};
    std::snprintf(line, sizeof(line), "Saga LAN %s generation=%llu room=%016llx publication=%u",
                  action, scene.generation, scene.room, publication);
    OutputDebugStringA(line);
}

}

Pad remote_pad(std::uint32_t loading, std::uint32_t publication) {
    const std::lock_guard lock(pad_mutex);
    if (loading != pad_scene.loading || publication != pad_scene.publication) {
        return {};
    }
    return pad_state;
}

void run_local_input(LocalRole role, InputSource source) {
    const auto id = token();
    WSADATA wsa{};
    if (id == 0 || WSAStartup(MAKEWORD(2, 2), &wsa) != 0) return;
    const Socket socket{::socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)};
    if (socket.value == INVALID_SOCKET) return;

    const auto is_host = role == LocalRole::host;
    const auto bind_to = address({INADDR_LOOPBACK, is_host ? host_peer.port : std::uint16_t{0}});
    constexpr int exclusive = 1;
    u_long nonblocking = 1;
    if (setsockopt(socket.value, SOL_SOCKET, SO_EXCLUSIVEADDRUSE,
                   reinterpret_cast<const char*>(&exclusive), sizeof(exclusive)) != 0
        || bind(socket.value, reinterpret_cast<const sockaddr*>(&bind_to), sizeof(bind_to)) != 0
        || ioctlsocket(socket.value, FIONBIO, &nonblocking) != 0) {
        return;
    }

    HostSession host(build, id);
    ClientSession client(host_peer, build, id);
    std::optional<Peer> joined;
    auto join_state = JoinState::waiting;
    NativeScene previous{};
    Scene confirmed{};
    std::uint32_t confirmed_publication{};
    ULONGLONG last_received{}, next_announce{}, next_input{};
    bool applied{};

    for (;;) {
        const auto now = GetTickCount64();
        const auto local = source.scene();
        const auto publish = [&](std::uint64_t room) {
            if (!host.publish_scene(room)) return;
            set_pad(std::nullopt, local);
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
                join_state = client.receive(sender, data);
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
            if (now >= next_announce) {
                if (const auto announcement = host.scene_packet()) {
                    transmit(socket.value, *joined, *announcement);
                }
                next_announce = now + 100;
            }
            const bool ready = host.latest_input() && now - last_received < input_timeout;
            set_pad(ready ? host.latest_input() : std::nullopt, local);
            if (ready != applied) {
                if (const auto scene = host.scene_packet()) {
                    trace(ready ? "host input ready" : "host input cleared", scene->scene,
                          local.publication);
                }
                applied = ready;
            }
        } else {
            if (join_state == JoinState::waiting && now >= next_announce) {
                transmit(socket.value, host_peer, client.hello());
                next_announce = now + 250;
            }
            const auto pending = client.pending_scene();
            if (local.room != 0 && local.room == pending.room && pending != confirmed
                && local.publication != confirmed_publication && client.confirm_scene(pending)) {
                confirmed = pending;
                confirmed_publication = local.publication;
                trace("client confirmed", confirmed, confirmed_publication);
            }
            if (local.room != 0 && local.publication == confirmed_publication && now >= next_input) {
                const auto pad = source.pad();
                if (const auto input = client.make_input(pad.buttons, pad.x, pad.y)) {
                    transmit(socket.value, host_peer, *input);
                }
                next_input = now + 16;
            }
        }
        Sleep(4);
    }
}

}
