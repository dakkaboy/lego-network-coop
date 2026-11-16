const scene = @import("scene_readiness.zig");
const Memory = @import("sparse_test_memory.zig").Memory;
const check = @import("native_test_support.zig").check;
const profile: u32 = 0x10000000;
const catalog: u32 = 0x11000000;
const areas: u32 = 0x12000000;
const records: u32 = 0x13000000;
const registry: u32 = 0x14000000;
const registry_entries: u32 = 0x14000100;
const definition: u32 = 0x15000000;
const world: u32 = 0x16000000;
const pool: u32 = 0x17000000;
const controllers: u32 = 0x18000000;
const resources: u32 = 0x19000000;
const devices: u32 = 0x1a000000;
fn fixture() Memory {
    var m = Memory{};
    m.add(0xe00000, 0x200000, true);
    m.add(0x8f02b0, 1, false);
    m.add(0x403e80, 1, false);
    m.add(profile, 0xb5c0, true);
    m.add(catalog, 2 * 0x1b0, true);
    m.add(areas, 0xd80, true);
    m.add(records, 0x20, true);
    m.add(registry, 0x200, true);
    m.add(definition, 0x40, true);
    m.add(world, 0x22e8, true);
    m.add(pool, 2 * 0x1440, true);
    m.add(controllers, 0x200, true);
    m.add(resources, 0x100, true);
    m.add(devices, 0x200, true);
    m.put(u32, 0xfbd8bc, profile);
    m.put(u32, profile, 0x500);
    const globals = [_]u32{ 0xfb519c, 0xfb847c, 0xfb4bdc, 0xfb4cb4, 0xfbc1dc, 0xfbc1cc, 0xfb3110 };
    const offsets = [_]u32{ 0x5b84, 0x1c, 0xb248, 0x6238, 0x6208, 0x6210, 0xb57c };
    for (0..7) |i| m.put(u32, globals[i], profile + offsets[i]);
    m.put(u32, 0xfb8404, catalog);
    m.put(u32, 0xfb8410, 2);
    m.put(u32, 0xfb8414, catalog);
    m.put(i16, catalog + 0x94, 0);
    m.put(i16, catalog + 0x1b0 + 0x94, 1);
    m.put(u32, world + 0x220, catalog + 0x1b0);
    m.put(u32, 0xfb4a20, world);
    m.put(u32, 0xfb5154, areas);
    m.put(u32, 0xfb5160, 1);
    m.put(u32, 0xe6de7c, records);
    m.put(u16, 0xe6de82, 1);
    m.put(u8, records + 9, 2);
    m.put(i16, records, 0);
    m.put(u32, 0xe6e0bc, registry);
    m.put(u32, registry, registry_entries);
    m.put(u32, registry + 4, 1);
    m.put(u32, registry_entries, definition);
    m.put(i8, registry_entries + 0xf, -1);
    m.put(i16, registry_entries + 0x10, 1);
    m.put(u32, 0xe6e124, 0x8f02b0);
    m.put(u32, 0xfb4d58, 0x403e80);
    m.put(u32, 0xfb2f60, pool);
    m.put(u32, 0xfb2e3c, 2);
    for (0..2) |index| {
        const i: u32 = @intCast(index);
        const actor = pool + i * 0x1440;
        m.put(u32, actor + 0x50, 3);
        m.put(i16, actor + 0xdc0, @as(i16, @intCast(i)));
        m.put(u32, actor + 0xf08, resources + i * 0x40);
        m.put(u32, actor + 0x6cc, controllers + i * 0x100);
        m.put(u32, controllers + i * 0x100, devices + i * 0x100);
    }
    return m;
}
fn makeOps(memory: *Memory) scene.Ops {
    return .{ .context = @intFromPtr(memory), .read = Memory.read, .range = Memory.range };
}
fn storage(memory: *Memory) bool {
    const read_ops = makeOps(memory);
    return scene.native_profile_storage_bound(&read_ops) != 0;
}
fn capability(memory: *Memory, level: i32, expected: u32) i32 {
    const read_ops = makeOps(memory);
    return scene.native_scene_input_capability(&read_ops, level, expected);
}
fn party(memory: *Memory) void {
    memory.put(u32, 0xfb4940, pool);
    memory.put(u32, 0xfb4944, pool + 0x1440);
}
pub fn main() void {
    var m = fixture();
    defer m.deinit();
    check(@src(), storage(&m));
    check(@src(), capability(&m, 1, world) == 2);
    const globals = [_]u32{ 0xfb519c, 0xfb847c, 0xfb4bdc, 0xfb4cb4, 0xfbc1dc, 0xfbc1cc, 0xfb3110 };
    for (globals) |global| {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, global, profile + 4);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, profile, 0x501);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, 0xfbd8bc, profile + 4);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.find(profile, 0xb5c0).writable = false;
        check(@src(), !storage(&bad));
    }
    for ([_]u32{ 0xfb8410, 0xfb5160, 0xfbd7bc }) |global| {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, global, 0xffffffff);
        check(@src(), !storage(&bad));
    }
    {
        var empty = m.clone();
        defer empty.deinit();
        for ([_]u32{ 0xfb8410, 0xfb5160, 0xfbd7bc, registry + 4 }) |global| empty.put(u32, global, 0);
        for ([_]u32{ 0xfb8404, 0xfb5154, 0xfbd7b8, registry }) |global| empty.put(u32, global, 0);
        empty.put(u16, 0xe6de82, 0);
        empty.put(u32, 0xe6de7c, 0);
        check(@src(), storage(&empty));
        check(@src(), capability(&empty, 1, world) == 0);
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, 0xe6e0bc, 0);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, registry + 4, 0xffffffff);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, registry, 0);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, registry_entries, 0);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(i8, registry_entries + 0xf, -2);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(i8, registry_entries + 0xf, 1);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(i16, registry_entries + 0x10, 2);
        check(@src(), !storage(&bad));
    }
    {
        var unused = m.clone();
        defer unused.deinit();
        unused.put(u8, registry_entries + 0x12, 1);
        unused.put(i8, registry_entries + 0xf, -2);
        check(@src(), storage(&unused));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(i16, records, -1);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(i16, records, 0x32c);
        check(@src(), !storage(&bad));
    }
    {
        var last = m.clone();
        defer last.deinit();
        last.put(i16, records, 0x32b);
        check(@src(), storage(&last));
    }
    {
        var unused = m.clone();
        defer unused.deinit();
        unused.put(u8, records + 9, 0);
        unused.put(i16, records, -1);
        check(@src(), storage(&unused));
    }
    for ([_]u32{ 0xe6e124, 0xfb4d58, 0xfb4d60 }) |global| {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, global, 0x1234);
        check(@src(), !storage(&bad));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, 0xe6e124, 0);
        check(@src(), !storage(&bad));
    }
    {
        var allowed = m.clone();
        defer allowed.deinit();
        allowed.put(u32, 0xfb4d58, 0);
        allowed.put(u32, 0xfb4d60, 0);
        check(@src(), storage(&allowed));
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, 0xfbbbcc, 0x1234);
        check(@src(), !storage(&bad));
    }
    {
        var changed = m.clone();
        defer changed.deinit();
        changed.mutate_on = 0xe6e124;
        changed.mutate_address = 0xfb519c;
        changed.mutate_value = profile + 4;
        check(@src(), !storage(&changed));
    }
    {
        var empty = m.clone();
        defer empty.deinit();
        empty.put(u32, 0xfb2e3c, 0);
        empty.put(u32, 0xfb2f60, 0);
        check(@src(), capability(&empty, 1, world) == 2);
    }
    for ([_]u32{ 4097, 0xffffffff }) |count| {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, 0xfb2e3c, count);
        check(@src(), capability(&bad, 1, world) == 0);
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, 0xfb2f60, 0);
        check(@src(), capability(&bad, 1, world) == 0);
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, 0xfb2e3c, 3);
        check(@src(), capability(&bad, 1, world) == 0);
    }
    check(@src(), capability(&m, 0, world) == 0);
    check(@src(), capability(&m, 2, world) == 0);
    check(@src(), capability(&m, -1, world) == 0);
    check(@src(), capability(&m, 1, world + 4) == 0);
    {
        var titles = m.clone();
        defer titles.deinit();
        titles.put(u32, 0xfb8414, catalog + 0x1b0);
        check(@src(), capability(&titles, 1, world) == 0);
    }
    {
        var titles = m.clone();
        defer titles.deinit();
        titles.put(u32, catalog + 0x1b0 + 0x50, 0x40000000);
        check(@src(), capability(&titles, 1, world) == 0);
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, 0xfb8414, 0x1234);
        check(@src(), capability(&bad, 1, world) == 0);
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(i16, catalog + 0x1b0 + 0x94, 0);
        check(@src(), capability(&bad, 1, world) == 0);
    }
    {
        var needs = m.clone();
        defer needs.deinit();
        needs.put(u32, catalog + 0x1b0 + 0x50, 2);
        check(@src(), capability(&needs, 1, world) == 0);
        party(&needs);
        check(@src(), capability(&needs, 1, world) == 1);
    }
    party(&m);
    check(@src(), capability(&m, 1, world) == 1);
    {
        var partial = m.clone();
        defer partial.deinit();
        partial.put(u32, 0xfb4944, 0);
        check(@src(), capability(&partial, 1, world) == 0);
    }
    {
        var partial = m.clone();
        defer partial.deinit();
        partial.put(u32, 0xfb4940, 0);
        check(@src(), capability(&partial, 1, world) == 0);
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, pool + 0xf08, 0);
        check(@src(), capability(&bad, 1, world) == 0);
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, pool + 0x1440 + 0x6cc, 0);
        check(@src(), capability(&bad, 1, world) == 0);
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(u32, 0xfb4944, pool + 0x1441);
        check(@src(), capability(&bad, 1, world) == 0);
    }
    {
        var bad = m.clone();
        defer bad.deinit();
        bad.put(i16, pool + 0xdc0, -1);
        check(@src(), capability(&bad, 1, world) == 0);
    }
    {
        var no_actors = m.clone();
        defer no_actors.deinit();
        no_actors.put(u32, 0xfb2e3c, 0);
        check(@src(), capability(&no_actors, 1, world) == 0);
    }
    {
        var respawn = m.clone();
        defer respawn.deinit();
        respawn.put(u32, pool + 0x50, 0);
        respawn.put(u32, pool + 0x1440 + 0x50, 0);
        respawn.put(u32, pool + 0x6cc, 0);
        respawn.put(u32, controllers + 0x100, 0);
        respawn.put(i16, pool + 0x1440 + 0xdc0, -1);
        respawn.put(u32, pool + 0x1440 + 0xf08, 0);
        respawn.put(u32, 0xfb4948, 0x1234);
        check(@src(), capability(&respawn, 1, world) == 1);
    }
    {
        var external = m.clone();
        defer external.deinit();
        external.add(0x20000000, 0x1440, true);
        external.put(u32, 0xfb4944, 0x20000000);
        external.put(u32, 0x20000000 + 0x6cc, controllers + 0x100);
        check(@src(), capability(&external, 1, world) == 1);
    }
    for ([_]u32{ 0xfb4a20, 0xfb2f60, 0xfb2e3c, 0xfb4944 }) |global| {
        var changed = m.clone();
        defer changed.deinit();
        changed.mutate_on = pool + 0x1440 + 0x6cc;
        changed.mutate_address = global;
        changed.mutate_value = 0;
        check(@src(), capability(&changed, 1, world) == 0);
    }
    const read_ops = makeOps(&m);
    var scratch: u32 = 0;
    check(@src(), scene.native_profile_storage_bound(null) == 0);
    check(@src(), scene.native_scene_read(&read_ops, 0xffffffff - 1, &scratch, 4) == 0);
    check(@src(), scene.native_scene_span(&read_ops, 0xffffffff - 1, 2, 4) == 0);
    check(@src(), scene.native_scene_span(&read_ops, 0, 0, 4) != 0);
}
