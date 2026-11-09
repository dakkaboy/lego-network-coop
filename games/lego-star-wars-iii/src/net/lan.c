#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <string.h>
#include <stddef.h>
#include <math.h>
#include "lan.h"
#include "../sync/preload_state.h"
#ifndef CLONEWARS_LAN_PORT
#define CLONEWARS_LAN_PORT 32510
#endif

static volatile LONG status;
static volatile LONG error_code;
static volatile LONG generation;
static volatile LONG published_session;
static volatile LONG generation_exhausted;
static LanSessionInvalidator session_invalidator;
static void *session_invalidator_user;
static int active(LONG ticket);
static volatile LONG host_role;
static volatile LONG local_level = -1;
static volatile LONG remote_level = -1;
static const unsigned char hello[] = {
    'L','S','W','3','L','A','N',SYNC_PROTOCOL_VERSION,
    0x71,0x6f,0x83,0x6d,0xa4,0x89,0x82,0x30,0x46,0x4e,0x72,0xe7,0x6f,0x59,0x35,0xc7,
    0x38,0xb3,0xbd,0x35,0x17,0x7a,0x91,0x02,0x0e,0x3b,0x08,0xfe,0x34,0x61,0xa9,0xe0
};

struct Request { int host; LONG generation; char address[64]; };

