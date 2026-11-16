const g = @import("gizmo_types.zig");
pub const Generator = extern struct { object: usize, team: usize, descriptor: usize, resource: usize, world: usize, engine: usize, team_slot: u32, index: u32, side: u32, object_class: u32 };
pub const Order = extern struct { order: usize, building: usize, team: usize, descriptor: usize, team_slot: u32, building_ordinal: u32, order_class: u32, gizmo: g.Source };
pub const Body = extern struct { object: usize, pad: usize, team: usize, world: usize, model: usize, receiver: usize, body: usize, dynamics: usize, ordinal: u32, body_class: u32, key: [4]u32, pad_source: g.Source };
pub const Object = extern struct { object: usize, pad: usize, team: usize, world: usize, ordinal: u32, object_class: u32, key: [4]u32, pad_source: g.Source };
