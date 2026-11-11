#include "preload_state.h"
#include <cmath>
#include <cstring>

static bool preload_bound(const NativePreloadState *state) {
    return state && state->session && state->epoch && state->level>=0 && state->level<4096 && state->world;
}

int preload_phase_active(uint32_t phase,int initialized) {
    return phase==0xd || phase==0xe || (initialized && (phase==0xa || phase==0xb));
}
int preload_stage_eligible(uint32_t phase,int level,int pending,int targeted,int initialized) {
    return level>=0 && level<4096 && targeted && pending<0 && preload_phase_active(phase,initialized);
}
int preload_input_valid(const SyncPreloadInput *input) {
    if (!input) return 0;
    const auto &v=*input;
    if (!v.epoch) {
        const SyncPreloadInput empty{.level=-1};
        return std::memcmp(&v,&empty,sizeof(v))==0;
    }
    return v.level>=0 && v.level<4096 && v.serial && preload_phase_active(v.root_phase,1) &&
        std::isfinite(v.delta) && v.delta>=0 && v.delta<=.1f &&
        std::isfinite(v.engine_delta) && v.engine_delta>=0 && v.engine_delta<=.1f && v.engine_mode<=16 && std::isfinite(v.game_time);
}
int preload_receipt_valid(const SyncPreloadReceipt *receipt) {
    if (!receipt) return 0;
    if (receipt->flow_count>SYNC_MAX_PRELOAD_FLOW_REQUESTS || receipt->track_count>SYNC_MAX_PRELOAD_FLOW_REQUESTS || receipt->world_calls>64 || receipt->end_phase>20) return 0;
    if (!receipt->serial && (receipt->world_calls || receipt->end_phase || receipt->flow_count || receipt->track_count)) return 0;
    for (unsigned i=0;i<SYNC_MAX_PRELOAD_FLOW_REQUESTS;++i) {
        const auto request=receipt->flow_requests[i];
        if (i<receipt->flow_count ? (request!=UINT32_MAX && request>20) : request!=0) return 0;
        const auto &track=receipt->tracks[i];
        float time;std::memcpy(&time,&track.time,4);
        if (i<receipt->track_count ? !std::isfinite(time) : (track.time || track.witness[0] || track.witness[1])) return 0;
    }
    return 1;
}
int preload_flow_request_read(const SyncPreloadReceipt *receipt,uint32_t serial,uint32_t ordinal,uint32_t *request) {
    if (!request || !serial || ordinal>=SYNC_MAX_PRELOAD_FLOW_REQUESTS || !preload_receipt_valid(receipt)) return -1;
    if (receipt->serial<serial) return 0;
    if (receipt->serial!=serial || ordinal>=receipt->flow_count) return -1;
    *request=receipt->flow_requests[ordinal];return 1;
}
int preload_track_read(const SyncPreloadReceipt *receipt,uint32_t serial,uint32_t ordinal,const uint32_t witness[2],uint32_t *time) {
    if (!witness || !time || !serial || ordinal>=SYNC_MAX_PRELOAD_FLOW_REQUESTS || !preload_receipt_valid(receipt)) return -1;
    if (receipt->serial<serial) return 0;
    if (receipt->serial!=serial || ordinal>=receipt->track_count) return -1;
    const auto &track=receipt->tracks[ordinal];
    if (std::memcmp(track.witness,witness,sizeof(track.witness))) return -1;
    *time=track.time;return 1;
}
int preload_world_ready_valid(const SyncWorldReady *ready) {
    if (!ready) return 0;
    if (!ready->epoch) return ready->level==-1 && !ready->root_phase && !ready->completed_serial &&
        !ready->collider_count && !ready->collider_roster;
    return ready->level>=0 && ready->level<4096 && ready->collider_count<=SYNC_MAX_ACTORS &&
        (ready->collider_count || !ready->collider_roster) &&
        preload_phase_active(ready->root_phase,ready->completed_serial!=0);
}
int preload_world_roster_matches(const SyncWorldReady *local,const SyncWorldReady *peer) {
    return preload_world_ready_matches(local,peer) && local->collider_count==peer->collider_count &&
        local->collider_roster==peer->collider_roster;
}
int preload_world_ready_matches(const SyncWorldReady *local,const SyncWorldReady *peer) {
    return preload_world_ready_valid(local) && preload_world_ready_valid(peer) && local->epoch &&
        local->epoch==peer->epoch && local->level==peer->level && local->root_phase==peer->root_phase &&
        local->completed_serial==peer->completed_serial;
}
int preload_state_peer_receipt(const NativePreloadState *state,const SyncPreloadReceipt *peer) {
    if (!preload_bound(state) || !state->input.serial || !preload_receipt_valid(peer)) return -1;
    if (peer->serial<state->applied.serial) return 0;
    if (peer->serial!=state->input.serial || state->applied.serial!=peer->serial ||
        std::memcmp(peer,&state->applied,sizeof(*peer))) return -1;
    return 1;
}
int preload_initial_seal_ready(const NativePreloadState *state,uint32_t phase) {
    // Phase 0xD still constructs mission entities after the asset loader is idle.
    // Keep those native initialization ticks coordinated until playable phase 0xE.
    return preload_bound(state) && !state->sealed_serial && state->completed &&
        phase==0xe && preload_input_valid(&state->input) &&
        state->input.epoch==state->epoch && state->input.level==state->level && state->input.root_phase==phase &&
        state->input.serial && state->applied.serial==state->input.serial &&
        preload_receipt_valid(&state->applied) && state->applied.world_calls && state->applied.end_phase==phase;
}
void preload_state_bind(NativePreloadState *state,uint32_t session,uint32_t epoch,int level,uintptr_t world) {
    if (!state) return;
    if (state->session==session && state->epoch==epoch && state->level==level && state->world==world) return;
    *state=NativePreloadState{.session=session,.epoch=epoch,.level=level,.world=world,.input={.level=-1}};
}
int preload_state_accept(NativePreloadState *state,const SyncPreloadInput *source) {
    if (!preload_bound(state) || state->sealed_serial || !preload_input_valid(source) || !source->epoch ||
        source->epoch!=state->epoch || source->level!=state->level) return 0;
    const auto &input=state->input;
    if (input.epoch) {
        if (source->serial==input.serial) return std::memcmp(&input,source,sizeof(input))==0;
        if (input.serial==UINT32_MAX || source->serial!=input.serial+1 ||
            state->applied.serial!=input.serial || !preload_receipt_valid(&state->applied)) return 0;
    } else if (source->serial!=1 || state->applied.serial) return 0;
    state->input=*source;return 1;
}
int preload_state_finish(NativePreloadState *state,const SyncPreloadReceipt *receipt) {
    if (!preload_bound(state) || !preload_receipt_valid(receipt) || !receipt->serial ||
        !preload_input_valid(&state->input) || state->input.epoch!=state->epoch ||
        state->input.level!=state->level || receipt->serial!=state->input.serial) return 0;
    if (state->applied.serial==receipt->serial)
        return std::memcmp(&state->applied,receipt,sizeof(*receipt))==0;
    if (state->sealed_serial || state->applied.serial==UINT32_MAX ||
        receipt->serial!=state->applied.serial+1) return 0;
    state->applied=*receipt;
    if (receipt->world_calls) state->completed=1;
    return 1;
}
int preload_state_seal(NativePreloadState *state,uint32_t serial) {
    if (!preload_bound(state) || !serial || !state->completed ||
        state->input.serial!=serial || state->applied.serial!=serial ||
        !preload_receipt_valid(&state->applied)) return 0;
    if (state->sealed_serial) return state->sealed_serial==serial;
    state->sealed_serial=serial;return 1;
}
