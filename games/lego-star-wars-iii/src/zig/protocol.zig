pub const SyncProfile = extern struct {
    epoch: u32,
    sequence: u32,
    level: i32,
    checksum: u32,
    data: [46528]u8,
};

pub const SyncLoading = extern struct {
    epoch: u32,
    level: i32,
    ready: u32,
    skip: u32,
    active: u32,
    elapsed: f32,
};

pub const SyncPreloadInput = extern struct {
    epoch: u32,
    level: i32,
    serial: u32,
    root_phase: u32,
    clock: u32,
    rng_game: u32,
    rng_engine: u32,
    rng_effects: u32,
    delta: f32,
    engine_delta: f32,
    engine_mode: u32,
    game_time: f32,
};

pub const SyncPreloadTrack = extern struct {
    witness: [2]u32,
    time: u32,
};

pub const SyncPreloadReceipt = extern struct {
    serial: u32,
    world_calls: u32,
    end_phase: u32,
    flow_count: u32,
    flow_requests: [64]u32,
    track_count: u32,
    tracks: [64]SyncPreloadTrack,
};

pub const SyncWorldReady = extern struct {
    epoch: u32,
    level: i32,
    root_phase: u32,
    completed_serial: u32,
    collider_count: u32,
    collider_roster: u32,
};

pub const SyncInput = extern struct {
    held: u32,
    pressed: u32,
    analog_x: u8,
    analog_y: u8,
    aim_x: u8,
    aim_y: u8,
};

pub const SyncAnimation = extern struct {
    frames: [5]f32,
    current: i16,
    flags: u16,
    clips: [5]i16,
    reserved: u16,
};

pub const SyncProjectileSeed = extern struct {
    cast_origin: [3]f32,
    age: f32,
    expires_at: f32,
    cast_countdown: f32,
};

pub const SyncShot = extern struct {
    id: u32,
    owner: i32,
    weapon: i32,
    owner_generation: u32,
    flags: u32,
    origin: [3]f32,
    transform: [16]f32,
    phase: u32,
    clock: u32,
    rng_game: u32,
    rng_engine: u32,
    delta: f32,
    has_launch_center: u32,
    launch_center: [3]f32,
    has_projectile_seed: u32,
    projectile_seed: SyncProjectileSeed,
    source: u8,
    depth: u8,
    reserved: u16,
    has_launch_motion: u32,
    launch_motion: [3]f32,
};

pub const SyncProjectile = extern struct {
    id: u32,
    transform: [32]f32,
    position: [3]f32,
    previous: [3]f32,
    velocity: [3]f32,
    direction: [3]f32,
    previous_direction: [3]f32,
    flight: [14]f32,
    flags: [3]u32,
    cast_origin: [3]f32,
};

pub const SyncSpawnSource = extern struct {
    producer: u32,
    serial: u32,
};

pub const SyncTagIdentity = extern struct {
    character: i32,
    spawn_tag: u32,
    spawn_source: SyncSpawnSource,
};

pub const SyncTag = extern struct {
    id: u32,
    parent: u32,
    from: i32,
    to: i32,
    from_generation: u32,
    to_generation: u32,
    arguments: [6]i32,
    clock: u32,
    rng_game: u32,
    rng_engine: u32,
    delta: f32,
    phase: u32,
    source: u32,
    from_identity: SyncTagIdentity,
    to_identity: SyncTagIdentity,
};

pub const SyncActorBody = extern struct {
    active: u32,
    position: [3]f32,
    velocity: [4]f32,
    floor_height: f32,
};

pub const SyncRigidBody = extern struct {
    active: u32,
    reserved: u32,
    transform: [16]f32,
};

pub const SyncActor = extern struct {
    slot: u32,
    generation: u32,
    spawn_tag: u32,
    player: i32,
    spawn_position: [3]f32,
    character: i32,
    flags: u32,
    position: [3]f32,
    previous_position: [3]f32,
    render_position: [3]f32,
    previous_render_position: [3]f32,
    velocity: [3]f32,
    heading: u16,
    render_heading: u16,
    health: i8,
    max_health: u8,
    party_slot: i16,
    wallet: u64,
    has_wallet: u32,
    animation: SyncAnimation,
    spawn_source: SyncSpawnSource,
    body: SyncActorBody,
    rigid_body: SyncRigidBody,
    motion_origin: [3]f32,
};

