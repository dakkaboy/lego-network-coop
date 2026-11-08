#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

enum { NATIVE_SCRIPT_SHOOT_MAX_ARGUMENTS=256, NATIVE_SCRIPT_SHOOT_MAX_STRING=4096 };
typedef struct NativeScriptShootInput {
    uint32_t clock,model_class,brain_class,state_class,brain_admission,state_flags;
    uint32_t argument_count,initialize,caller_rva,argument_hash[4],reserved;
} NativeScriptShootInput;
typedef struct NativeScriptShootSource {
    void *world,*definition,*actor,*model,*brain,*state,*wrapper,*arguments,*command;
    uintptr_t native_frame,actor_pool;
    uint32_t actor_count,actor_ordinal,brain_admission_raw,frame_words[8];
    NativeScriptShootInput input;
} NativeScriptShootSource;
int native_script_shoot_source_resolve(void *actor,void *state,void *model,
    uintptr_t native_frame,NativeScriptShootSource *out);
int native_script_shoot_source_revalidate(const NativeScriptShootSource *source);
typedef struct NativeScriptShootDispatchSource {
    NativeScriptShootInput input;
    void *world,*definition,*actor,*model,*brain,*state,*wrapper,*arguments,*command;
    void *descriptor,*handler;
    uintptr_t native_stack,actor_pool;
    uint32_t actor_count,actor_ordinal,brain_admission_raw,state_flags_raw;
    uint32_t stack_words[8];
} NativeScriptShootDispatchSource;
int native_script_shoot_dispatch_source_resolve(void *descriptor,uintptr_t native_stack,
    NativeScriptShootDispatchSource *out);
int native_script_shoot_dispatch_initial_admission(uintptr_t native_stack);
int native_script_shoot_dispatch_source_revalidate(const NativeScriptShootDispatchSource *source);
int native_script_shoot_dispatch_frame_matches(const NativeScriptShootDispatchSource *source,
    void *actor,void *state,void *model,uintptr_t native_frame);
#ifdef __cplusplus
}
#endif
