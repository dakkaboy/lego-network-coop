#pragma once
#include "../net/sync_wire.h"
typedef struct ShotContext { uint32_t clock,rng_game,rng_engine; float delta; } ShotContext;
static inline ShotContext shot_context_read(const uint32_t *clock,const uint32_t *game,const uint32_t *engine,const float *delta) {
    return (ShotContext){*clock,*game,*engine,*delta};
}
static inline void shot_context_apply(const ShotContext *value,uint32_t *clock,uint32_t *game,uint32_t *engine,float *delta) {
    *clock=value->clock;*game=value->rng_game;*engine=value->rng_engine;*delta=value->delta;
}
static inline int shot_native_match(const SyncShot *shot,int owner,uint32_t generation,int weapon,
                                    uint8_t source,uint8_t depth) {
    return shot->phase==0 && shot->owner==owner && shot->owner_generation==generation &&
           shot->weapon==weapon && shot->source==source && shot->depth==depth;
}