struct PeerState { uint32_t epoch; int32_t level, ready; SyncInput input; SyncLoading loading; uint32_t auto_skip,ack,native_entry; SyncPreloadInput preload; SyncPreloadReceipt preload_receipt; uint32_t preload_seal; SyncWorldReady world_ready; };
struct Header { uint32_t magic, kind, size; };
static INIT_ONCE queue_once = INIT_ONCE_STATIC_INIT;
static CRITICAL_SECTION queue_lock,session_worker_lock;
static SyncFrame outbound[SYNC_QUEUE_SIZE], inbound[SYNC_QUEUE_SIZE];
static unsigned out_head, out_count, in_head, in_count;
static SyncProfile own_profile, peer_profile;
static int own_profile_pending, peer_profile_pending;
static struct PeerState local_state = {.level=-1,.input={.analog_x=128,.analog_y=128,.aim_x=128,.aim_y=128},.loading={.level=-1},.preload={.level=-1},.world_ready={.level=-1}};
static struct PeerState peer_state = {.level=-1,.input={.analog_x=128,.analog_y=128,.aim_x=128,.aim_y=128},.loading={.level=-1},.preload={.level=-1},.world_ready={.level=-1}};
static BOOL CALLBACK init_queue(PINIT_ONCE once, PVOID param, PVOID *context) {
    (void)once; (void)param; (void)context;
    InitializeCriticalSection(&queue_lock);
    InitializeCriticalSection(&session_worker_lock);
    return TRUE;
}
static void lock_queue(void) {
    InitOnceExecuteOnce(&queue_once,init_queue,NULL,NULL);
    EnterCriticalSection(&queue_lock);
}
void lan_clear_frames(void) {
    lock_queue();
    out_head=out_count=in_head=in_count=0;
    LeaveCriticalSection(&queue_lock);
}
static void reset_preload_locked(void) {
    local_state.preload=(SyncPreloadInput){.level=-1};
    local_state.preload_receipt=(SyncPreloadReceipt){0};local_state.preload_seal=0;
    local_state.world_ready=(SyncWorldReady){.level=-1};
}
static void publish_epoch_locked(uint32_t epoch) {
    if (local_state.epoch!=epoch) {
        local_state.epoch=epoch;local_state.ack=0;local_state.ready=0;
        local_state.input=(SyncInput){0,0,128,128,128,128};
        local_state.loading=(SyncLoading){.epoch=epoch,.level=-1};
        reset_preload_locked();
        if(lan_is_host())out_head=out_count=0;
    }
}
void lan_publish_epoch(uint32_t epoch) {
    lock_queue();publish_epoch_locked(epoch);LeaveCriticalSection(&queue_lock);
}
void lan_publish_transition(uint32_t epoch,int level,uint32_t native_entry) {
    if(level< -1||level>=4096||native_entry>1)return;
    lock_queue();
    if(local_state.epoch!=epoch||local_state.level!=level)local_state.native_entry=native_entry;
    publish_epoch_locked(epoch);
    if(local_state.level!=level)reset_preload_locked();
    local_state.level=level;InterlockedExchange(&local_level,level);
    LeaveCriticalSection(&queue_lock);
}
static int publication_snapshot(LONG ticket, struct PeerState *own, int heartbeat,
                                uint32_t sent_epoch, uint32_t sent_ack) {
    lock_queue();
    int result = -1;
    if (active(ticket)) {
        result = heartbeat || (local_state.ack &&
                               (local_state.epoch != sent_epoch || local_state.ack != sent_ack));
        if (result) {
            *own = local_state;
            own->level = local_level;
            local_state.input.pressed = 0;
        }
    }
    LeaveCriticalSection(&queue_lock);
    return result;
}
uint32_t lan_epoch(void) {
    lock_queue(); uint32_t value=local_state.epoch; LeaveCriticalSection(&queue_lock); return value;
}
LanTransition lan_remote_transition(void) {
    lock_queue();LanTransition result={peer_state.epoch,peer_state.level,peer_state.native_entry};LeaveCriticalSection(&queue_lock);return result;
}
uint32_t lan_remote_epoch(void) {
    lock_queue(); uint32_t value=peer_state.epoch; LeaveCriticalSection(&queue_lock); return value;
}
void lan_publish_ack(uint32_t sequence) {
    lock_queue(); local_state.ack=sequence; LeaveCriticalSection(&queue_lock);
}
uint32_t lan_peer_ack(void) {
    lock_queue();
    uint32_t value=peer_state.epoch==local_state.epoch && peer_state.level==local_state.level ? peer_state.ack : 0;
    LeaveCriticalSection(&queue_lock);
    return value;
}
void lan_publish_ready(int actors) {
    lock_queue(); local_state.ready=actors > 0; LeaveCriticalSection(&queue_lock);
}
int lan_peer_ready(void) {
    lock_queue(); int value=peer_state.ready && local_state.epoch && peer_state.epoch==local_state.epoch; LeaveCriticalSection(&queue_lock); return value;
}
void lan_invalidate_world_ready(void) {
    lock_queue();local_state.world_ready=(SyncWorldReady){.level=-1};LeaveCriticalSection(&queue_lock);
}
int lan_publish_world_ready(const SyncWorldReady *ready) {
    if (!preload_world_ready_valid(ready) || !ready->epoch) return 0;
    lock_queue();
    int accepted=status==LAN_CONNECTED && local_state.epoch==ready->epoch && local_state.level==ready->level;
    if(accepted)local_state.world_ready=*ready;
    LeaveCriticalSection(&queue_lock);return accepted;
}
int lan_remote_world_ready(uint32_t epoch,int level,SyncWorldReady *ready) {
    if(!ready)return 0;
    lock_queue();
    int accepted=status==LAN_CONNECTED && peer_state.epoch==epoch && peer_state.level==level &&
        preload_world_ready_valid(&peer_state.world_ready) && peer_state.world_ready.epoch==epoch && peer_state.world_ready.level==level;
    if(accepted)*ready=peer_state.world_ready;
    LeaveCriticalSection(&queue_lock);return accepted;
}
int lan_publish_preload(const SyncPreloadInput *input) {
    if (!input || !input->epoch || !preload_input_valid(input)) return 0;
    lock_queue();
    int accepted=lan_is_host() && status==LAN_CONNECTED && local_state.epoch==input->epoch && local_state.level==input->level &&
        peer_state.epoch==input->epoch && peer_state.level==input->level &&
        preload_world_ready_matches(&local_state.world_ready,&peer_state.world_ready) &&
        local_state.world_ready.epoch==input->epoch && local_state.world_ready.level==input->level &&
        local_state.world_ready.completed_serial!=UINT32_MAX && local_state.world_ready.completed_serial+1==input->serial &&
        local_state.world_ready.root_phase==input->root_phase;
    if (accepted) local_state.preload=*input;
    LeaveCriticalSection(&queue_lock);return accepted;
}
int lan_receive_preload(uint32_t epoch,int level,SyncPreloadInput *input) {
    if (!input) return 0;
    lock_queue();
    int accepted=!lan_is_host() && status==LAN_CONNECTED && peer_state.epoch==epoch &&
        peer_state.preload.epoch==epoch && peer_state.preload.level==level && preload_input_valid(&peer_state.preload) &&
        local_state.world_ready.epoch==epoch && local_state.world_ready.level==level &&
        local_state.world_ready.completed_serial!=UINT32_MAX && local_state.world_ready.completed_serial+1==peer_state.preload.serial &&
        local_state.world_ready.root_phase==peer_state.preload.root_phase;
    if (accepted) *input=peer_state.preload;
    LeaveCriticalSection(&queue_lock);return accepted;
}
int lan_publish_preload_receipt(uint32_t epoch,int level,const SyncPreloadReceipt *receipt) {
    if(!preload_receipt_valid(receipt)||!receipt->serial)return 0;
    lock_queue();
    const SyncPreloadInput *source=lan_is_host()?&local_state.preload:&peer_state.preload;
    int accepted=status==LAN_CONNECTED&&local_state.epoch==epoch&&local_state.level==level&&
        source->epoch==epoch&&source->level==level&&source->serial==receipt->serial;
    if(accepted)local_state.preload_receipt=*receipt;
    LeaveCriticalSection(&queue_lock);return accepted;
}
int lan_remote_preload_receipt(uint32_t epoch,int level,SyncPreloadReceipt *receipt) {
    if(!receipt)return 0;
    lock_queue();
    int accepted=status==LAN_CONNECTED&&peer_state.epoch==epoch&&peer_state.level==level&&preload_receipt_valid(&peer_state.preload_receipt);
    if(accepted)*receipt=peer_state.preload_receipt;
    LeaveCriticalSection(&queue_lock);return accepted;
}
int lan_publish_preload_seal(uint32_t epoch,int level,uint32_t serial) {
    if(!serial)return 0;
    lock_queue();
    int accepted=lan_is_host()&&status==LAN_CONNECTED&&local_state.epoch==epoch&&local_state.level==level&&peer_state.epoch==epoch&&peer_state.level==level&&
        local_state.preload_receipt.serial==serial&&peer_state.preload_receipt.serial==serial&&
        local_state.preload_receipt.world_calls==peer_state.preload_receipt.world_calls&&
        local_state.preload_receipt.end_phase==peer_state.preload_receipt.end_phase&&
        preload_world_ready_matches(&local_state.world_ready,&peer_state.world_ready)&&
        local_state.world_ready.completed_serial==serial&&
        local_state.preload_receipt.end_phase==local_state.world_ready.root_phase&&
        (local_state.world_ready.root_phase==0xd||local_state.world_ready.root_phase==0xe);
    if(accepted)local_state.preload_seal=serial;
    LeaveCriticalSection(&queue_lock);return accepted;
}
uint32_t lan_remote_preload_seal(uint32_t epoch,int level) {
    lock_queue();uint32_t serial=status==LAN_CONNECTED&&peer_state.epoch==epoch&&peer_state.level==level?peer_state.preload_seal:0;
    LeaveCriticalSection(&queue_lock);return serial;
}
void lan_publish_input(const SyncInput *input) {
    lock_queue();
    uint32_t pending=local_state.input.pressed;
    local_state.input=*input;
    local_state.input.pressed |= pending;
    LeaveCriticalSection(&queue_lock);
}
SyncInput lan_consume_input(void) {
    lock_queue(); SyncInput value=peer_state.epoch==local_state.epoch ? peer_state.input : (SyncInput){0,0,128,128,128,128};
    peer_state.input.pressed=0;
    LeaveCriticalSection(&queue_lock); return value;
}
int lan_send_frame(const SyncFrame *frame) {
    if (!sync_frame_valid(frame,sync_frame_size(frame))) return 0;
    lock_queue();
    int ok=out_count < SYNC_QUEUE_SIZE;
    if (ok) { sync_frame_copy_valid(&outbound[(out_head+out_count)%SYNC_QUEUE_SIZE],frame); ++out_count; }
    LeaveCriticalSection(&queue_lock); return ok;
}
int lan_receive_frame(SyncFrame *frame) {
    lock_queue();
    while (in_count && inbound[in_head].epoch<local_state.epoch) { in_head=(in_head+1)%SYNC_QUEUE_SIZE; --in_count; }
    int ok=in_count && inbound[in_head].epoch==local_state.epoch;
    if (ok) { sync_frame_copy_valid(frame,&inbound[in_head]); in_head=(in_head+1)%SYNC_QUEUE_SIZE; --in_count; }
    LeaveCriticalSection(&queue_lock); return ok;
}


