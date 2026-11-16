pub const SpawnIdentity = extern struct { site: u32, source: @import("protocol.zig").SyncSpawnSource };
pub const Key = extern struct { generation: u32, spawn_tag: u32, character: i32, spawn_source: @import("protocol.zig").SyncSpawnSource };
