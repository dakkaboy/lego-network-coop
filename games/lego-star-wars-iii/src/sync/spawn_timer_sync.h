#pragma once

#include "../net/sync_wire.h"
#include "coherent_frame_fence.h"

#ifdef __cplusplus
extern "C" {
#endif

int spawn_timers_prepare(const CoherentFrameToken *token, SyncFrame *frame, int host);

#ifdef __cplusplus
}
#endif
