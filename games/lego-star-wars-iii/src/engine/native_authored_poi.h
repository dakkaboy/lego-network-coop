#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum { NATIVE_AUTHORED_POI_CHAIN_CAPACITY = 16 };
enum {
    NATIVE_AUTHORED_POI_RUNTIME_READABLE = 1,
    NATIVE_AUTHORED_POI_RECORD_READABLE = 2
};

typedef struct NativeAuthoredPoiLink {
    void *model,*receiver,*parent,*receiver_model;
    void *resource,*runtime,*array,*poi,*poi_receiver;
    uint32_t poi_count,receiver_class,readable_fields;
    uint16_t model_flags,reserved;
} NativeAuthoredPoiLink;

typedef struct NativeAuthoredPoi {
    void *model,*receiver,*authored_model,*authored_receiver;
    void *resource,*runtime,*array,*poi;
    uint32_t poi_count,poi_ordinal,receiver_class,chain_count;
    NativeAuthoredPoiLink chain[NATIVE_AUTHORED_POI_CHAIN_CAPACITY];
} NativeAuthoredPoi;

int native_authored_poi_resolve(void *model,NativeAuthoredPoi *out);
int native_authored_poi_revalidate(const NativeAuthoredPoi *witness);

#ifdef __cplusplus
}
#endif
