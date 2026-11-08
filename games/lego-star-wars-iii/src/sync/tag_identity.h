#pragma once
#include <string.h>
#include "../net/sync_wire.h"

/* Command operands can retire before the authoritative post-state is collected. */
static inline int tag_identity_reference(SyncActor *reference, int32_t slot, uint32_t generation,
    const SyncTagIdentity *identity) {
    if (!reference || !identity || slot < 0 || slot >= SYNC_MAX_ACTORS || !generation ||
        identity->character < 0 || identity->character >= 4096) return 0;
    memset(reference, 0, sizeof *reference);
    reference->slot = (uint32_t)slot;
    reference->generation = generation;
    reference->character = identity->character;
    reference->spawn_tag = identity->spawn_tag;
    reference->spawn_source = identity->spawn_source;
    return 1;
}
