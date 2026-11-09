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
uint32_t native_tick_clock_input(const uint32_t witness[2],uint32_t sample);
static inline int native_track_time_valid(uint32_t sample) {
    return (sample&0x7fffffffu)<0x7f800000u;
}
static inline int native_tick_gate_valid(const SyncTickGate *gate) {
    return gate && ((gate->site==0x8888cd && gate->value<=UINT8_MAX) ||
        (gate->site==0x888889 && gate->value<=1) ||
        (gate->site==0x889edc && (gate->value==UINT32_MAX || gate->value<=0x14)) ||
        (gate->site==0x9dda14 && (gate->value==1 || (!(gate->value&1) && gate->value/2<=SYNC_MAX_ACTORS))) ||
        gate->site==0x7b8ae1 || gate->site==0x7b8afd ||
        (gate->site==0x7b8b08 && native_track_time_valid(gate->value)));
}
static inline int native_tick_stream_valid(const SyncTickGate *gates,uint32_t count) {
    if (count>SYNC_MAX_TICK_GATES || (count && !gates)) return 0;
    for (uint32_t i=0;i<count;++i) {
        if (!native_tick_gate_valid(gates+i)) return 0;
        if (gates[i].site==0x7b8ae1) {
            if (count-i<3 || gates[i+1].site!=0x7b8afd || gates[i+2].site!=0x7b8b08 ||
                gates[i].clock!=gates[i+1].clock || gates[i].clock!=gates[i+2].clock ||
                !native_tick_gate_valid(gates+i+2)) return 0;
            i+=2;
        } else if (gates[i].site==0x7b8afd || gates[i].site==0x7b8b08) return 0;
    }
    return 1;
}
#ifdef __cplusplus
}
#endif