void lan_publish_profile(const SyncProfile *profile) {
    if (!sync_profile_valid(profile)) return;
    lock_queue(); own_profile=*profile; own_profile_pending=1; LeaveCriticalSection(&queue_lock);
}
int lan_receive_profile(SyncProfile *profile,uint32_t max_sequence) {
    lock_queue();
    if (peer_profile_pending && peer_profile.epoch<local_state.epoch) peer_profile_pending=0;
    int ready=peer_profile_pending && peer_profile.epoch==local_state.epoch && peer_profile.sequence<=max_sequence;
    if (ready) { *profile=peer_profile; peer_profile_pending=0; }
    LeaveCriticalSection(&queue_lock); return ready;
}

void lan_publish_loading(const SyncLoading *loading,int auto_skip) {
    lock_queue(); local_state.loading=*loading; local_state.auto_skip=auto_skip!=0; LeaveCriticalSection(&queue_lock);
}
SyncLoading lan_remote_loading(void) {
    lock_queue(); SyncLoading result=peer_state.loading; LeaveCriticalSection(&queue_lock); return result;
}
int lan_remote_auto_skip(void) {
    lock_queue(); int result=peer_state.auto_skip; LeaveCriticalSection(&queue_lock); return result;
}

static int active(LONG ticket) {
    return ticket && !InterlockedCompareExchange(&generation_exhausted,0,0) && InterlockedCompareExchange(&generation,0,0)==ticket;
}