pub const SyncVariable = extern struct {
    name: [32]u8,
    scope: u32,
    value: f32,
};

pub const SyncActorInput = extern struct {
    slot: u32,
    generation: u32,
    spawn_tag: u32,
    character: i32,
    origin: [3]f32,
    held: u32,
    pressed: u32,
    spawn_source: SyncSpawnSource,
};

pub const SyncCadence = extern struct {
    slot: u32,
    generation: u32,
    spawn_tag: u32,
    character: i32,
    origin: [3]f32,
    period: u32,
    phase: u32,
    elapsed: f32,
    spawn_source: SyncSpawnSource,
};

pub const SyncCollider = extern struct {
    manager_ordinal: u32,
    slot: u32,
    generation: u32,
    spawn_tag: u32,
    character: i32,
    origin: [3]f32,
    bounds: [6]f32,
    center: [3]f32,
    extents: [2]f32,
    spawn_source: SyncSpawnSource,
};

pub const SyncItemRange = extern struct {
    target_slot: u32,
    target_generation: u32,
    heading: u16,
    reverse: u16,
    animation: i16,
    reserved: u16,
    actor_position: [3]f32,
    target_position: [3]f32,
    actor_radius: f32,
    target_radius: f32,
    reach: f32,
};

pub const SyncReactionHitOutcome = extern struct {
    completed: u32,
    health_before: i32,
    health_after: i32,
    life_before: u32,
    life_after: u32,
    action_before: i32,
    action_after: i32,
    timer_before: f32,
    timer_after: f32,
};

const ReactionClipValue = extern union {
    clip: i32,
    damage_draw: u32,
};

const ReactionClip = extern struct {
    selection: ReactionClipValue,
    source_id: u32,
    arena_attacker_slot: u32,
    arena_attacker_generation: u32,
    hit: SyncReactionHitOutcome,
};

const ReactionPayload = extern union {
    clip: ReactionClip,
    range: SyncItemRange,
};

pub const SyncReactionChoice = extern struct {
    slot: u32,
    generation: u32,
    spawn_tag: u32,
    character: i32,
    origin: [3]f32,
    old_action: i32,
    kind: u32,
    spawn_source: SyncSpawnSource,
    payload: ReactionPayload,
};

pub const SyncModelInputContext = extern struct {
    role_mask: u32,
    life_54: u32,
    axis_1dd: u32,
    provider_190_bit: u32,
    normalization_mode: u32,
    action: u32,
    substate_2fa: u32,
    c7c_block: u32,
    byte_110a: u32,
    c84_mask: u32,
    c00_present: u32,
    actor_76: u32,
    actor_1c8_mask: u32,
    override_c44: u32,
    override_c48: u32,
    resource_speed: [4]u32,
    motion_alternate: u32,
    resource_d8_bit: u32,
    actor_4c_mask: u32,
    c7c_1000: u32,
    cf4_raw: u32,
    model_42: u32,
    actor_309_mask: u32,
    global_e63e14_raw: u32,
    global_fbcb88_raw: u32,
    global_fc0e80: u32,
    numeric_cw: u32,
    numeric_mxcsr: u32,
};

pub const SyncModelInput = extern struct {
    slot: u32,
    generation: u32,
    spawn_tag: u32,
    character: i32,
    origin: [3]f32,
    native_clock: u32,
    input_x: f32,
    input_z: f32,
    input_mode: u32,
    period: u32,
    phase: u32,
    elapsed: f32,
    context: SyncModelInputContext,
    spawn_source: SyncSpawnSource,
};

pub const SyncSpawnTimer = extern struct {
    id: u32,
    type: u32,
    remaining: f32,
};

