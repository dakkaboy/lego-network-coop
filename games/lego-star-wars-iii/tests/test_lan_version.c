#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <windows.h>
#include <assert.h>
#include "net/lan.h"

int main(void) {
    WSADATA data;
    assert(WSAStartup(MAKEWORD(2, 2), &data) == 0);

    SOCKET listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    assert(listener != INVALID_SOCKET);
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_port = htons(CLONEWARS_LAN_PORT);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    assert(bind(listener, (const struct sockaddr *)&address, sizeof(address)) == 0);
    assert(listen(listener, 1) == 0);

    lan_start(0, "127.0.0.1");
    fd_set pending;
    FD_ZERO(&pending);
    FD_SET(listener, &pending);
    struct timeval accept_timeout = {5, 0};
    assert(select(0, &pending, NULL, NULL, &accept_timeout) == 1);
    SOCKET peer = accept(listener, NULL, NULL);
    assert(peer != INVALID_SOCKET);

    DWORD transfer_timeout = 5000;
    assert(setsockopt(peer, SOL_SOCKET, SO_RCVTIMEO, (const char *)&transfer_timeout, sizeof(transfer_timeout)) == 0);
    assert(setsockopt(peer, SOL_SOCKET, SO_SNDTIMEO, (const char *)&transfer_timeout, sizeof(transfer_timeout)) == 0);
    unsigned char hello[40];
    assert(recv(peer, (char *)hello, sizeof(hello), MSG_WAITALL) == sizeof(hello));
    assert(hello[7] == SYNC_PROTOCOL_VERSION);
    --hello[7];
    assert(send(peer, (const char *)hello, sizeof(hello), 0) == sizeof(hello));

    ULONGLONG deadline = GetTickCount64() + transfer_timeout;
    while (lan_status() == LAN_CONNECTING && GetTickCount64() < deadline)
        Sleep(10);
    assert(lan_status() == LAN_FAILED);
    assert(lan_error() == WSAEPROTONOSUPPORT);
    lan_stop();
    closesocket(peer);
    closesocket(listener);
    WSACleanup();
    return 0;
}
