#undef NDEBUG
#include <assert.h>
#include <stdio.h>
#include "sync/epoch_state.h"
int main(void) {
    SyncEpochCursor host={.level=-1},client={.level=-1};
    assert(sync_epoch_begin(&host,6)==1);assert(sync_epoch_begin(&host,6)==1);
    host.sequence=10000;assert(sync_epoch_apply(&client,6,1,6,1)==EPOCH_FIRST);
    assert(sync_epoch_apply(&client,6,1,6,2)==EPOCH_NEXT);
    assert(sync_epoch_apply(&client,6,1,6,2)==EPOCH_STALE);
    assert(sync_epoch_classify(&client,6,1,6,4)==EPOCH_GAP);
    sync_epoch_loading(&host);sync_epoch_loading(&client);
    assert(sync_epoch_unacknowledged(&host,1,10000)==0);
    assert(sync_epoch_classify(&client,6,1,6,3)==EPOCH_STALE);
    assert(sync_epoch_begin(&host,6)==2);host.sequence=1;
    assert(sync_epoch_unacknowledged(&host,1,10000)==1);
    assert(sync_epoch_apply(&client,6,2,6,1)==EPOCH_FIRST);
    assert(sync_epoch_classify(&client,6,1,6,99999)==EPOCH_STALE);
    assert(sync_epoch_profile_ready(&client,2,1));assert(!sync_epoch_profile_ready(&client,1,1));
    sync_epoch_loading(&client);sync_epoch_loading(&host);assert(sync_epoch_begin(&host,8)==3);
    assert(sync_epoch_apply(&client,6,3,8,1)==EPOCH_WAIT_LEVEL);assert(client.epoch==2 && !client.active);
    assert(sync_epoch_apply(&client,8,3,8,1)==EPOCH_FIRST);
    assert(!sync_epoch_profile_ready(&client,4,0));assert(!sync_epoch_profile_ready(&client,3,2));
    assert(sync_epoch_classify(&client,8,4,8,2)==EPOCH_GAP);
    assert(sync_epoch_classify(&client,8,0,8,1)==EPOCH_INVALID);
    assert(sync_epoch_classify(&client,8,4,8,0)==EPOCH_INVALID);
    puts("Epoch boundaries: stale in-flight frames, same-level restart, future-level pending, sequence gaps, stale/future ack and profile gating passed");
}