pub const SyncFireTaskState = extern struct {
    repeat: u32,
    timers: [4]f32,
    target: [3]f32,
    delta: f32,
};

pub const SyncAimTaskState = extern struct {
    target_slot: u32,
    target_generation: u32,
    rng_engine: u32,
    clock: u32,
    remaining: f32,
    minimum: f32,
    maximum: f32,
    task_class: u32,
    reserved: u32,
};

pub const SyncMeleeContact = extern struct { attacker_slot: u32, attacker_generation: u32, attack_pool_slot: u32, impact_time: f32 };

pub const SyncAimBaseState = extern struct {
    rng_engine: u32,
    rng_game: u32,
    clock: u32,
    task_class: u32,
    callback_class: u32,
    elapsed: f32,
    remaining: f32,
    delta: f32,
    reserved: u32,
};

pub const SyncForceQueryState = extern struct {
    caster_slot: u32,
    caster_generation: u32,
    mode: u32,
    clock: u32,
    reserved: [5]u32,
};

pub const SyncForceGeometryState = extern struct {
    caster_slot: u32,
    caster_generation: u32,
    mode: u32,
    clock: u32,
    caster_position: [3]f32,
    candidate_position: [3]f32,
    reserved: u32,
};

pub const SyncSpellItQueryState = extern struct {
    clock: u32,
    manager_class: u32,
    caller_site: u32,
    heading: u32,
    position: [3]f32,
    limit: f32,
    reserved: u32,
};

pub const SyncRtsCompetitorState = extern struct {
    rng_game: u32,
    rng_engine: u32,
    clock: u32,
    competitor_class: u32,
    delta: f32,
    timers: [12]f32,
};

pub const SYNC_SUPPORT_ABSENT: u32 = 0x20000;
pub const SYNC_SUPPORT_SCENE: u32 = 0x40000;
pub const SYNC_SUPPORT_VEHICLE: u32 = 0x80000;
pub const SyncCharacterMotionState = extern struct {
    clock: u32,
    body_class: u32,
    velocity: [4]f32,
    rest_counter: u32,
    support_frame: u32,
    support_event: u32,
    support_anchor: [4]f32,
    support_normal: [3]f32,
    support_material_flags: u32,
};

pub const SyncSpellItNodeState = extern struct {
    clock: u32,
    gizmo_class: u32,
    receiver_class: u32,
    resource_name: [4]u32,
    poi_ordinal: u32,
    poi_count: u32,
    poi_name: u32,
    component_class: u32,
    node_ordinal: u32,
    gizmo_ordinal: u32,
    position: [3]f32,
    reserved: u32,
};

pub const SyncScriptShootState = extern struct {
    clock: u32,
    model_class: u32,
    brain_class: u32,
    state_class: u32,
    brain_admission: u32,
    state_flags: u32,
    argument_count: u32,
    initialize: u32,
    caller_rva: u32,
    argument_hash: [4]u32,
    reserved: u32,
};

pub const SyncPrimaryPerceptionState = extern struct {
    clock: u32,
    target_slot: u32,
    target_generation: u32,
    target_tag: u32,
    target_character: i32,
    target_source: SyncSpawnSource,
    target_origin: [3]f32,
    distance: f32,
    target_visible: u32,
};

pub const SyncRiderFireState = extern struct { clock: u32, behavior_class: u32, mount_slot: u32, mount_generation: u32, cooldown: f32 };
pub const SyncBarcSuspensionState = extern struct { clock: u32, body_flags: u32, cache_index: u32 };
pub const SyncBarcAlignmentState = extern struct { clock: u32, body_flags: u32, basis: [9]f32 };
pub const SyncArenaRunRandomState = extern struct { clock: u32, behavior_class: u32, run_state: u32 };
const FireTaskPayload = extern union {
    storage: [68]u8,
    state: SyncFireTaskState,
    aim: SyncAimTaskState,
    competitor: SyncRtsCompetitorState,
    force: SyncForceQueryState,
    aim_base: SyncAimBaseState,
    tube_position: [3]f32,
    melee_contact: SyncMeleeContact,
    force_geometry: SyncForceGeometryState,
    spellit: SyncSpellItQueryState,
    character_motion: SyncCharacterMotionState,
    spellit_node: SyncSpellItNodeState,
    script_shoot: SyncScriptShootState,
    perception: SyncPrimaryPerceptionState,
    rider_fire: SyncRiderFireState,
    barc_alignment: SyncBarcAlignmentState,
    barc_suspension: SyncBarcSuspensionState,
    arena_run_random: SyncArenaRunRandomState,
};

