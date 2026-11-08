#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NativeResourceIdentity {
    uint32_t key[4],container_class,source_world_present;
    void *world,*registry,*actual_resource,*root_resource,*runtime,*array,*entry;
    void *container,*source_world,*filename,*name;
    uint32_t world_name_length,source_world_name_length,filename_length,name_length;
} NativeResourceIdentity;

int native_resource_identity_resolve(void *current_world,void *resource,NativeResourceIdentity *out);
int native_resource_identity_revalidate(const NativeResourceIdentity *witness);

#ifdef __cplusplus
}
#endif