int lan_set_session_invalidator(LanSessionInvalidator callback,void *user){
    if(!callback)return 0;
    lock_queue();int ok=0;
    if(session_invalidator)ok=session_invalidator==callback&&session_invalidator_user==user;
    else if(!generation&&!generation_exhausted){session_invalidator=callback;session_invalidator_user=user;ok=1;}
    LeaveCriticalSection(&queue_lock);return ok;
}
#ifdef LAN_PUBLICATION_TEST
extern void lan_publication_test_boundary(unsigned,uint32_t);
#define PUBLICATION_BOUNDARY(stage,ticket) lan_publication_test_boundary(stage,(uint32_t)(ticket))
#else
#define PUBLICATION_BOUNDARY(stage,ticket) ((void)0)
#endif
static void publish_session_locked(LONG ticket){PUBLICATION_BOUNDARY(4,ticket);InterlockedExchange(&published_session,ticket);PUBLICATION_BOUNDARY(5,ticket);}
static LONG advance_generation_locked(void) {
    uint32_t old=(uint32_t)generation;
    if(generation_exhausted || old>=UINT32_MAX-1){
        if(!generation_exhausted&&session_invalidator)session_invalidator(0,session_invalidator_user);
        InterlockedExchange(&published_session,0);InterlockedExchange(&generation_exhausted,1);InterlockedExchange(&error_code,ERROR_ARITHMETIC_OVERFLOW);return 0;
    }
    if(session_invalidator)session_invalidator(old+1,session_invalidator_user);
    PUBLICATION_BOUNDARY(1,old+1);InterlockedExchange(&published_session,0);PUBLICATION_BOUNDARY(2,old+1);
    LONG next=(LONG)(old+1);InterlockedExchange(&generation,next);PUBLICATION_BOUNDARY(3,next);return next;
}
uint32_t lan_session_serial(void){return (uint32_t)InterlockedCompareExchange(&published_session,0,0);}
static int session_status(LONG ticket,LONG next,LONG error){
    lock_queue();int ok=active(ticket);
    if(ok){InterlockedExchange(&error_code,error);InterlockedExchange(&status,next);}
    LeaveCriticalSection(&queue_lock);return ok;
}
static int session_peer(LONG ticket,const struct PeerState *value){
    if(value->native_entry>1)return 0;
    lock_queue();int ok=active(ticket);
    if(ok){struct PeerState peer=*value;if(peer.epoch==peer_state.epoch&&peer.epoch==local_state.epoch)peer.input.pressed|=peer_state.input.pressed;peer_state=peer;InterlockedExchange(&remote_level,peer.level);}
    LeaveCriticalSection(&queue_lock);return ok;
}
static int session_inbound(LONG ticket,const SyncFrame *frame){
    lock_queue();int ok=active(ticket)?(in_count<SYNC_QUEUE_SIZE?1:-1):0;
    if(ok==1){sync_frame_copy_valid(&inbound[(in_head+in_count)%SYNC_QUEUE_SIZE],frame);++in_count;}
    LeaveCriticalSection(&queue_lock);return ok;
}

