#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct NativeHubSource {
    void *world,*definition,*profile,*manager,*registry,*registration,*owner,*records,*record,*native_frame;
    uint32_t manager_id,manager_generation,manager_type,owner_id,ordinal,count,serial;
    int32_t level;
    uint8_t registration_data[20],record_data[100];
} NativeHubSource;
int native_hub_source_resolve(void *owner,void *native_frame,const uint32_t arguments[12],
    NativeHubSource *out,uint32_t *reason);
int native_hub_source_revalidate(const NativeHubSource *source);
#ifdef __cplusplus
}
#endif
