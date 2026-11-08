#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum { NATIVE_SAVED_ROSTER_CAPACITY = 8, NATIVE_SAVED_ROSTER_PRODUCER = 2 };
typedef struct NativeRosterSource {
    void *world, *definition, *profile, *provider, *provider_class, *record;
    uint32_t ordinal, count;
    int32_t level;
    uint8_t record_data[40];
} NativeRosterSource;

int native_roster_source_resolve(void *record_plus_28, const uint32_t arguments[12], NativeRosterSource *out);
/* The original caller publishes record+0 after the constructor returns. */
int native_roster_source_revalidate(const NativeRosterSource *source, const void *linked_actor);

#ifdef __cplusplus
}
#endif