static int session_take_profile(LONG ticket,SyncProfile *value){
    lock_queue();int ok=active(ticket)&&own_profile_pending;
    if(ok){*value=own_profile;own_profile_pending=0;}
    LeaveCriticalSection(&queue_lock);return ok;
}
static int session_take_frame(LONG ticket,SyncFrame *value){
    lock_queue();int ok=active(ticket)&&out_count;
    if(ok){sync_frame_copy_valid(value,&outbound[out_head]);out_head=(out_head+1)%SYNC_QUEUE_SIZE;--out_count;}
    LeaveCriticalSection(&queue_lock);return ok;
}

static int ready(SOCKET socket, int write, LONG ticket, int attempts) {
    while (active(ticket) && attempts-- > 0) {
        fd_set set;
        FD_ZERO(&set);
        FD_SET(socket, &set);
        struct timeval timeout = {0, 200000};
        int result = select(0, write ? NULL : &set, write ? &set : NULL, NULL, &timeout);
        if (result) return result > 0;
    }
    WSASetLastError(WSAETIMEDOUT);
    return 0;
}

static int transfer(SOCKET socket, unsigned char *data, int size, int write, LONG ticket) {
    int position = 0;
    while (position < size && active(ticket)) {
        if (!ready(socket, write, ticket, 25)) return 0;
        int count = write ? send(socket, (char *)data + position, size - position, 0) :
                            recv(socket, (char *)data + position, size - position, 0);
        if (count <= 0) {
            if (!count) WSASetLastError(WSAECONNRESET);
            return 0;
        }
        position += count;
    }
    return position == size;
}

