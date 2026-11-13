#pragma once
#include <stdint.h>
struct NativeRtsOrderSource {
    void *order,*building,*team,*descriptor;
    uint32_t team_slot,building_id,order_class;
};
int native_rts_order_source(void *,NativeRtsOrderSource *);
int native_rts_order_source_live(const NativeRtsOrderSource *);
