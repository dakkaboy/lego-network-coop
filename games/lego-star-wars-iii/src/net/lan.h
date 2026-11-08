#pragma once
#include "sync_wire.h"
enum { LAN_OFF, LAN_LISTENING, LAN_CONNECTING, LAN_CONNECTED, LAN_FAILED };
void lan_start(int host, const char *address);
void lan_stop(void);
long lan_status(void);
long lan_error(void);
int lan_is_host(void);
void lan_publish_level(int level);
int lan_remote_level(void);
void lan_publish_ready(int actors);
int lan_peer_ready(void);
int lan_publish_world_ready(const SyncWorldReady *ready);
int lan_remote_world_ready(uint32_t epoch,int level,SyncWorldReady *ready);
void lan_invalidate_world_ready(void);
int lan_publish_preload(const SyncPreloadInput *input);
int lan_receive_preload(uint32_t epoch,int level,SyncPreloadInput *input);
int lan_publish_preload_receipt(uint32_t epoch,int level,const SyncPreloadReceipt *receipt);
int lan_remote_preload_receipt(uint32_t epoch,int level,SyncPreloadReceipt *receipt);
int lan_publish_preload_seal(uint32_t epoch,int level,uint32_t serial);
uint32_t lan_remote_preload_seal(uint32_t epoch,int level);
void lan_publish_input(const SyncInput *input);
SyncInput lan_consume_input(void);
int lan_send_frame(const SyncFrame *frame);
int lan_receive_frame(SyncFrame *frame);
void lan_clear_frames(void);
void lan_publish_epoch(uint32_t epoch);
void lan_publish_transition(uint32_t epoch,int level,uint32_t native_entry);
uint32_t lan_epoch(void);
uint32_t lan_remote_epoch(void);
typedef struct { uint32_t epoch;int level;uint32_t native_entry; } LanTransition;
LanTransition lan_remote_transition(void);
void lan_publish_profile(const SyncProfile *profile);
int lan_receive_profile(SyncProfile *profile,uint32_t max_sequence);
void lan_publish_loading(const SyncLoading *loading,int auto_skip);
SyncLoading lan_remote_loading(void);
int lan_remote_auto_skip(void);

void lan_publish_ack(uint32_t sequence);
uint32_t lan_peer_ack(void);

uint32_t lan_session_serial(void);

typedef void (*LanSessionInvalidator)(uint32_t,void *);
int lan_set_session_invalidator(LanSessionInvalidator,void *);
