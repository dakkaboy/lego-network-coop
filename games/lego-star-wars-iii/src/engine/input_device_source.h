#pragma once
#include <stdint.h>
typedef struct NativeInputDeviceSource {void *device;uint32_t session;} NativeInputDeviceSource;
static inline int native_input_device_source(void *observed,void *shadow,void *other_shadow,
                                            NativeInputDeviceSource original,uint32_t session,void **out) {
    if (observed==other_shadow) return 4;
    if (observed==shadow) {
        if (!session || session==UINT32_MAX || original.session!=session) return 5;
        *out=original.device;
    } else *out=observed;
    return 0;
}
