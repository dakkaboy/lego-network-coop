#pragma once
#include <stdint.h>
#include <math.h>
typedef struct GlobalStepState { uint32_t worlds,ticks; int input_taken; } GlobalStepState;
static inline void global_step_run(GlobalStepState *step,void (*native)(void *,void *),void *dispatcher,void *packet) {
    *step=(GlobalStepState){0};
    native(dispatcher,packet);
}
static inline int global_step_world(GlobalStepState *step) {
    ++step->worlds;
    int first=!step->input_taken;
    step->input_taken=1;
    return first;
}
static inline int global_step_matches(const GlobalStepState *step,uint32_t worlds,uint32_t ticks) {
    return step->worlds==worlds && step->ticks==ticks;
}

static inline int global_step_packet_valid(uint32_t vtable,uint32_t zero,float delta) {
    return vtable==0xc37cfc && !zero && isfinite(delta) && delta>=0 && delta<=.1f;
}
