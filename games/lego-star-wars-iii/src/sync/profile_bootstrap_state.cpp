#include "profile_bootstrap_state.h"
#include <cstring>

namespace {
bool same_context(const ProfileBootstrapContext &a, const ProfileBootstrapContext &b) {
    return a.session == b.session && a.epoch == b.epoch && a.level == b.level;
}
uint32_t checksum(const void *data, size_t size) {
    const auto *bytes = static_cast<const uint8_t *>(data);
    uint32_t result = 2166136261u;
    for (size_t i = 0; i < size; ++i) result = (result ^ bytes[i]) * 16777619u;
    return result;
}
bool native_data_valid(const void *data, size_t size) {
    if (!data || size != SYNC_PROFILE_BYTES) return false;
    uint32_t version;
    std::memcpy(&version, data, sizeof version);
    return version == 0x500;
}
bool bound(const ProfileBootstrapContext &bound_context, const ProfileBootstrapContext *context) {
    return profile_bootstrap_context_valid(context) &&
        profile_bootstrap_context_valid(&bound_context) && same_context(bound_context, *context);
}
}

int profile_bootstrap_context_valid(const ProfileBootstrapContext *context) {
    return context && context->session && context->session != UINT32_MAX && context->epoch &&
        context->level >= 0 && context->level < 4096;
}
int profile_bootstrap_profile_valid(const SyncProfile *profile, const ProfileBootstrapContext *context) {
    return profile && profile_bootstrap_context_valid(context) && profile->epoch == context->epoch &&
        profile->level == context->level && native_data_valid(profile->data, sizeof profile->data) &&
        profile->checksum == checksum(profile->data, sizeof profile->data);
}
void profile_bootstrap_host_reset(ProfileBootstrapHostState *state) {
    if (state) std::memset(state, 0, sizeof *state);
}
int profile_bootstrap_host_bind(ProfileBootstrapHostState *state, const ProfileBootstrapContext *context) {
    if (!state || !profile_bootstrap_context_valid(context)) return 0;
    if (same_context(state->context, *context)) return 1;
    const auto next = *context;
    profile_bootstrap_host_reset(state);
    state->context = next;
    return 1;
}
int profile_bootstrap_host_capture(ProfileBootstrapHostState *state, const ProfileBootstrapContext *context,
    const void *data, size_t size, uint32_t sequence) {
    if (!state || !bound(state->context, context) || !native_data_valid(data, size)) return 0;
    if (state->captured) {
        return state->captured == 1 && profile_bootstrap_profile_valid(&state->initial, context) &&
            state->initial.sequence == sequence && !std::memcmp(state->initial.data, data, size);
    }
    SyncProfile candidate{};
    candidate.epoch = context->epoch;
    candidate.sequence = sequence;
    candidate.level = context->level;
    std::memcpy(candidate.data, data, size);
    candidate.checksum = checksum(candidate.data, size);
    state->initial = candidate;
    state->captured = 1;
    return 1;
}
const SyncProfile *profile_bootstrap_host_initial(const ProfileBootstrapHostState *state,
    const ProfileBootstrapContext *context) {
    if (!state || state->captured != 1 || !bound(state->context, context) ||
        !profile_bootstrap_profile_valid(&state->initial, context)) return nullptr;
    return &state->initial;
}
void profile_bootstrap_client_reset(ProfileBootstrapClientState *state) {
    if (state) std::memset(state, 0, sizeof *state);
}
int profile_bootstrap_client_bind(ProfileBootstrapClientState *state, const ProfileBootstrapContext *context) {
    if (!state || !profile_bootstrap_context_valid(context)) return 0;
    if (same_context(state->context, *context)) return 1;
    const auto next = *context;
    profile_bootstrap_client_reset(state);
    state->context = next;
    return 1;
}
int profile_bootstrap_client_should_apply(const ProfileBootstrapClientState *state,
    const ProfileBootstrapContext *context, int sealed) {
    return state && bound(state->context, context) && state->applied <= 1 &&
        (sealed || !state->applied);
}
int profile_bootstrap_client_is_applied(const ProfileBootstrapClientState *state,
    const ProfileBootstrapContext *context) {
    return state && bound(state->context, context) && state->applied == 1;
}
int profile_bootstrap_client_accepts_packet(const ProfileBootstrapClientState *state,
    const ProfileBootstrapContext *context, const SyncProfile *profile, int sealed) {
    if (!state || !bound(state->context, context) || state->applied > 1 ||
        !profile_bootstrap_profile_valid(profile, context)) return 0;
    return !state->applied ? profile->sequence == 0 : sealed && profile->sequence > 0;
}
int profile_bootstrap_client_mark_applied(ProfileBootstrapClientState *state,
    const ProfileBootstrapContext *context) {
    if (!state || !bound(state->context, context) || state->applied > 1) return 0;
    state->applied = 1;
    return 1;
}
