const a = @import("abi.zig");
const check = @import("native_test_support.zig").check;
comptime {
    _ = @import("epoch.zig");
}
pub fn main() void {
    var host = a.SyncEpochCursor{ .level = -1, .epoch = 0, .sequence = 0, .active = 0 };
    var client = host;
    check(@src(), a.sync_epoch_begin(&host, 6) == 1 and a.sync_epoch_begin(&host, 6) == 1);
    host.sequence = 10000;
    check(@src(), a.sync_epoch_apply(&client, 6, 1, 6, 1) == 2 and a.sync_epoch_apply(&client, 6, 1, 6, 2) == 1);
    check(@src(), a.sync_epoch_apply(&client, 6, 1, 6, 2) == 0 and a.sync_epoch_classify(&client, 6, 1, 6, 4) == -2);
    a.sync_epoch_loading(&host);
    a.sync_epoch_loading(&client);
    check(@src(), a.sync_epoch_unacknowledged(&host, 1, 10000) == 0 and a.sync_epoch_classify(&client, 6, 1, 6, 3) == 0);
    check(@src(), a.sync_epoch_begin(&host, 6) == 2);
    host.sequence = 1;
    check(@src(), a.sync_epoch_unacknowledged(&host, 1, 10000) == 1 and a.sync_epoch_apply(&client, 6, 2, 6, 1) == 2);
    check(@src(), a.sync_epoch_classify(&client, 6, 1, 6, 99999) == 0 and a.sync_epoch_profile_ready(&client, 2, 1) != 0 and a.sync_epoch_profile_ready(&client, 1, 1) == 0);
    a.sync_epoch_loading(&client);
    a.sync_epoch_loading(&host);
    check(@src(), a.sync_epoch_begin(&host, 8) == 3);
    check(@src(), a.sync_epoch_apply(&client, 6, 3, 8, 1) == -1 and client.epoch == 2 and client.active == 0);
    check(@src(), a.sync_epoch_apply(&client, 8, 3, 8, 1) == 2 and a.sync_epoch_profile_ready(&client, 4, 0) == 0 and a.sync_epoch_profile_ready(&client, 3, 2) == 0);
    check(@src(), a.sync_epoch_classify(&client, 8, 4, 8, 2) == -2 and a.sync_epoch_classify(&client, 8, 0, 8, 1) == -3 and a.sync_epoch_classify(&client, 8, 4, 8, 0) == -3);
}