pub const SyncFireTaskGate = extern struct {
    slot: u32,
    generation: u32,
    spawn_tag: u32,
    character: i32,
    origin: [3]f32,
    flags: u16,
    action: u16,
    value: i32,
    kind: u32,
    spawn_source: SyncSpawnSource,
    payload: FireTaskPayload,
};

pub const SyncRtsTeamTimers = extern struct {
    slot: u32,
    remaining: [3]f32,
};

pub const SyncSpawnTimerChoice = extern struct {
    kind: u32,
    owner: u32,
    selector: u32,
    serial: u32,
    remaining: f32,
};

pub const SyncPhysicsWorldInput = extern struct {
    clock: u32,
    value: u32,
    source_name: [4]u32,
    gizmo_class: u32,
    gizmo_ordinal: u32,
    resource_name: [4]u32,
    poi_name: [4]u32,
    poi_ordinal: u32,
    poi_count: u32,
    receiver_class: u32,
    piece_ordinal: u32,
};

pub const SyncPhysicsModuleInput = extern struct {
    clock: u32,
    value: u32,
    module_id: u32,
    module_type: u32,
    module_generation: u32,
    module_class: u32,
    burst_min: u32,
    burst_max: u32,
    channel_count: u32,
    weapon: i32,
    intervals: [3]f32,
    reserved: [7]u32,
};

pub const SyncPhysicsGunJamInput = extern struct {
    clock: u32,
    value: u32,
    module_id: u32,
    module_type: u32,
    module_generation: u32,
    member_count: u32,
    candidate_count: u32,
    clip: i32,
    remaining: f32,
    minimum: f32,
    maximum: f32,
    reserved: [9]u32,
};

pub const SyncPhysicsSpellItPoseInput = extern struct {
    clock: u32,
    position: [3]f32,
    source_name: [4]u32,
    gizmo_class: u32,
    gizmo_ordinal: u32,
    resource_name: [4]u32,
    poi_name: [4]u32,
    poi_ordinal: u16,
    piece_ordinal: u16,
    last_time: f32,
};

pub const SyncPhysicsSpellItStepInput = extern struct {
    clock: u32,
    engine_seed: u32,
    delta: f32,
    timer: f32,
    game_seed: u32,
    source_name: [4]u32,
    gizmo_class: u32,
    gizmo_ordinal: u32,
    reserved: [9]u32,
};

pub const SyncPhysicsSpellItSelectionInput = extern struct {
    clock: u32,
    engine_seed: u32,
    source_name: [4]u32,
    gizmo_class: u32,
    gizmo_ordinal: u32,
    candidate_count: u32,
    eligibility: [4]u32,
    piece_count: u32,
    reserved: [6]u32,
};

pub const SyncPhysicsSpellItBodyInput = extern struct {
    clock: u32,
    key: [4]u32,
    body_class: u32,
    piece_ordinal: u32,
    reserved: u32,
    values: [12]f32,
};

pub const SyncPhysicsVehicleRngInput = extern struct {
    clock: u32,
    value: u32,
    slot: u32,
    generation: u32,
    spawn_tag: u32,
    character: i32,
    spawn_source: SyncSpawnSource,
    vehicle_type: u32,
    reserved: [11]u32,
};

pub const SyncPhysicsBreakupBasisInput = extern struct {
    clock: u32,
    model: u32,
    name_hash: [2]u32,
    matrix: [16]f32,
};

