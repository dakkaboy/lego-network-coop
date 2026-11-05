#pragma once
#include "../net/sync_wire.h"
#include "coherent_frame_fence.h"
int world_vars_bind_cohort(const CoherentFrameToken *token);
int world_vars_cohort_valid(const CoherentFrameToken *token,uint32_t phases);
int world_vars_abort_cohort(const CoherentFrameToken *token);
int world_vars_collect(SyncFrame *frame);
int world_vars_apply(const SyncFrame *frame);
