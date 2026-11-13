#pragma once
#include <stdint.h>

struct NativeGlobalPackSource {
    const void *manager,*pool,*definition,*pack;
    uint32_t faction;
};

unsigned native_global_pack_registry_count();
int native_global_pack_source(const void *pack,NativeGlobalPackSource *out);