pub const SyncPhysicsRtsOrderInput = extern struct {
    clock: u32,
    team_slot: u32,
    building_ordinal: u32,
    order_class: u32,
    state: u32,
    previous_state: u32,
    elapsed: f32,
    progress: f32,
    ready: u32,
    source_key: [4]u32,
    reserved: [7]u32,
};

pub const SyncPhysicsRtsGeneratorInput = extern struct {
    clock: u32,
    team_slot: u32,
    index: u32,
    side: u32,
    object_class: u32,
    state: u32,
    delta: f32,
    elapsed: f32,
    countdown: f32,
    phase_time: f32,
    previous_state: u32,
    rng_game: u32,
    rng_engine: u32,
    rng_effects: u32,
    timer_delta: f32,
    reserved: [5]u32,
};

const PhysicsBasic = extern struct {
    flags: u32,
    model: u32,
    clock: u32,
    name_hash: [2]u32,
    recipe: [6]u32,
    rng: u32,
};

const PhysicsPayload = extern union {
    basic: PhysicsBasic,
    world: SyncPhysicsWorldInput,
    module: SyncPhysicsModuleInput,
    gun_jam: SyncPhysicsGunJamInput,
    spellit_pose: SyncPhysicsSpellItPoseInput,
    spellit_step: SyncPhysicsSpellItStepInput,
    spellit_selection: SyncPhysicsSpellItSelectionInput,
    spellit_body: SyncPhysicsSpellItBodyInput,
    vehicle_rng: SyncPhysicsVehicleRngInput,
    breakup_basis: SyncPhysicsBreakupBasisInput,
    rts_order: SyncPhysicsRtsOrderInput,
    rts_generator: SyncPhysicsRtsGeneratorInput,
};

pub const SyncPhysicsChoice = extern struct {
    kind: u32,
    site: u32,
    payload: PhysicsPayload,
};

pub const SyncTickGate = extern struct {
    site: u32,
    clock: u32,
    value: u32,
};

pub const SyncProjectileRetireRequest = extern struct {
    id: u32,
    flags: u32,
    effects: i32,
    caller: u32,
};

pub const SyncFrame = extern struct {
    epoch: u32,
    sequence: u32,
    level: i32,
    clock: u32,
    rng_game: u32,
    rng_engine: u32,
    rng_game_after: u32,
    rng_engine_after: u32,
    delta: f32,
    engine_delta: f32,
    engine_mode: u32,
    world_calls: u32,
    tick_calls: u32,
    inputs: [2]SyncInput,
    actor_count: u32,
    variable_count: u32,
    shot_count: u32,
    projectile_count: u32,
    tag_count: u32,
    combat_ready: u32,
    actor_input_count: u32,
    numeric_cw: u32,
    cadence_count: u32,
    numeric_mxcsr: u32,
    geometry_count: u32,
    geometry_calls: u32,
    reaction_count: u32,
    reaction_reserved: u32,
    model_input_count: u32,
    model_input_reserved: u32,
    checksum: u32,
    native_span_plan: u32,
    native_span_calls: u32,
    spawn_timer_count: u32,
    spawn_timer_reserved: u32,
    fire_task_gate_count: u32,
    fire_task_gate_reserved: u32,
    rts_team_timer_count: u32,
    spawn_timer_choice_count: u32,
    physics_choice_count: u32,
    projectile_retire_count: u32,
    tick_gate_count: u32,
    tick_gate_reserved: u32,
    dormant_party: [8]u16,
    actors: [4096]SyncActor,
    variables: [1024]SyncVariable,
    shots: [128]SyncShot,
    projectiles: [512]SyncProjectile,
    tags: [16]SyncTag,
    actor_inputs: [4096]SyncActorInput,
    cadence: [4096]SyncCadence,
    geometry: [4096]SyncCollider,
    reactions: [4096]SyncReactionChoice,
    model_inputs: [4096]SyncModelInput,
    spawn_timers: [192]SyncSpawnTimer,
    fire_task_gates: [4096]SyncFireTaskGate,
    rts_team_timers: [8]SyncRtsTeamTimers,
    spawn_timer_choices: [224]SyncSpawnTimerChoice,
    physics_choices: [1024]SyncPhysicsChoice,
    tick_gates: [SYNC_MAX_TICK_GATES]SyncTickGate,
    projectile_retires: [512]SyncProjectileRetireRequest,
};