static int send_packet(SOCKET socket, uint32_t kind, void *payload, uint32_t size, LONG ticket) {
    struct Header header={0x334e414c,kind,size};
    return transfer(socket,(unsigned char *)&header,sizeof(header),1,ticket) &&
           transfer(socket,payload,(int)size,1,ticket);
}
static int exchange_packets(SOCKET socket, LONG ticket,int is_host) {
    SyncFrame *frame=HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,sizeof(*frame));
    unsigned char *wire=HeapAlloc(GetProcessHeap(),0,sizeof(*frame));
    SyncProfile *profile=HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,sizeof(*profile));
    if (!frame || !profile || !wire) {
        if (wire) HeapFree(GetProcessHeap(),0,wire);
        if (frame) HeapFree(GetProcessHeap(),0,frame);
        if (profile) HeapFree(GetProcessHeap(),0,profile);
        WSASetLastError(WSAENOBUFS); return 0;
    }
    DWORD sent=GetTickCount()-20, received=GetTickCount();
    uint32_t sent_epoch=0, sent_ack=0;
    int success=1;
    while (active(ticket)) {
        if (GetTickCount()-received > 10000) { WSASetLastError(WSAETIMEDOUT); success=0; break; }
        struct PeerState own;
        /* The host can be waiting for an ACK even between state heartbeats. */
        int publish = publication_snapshot(ticket, &own, GetTickCount()-sent >= 20,
                                           sent_epoch, sent_ack);
        if (publish < 0) break;
        if (publish) {
            if (!send_packet(socket,1,&own,sizeof(own),ticket)) { success=0; break; }
            sent=GetTickCount();
            sent_epoch=own.epoch;
            sent_ack=own.ack;
        }
        int profile_pending=session_take_profile(ticket,profile);
        if (profile_pending && !send_packet(socket,3,profile,sizeof(*profile),ticket)) { success=0; break; }
        int pending=session_take_frame(ticket,frame);
        if (pending) {
            uint32_t bytes=sync_frame_encode(frame,wire,sizeof(*frame));
            if (!bytes) { WSASetLastError(WSAEINVAL); success=0; break; }
            if (!send_packet(socket,2,wire,bytes,ticket)) { success=0; break; }
        }
        fd_set set; FD_ZERO(&set); FD_SET(socket,&set);
        struct timeval timeout={0,1000};
        int available=select(0,&set,NULL,NULL,&timeout);
        if (available < 0) { success=0; break; }
        if (!available) continue;
        struct Header header;
        if (!transfer(socket,(unsigned char *)&header,sizeof(header),0,ticket)) { success=0; break; }
        if (header.magic != 0x334e414c ||
            (header.kind != 1 && header.kind != 2 && header.kind != 3) ||
            (header.kind == 1 && header.size != sizeof(struct PeerState)) ||
            (header.kind == 3 && header.size != sizeof(*profile)) ||
            (header.kind == 2 && (header.size < offsetof(SyncFrame,actors) || header.size > sizeof(*frame)))) {
            WSASetLastError(WSAEPROTONOSUPPORT); success=0; break;
        }
        if (header.kind == 1) {
            struct PeerState peer;
            if (!transfer(socket,(unsigned char *)&peer,sizeof(peer),0,ticket)) { success=0; break; }
            if (peer.level < -1 || peer.level >= 4096 || peer.native_entry>1 || (peer.ready != 0 && peer.ready != 1) ||
                peer.loading.level < -1 || peer.loading.level >= 4096 || peer.loading.ready>1 ||
                peer.loading.skip>1 || peer.loading.active>1 || peer.auto_skip>1 ||
                !isfinite(peer.loading.elapsed) || peer.loading.elapsed<0 || peer.loading.elapsed>86400 ||
                !preload_input_valid(&peer.preload) || !preload_receipt_valid(&peer.preload_receipt) || !preload_world_ready_valid(&peer.world_ready) ||
                (peer.world_ready.epoch && (peer.world_ready.epoch!=peer.epoch || peer.world_ready.level!=peer.level)) ||
                (peer.preload_seal && peer.preload_seal!=peer.preload_receipt.serial) ||
                (peer.preload.epoch && (peer.preload.epoch!=peer.epoch || peer.preload.level!=peer.level))) {
                WSASetLastError(WSAEINVAL); success=0; break;
            }
            if(!session_peer(ticket,&peer))break;
        } else if (header.kind==3) {
            if (!transfer(socket,(unsigned char *)profile,header.size,0,ticket)) { success=0; break; }
            if (is_host || !sync_profile_valid(profile)) { WSASetLastError(WSAEINVAL); success=0; break; }
            lock_queue();
            if (active(ticket)) { peer_profile=*profile; peer_profile_pending=1; }
            LeaveCriticalSection(&queue_lock);
        } else {
            if (!transfer(socket,wire,header.size,0,ticket)) { success=0; break; }
            if (is_host || !sync_frame_decode(frame,wire,header.size)) { WSASetLastError(WSAEINVAL); success=0; break; }
            int accepted=session_inbound(ticket,frame);
            if(!accepted)break;
            if(accepted<0){WSASetLastError(WSAENOBUFS);success=0;break;}
        }
        received=GetTickCount();
    }
    int error=WSAGetLastError();
    HeapFree(GetProcessHeap(),0,frame); HeapFree(GetProcessHeap(),0,profile); HeapFree(GetProcessHeap(),0,wire);
    WSASetLastError(error);
    return success;
}

