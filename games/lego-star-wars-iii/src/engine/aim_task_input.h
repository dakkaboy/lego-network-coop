#pragma once
#include <string.h>
#include "../net/sync_wire.h"
static inline int aim_task_context_equal(const SyncAimTaskState *a,const SyncAimTaskState *b) {
    return a->target_slot==b->target_slot && a->target_generation==b->target_generation &&
        a->clock==b->clock && a->task_class==b->task_class &&
        !memcmp(&a->minimum,&b->minimum,2*sizeof(float));
}
