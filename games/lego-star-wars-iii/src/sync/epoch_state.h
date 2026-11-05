#pragma once
#include <stdint.h>
typedef struct SyncEpochCursor {
    uint32_t epoch,sequence;
    int32_t level;
    int active;
} SyncEpochCursor;
enum { EPOCH_INVALID=-3,EPOCH_GAP=-2,EPOCH_WAIT_LEVEL=-1,EPOCH_STALE=0,EPOCH_NEXT=1,EPOCH_FIRST=2 };
#ifdef __cplusplus
extern "C" {
#endif

uint32_t sync_epoch_begin(SyncEpochCursor *cursor,int level);
void sync_epoch_loading(SyncEpochCursor *cursor);
int sync_epoch_classify(const SyncEpochCursor *cursor,int loaded_level,uint32_t epoch,int level,uint32_t sequence);
int sync_epoch_apply(SyncEpochCursor *cursor,int loaded_level,uint32_t epoch,int level,uint32_t sequence);
uint32_t sync_epoch_unacknowledged(const SyncEpochCursor *cursor,uint32_t ack_epoch,uint32_t ack_sequence);
int sync_epoch_profile_ready(const SyncEpochCursor *cursor,uint32_t epoch,uint32_t sequence);

#ifdef __cplusplus
}
#endif
