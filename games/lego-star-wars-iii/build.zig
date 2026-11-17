const std = @import("std");
const builtin = @import("builtin");
const NativeSuite = struct {
    step: *std.Build.Step,
    cases: std.StringHashMap(*std.Build.Step.Compile),
    fixtures: std.StringHashMap(*std.Build.Step.Compile),
};

pub fn build(b: *std.Build) void {
    if (!std.mem.eql(u8, builtin.zig_version_string, "0.17.1"))
        @panic("Zig 0.17.1 is required");
    const target = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .windows, .abi = .gnu });
    const optimize = b.standardOptimizeOption(.{});
    const native_target = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .windows, .abi = .msvc });
    var native_suite: NativeSuite = .{ .step = b.step("native-tests", "Build native Zig regressions"), .cases = std.StringHashMap(*std.Build.Step.Compile).init(b.allocator), .fixtures = std.StringHashMap(*std.Build.Step.Compile).init(b.allocator) };
    _ = nativeTest(b, &native_suite, native_target, "tag_runtime", "native-tag");
    _ = nativeTest(b, &native_suite, native_target, "tick_install", "native-tick");
    _ = nativeTest(b, &native_suite, native_target, "camera_family", "native-camera-family");
    _ = nativeTest(b, &native_suite, native_target, "camera_graphics", "native-camera-graphics");
    _ = nativeTest(b, &native_suite, native_target, "camera_install", "native-camera-install");
    _ = nativeTest(b, &native_suite, native_target, "sync_input", "native-sync-input");
    _ = nativeTest(b, &native_suite, native_target, "native_numeric", "native-numeric");
    _ = nativeTest(b, &native_suite, native_target, "sync_preload", "native-sync-preload");
    _ = nativeTest(b, &native_suite, native_target, "sync_core", "native-sync-core");
    _ = nativeTest(b, &native_suite, native_target, "hit_entry", "native-hit-entry");
    _ = nativeTest(b, &native_suite, native_target, "constructor_observer", "native-constructor-observer");
    _ = nativeTest(b, &native_suite, native_target, "constructor_query", "native-constructor-query");
    _ = nativeTest(b, &native_suite, native_target, "projectile_constructor", "native-projectile-constructor");
    const wire_abi_test = nativeTest(b, &native_suite, native_target, "wire_abi", "native-wire-abi");
    _ = nativeTest(b, &native_suite, native_target, "lan_version", "native-lan-version");
    _ = nativeTest(b, &native_suite, native_target, "lan_transport", "native-lan-transport");
    _ = nativeTest(b, &native_suite, native_target, "reaction_receipt", "native-reaction-receipt");
    _ = nativeTest(b, &native_suite, native_target, "input_device_source", "native-input-device");
    _ = nativeTest(b, &native_suite, native_target, "diagnostics", "native-diagnostics");
    const proxy_test = nativeTest(b, &native_suite, native_target, "proxy", "native-proxy");
    const game_dll_test = nativeTest(b, &native_suite, native_target, "game_dll", "native-game-dll");
    _ = nativeTest(b, &native_suite, native_target, "lexical_seh", "native-lexical-seh");
    _ = nativeTest(b, &native_suite, native_target, "loading", "native-loading");
    _ = nativeTest(b, &native_suite, native_target, "capture", "native-capture");
    _ = nativeTest(b, &native_suite, native_target, "remote_trace", "native-remote-trace");
    _ = nativeTest(b, &native_suite, native_target, "npc_input", "native-npc-input");
    _ = nativeTest(b, &native_suite, native_target, "pool_birth", "native-pool-birth");
    _ = nativeTest(b, &native_suite, native_target, "sync_profiling", "native-sync-profiling");
    _ = nativeTest(b, &native_suite, native_target, "network_window", "native-network-window");
    _ = nativeTest(b, &native_suite, native_target, "span_installer", "native-span-installer");
    _ = nativeTest(b, &native_suite, native_target, "span_engine", "native-span-engine");
    _ = nativeTest(b, &native_suite, native_target, "span_marker", "native-span-marker");
    _ = nativeTest(b, &native_suite, native_target, "script_dispatch", "native-script-dispatch");
    _ = nativeTest(b, &native_suite, native_target, "rts_order_ready", "native-rts-order-ready");
    _ = nativeTest(b, &native_suite, native_target, "flow_request", "native-flow-request");
    _ = nativeTest(b, &native_suite, native_target, "world_admission", "native-world-admission");
    _ = nativeTest(b, &native_suite, native_target, "spellit_completion", "native-spellit-completion");
    _ = nativeTest(b, &native_suite, native_target, "fixture_loader", "native-fixture-loader");
    _ = nativeTest(b, &native_suite, native_target, "native_scene_readiness", "native-scene-readiness");
    _ = nativeTest(b, &native_suite, native_target, "mapping_session", "native-mapping-session");
    _ = nativeTest(b, &native_suite, native_target, "rts_competitor", "native-rts-competitor");
    _ = nativeTest(b, &native_suite, native_target, "breakup_launch", "native-breakup-launch");
    _ = nativeTest(b, &native_suite, native_target, "vehicle_rng_thunk", "native-vehicle-rng-thunk");
    _ = nativeTest(b, &native_suite, native_target, "force_target", "native-force-target");
    _ = nativeTest(b, &native_suite, native_target, "force_geometry", "native-force-geometry");
    _ = nativeTest(b, &native_suite, native_target, "character_motion", "native-character-motion");
    _ = nativeTest(b, &native_suite, native_target, "aim_base", "native-aim-base");
    _ = nativeTest(b, &native_suite, native_target, "aim_task", "native-aim-task");
    _ = nativeTest(b, &native_suite, native_target, "breakup_visibility", "native-breakup-visibility");
    _ = nativeTest(b, &native_suite, native_target, "gizmo_source", "native-gizmo-source");
    _ = nativeTest(b, &native_suite, native_target, "resource_identity", "native-resource-identity");
    _ = nativeTest(b, &native_suite, native_target, "frame_queue", "native-frame-queue");
    _ = nativeTest(b, &native_suite, native_target, "authored_poi", "native-authored-poi");
    _ = nativeTest(b, &native_suite, native_target, "vehicle_rng", "native-vehicle-rng");
    _ = nativeTest(b, &native_suite, native_target, "list_memory", "native-list-memory");
    _ = nativeTest(b, &native_suite, native_target, "module_rng", "native-module-rng");
    _ = nativeTest(b, &native_suite, native_target, "object_progress", "native-object-progress");
    _ = nativeTest(b, &native_suite, native_target, "geometry_runtime", "native-geometry-runtime");
    _ = nativeTest(b, &native_suite, native_target, "saved_sources", "native-saved-sources");
    _ = nativeTest(b, &native_suite, native_target, "page_access", "native-page-access");
    _ = nativeTest(b, &native_suite, native_target, "world_vars", "native-world-vars");
    _ = nativeTest(b, &native_suite, native_target, "rts_generator", "native-rts-generator");
    _ = nativeTest(b, &native_suite, native_target, "rts_order", "native-rts-order");
    _ = nativeTest(b, &native_suite, native_target, "rts_body", "native-rts-body");
    _ = nativeTest(b, &native_suite, native_target, "character_support", "native-character-support");
    _ = nativeTest(b, &native_suite, native_target, "camera_observation", "native-camera-observation");
    _ = nativeTest(b, &native_suite, native_target, "spawn_timers", "native-spawn-timers");
    const spellit_source_test = nativeTest(b, &native_suite, native_target, "spellit_source", "native-spellit-source");
    spellit_source_test.image_base = 0x400000;
    _ = nativeTest(b, &native_suite, native_target, "spellit_body", "native-spellit-body");
    _ = nativeTest(b, &native_suite, native_target, "spellit_query", "native-spellit-query");
    _ = nativeTest(b, &native_suite, native_target, "spellit_pose", "native-spellit-pose");
    _ = nativeTest(b, &native_suite, native_target, "spellit_input", "native-spellit-input");
    _ = nativeTest(b, &native_suite, native_target, "script_shoot", "native-script-shoot");
    _ = nativeTest(b, &native_suite, native_target, "spellit_admission", "native-spellit-admission");
    _ = nativeTest(b, &native_suite, native_target, "spellit_admission_thunk", "native-spellit-admission-thunk");
    _ = nativeTest(b, &native_suite, native_target, "hazard_death_thunk", "native-hazard-death-thunk");
    _ = nativeTest(b, &native_suite, native_target, "tick_pack_behavior", "native-pack-behavior");
    _ = nativeTest(b, &native_suite, native_target, "decision", "native-decision");
    _ = nativeTest(b, &native_suite, native_target, "shooter", "native-shooter");
    _ = nativeTest(b, &native_suite, native_target, "spawn_observation", "native-spawn-observation");
    _ = nativeTest(b, &native_suite, native_target, "rts_dispatch_thunk", "native-rts-dispatch-thunk");
    const overlay_test = nativeTest(b, &native_suite, native_target, "overlay", "native-overlay");
    inline for (.{ "gdi32", "winmm", "shell32", "user32" }) |library| overlay_test.root_module.linkSystemLibrary(library, .{ .use_pkg_config = .no });
    _ = nativeTest(b, &native_suite, native_target, "entity_entry", "native-entity-entry");
    _ = nativeTest(b, &native_suite, native_target, "game_state", "native-game-state");
    _ = nativeTest(b, &native_suite, native_target, "entity_runtime", "native-entity-runtime");
    _ = nativeTest(b, &native_suite, native_target, "cadence_runtime", "native-cadence-runtime");
    _ = nativeTest(b, &native_suite, native_target, "physics_runtime", "native-physics-runtime");
    _ = nativeTest(b, &native_suite, native_target, "breakup_source", "native-breakup-source");
    _ = nativeTest(b, &native_suite, native_target, "projectile_pool", "native-projectile-pool");
    _ = nativeTest(b, &native_suite, native_target, "combat", "native-combat");
    _ = nativeTest(b, &native_suite, native_target, "model_runtime", "native-model-runtime");
    _ = nativeTest(b, &native_suite, native_target, "reaction_runtime", "native-reaction-runtime");
    _ = nativeTest(b, &native_suite, native_target, "sync_wire", "native-sync-wire");
    _ = nativeTest(b, &native_suite, native_target, "projectile_runtime", "native-projectile-runtime");
    _ = nativeTest(b, &native_suite, native_target, "native_tick_journal", "native-tick-journal");
    _ = nativeTest(b, &native_suite, native_target, "collision", "native-collision");
    _ = nativeTest(b, &native_suite, native_target, "collision_owner", "native-collision-owner");
    _ = nativeTest(b, &native_suite, native_target, "rigid_body_binding", "native-rigid-body-binding");
    for ([_]struct { name: []const u8, mode: std.builtin.OptimizeMode }{ .{ .name = "Debug", .mode = .Debug }, .{ .name = "ReleaseSafe", .mode = .ReleaseSafe } }) |configuration| {
        for ([_]struct { name: []const u8, source: []const u8 }{
            .{ .name = "owner", .source = "owner_fixture_test" },
            .{ .name = "mapping-observer", .source = "mapping_observer_fixture_test" },
            .{ .name = "mapping-bridge", .source = "mapping_bridge_fixture_test" },
            .{ .name = "mapping-session", .source = "mapping_session_fixture_test" },
        }) |unit| {
            const fixture = b.addLibrary(.{ .name = b.fmt("{s}-{s}", .{ unit.name, configuration.name }), .linkage = .dynamic, .root_module = module(b, native_target, configuration.mode, b.fmt("src/zig/{s}.zig", .{unit.source})), .use_llvm = true });
            fixture.image_base = 0x65000000;
            fixture.linker_dynamicbase = false;
            native_suite.step.dependOn(&b.addInstallArtifact(fixture, .{}).step);
            native_suite.fixtures.put(fixture.name, fixture) catch @panic("OOM");
        }
    }
    const profile_test = nativeTest(b, &native_suite, native_target, "profile_bootstrap_state", "native-profile-bootstrap");
    const preload_test = nativeTest(b, &native_suite, native_target, "preload_state", "native-preload-state");
    const input_test = nativeTest(b, &native_suite, native_target, "input_buffer", "native-input-buffer");
    const epoch_test = nativeTest(b, &native_suite, native_target, "epoch_state", "native-epoch-state");
    const tracy_enabled = b.option(bool, "tracy", "Profile synchronization with Tracy") orelse false;
    const game_options = b.addOptions();
    game_options.addOption(bool, "hit_entry", b.option(bool, "hit-entry", "Record native hit entries") orelse false);
    const constructor_query = b.option(bool, "constructor-query", "Record native projectile construction queries") orelse false;
    game_options.addOption(bool, "constructor_query", constructor_query);
    game_options.addOption(bool, "tracy", tracy_enabled);
    const game_module = module(b, native_target, .ReleaseSafe, "src/zig/game_root.zig");
    game_module.addOptions("game_options", game_options);
    const game_object = b.addObject(.{ .name = "clonewars-game", .root_module = game_module, .use_llvm = true });
    game_object.dll_export_fns = false;
    const game = b.addLibrary(.{ .name = "clonewars-camera", .linkage = .dynamic, .root_module = b.createModule(.{ .target = native_target, .optimize = .ReleaseSafe, .link_libc = true }), .use_llvm = true, .win32_module_definition = gameExports(b, constructor_query) });
    game.root_module.addObject(game_object);
    game.root_module.linkSystemLibrary("user32", .{ .use_pkg_config = .no });
    game.root_module.linkSystemLibrary("ws2_32", .{ .use_pkg_config = .no });
    game.root_module.linkSystemLibrary("shell32", .{ .use_pkg_config = .no });
    game.root_module.linkSystemLibrary("gdi32", .{ .use_pkg_config = .no });
    game.root_module.linkSystemLibrary("winmm", .{ .use_pkg_config = .no });
    const proxy_object = b.addObject(.{ .name = "d3d9-proxy", .root_module = module(b, native_target, .ReleaseSafe, "src/zig/proxy.zig"), .use_llvm = true });
    const native_proxy = b.addLibrary(.{ .name = "d3d9", .linkage = .dynamic, .root_module = b.createModule(.{ .target = native_target, .optimize = .ReleaseSafe, .link_libc = true }), .use_llvm = true, .win32_module_definition = b.path("src/engine/proxy.def") });
    native_proxy.root_module.addObject(proxy_object);
    const native_dlls = b.step("dll-native", "Build game DLLs directly with Zig");
    native_dlls.dependOn(&b.addInstallArtifact(game, .{}).step);
    native_dlls.dependOn(&b.addInstallArtifact(native_proxy, .{}).step);
    const native_dll_tests = b.step("test-dll", "Test native DLL loading and D3D9 forwarding");
    const run_game_dll = b.addRunArtifact(game_dll_test);
    run_game_dll.addArtifactArg(game);
    native_dll_tests.dependOn(&run_game_dll.step);
    const run_proxy = b.addRunArtifact(proxy_test);
    run_proxy.addArtifactArg(native_proxy);
    native_dll_tests.dependOn(&run_proxy.step);
    const core = b.addLibrary(.{
        .name = "clonewars-core",
        .linkage = .static,
        .root_module = module(b, target, optimize, if (tracy_enabled) "src/zig/profiled_root.zig" else "src/zig/root.zig"),
        .use_llvm = true,
    });
    if (tracy_enabled) {
        if (tracyLibrary(b, target)) |tracy| core.root_module.linkLibrary(tracy);
        if (tracyLibrary(b, native_target)) |tracy| {
            game.root_module.linkLibrary(tracy);
            const tracy_runtime = nativeTest(b, &native_suite, native_target, "tracy_runtime", "native-tracy-runtime");
            tracy_runtime.root_module.linkLibrary(tracy);
            native_dll_tests.dependOn(&b.addRunArtifact(tracy_runtime).step);
        }
    }
    b.installArtifact(core);
    const trace_exe = b.addExecutable(.{ .name = "clonewars-trace", .root_module = module(b, b.graph.host, .ReleaseSafe, "src/zig/trace_file.zig"), .use_llvm = true });
    const install_trace = b.addInstallArtifact(trace_exe, .{});
    b.getInstallStep().dependOn(&install_trace.step);
    b.step("tools", "Build diagnostics").dependOn(&install_trace.step);

    const filter = b.option([]const u8, "filter", "Test name");
    const tests = b.addTest(.{
        .root_module = module(b, target, .Debug, "src/zig/tests.zig"),
        .filters = if (filter) |name| &.{name} else &.{},
        .use_llvm = true,
    });
    const trace_fixture = b.addLibrary(.{
        .name = "clonewars-camera",
        .linkage = .dynamic,
        .root_module = b.createModule(.{ .root_source_file = b.path("src/zig/trace_fixture.zig"), .target = target, .optimize = .ReleaseSafe }),
        .use_llvm = true,
    });
    const test_options = b.addOptions();
    test_options.addOptionPath("trace_fixture", trace_fixture.getEmittedBin());
    tests.root_module.addOptions("test_options", test_options);
    const run = b.addRunArtifact(tests);
    run.has_side_effects = true;
    b.step("test", "Run core tests").dependOn(&run.step);
    const seh_test = b.addExecutable(.{ .name = "test-seh", .root_module = module(b, target, .Debug, "src/zig/seh_guard_test.zig"), .use_llvm = true });
    b.step("test-seh", "Test native SEH filters").dependOn(&b.addRunArtifact(seh_test).step);

    b.step("dll", "Build game DLLs").dependOn(native_dlls);
    b.getInstallStep().dependOn(native_dlls);
    const all_tests = b.step("test-all", "Run unit and native regression tests");
    const selected_case = b.option([]const u8, "case", "Run one native regression or fixture family");
    const selected_scenario = b.option(u32, "scenario", "Run one scenario of the selected regression");
    if (selected_scenario != null and selected_case == null) @panic("--scenario requires --case");
    if (selected_case == null or std.mem.eql(u8, selected_case.?, "core")) all_tests.dependOn(&run.step);
    nativeRegressions(b, &native_suite, all_tests, native_target, game, native_proxy, selected_case, selected_scenario);

    const abi_tests = b.step("test-abi", "Run C ABI regression tests against Zig");
    abi_tests.dependOn(&b.addRunArtifact(profile_test).step);
    abi_tests.dependOn(&b.addRunArtifact(preload_test).step);
    abi_tests.dependOn(&b.addRunArtifact(input_test).step);
    abi_tests.dependOn(&b.addRunArtifact(epoch_test).step);
    abi_tests.dependOn(&b.addRunArtifact(wire_abi_test).step);
}

