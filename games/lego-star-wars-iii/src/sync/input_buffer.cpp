#include "input_buffer.h"
#include "net/input_edges.h"

void input_buffer_reset(InputBuffer *buffer) {
    *buffer=InputBuffer{{0,0,128,128,128,128},0};
}
void input_buffer_sample(InputBuffer *buffer,const SyncInput *input) {
    buffer->latest=*input;
    lego::net::latch_pressed(buffer->pending,input->pressed);
}
SyncInput input_buffer_take(InputBuffer *buffer) {
    SyncInput input=buffer->latest;
    input.pressed=lego::net::take_pressed(buffer->pending);
    return input;
}

void remote_input_pulse_reset(RemoteInputPulse *pulse) { pulse->next_hold=0; }
SyncInput remote_input_execute(RemoteInputPulse *pulse,const SyncInput *incoming) {
    SyncInput executed=*incoming;
    executed.held=lego::net::replay_held(incoming->held,incoming->pressed,pulse->next_hold);
    return executed;
}