/* The previous worker closes its listener before a replacement binds. Main never waits here. */
static int worker_enter(LONG ticket){
    while(active(ticket)){
        if(TryEnterCriticalSection(&session_worker_lock)){
            if(active(ticket))return 1;
            LeaveCriticalSection(&session_worker_lock);return 0;
        }
        Sleep(10);
    }
    return 0;
}
static DWORD WINAPI run_session(void *parameter) {
    struct Request request = *(struct Request *)parameter;
    HeapFree(GetProcessHeap(),0,parameter);
    if(!worker_enter(request.generation))return 0;
    WSADATA data;
    int failure = WSAStartup(MAKEWORD(2,2), &data);
    SOCKET listener = INVALID_SOCKET;
    SOCKET connection = INVALID_SOCKET;
    if (failure) goto done;
    struct sockaddr_in endpoint;
    memset(&endpoint, 0, sizeof(endpoint));
    endpoint.sin_family = AF_INET;
    endpoint.sin_port = htons(CLONEWARS_LAN_PORT);
    if (request.host) {
        endpoint.sin_addr.s_addr = htonl(INADDR_ANY);
        listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (listener == INVALID_SOCKET || bind(listener, (struct sockaddr *)&endpoint, sizeof(endpoint)) ||
            listen(listener, 1)) goto socket_failure;
        while (active(request.generation)) {
            if (!ready(listener, 0, request.generation, 1)) continue;
            connection = accept(listener, NULL, NULL);
            break;
        }
        if (!active(request.generation)) goto close_session;
    } else {
        if (InetPtonA(AF_INET, request.address, &endpoint.sin_addr) != 1) {
            failure = WSAEINVAL;
            goto close_session;
        }
        connection = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (connection == INVALID_SOCKET) goto socket_failure;
        u_long nonblocking = 1;
        ioctlsocket(connection, FIONBIO, &nonblocking);
        if (connect(connection, (struct sockaddr *)&endpoint, sizeof(endpoint)) &&
            WSAGetLastError() != WSAEWOULDBLOCK) goto socket_failure;
        if (!ready(connection, 1, request.generation, 25)) goto socket_failure;
        int length = sizeof(failure);
        getsockopt(connection, SOL_SOCKET, SO_ERROR, (char *)&failure, &length);
        if (failure) goto close_session;
        nonblocking = 0;
        ioctlsocket(connection, FIONBIO, &nonblocking);
    }
    if (connection == INVALID_SOCKET) goto socket_failure;
    DWORD send_timeout=5000;
    if(setsockopt(connection,SOL_SOCKET,SO_SNDTIMEO,(const char*)&send_timeout,sizeof(send_timeout)))goto socket_failure;
    BOOL no_delay = TRUE;
    setsockopt(connection,IPPROTO_TCP,TCP_NODELAY,(const char *)&no_delay,sizeof(no_delay));
    unsigned char peer[sizeof(hello)];
    unsigned char own[sizeof(hello)];
    memcpy(own, hello, sizeof(hello));
    if (!transfer(connection, own, sizeof(own), 1, request.generation) ||
        !transfer(connection, peer, sizeof(peer), 0, request.generation)) goto socket_failure;
    if (memcmp(peer, hello, sizeof(peer))) {
        failure = WSAEPROTONOSUPPORT;
        goto close_session;
    }
    if(!session_status(request.generation,LAN_CONNECTED,0))goto close_session;
    if (!exchange_packets(connection, request.generation,request.host)) goto socket_failure;
    goto close_session;
socket_failure:
    failure = WSAGetLastError();
close_session:
    if (connection != INVALID_SOCKET) closesocket(connection);
    if (listener != INVALID_SOCKET) closesocket(listener);
    WSACleanup();
done:
    session_status(request.generation,failure?LAN_FAILED:LAN_OFF,failure);
    LeaveCriticalSection(&session_worker_lock);
    return 0;
}

