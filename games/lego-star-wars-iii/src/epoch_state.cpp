#include "epoch_state.h"
uint32_t sync_epoch_begin(SyncEpochCursor *cursor,int level) {
    if (cursor->active && cursor->level==level) return cursor->epoch;
    if (!++cursor->epoch) ++cursor->epoch;
    cursor->sequence=0;cursor->level=level;cursor->active=1;
    return cursor->epoch;
}
void sync_epoch_loading(SyncEpochCursor *cursor) { cursor->active=0;cursor->sequence=0; }
int sync_epoch_classify(const SyncEpochCursor *cursor,int loaded_level,uint32_t epoch,int level,uint32_t sequence) {
    if (!epoch || !sequence || level<0 || level>=4096) return EPOCH_INVALID;
    if (epoch<cursor->epoch || (epoch==cursor->epoch && !cursor->active)) return EPOCH_STALE;
    if (level!=loaded_level) return epoch>cursor->epoch ? EPOCH_WAIT_LEVEL : EPOCH_STALE;
    if (epoch>cursor->epoch) return sequence==1 ? EPOCH_FIRST : EPOCH_GAP;
    if (level!=cursor->level) return EPOCH_INVALID;
    if (sequence<=cursor->sequence) return EPOCH_STALE;
    return sequence==cursor->sequence+1 ? EPOCH_NEXT : EPOCH_GAP;
}
int sync_epoch_apply(SyncEpochCursor *cursor,int loaded_level,uint32_t epoch,int level,uint32_t sequence) {
    int result=sync_epoch_classify(cursor,loaded_level,epoch,level,sequence);
    if (result>0) { cursor->epoch=epoch;cursor->sequence=sequence;cursor->level=level;cursor->active=1; }
    return result;
}
uint32_t sync_epoch_unacknowledged(const SyncEpochCursor *cursor,uint32_t ack_epoch,uint32_t ack_sequence) {
    if (ack_epoch!=cursor->epoch || ack_sequence>cursor->sequence) return cursor->sequence;
    return cursor->sequence-ack_sequence;
}
int sync_epoch_profile_ready(const SyncEpochCursor *cursor,uint32_t epoch,uint32_t sequence) {
    return cursor->active && epoch==cursor->epoch && sequence<=cursor->sequence;
}
