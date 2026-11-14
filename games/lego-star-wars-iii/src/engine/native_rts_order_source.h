#pragma once
#include <stdint.h>
#include "native_gizmo_source.h"
struct NativeRtsOrderSource {
    void *order,*building,*team,*descriptor;
    uint32_t team_slot,building_ordinal,order_class;
    NativeGizmoSource gizmo;
};
int native_rts_order_source(void *,NativeRtsOrderSource *);
int native_rts_order_source_live(const NativeRtsOrderSource *);