fn module(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, path: []const u8) *std.Build.Module {
    const result = b.createModule(.{ .root_source_file = b.path(path), .target = target, .optimize = optimize, .link_libc = true });
    result.addIncludePath(b.path("src"));
    return result;
}

fn nativeTest(b: *std.Build, suite: *NativeSuite, target: std.Build.ResolvedTarget, unit: []const u8, step: []const u8) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = b.fmt("test_{s}", .{unit}),
        .root_module = module(b, target, .ReleaseSafe, b.fmt("src/zig/{s}_test.zig", .{unit})),
        .use_llvm = true,
    });
    exe.image_base = 0x100000;
    exe.linker_dynamicbase = false;
    exe.win32_manifest = b.path("src/zig/native_tests.manifest");
    const install = b.addInstallArtifact(exe, .{});
    b.step(step, b.fmt("Build native {s} regression", .{unit})).dependOn(&install.step);
    suite.step.dependOn(&install.step);
    suite.cases.put(unit, exe) catch @panic("OOM");
    return exe;
}
fn regressionRun(b: *std.Build, all: *std.Build.Step, exe: *std.Build.Step.Compile, name: []const u8) *std.Build.Step.Run {
    const run = b.addRunArtifact(exe);
    run.step.name = name;
    run.has_side_effects = true;
    all.dependOn(&run.step);
    return run;
}
fn chosen(selected: ?[]const u8, name: []const u8) bool {
    return selected == null or std.mem.eql(u8, selected.?, name);
}
fn nativeRegressions(b: *std.Build, suite: *NativeSuite, all: *std.Build.Step, target: std.Build.ResolvedTarget, game: *std.Build.Step.Compile, proxy: *std.Build.Step.Compile, selected: ?[]const u8, selected_scenario: ?u32) void {
    if (selected) |name| {
        if (std.mem.eql(u8, name, "core")) return;
        if (!suite.cases.contains(name) and !std.mem.eql(u8, name, "owner") and !std.mem.eql(u8, name, "mapping-observer") and !std.mem.eql(u8, name, "mapping-bridge") and !std.mem.eql(u8, name, "mapping-session") and !std.mem.eql(u8, name, "environment") and !std.mem.eql(u8, name, "seh_guard") and !std.mem.eql(u8, name, "transition_publication")) @panic("Unknown --case");
        if (std.mem.eql(u8, name, "fixture_loader")) @panic("Use --case=owner or a mapping fixture family");
    }
    var cases = suite.cases.iterator();
    var prior_network: ?*std.Build.Step.Run = null;
    while (cases.next()) |entry| {
        const name = entry.key_ptr.*;
        const exe = entry.value_ptr.*;
        if (std.mem.eql(u8, name, "fixture_loader")) continue;
        if (!chosen(selected, name)) continue;
        const scenarios: usize = if (std.mem.eql(u8, name, "span_engine")) 10 else if (std.mem.eql(u8, name, "mapping_session")) 8 else if (std.mem.eql(u8, name, "native_tick_journal")) 6 else if (std.mem.eql(u8, name, "sync_wire")) 5 else 1;
        if (selected_scenario) |scenario| if (scenario >= scenarios) @panic("Scenario is outside the selected regression");
        for (0..scenarios) |scenario| {
            if (selected_scenario != null and selected_scenario.? != scenario) continue;
            const run = regressionRun(b, all, exe, b.fmt("check {s}{s}", .{ name, if (scenarios > 1) b.fmt("/{d}", .{scenario}) else "" }));
            if (scenarios > 1) run.addArg(b.fmt("{d}", .{scenario}));
            if (std.mem.eql(u8, name, "proxy")) run.addArtifactArg(proxy);
            if (std.mem.eql(u8, name, "game_dll")) run.addArtifactArg(game);
            if (std.mem.eql(u8, name, "lan_version") or std.mem.eql(u8, name, "lan_transport")) {
                if (prior_network) |prior| run.step.dependOn(&prior.step);
                prior_network = run;
            }
        }
    }
    const loader = suite.cases.get("fixture_loader").?;
    for ([_]struct { name: []const u8, mode: std.builtin.OptimizeMode }{ .{ .name = "Debug", .mode = .Debug }, .{ .name = "ReleaseSafe", .mode = .ReleaseSafe } }) |configuration| {
        const environment = b.addExecutable(.{ .name = b.fmt("test_environment_{s}", .{configuration.name}), .root_module = module(b, target, configuration.mode, "src/zig/machine_environment_test.zig"), .use_llvm = true });
        if (chosen(selected, "environment")) _ = regressionRun(b, all, environment, b.fmt("check machine environment/{s}", .{configuration.name}));
        const owner = suite.fixtures.get(b.fmt("owner-{s}", .{configuration.name})).?;
        for ([_][]const u8{ "A", "B" }) |owner_target| for (0..8) |scenario| {
            if (!chosen(selected, "owner")) continue;
            if (selected_scenario) |wanted| {
                if (wanted >= 8) @panic("Owner scenario must be in 0..7");
                if (wanted != scenario) continue;
            }
            const run = regressionRun(b, all, loader, b.fmt("check owner/{s}/{s}/{d}", .{ configuration.name, owner_target, scenario }));
            run.addArg("owner");
            run.addArtifactArg(owner);
            run.setEnvironmentVariable("OWNER_TARGET", owner_target);
            run.setEnvironmentVariable("OWNER_SCENARIO", b.fmt("{d}", .{scenario}));
        };
        for ([_][]const u8{ "observer", "bridge", "session" }) |kind| {
            if (!chosen(selected, b.fmt("mapping-{s}", .{kind}))) continue;
            const fixture = suite.fixtures.get(b.fmt("mapping-{s}-{s}", .{ kind, configuration.name })).?;
            const session_scenarios = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 20, 21, 22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34 };
            const observer_scenarios = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 };
            const scenarios: []const u32 = if (std.mem.eql(u8, kind, "session")) &session_scenarios else if (std.mem.eql(u8, kind, "observer")) &observer_scenarios else &.{0};
            if (selected_scenario) |scenario| if (std.mem.indexOfScalar(u32, scenarios, scenario) == null) @panic("Scenario is outside the selected fixture");
            for (scenarios) |scenario| {
                if (selected_scenario != null and selected_scenario.? != scenario) continue;
                const run = regressionRun(b, all, loader, b.fmt("check mapping/{s}/{s}/{d}", .{ kind, configuration.name, scenario }));
                run.addArg(if (std.mem.eql(u8, kind, "session")) "session" else "mapping");
                run.addArtifactArg(fixture);
                run.addArg(b.fmt("{d}", .{scenario}));
            }
        }
    }
    const seh = b.addExecutable(.{ .name = "test_seh_guard", .root_module = module(b, target, .Debug, "src/zig/seh_guard_test.zig"), .use_llvm = true });
    if (chosen(selected, "seh_guard")) _ = regressionRun(b, all, seh, "check structured exceptions");
    const publication = b.addExecutable(.{ .name = "test_transition_publication", .root_module = module(b, target, .ReleaseSafe, "src/zig/lan_publication_test.zig"), .use_llvm = true });
    const publication_core = b.addLibrary(.{ .name = "publication-network-core", .linkage = .static, .root_module = module(b, target, .ReleaseSafe, "src/zig/dll_root.zig"), .use_llvm = true });
    publication.root_module.linkLibrary(publication_core);
    if (chosen(selected, "transition_publication")) _ = regressionRun(b, all, publication, "check transition publication");
}
fn gameExports(b: *std.Build, constructor_query: bool) std.Build.LazyPath {
    const io = b.graph.io;
    var directory = b.root.openDir(io, "src/zig", .{ .iterate = true }) catch @panic("Cannot read Zig sources");
    defer directory.close(io);
    b.dependOnDirectoryContents(b.path("src/zig"));
    var iterator = directory.iterate();
    var symbols: std.ArrayList([]const u8) = .empty;
    while (iterator.next(io) catch @panic("Cannot enumerate Zig sources")) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig") or std.mem.indexOf(u8, entry.name, "test") != null or std.mem.indexOf(u8, entry.name, "fixture") != null) continue;
        b.dependOnFileContents(b.path(b.fmt("src/zig/{s}", .{entry.name})));
        const source = directory.readFileAlloc(io, entry.name, b.allocator, .limited(1024 * 1024)) catch @panic("Cannot read Zig source");
        var tokens = std.mem.tokenizeAny(u8, source, " \t\r\n:=");
        while (tokens.next()) |token| {
            if (!std.mem.eql(u8, token, "export")) continue;
            const kind = tokens.next() orelse break;
            if (!std.mem.eql(u8, kind, "var") and !std.mem.eql(u8, kind, "const")) continue;
            const name = tokens.next() orelse break;
            if (!std.mem.startsWith(u8, name, "clonewars_") or (!constructor_query and std.mem.startsWith(u8, name, "clonewars_constructor_"))) continue;
            symbols.append(b.allocator, name) catch @panic("OOM");
        }
    }
    std.mem.sortUnstable([]const u8, symbols.items, {}, struct {
        fn less(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.order(u8, left, right) == .lt;
        }
    }.less);
    var definition: std.ArrayList(u8) = .empty;
    definition.appendSlice(b.allocator, "EXPORTS\n") catch @panic("OOM");
    var previous: []const u8 = "";
    for (symbols.items) |symbol| {
        if (std.mem.eql(u8, symbol, previous)) continue;
        definition.appendSlice(b.allocator, b.fmt("    {s}\n", .{symbol})) catch @panic("OOM");
        previous = symbol;
    }
    return b.addWriteFiles().add("game-exports.def", definition.items);
}
fn tracyLibrary(b: *std.Build, target: std.Build.ResolvedTarget) ?*std.Build.Step.Compile {
    const dependency = b.lazyDependency("tracy", .{}) orelse return null;
    const msvc = target.result.abi == .msvc;
    const tracy_module = b.createModule(.{ .target = target, .optimize = .ReleaseFast, .link_libc = true, .link_libcpp = !msvc });
    const flags: []const []const u8 = if (msvc)
        &.{ "-std=c++17", "-DTRACY_ENABLE", "-DTRACY_ON_DEMAND", "-DTRACY_ONLY_LOCALHOST", "-DTRACY_NO_SYSTEM_TRACING", "-fno-sanitize=undefined", "-D_MT", "-D_HAS_EXCEPTIONS=0", "-fno-exceptions", "-fno-rtti" }
    else
        &.{ "-std=c++17", "-DTRACY_ENABLE", "-DTRACY_ON_DEMAND", "-DTRACY_ONLY_LOCALHOST", "-DTRACY_NO_SYSTEM_TRACING", "-fno-sanitize=undefined" };
    tracy_module.addCSourceFile(.{ .file = dependency.path("tracy-0.14.1/public/TracyClient.cpp"), .flags = flags });
    if (msvc) tracy_module.linkSystemLibrary("libcpmt", .{ .use_pkg_config = .no });
    inline for (.{ "ws2_32", "dbghelp", "secur32" }) |library| tracy_module.linkSystemLibrary(library, .{ .use_pkg_config = .no });
    return b.addLibrary(.{ .name = "tracy", .linkage = .static, .root_module = tracy_module, .use_llvm = true });
}
