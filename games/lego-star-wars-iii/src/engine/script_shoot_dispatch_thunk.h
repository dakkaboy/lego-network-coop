#pragma once
#include "native_script_shoot_source.h"
#ifdef __cplusplus
extern "C" {
#endif
typedef struct NativeScriptShootDispatchBinding { uintptr_t words[32]; } NativeScriptShootDispatchBinding;
int cadence_script_shoot_dispatch_active(void);
int cadence_script_shoot_dispatch_begin(const NativeScriptShootDispatchSource *source,
    uint32_t local_value,uint32_t *canonical,NativeScriptShootDispatchBinding *binding);
int cadence_script_shoot_dispatch_validate(const NativeScriptShootDispatchSource *source,
    const NativeScriptShootDispatchBinding *binding);
void cadence_script_shoot_dispatch_invalid(const NativeScriptShootDispatchSource *source,
    const NativeScriptShootDispatchBinding *binding,uint32_t reason);
uint32_t native_script_shoot_dispatch_consume(void *actor,void *state,void *model,
    uintptr_t native_frame,uint32_t local_value);
int native_script_shoot_dispatch_install(void);
extern uintptr_t script_shoot_dispatch_original;
void native_script_shoot_dispatch_entry(void);
#ifdef __cplusplus
}
#endif
