#pragma once

#include "../net/sync_wire.h"
#include "coherent_frame_fence.h"

#ifdef __cplusplus
extern "C" {
#endif

int spawn_timers_prepare(const CoherentFrameToken *token, SyncFrame *frame, int host);
int rts_spawn_timers_install(void);
int rts_spawn_timers_finish(const SyncFrame *frame);

#ifdef __cplusplus
}
#endif
