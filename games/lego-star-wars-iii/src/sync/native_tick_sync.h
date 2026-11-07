#pragma once
#include "../net/sync_wire.h"
#include "coherent_frame_fence.h"
#ifdef __cplusplus
extern "C" {
#endif
int native_tick_install(void);
int native_tick_begin(SyncFrame *,int,const CoherentFrameToken *);
int native_tick_finish(void);
void native_tick_cancel(const CoherentFrameToken *);
static inline int native_tick_gate_valid(const SyncTickGate *gate) {
    return gate && (gate->site==0x8888cd || gate->site==0x8889ea) && gate->value<=UINT8_MAX;
}
#ifdef __cplusplus
}
#endif
