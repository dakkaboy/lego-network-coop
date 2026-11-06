#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <windows.h>

#include "net/session.hpp"

#include <cstdio>
#include <cstdlib>
#include <cwchar>
#include <string>

namespace {

using namespace saga::net;
constexpr std::uint64_t build = 0x085688e73561c61f;
constexpr std::uint64_t token = 0x721beae54551dd63;
constexpr std::uint64_t nonce = 0x43bf805f3eb88093;
constexpr std::uint64_t room = 0xf673a61cf3c42b08;

void require(bool success, const char* step) {
    if (!success) {
        std::fprintf(stderr, "Failed: %s\n", step);
        std::exit(1);
    }
}

Peer peer(const sockaddr_in& address) {
    return {ntohl(address.sin_addr.s_addr), ntohs(address.sin_port)};
}

sockaddr_in loopback(unsigned short port) {
    sockaddr_in result{};
    result.sin_family = AF_INET;
    result.sin_port = htons(port);
    result.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    return result;
}

void transmit(SOCKET socket, const sockaddr_in& target, std::span<const std::uint8_t> bytes) {
    require(sendto(socket, reinterpret_cast<const char*>(bytes.data()), static_cast<int>(bytes.size()),
                   0, reinterpret_cast<const sockaddr*>(&target), sizeof(target))
            == static_cast<int>(bytes.size()), "send loopback datagram");
}

std::span<const std::uint8_t> receive(SOCKET socket, sockaddr_in& sender, Wire& buffer) {
    int sender_size = sizeof(sender);
    const int count = recvfrom(socket, reinterpret_cast<char*>(buffer.data()),
                               static_cast<int>(buffer.size()), 0,
                               reinterpret_cast<sockaddr*>(&sender), &sender_size);
    require(count >= 0, "receive loopback datagram");
    return std::span(buffer).first(static_cast<std::size_t>(count));
}

void verify_protocol() {
    const Peer host{0x7f000001, 20001};
    const Peer first{0x7f000001, 20002};
    const Peer other{0x7f000001, 20003};
    HostSession receiver(build, token);
    ClientSession client(host, build, nonce);
    require(receiver.publish_scene(room), "publish the opening room");
    require(!client.make_input(1, 12, 13), "input before welcome");

    const auto hello = encode(client.hello());
    auto invalid = hello;
    invalid[0] = 0;
    require(!receiver.receive(first, invalid), "reject corrupt magic");
    require(!receiver.receive(first, std::span(hello).first(hello.size() - 1)), "reject truncation");
    invalid = hello;
    invalid[4] = protocol_version + 1;
    const auto reject = receiver.receive(first, invalid);
    require(reject && reject->kind == Kind::incompatible, "reject incompatible version");

    const auto welcome = receiver.receive(first, hello);
    require(welcome && welcome->kind == Kind::welcome, "accept compatible peer");
    require(receiver.receive(first, hello) == welcome, "retry returns same session");
    require(!receiver.receive(other, hello), "do not replace the joined peer");
    auto fake_welcome = *welcome;
    ++fake_welcome.nonce;
    require(client.receive(host, encode(fake_welcome)) == JoinState::waiting, "reject stale welcome");
    require(client.receive(other, encode(*welcome)) == JoinState::waiting, "reject foreign welcome");
    require(client.receive(host, encode(*welcome)) == JoinState::connected, "accept host welcome");
    require(client.receive(host, encode(*reject)) == JoinState::connected, "ignore late rejection");
    require(!client.make_input(1, 12, 13), "input before scene publication");

    const auto initial_scene = receiver.scene_packet();
    require(initial_scene.has_value(), "send initial scene to the joined peer");
    require(client.receive(other, encode(*initial_scene)) == JoinState::connected
            && client.pending_scene() == Scene{}, "ignore a scene from another peer");
    auto foreign_scene = *initial_scene;
    ++foreign_scene.session;
    client.receive(host, encode(foreign_scene));
    require(client.pending_scene() == Scene{}, "ignore a scene from another session");
    client.receive(host, encode(*initial_scene));
    require(!client.make_input(1, 12, 13), "input before local scene confirmation");
    require(!client.confirm_scene({initial_scene->scene.generation, room + 1}),
            "refuse a mismatched local room");
    require(client.confirm_scene(initial_scene->scene), "confirm the opening scene");

    const auto input = client.make_input(0x0123, -32768, 32767);
    require(input.has_value(), "produce input");
    const auto wire = encode(*input);
    require(wire[6] == 1 && wire[7] == 0x23 && wire[35] == 1
            && wire[36] == 0x80 && wire[37] == 0
            && decode(wire) == input, "signed axes and network byte order");
    receiver.receive(other, wire);
    auto old_session = *input;
    ++old_session.session;
    receiver.receive(first, encode(old_session));
    require(!receiver.latest_input(), "foreign peer and stale session cannot update input");
    receiver.receive(first, wire);
    require(receiver.latest_input() == input->input, "apply input from the joined client");

    require(receiver.publish_scene(0), "start a scene reload");
    receiver.receive(first, wire);
    require(!receiver.latest_input(), "loading clears remote input");
    client.receive(host, encode(*receiver.scene_packet()));
    require(!client.confirm_scene(client.pending_scene()) && !client.make_input(1, 2, 3),
            "loading blocks confirmation and input");
    require(receiver.publish_scene(room), "republish the same room");
    const auto reloaded = receiver.scene_packet();
    require(reloaded && reloaded->scene.generation > initial_scene->scene.generation,
            "same room receives a fresh generation");
    client.receive(host, encode(*reloaded));
    client.receive(host, encode(*initial_scene));
    require(!client.confirm_scene(initial_scene->scene) && !client.make_input(1, 2, 3),
            "an older load of the same room cannot unlock input");
    require(client.confirm_scene(reloaded->scene), "confirm the fresh scene");
    client.receive(host, encode(*reloaded));
    const auto fresh_input = client.make_input(0, 0, 0);
    require(fresh_input.has_value(), "a repeated publication preserves scene confirmation");
    auto delayed_input = *input;
    delayed_input.input.sequence = fresh_input->input.sequence + 100;
    receiver.receive(first, encode(delayed_input));
    require(!receiver.latest_input(), "a newer sequence from the old scene is discarded");
    receiver.receive(first, encode(*fresh_input));
    require(receiver.latest_input() == fresh_input->input, "accept input for the new scene");
}

void run_client(SOCKET socket, const sockaddr_in& host) {
    sockaddr_in sender{};
    Wire buffer{};
    ClientSession wrong(peer(host), build + 1, nonce + 1);
    transmit(socket, host, encode(wrong.hello()));
    const auto rejection = receive(socket, sender, buffer);
    require(wrong.receive(peer(sender), rejection) == JoinState::incompatible,
            "incompatible build is reported to the client");

    ClientSession client(peer(host), build, nonce);
    transmit(socket, host, encode(client.hello()));
    const auto acceptance = receive(socket, sender, buffer);
    require(client.receive(peer(sender), acceptance) == JoinState::connected, "client joins by IP");
    const auto initial_scene = receive(socket, sender, buffer);
    client.receive(peer(sender), initial_scene);
    const auto initial_ticket = client.pending_scene();
    require(initial_ticket.room == room && client.confirm_scene(initial_ticket), "match opening room");

    const auto first = *client.make_input(1, 20, -50);
    const auto second = *client.make_input(0, 0, 0);
    const auto neutral = encode(second);
    transmit(socket, host, encode(first));
    transmit(socket, host, neutral);
    transmit(socket, host, encode(first));
    auto duplicate = second;
    duplicate.input.buttons = 4;
    transmit(socket, host, encode(duplicate));
    transmit(socket, host, std::span(neutral).first(neutral.size() - 1));

    const auto loading = receive(socket, sender, buffer);
    client.receive(peer(sender), loading);
    require(client.pending_scene().room == 0 && !client.make_input(1, 20, -50),
            "wait during the reload");
    const auto reloaded = receive(socket, sender, buffer);
    client.receive(peer(sender), reloaded);
    require(!client.confirm_scene(initial_ticket) && !client.make_input(1, 20, -50),
            "old scene confirmation does not carry into the same room");
    require(client.confirm_scene(client.pending_scene()), "confirm the reloaded room");
    auto stale = first;
    stale.input.sequence = 60000;
    transmit(socket, host, encode(stale));
    transmit(socket, host, encode(*client.make_input(2, 4, -5)));
}

void run_host(SOCKET socket, const wchar_t* executable) {
    sockaddr_in address = loopback(0);
    require(bind(socket, reinterpret_cast<const sockaddr*>(&address), sizeof(address)) == 0,
            "bind host to loopback");
    int address_size = sizeof(address);
    require(getsockname(socket, reinterpret_cast<sockaddr*>(&address), &address_size) == 0,
            "read host port");

    std::wstring command = L"\"" + std::wstring(executable) + L"\" "
        + std::to_wstring(ntohs(address.sin_port));
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION child{};
    require(CreateProcessW(executable, command.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW,
                           nullptr, nullptr, &startup, &child) != 0, "start separate client process");
    CloseHandle(child.hThread);

    HostSession host(build, token);
    require(host.publish_scene(room), "prepare opening scene");
    sockaddr_in client{};
    for (int packet = 0; packet < 7; ++packet) {
        sockaddr_in sender{};
        Wire buffer{};
        const auto bytes = receive(socket, sender, buffer);
        if (const auto response = host.receive(peer(sender), bytes)) {
            transmit(socket, sender, encode(*response));
            if (response->kind == Kind::welcome) {
                client = sender;
                transmit(socket, client, encode(*host.scene_packet()));
            }
        }
    }
    require(host.latest_input() == Input{.sequence = 2}, "duplicate and stale input preserve release");
    require(host.publish_scene(0), "publish loading state");
    transmit(socket, client, encode(*host.scene_packet()));
    require(host.publish_scene(room), "publish reloaded room");
    transmit(socket, client, encode(*host.scene_packet()));
    sockaddr_in sender{};
    Wire buffer{};
    const auto delayed = receive(socket, sender, buffer);
    host.receive(peer(sender), delayed);
    require(!host.latest_input(), "ignore old-room input on loopback");
    const auto current = receive(socket, sender, buffer);
    host.receive(peer(sender), current);
    require(host.latest_input() == Input{.sequence = 3, .buttons = 2, .x = 4, .y = -5},
            "accept input on loopback after scene confirmation");
    require(WaitForSingleObject(child.hProcess, 4000) == WAIT_OBJECT_0, "client exits");
    DWORD child_status{};
    require(GetExitCodeProcess(child.hProcess, &child_status) && child_status == 0,
            "client test passed");
    CloseHandle(child.hProcess);
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
    WSADATA winsock{};
    require(WSAStartup(MAKEWORD(2, 2), &winsock) == 0, "initialize Winsock");
    const SOCKET socket = ::socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    require(socket != INVALID_SOCKET, "create UDP socket");
    const DWORD timeout = 4000;
    require(setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO,
                       reinterpret_cast<const char*>(&timeout), sizeof(timeout)) == 0,
            "set receive timeout");
    if (argc == 2) {
        run_client(socket, loopback(static_cast<unsigned short>(std::wcstoul(argv[1], nullptr, 10))));
    } else {
        verify_protocol();
        wchar_t executable[MAX_PATH]{};
        const DWORD length = GetModuleFileNameW(nullptr, executable, MAX_PATH);
        require(length != 0 && length < MAX_PATH, "get test executable path");
        run_host(socket, executable);
        std::puts("Separate UDP processes joined and preserved the newest input.");
    }
    closesocket(socket);
    WSACleanup();
    return 0;
}