pub const SYNC_SHOT_WEAPON: c_int = 0;

pub const SYNC_SHOT_ACTOR_FOLLOWUP: c_int = 1;

pub const SYNC_SHOT_PROJECTILE_CHILD: c_int = 2;

pub const enum_SyncShotSource = c_int;

pub const SYNC_TAG_UNSCOPED: c_int = 0;

pub const SYNC_TAG_ACTOR_UPDATE: c_int = 1;

pub const SYNC_VARIABLE_GLOBAL: c_int = 0;

pub const SYNC_VARIABLE_AREA: c_int = 1;

pub const SYNC_VARIABLE_AREA_DECLARATION: c_int = 2;

pub const enum_SyncVariableScope = c_int;

pub const SYNC_REACTION_CLIP: c_int = 0;

pub const SYNC_REACTION_DAMAGE_DRAW: c_int = 1;

pub const SYNC_REACTION_ITEM_RANGE: c_int = 2;

pub const enum_SyncReactionKind = c_int;

pub const SYNC_FIRE_TASK_VISIBILITY: c_int = 0;

pub const SYNC_FIRE_ATTACK_SUPPORT: c_int = 1;

pub const SYNC_ACTOR_BREAKUP_VISIBILITY: c_int = 2;

pub const SYNC_ACTOR_DEATH_BREAKUP: c_int = 3;

pub const SYNC_ACTOR_FALL_VISIBILITY: c_int = 4;

pub const SYNC_ACTOR_AIM_TASK: c_int = 5;

pub const SYNC_ACTOR_RTS_COMPETITOR: c_int = 6;

pub const SYNC_ACTOR_FORCE_VISIBILITY: c_int = 7;

pub const SYNC_ACTOR_AIM_BASE: c_int = 8;

pub const SYNC_ACTOR_FORCE_GEOMETRY: c_int = 9;

pub const SYNC_ACTOR_SPELLIT_QUERY: c_int = 10;

pub const SYNC_ACTOR_CHARACTER_MOTION: c_int = 11;

pub const SYNC_ACTOR_SPELLIT_NODE: c_int = 12;

pub const SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY: c_int = 13;

pub const SYNC_ACTOR_PRIMARY_PERCEPTION: c_int = 14;
pub const SYNC_ACTOR_SPELLIT_ADMISSION: c_int = 15;
pub const SYNC_ACTOR_HAZARD_DEATH: c_int = 16;
pub const SYNC_ACTOR_RIDER_FIRE: c_int = 17;
pub const SYNC_ACTOR_ARENA_RUN_RANDOM: c_int = 18;
pub const SYNC_ACTOR_BARC_ALIGNMENT: c_int = 19;
pub const SYNC_ACTOR_BARC_SUSPENSION: c_int = 20;
pub const SYNC_ACTOR_RYLOTH_FIGHTER_DEATH: c_int = 21;
pub const SYNC_ACTOR_FORCE_ELIGIBILITY: c_int = 22;
pub const SYNC_ACTOR_TUBE_CONTACT: c_int = 23;
pub const SYNC_ACTOR_MELEE_CONTACT: c_int = 24;
pub const SYNC_TRANSITION_NATIVE_CYCLE: u32 = 2;

pub const enum_SyncFireGateKind = c_int;

pub const SYNC_SCRIPT_SHOOT_MAX_ARGUMENTS: c_int = 256;

pub const SYNC_SPAWN_TIMER_RTS: c_int = 0;

pub const SYNC_SPAWN_TIMER_MODULE: c_int = 1;

pub const enum_SyncSpawnTimerChoiceKind = c_int;

pub const SYNC_PHYSICS_AXIS_SPIN: c_int = 1;

pub const SYNC_PHYSICS_ROTATION_SPIN: c_int = 2;