void lan_start(int host, const char *address) {
    lock_queue();LONG ticket=advance_generation_locked();
    if(!ticket){InterlockedExchange(&status,LAN_FAILED);LeaveCriticalSection(&queue_lock);return;}
    out_head=out_count=in_head=in_count=0;
    memset(&local_state,0,sizeof(local_state)); memset(&peer_state,0,sizeof(peer_state));
    local_state.preload.level=peer_state.preload.level=-1;
    local_state.world_ready.level=peer_state.world_ready.level=-1;
    own_profile_pending=peer_profile_pending=0;
    local_state.level=peer_state.level=-1;
    local_state.loading.level=peer_state.loading.level=-1;
    local_state.input.analog_x=local_state.input.analog_y=local_state.input.aim_x=local_state.input.aim_y=128;
    peer_state.input.analog_x=peer_state.input.analog_y=peer_state.input.aim_x=peer_state.input.aim_y=128;
    InterlockedExchange(&host_role,host != 0);
    InterlockedExchange(&local_level,-1);
    InterlockedExchange(&remote_level,-1);
    InterlockedExchange(&error_code, 0);
    InterlockedExchange(&status,host?LAN_LISTENING:LAN_CONNECTING);
    publish_session_locked(ticket);LeaveCriticalSection(&queue_lock);
    struct Request *request = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*request));
    if (!request) {
        session_status(ticket,LAN_FAILED,ERROR_NOT_ENOUGH_MEMORY);
        return;
    }
    request->host = host;
    request->generation = ticket;
    strncpy(request->address, address, sizeof(request->address) - 1);
    HANDLE worker = CreateThread(NULL, 0, run_session, request, 0, NULL);
    if (worker) CloseHandle(worker);
    else {
        DWORD failure=GetLastError();HeapFree(GetProcessHeap(),0,request);
        session_status(ticket,LAN_FAILED,failure);
    }
}

void lan_stop(void) {
    lock_queue();LONG ticket=advance_generation_locked();
    InterlockedExchange(&status,LAN_OFF);InterlockedExchange(&remote_level,-1);
    out_head=out_count=in_head=in_count=0;own_profile_pending=peer_profile_pending=0;
    if(ticket)publish_session_locked(ticket);LeaveCriticalSection(&queue_lock);
}

long lan_status(void) { return InterlockedCompareExchange(&status, 0, 0); }
long lan_error(void) { return InterlockedCompareExchange(&error_code, 0, 0); }
int lan_is_host(void) { return InterlockedCompareExchange(&host_role,0,0) != 0; }
void lan_publish_level(int level) {
    if(level>=-1&&level<4096){lock_queue();if(local_state.level!=level)reset_preload_locked();local_state.level=level;InterlockedExchange(&local_level,level);LeaveCriticalSection(&queue_lock);}
}
int lan_remote_level(void) { return InterlockedCompareExchange(&remote_level,0,0); }
