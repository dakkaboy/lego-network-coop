#pragma once
#include "../net/sync_wire.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct InputBuffer {
    SyncInput latest;
    uint32_t pending;
} InputBuffer;

void input_buffer_reset(InputBuffer *buffer);
void input_buffer_sample(InputBuffer *buffer,const SyncInput *input);
SyncInput input_buffer_take(InputBuffer *buffer);

typedef struct RemoteInputPulse { uint32_t next_hold; } RemoteInputPulse;
void remote_input_pulse_reset(RemoteInputPulse *pulse);
SyncInput remote_input_execute(RemoteInputPulse *pulse,const SyncInput *incoming);

#ifdef __cplusplus
}
#endif