pub const SYNC_PHYSICS_BREAKUP_LAUNCH: c_int = 3;

pub const SYNC_PHYSICS_SPELLIT_SEED: c_int = 4;

pub const SYNC_PHYSICS_SPELLIT_ENTITY: c_int = 5;

pub const SYNC_PHYSICS_SPELLIT_ENABLED: c_int = 6;

pub const SYNC_PHYSICS_MODULE_SEED: c_int = 7;

pub const SYNC_PHYSICS_GUN_JAM_SEED: c_int = 8;

pub const SYNC_PHYSICS_SPELLIT_POSE: c_int = 9;

pub const SYNC_PHYSICS_SPELLIT_STEP: c_int = 10;

pub const SYNC_PHYSICS_SPELLIT_SELECTION: c_int = 11;

pub const SYNC_PHYSICS_SPELLIT_BODY_BASIS: c_int = 12;

pub const SYNC_PHYSICS_SPELLIT_BODY_MOTION: c_int = 13;

pub const SYNC_PHYSICS_VEHICLE_RNG: c_int = 14;

pub const SYNC_PHYSICS_BREAKUP_BASIS: c_int = 15;

pub const SYNC_PHYSICS_BREAKUP_SCALE: c_int = 16;

pub const SYNC_PHYSICS_EFFECT_BIRTH: c_int = 17;

pub const SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS: c_int = 18;

pub const SYNC_PHYSICS_RTS_ORDER: c_int = 19;

pub const SYNC_PHYSICS_RTS_GENERATOR: c_int = 20;

pub const SYNC_PHYSICS_RTS_BODY_BASIS: c_int = 21;

pub const SYNC_PHYSICS_RTS_BODY_MOTION: c_int = 22;

pub const SYNC_PHYSICS_RTS_VISIBILITY: c_int = 23;

pub const SYNC_PHYSICS_EFFECT_STEP: c_int = 24;
pub const SYNC_PHYSICS_EFFECT_REST: c_int = 25;

pub const enum_SyncPhysicsChoiceKind = c_int;

pub const SYNC_MAX_ACTORS = @as(c_int, 4096);

pub const SYNC_MAX_VARIABLES = @as(c_int, 1024);

pub const SYNC_MAX_SHOTS = @as(c_int, 128);

pub const SYNC_MAX_PHYSICS_CHOICES = @as(c_int, 1024);

pub const SYNC_MAX_TICK_GATES = SYNC_MAX_ACTORS * @as(c_int, 16);

pub const SYNC_MAX_PROJECTILES = @as(c_int, 512);

pub const SYNC_MAX_TAGS = @as(c_int, 16);

pub const SYNC_MAX_SPAWN_TIMERS = @as(c_int, 192);

pub const SYNC_MAX_RTS_TEAMS = @as(c_int, 8);

pub const SYNC_MAX_SPAWN_TIMER_CHOICES = SYNC_MAX_SPAWN_TIMERS + (SYNC_MAX_RTS_TEAMS * @as(c_int, 4));

pub const SYNC_QUEUE_SIZE = @as(c_int, 64);

pub const SYNC_PROFILE_BYTES = @as(c_int, 0xb5c0);

pub const SYNC_LAYOUT_VERSION = @as(c_int, 55);

pub const SYNC_WIRE_VERSION = @as(c_int, 216);

pub const SYNC_NATIVE_SPAN_PLAN_MASK = @as(c_uint, 7);

pub const SYNC_NATIVE_SPAN_MAIN_CALL = @as(c_uint, 1);

pub const SYNC_NATIVE_SPAN_OPTIONAL_CALL = @as(c_uint, 2);

pub const SYNC_NATIVE_SPAN_CALLS_MASK = @as(c_uint, 3);

pub const SYNC_FIRE_TASK_QUEUES_SHOT = @as(c_uint, 0x40);

pub const SYNC_PROTOCOL_VERSION = SYNC_WIRE_VERSION;

pub const SYNC_MAX_PRELOAD_FLOW_REQUESTS = @as(c_int, 64);
