#pragma once
#include <stdint.h>
#include "../net/sync_wire.h"
#ifdef __cplusplus
extern "C" {
#endif
typedef struct NativePreloadState {
    uint32_t session,epoch;
    int level;
    uintptr_t world;
    SyncPreloadInput input;
    SyncPreloadReceipt applied;
    int completed;
    uint32_t sealed_serial;
} NativePreloadState;
int preload_input_valid(const SyncPreloadInput *input);
int preload_phase_active(uint32_t phase,int initialized);
int preload_stage_eligible(uint32_t phase,int level,int pending,int targeted,int initialized);
int preload_receipt_valid(const SyncPreloadReceipt *receipt);
int preload_flow_request_read(const SyncPreloadReceipt *receipt,uint32_t serial,uint32_t ordinal,uint32_t *request);
int preload_track_read(const SyncPreloadReceipt *receipt,uint32_t serial,uint32_t ordinal,const uint32_t witness[2],uint32_t *time);
int preload_world_ready_valid(const SyncWorldReady *ready);
int preload_world_ready_matches(const SyncWorldReady *local,const SyncWorldReady *peer);
int preload_world_roster_matches(const SyncWorldReady *local,const SyncWorldReady *peer);
int preload_state_peer_receipt(const NativePreloadState *state,const SyncPreloadReceipt *peer);
int preload_initial_seal_ready(const NativePreloadState *state,uint32_t phase);
static inline int native_jobs_idle(uint32_t queued_before,uintptr_t active_before,uint32_t queued_after,uintptr_t active_after) {
    return !queued_before && !active_before && !queued_after && !active_after;
}
void preload_state_bind(NativePreloadState *state,uint32_t session,uint32_t epoch,int level,uintptr_t world);
int preload_state_accept(NativePreloadState *state,const SyncPreloadInput *input);
int preload_state_finish(NativePreloadState *state,const SyncPreloadReceipt *receipt);
int preload_state_seal(NativePreloadState *state,uint32_t serial);
#ifdef __cplusplus
}
#endif
