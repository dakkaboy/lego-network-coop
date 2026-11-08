#pragma once
#include "../net/sync_wire.h"
static inline int rts_competitor_context_equal(const SyncRtsCompetitorState *a,const SyncRtsCompetitorState *b) {
    return a->clock==b->clock && a->competitor_class==b->competitor_class;
}
