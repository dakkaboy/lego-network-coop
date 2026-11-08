#pragma once
#include <stddef.h>
#include <stdint.h>
#include "../net/sync_wire.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ProfileBootstrapContext {
    uint32_t session;
    uint32_t epoch;
    int32_t level;
} ProfileBootstrapContext;

typedef struct ProfileBootstrapHostState {
    ProfileBootstrapContext context;
    uint32_t captured;
    SyncProfile initial;
} ProfileBootstrapHostState;

typedef struct ProfileBootstrapClientState {
    ProfileBootstrapContext context;
    uint32_t applied;
} ProfileBootstrapClientState;

int profile_bootstrap_context_valid(const ProfileBootstrapContext *context);
int profile_bootstrap_profile_valid(const SyncProfile *profile, const ProfileBootstrapContext *context);
void profile_bootstrap_host_reset(ProfileBootstrapHostState *state);
int profile_bootstrap_host_bind(ProfileBootstrapHostState *state, const ProfileBootstrapContext *context);
/* A captured transaction accepts only an identical retry, including its original sequence. */
int profile_bootstrap_host_capture(ProfileBootstrapHostState *state, const ProfileBootstrapContext *context,
    const void *data, size_t size, uint32_t sequence);
const SyncProfile *profile_bootstrap_host_initial(const ProfileBootstrapHostState *state,
    const ProfileBootstrapContext *context);
void profile_bootstrap_client_reset(ProfileBootstrapClientState *state);
int profile_bootstrap_client_bind(ProfileBootstrapClientState *state, const ProfileBootstrapContext *context);
/* This decision does not commit a copy: the caller marks completion after its callback succeeds. */
int profile_bootstrap_client_should_apply(const ProfileBootstrapClientState *state,
    const ProfileBootstrapContext *context, int sealed);
int profile_bootstrap_client_is_applied(const ProfileBootstrapClientState *state,
    const ProfileBootstrapContext *context);
int profile_bootstrap_client_accepts_packet(const ProfileBootstrapClientState *state,
    const ProfileBootstrapContext *context, const SyncProfile *profile, int sealed);
int profile_bootstrap_client_mark_applied(ProfileBootstrapClientState *state,
    const ProfileBootstrapContext *context);

#ifdef __cplusplus
}
#endif
