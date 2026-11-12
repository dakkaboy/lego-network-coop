#undef NDEBUG
#include <assert.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdio.h>
#include "net/sync_wire.h"
#include "sync/shot_context.h"
#include "sync/physics_input_sync.h"
#include "sync/native_tick_sync.h"
_Static_assert(sizeof(SyncActor)==280,"Actor wire layout changed");
_Static_assert(offsetof(SyncActor,rigid_body)==196,"Native rigid body wire offset changed");
_Static_assert(offsetof(SyncActor,party_slot)==102,"Party slot must use defined padding");
_Static_assert(sizeof(SyncTagIdentity)==16,"Tag identity wire layout changed");
_Static_assert(sizeof(SyncTag)==104,"Tag command wire layout changed");
static void world_physics_inputs(void) {
    SyncFrame *frame=calloc(1,sizeof(*frame)),*decoded=calloc(1,sizeof(*decoded));
    unsigned char *wire=malloc(sizeof(*frame));
    assert(frame && decoded && wire);
    frame->epoch=1;frame->sequence=1;frame->level=6;frame->delta=.016f;
    frame->physics_choice_count=3;
    SyncPhysicsChoice *seed=frame->physics_choices,*entity=seed+1,*enabled=seed+2;
    seed->kind=SYNC_PHYSICS_SPELLIT_SEED;seed->site=0x86101e;
    seed->world=(SyncPhysicsWorldInput){.clock=UINT32_MAX,.value=0xfedcba98,
        .source_name={1,2,3,4},.gizmo_class=0x8480ac,.gizmo_ordinal=65535};
    *entity=*seed;entity->kind=SYNC_PHYSICS_SPELLIT_ENTITY;entity->site=0x8407d4;
    entity->world.value=1;entity->world.resource_name[0]=17;entity->world.poi_name[3]=19;
    entity->world.poi_count=65536;entity->world.poi_ordinal=65535;
    entity->world.piece_ordinal=65535;entity->world.receiver_class=0x820f64;
    *enabled=*entity;enabled->kind=SYNC_PHYSICS_SPELLIT_ENABLED;enabled->site=0x84085b;
    size_t size=sync_frame_encode(frame,wire,sizeof(*frame));
    assert(size && sync_frame_decode(decoded,wire,size));
    assert(!memcmp(frame->physics_choices,decoded->physics_choices,3*sizeof(*seed)));
    SyncPhysicsChoice different=*entity;different.world.value=0;
    assert(physics_choice_same_source(entity,&different));
    different.world.poi_ordinal=65534;assert(!physics_choice_same_source(entity,&different));
    different=*entity;different.world.source_name[3]^=1;assert(!physics_choice_same_source(entity,&different));
    different=*entity;different.world.receiver_class^=1;assert(!physics_choice_same_source(entity,&different));
    entity->world.value=2;assert(!sync_frame_valid(frame,sync_frame_size(frame)));entity->world.value=1;
    entity->world.poi_ordinal=65536;assert(!sync_frame_encode(frame,wire,sizeof(*frame)));entity->world.poi_ordinal=65535;
    entity->world.poi_count=65537;assert(!physics_choice_valid(entity));entity->world.poi_count=65536;
    entity->world.piece_ordinal=65536;assert(!physics_choice_valid(entity));entity->world.piece_ordinal=65535;
    enabled->site=entity->site;assert(!physics_choice_valid(enabled));enabled->site=0x84085b;
    seed->world.receiver_class=1;assert(!physics_choice_valid(seed));seed->world.receiver_class=0;
    seed->world.resource_name[3]=1;assert(!physics_choice_valid(seed));seed->world.resource_name[3]=0;
    seed->world.gizmo_ordinal=65536;assert(!physics_choice_valid(seed));seed->world.gizmo_ordinal=65535;
    different=(SyncPhysicsChoice){.kind=SYNC_PHYSICS_AXIS_SPIN,.site=0x7425c3,
        .flags=0x40000091,.model=1,.name_hash={12,34}};
    assert(physics_choice_valid(&different));
    ((unsigned char *)&different)[sizeof(different)-1]=1;assert(!physics_choice_valid(&different));
    frame->physics_choice_count=4;
    SyncPhysicsChoice *pose=frame->physics_choices+3;
    *pose=(SyncPhysicsChoice){.kind=SYNC_PHYSICS_SPELLIT_POSE,.site=0x8406b2,
        .spellit_pose={.clock=32,.position={340.76535f,44.27975f,47.423156f},
            .source_name={1,2,3,4},.gizmo_class=0x8480ac,.gizmo_ordinal=3,
            .resource_name={5,6,7,8},.poi_name={9,10,11,12},.poi_ordinal=265,.piece_ordinal=8}};
    size=sync_frame_encode(frame,wire,sizeof(*frame));assert(size && sync_frame_decode(decoded,wire,size));
    assert(sizeof(SyncPhysicsSpellItPoseInput)==80 && !memcmp(pose,decoded->physics_choices+3,sizeof(*pose)));
    different=*pose;different.spellit_pose.position[2]=nextafterf(pose->spellit_pose.position[2],-INFINITY);
    different.spellit_pose.last_time=123;assert(physics_choice_same_source(pose,&different));
    ++different.spellit_pose.piece_ordinal;assert(!physics_choice_same_source(pose,&different));
    for(unsigned axis=0;axis<3;++axis) {
        different=*pose;different.spellit_pose.position[axis]=NAN;assert(!physics_choice_valid(&different));
        different.spellit_pose.position[axis]=INFINITY;assert(!physics_choice_valid(&different));
    }
    frame->physics_choice_count=5;SyncPhysicsChoice *step=frame->physics_choices+4;
    *step=(SyncPhysicsChoice){.kind=SYNC_PHYSICS_SPELLIT_STEP,.site=0x86101e,
        .spellit_step={.clock=42,.engine_seed=12345,.game_seed=23456,.delta=.016f,.timer=-.004f,
            .source_name={1,2,3,4},.gizmo_class=0x8480ac,.gizmo_ordinal=3}};
    size=sync_frame_encode(frame,wire,sizeof(*frame));assert(size && sync_frame_decode(decoded,wire,size));
    assert(sizeof(SyncPhysicsSpellItStepInput)==80 && !memcmp(step,decoded->physics_choices+4,sizeof(*step)));
    different=*step;different.spellit_step.delta=.017f;different.spellit_step.timer=1;
    different.spellit_step.engine_seed=5;different.spellit_step.game_seed=6;
    assert(physics_choice_same_source(step,&different));
    ++different.spellit_step.gizmo_ordinal;assert(!physics_choice_same_source(step,&different));
    different=*step;different.spellit_step.timer=NAN;assert(!physics_choice_valid(&different));
    different=*step;different.spellit_step.delta=INFINITY;assert(!physics_choice_valid(&different));
    different=*step;different.spellit_step.game_seed=65536;assert(!physics_choice_valid(&different));
    different=*step;different.spellit_step.reserved[8]=1;assert(!physics_choice_valid(&different));
    free(wire);free(decoded);free(frame);
}
static void breakup_launch_motion(void) {
    const uint32_t observed[22]={3,9461560,1073741840,382,1322,536967224,2001786700,
        513,0,1082130432,791994746,1084788834,2934384681,61924};
    SyncPhysicsChoice local,expected;
    memcpy(&local,observed,sizeof local);expected=local;
    expected.recipe[3]=800383354;expected.recipe[5]=2942773289;
    assert(physics_choice_valid(&local) && physics_choice_valid(&expected));
    assert(physics_choice_same_source(&local,&expected));
    unsigned char descriptor[0x30],original[0x30];
    memset(original,0x5a,sizeof original);memcpy(original+8,local.recipe,sizeof local.recipe);
    memcpy(descriptor,original,sizeof descriptor);
    assert(physics_breakup_launch_replay(descriptor,&local,&expected));
    assert(!memcmp(descriptor+0x10,expected.recipe+2,16));
    assert(!memcmp(descriptor,original,0x10) && !memcmp(descriptor+0x20,original+0x20,0x10));
    for (unsigned field=0;field<9;++field) {
        SyncPhysicsChoice wrong=expected;
        uint32_t *identity[]={&wrong.kind,&wrong.site,&wrong.flags,&wrong.model,&wrong.clock,
            &wrong.name_hash[0],&wrong.name_hash[1],&wrong.recipe[0],&wrong.recipe[1]};
        *identity[field]^=1;memcpy(descriptor,original,sizeof descriptor);
        assert(!physics_breakup_launch_replay(descriptor,&local,&wrong));
        assert(!memcmp(descriptor,original,sizeof descriptor));
    }
    for (unsigned field=2;field<6;++field) {
        SyncPhysicsChoice wrong=expected;wrong.recipe[field]=0x7fc00000;
        assert(!physics_choice_valid(&wrong));
        memcpy(descriptor,original,sizeof descriptor);
        assert(!physics_breakup_launch_replay(descriptor,&local,&wrong));
        assert(!memcmp(descriptor,original,sizeof descriptor));
        wrong.recipe[field]=0x7f800000;assert(!physics_choice_valid(&wrong));
    }
    local.kind=expected.kind=SYNC_PHYSICS_AXIS_SPIN;
    local.site=expected.site=0x7425c3;local.flags=expected.flags=0x40000080;
    assert(!physics_choice_same_source(&local,&expected));
}
static void breakup_geometry_inputs(void) {
    assert(sizeof(SyncPhysicsBreakupBasisInput)==80 && sizeof(SyncPhysicsChoice)==88);
    SyncFrame *frame=calloc(1,sizeof *frame),*decoded=calloc(1,sizeof *decoded);unsigned char *wire=malloc(sizeof *frame);
    frame->epoch=2;frame->sequence=71;frame->level=41;frame->physics_choice_count=2;
    SyncPhysicsChoice *basis=&frame->physics_choices[0],*scale=&frame->physics_choices[1];
    *basis=(SyncPhysicsChoice){.kind=SYNC_PHYSICS_BREAKUP_BASIS,.site=0x905f38,
        .breakup_basis={.clock=73,.model=184,.name_hash={123,456},.matrix={1,0,0,0,0,1,0,0,0,0,1,0,155.8f,132.6f,38.7f,1}}};
    *scale=(SyncPhysicsChoice){.kind=SYNC_PHYSICS_BREAKUP_SCALE,.site=0x905f38,
        .flags=0x40000010,.clock=73,.model=184,.name_hash={123,456}};
    const float native_scale[3]={1,.5f,2};memcpy(scale->recipe,native_scale,sizeof native_scale);
    SyncPhysicsChoice local_basis=*basis,local_scale=*scale;local_basis.breakup_basis.matrix[13]=132.7f;
    float matrix[16],size[3];memset(matrix,0xa5,sizeof matrix);memset(size,0xa5,sizeof size);
    assert(physics_breakup_geometry_replay(matrix,size,&local_basis,&local_scale,basis,scale));
    assert(!memcmp(matrix,basis->breakup_basis.matrix,sizeof matrix) && !memcmp(size,native_scale,sizeof size));
    size_t n=sync_frame_encode(frame,wire,sizeof *frame);assert(n && sync_frame_decode(decoded,wire,n));
    assert(!memcmp(frame->physics_choices,decoded->physics_choices,2*sizeof *basis));
    for(unsigned axis=0;axis<16;++axis){SyncPhysicsChoice bad=*basis;bad.breakup_basis.matrix[axis]=NAN;assert(!physics_choice_valid(&bad));}
    for(unsigned axis=0;axis<3;++axis){SyncPhysicsChoice bad=*scale;float invalid=INFINITY;memcpy(bad.recipe+axis,&invalid,4);assert(!physics_choice_valid(&bad));}
    for(unsigned field=0;field<6;++field){
        SyncPhysicsChoice bad=*basis;uint32_t *identity[]={&bad.kind,&bad.site,&bad.breakup_basis.clock,&bad.breakup_basis.model,&bad.breakup_basis.name_hash[0],&bad.breakup_basis.name_hash[1]};
        ++*identity[field];float before[16];memcpy(before,matrix,sizeof before);
        assert(!physics_breakup_geometry_replay(matrix,size,&local_basis,&local_scale,&bad,scale));assert(!memcmp(before,matrix,sizeof before));
    }
    local_scale.clock++;assert(!physics_breakup_geometry_replay(matrix,size,&local_basis,&local_scale,basis,scale));
    free(wire);free(decoded);free(frame);
}
static void vehicle_rng_inputs(void) {
    _Static_assert(sizeof(SyncPhysicsVehicleRngInput)==80,"vehicle RNG input size");
    _Static_assert(SYNC_PROTOCOL_VERSION<=UINT8_MAX,"LAN version must fit its handshake byte");
    _Static_assert((SYNC_WIRE_VERSION^128)!=SYNC_WIRE_VERSION,"trace and release must differ");
    SyncFrame *frame=calloc(1,sizeof *frame),*decoded=calloc(1,sizeof *decoded);
    unsigned char *wire=malloc(sizeof *frame);assert(frame && decoded && wire);
    frame->epoch=2;frame->sequence=5416;frame->level=41;frame->delta=.06666667f;frame->physics_choice_count=1;
    const uint32_t sites[]={0x997f03,0x997f14,0x997f25,0x99803e,0x998085,0x9980b4,0x99813e,0x9981cf,0x998288,0x9982b7,0x9982ee};
    for (unsigned i=0;i<sizeof sites/sizeof *sites;++i) {
        SyncPhysicsChoice *p=frame->physics_choices;
        *p=(SyncPhysicsChoice){.kind=SYNC_PHYSICS_VEHICLE_RNG,.site=sites[i],
            .vehicle_rng={.clock=5418,.value=3338446660u,.slot=5,.generation=229,.spawn_tag=0xcb8c1,
                .character=381,.spawn_source={1,1},.vehicle_type=4}};
        const size_t bytes=sync_frame_encode(frame,wire,sizeof *frame);
        assert(bytes && sync_frame_decode(decoded,wire,bytes));
        assert(!memcmp(p,decoded->physics_choices,sizeof *p));
        SyncPhysicsChoice altered=*p;altered.vehicle_rng.value=1325471230;
        assert(physics_choice_same_source(p,&altered));
        for (unsigned field=0;field<8;++field) {
            altered=*p;
            uint32_t *identity[]={&altered.vehicle_rng.clock,&altered.vehicle_rng.slot,&altered.vehicle_rng.generation,
                &altered.vehicle_rng.spawn_tag,(uint32_t *)&altered.vehicle_rng.character,
                &altered.vehicle_rng.spawn_source.producer,&altered.vehicle_rng.spawn_source.serial,&altered.vehicle_rng.vehicle_type};
            ++*identity[field];assert(!physics_choice_same_source(p,&altered));
        }
        altered=*p;altered.vehicle_rng.slot=SYNC_MAX_ACTORS;assert(!physics_choice_valid(&altered));
        altered=*p;altered.vehicle_rng.generation=0;assert(!physics_choice_valid(&altered));
        altered=*p;altered.vehicle_rng.character=-1;assert(!physics_choice_valid(&altered));
        for(unsigned j=0;j<11;++j){altered=*p;altered.vehicle_rng.reserved[j]=1;assert(!physics_choice_valid(&altered));}
        altered=*p;++altered.site;assert(!physics_choice_valid(&altered));
    }
    free(wire);free(decoded);free(frame);
}
int main(void) {
    breakup_launch_motion();
    breakup_geometry_inputs();
    vehicle_rng_inputs();
    world_physics_inputs();
    SyncFrame *input=calloc(1,sizeof(*input)),*output=calloc(1,sizeof(*output));
    unsigned char *wire=malloc(sizeof(*input));
    assert(input && output && wire);
    input->epoch=7; input->sequence=1; input->level=6; input->delta=1.0f/60;
    input->engine_delta=.017f; input->world_calls=1; input->tick_calls=1;
    input->physics_choice_count=3;
    input->physics_choices[0]=(SyncPhysicsChoice){.kind=SYNC_PHYSICS_AXIS_SPIN,.site=0x7425c3,.flags=0x40000091,.model=65535,.clock=1550,.name_hash={123,456},.rng=1744529096};
    input->physics_choices[1]=input->physics_choices[0];input->physics_choices[1].rng=111477372;
    input->physics_choices[2]=input->physics_choices[0];
    input->physics_choices[2].kind=SYNC_PHYSICS_BREAKUP_LAUNCH;
    input->physics_choices[2].site=0x905f38;input->physics_choices[2].flags=0x40000000;
    input->geometry_calls=1;input->geometry_count=2;
    input->tick_gate_count=2;
    input->tick_gates[0]=(SyncTickGate){.site=0x8888cd,.clock=14313,.value=1};
    input->tick_gates[1]=(SyncTickGate){.site=0x8888cd,.clock=14314,.value=0};
    input->geometry[0]=(SyncCollider){.manager_ordinal=1,.slot=0,.generation=12,.character=360,.bounds={-1,-1,-1,1,1,1},.extents={.5f,1}};
    input->geometry[1]=input->geometry[0];input->geometry[1].slot=5;input->geometry[1].generation=17;input->geometry[1].character=321;
    input->cadence_count=1;
    input->cadence[0]=(SyncCadence){.slot=5,.generation=17,.character=321,.period=8,.phase=5,.elapsed=.05f};
    input->reaction_count=4;
    input->reactions[0]=(SyncReactionChoice){.slot=6,.generation=26,.spawn_tag=123,.character=321,.old_action=-1,.clip=975,.source_id=667};
    input->reactions[1]=input->reactions[0];input->reactions[1].old_action=20;input->reactions[1].clip=-1;
    input->reactions[2]=input->reactions[0];
    input->reactions[2].kind=SYNC_REACTION_DAMAGE_DRAW;
    input->reactions[2].damage_draw=27742;
    input->reactions[3]=(SyncReactionChoice){.slot=1,.generation=13,.character=152,.old_action=102,
        .kind=SYNC_REACTION_ITEM_RANGE,.range={.target_slot=6,.target_generation=26,.heading=8108,
        .animation=921,.actor_position={4,-.25f,-3},.target_position={4.2f,-.25f,-2.8f},
        .actor_radius=.1f,.target_radius=.1f,.reach=.1f}};
    input->actor_input_count=2;
    input->actor_inputs[0]=(SyncActorInput){.slot=15,.generation=27,.spawn_tag=123,.character=321,.pressed=0x8000};
    input->actor_inputs[1]=input->actor_inputs[0]; input->actor_inputs[1].pressed=0;
    input->actor_count=2; input->variable_count=3; input->shot_count=3; input->projectile_count=2;
    input->actors[0].party_slot=0; input->actors[1].party_slot=1;
    input->rng_game_after=123; input->rng_engine_after=456;
    input->tag_count=1; input->tags[0]=(SyncTag){.id=1,.from=0,.to=1,.from_generation=7,.to_generation=8,.phase=1,.delta=.016f};
    input->tags[0].from_identity=(SyncTagIdentity){.character=329,.spawn_tag=0x5c5ef6,.spawn_source={1,0}};
    input->tags[0].to_identity=(SyncTagIdentity){.character=189,.spawn_tag=0x5c5ce6,.spawn_source={2,1}};
    input->actors[0].generation=7; input->actors[0].player=0;
    input->actors[1].generation=8; input->actors[1].player=1;
    input->inputs[1].aim_x=13; input->inputs[1].aim_y=219;
    input->actors[1].spawn_tag=0x5c5cff; input->actors[1].spawn_source=(SyncSpawnSource){0xf29a3889,17}; input->actors[1].spawn_position[2]=3.5f;
    input->actors[1].slot=1; input->actors[1].animation.current=100;
    input->actors[1].animation.frames[3]=19.5f;
    input->actors[1].animation.clips[2]=-1;
    input->actors[1].position[1]=1;
    const uint32_t native_motion_origin[]={0x431d103b,0x4304a96d,0x420c9113};
    memcpy(input->actors[1].motion_origin,native_motion_origin,sizeof native_motion_origin);
    input->actors[1].body=(SyncActorBody){.active=1,.position={1,.078638f,-3},.velocity={.1f,-.25f,.2f,0},.floor_height=.080519f};
    input->actors[1].rigid_body=(SyncRigidBody){.active=1,.transform={0,0,1,0,0,1,0,0,-1,0,0,0,12,3,-5,1}};
    input->actors[1].previous_position[1]=.5f;
    input->actors[1].render_position[1]=2;
    input->actors[1].previous_render_position[1]=1.5f;
    input->actors[1].velocity[1]=3;
    input->actors[1].render_heading=1234;
    input->combat_ready=1;
    strcpy(input->variables[0].name,"QuestDoor"); input->variables[0].value=1;
    input->variables[1]=input->variables[0];
    input->variables[1].scope=SYNC_VARIABLE_AREA;
    input->variables[1].value=2;
    input->variables[2]=input->variables[0];
    input->variables[2].scope=SYNC_VARIABLE_AREA_DECLARATION;
    input->variables[2].value=3;
    input->shots[0].phase=1; input->shots[0].clock=77; input->shots[0].rng_game=123; input->shots[0].rng_engine=456; input->shots[0].delta=.015f;
    input->shots[0].id=42; input->shots[0].owner=1; input->shots[0].owner_generation=8; input->shots[0].weapon=7;
    input->shots[0].origin[0]=12.25f; input->shots[0].transform[15]=1;
    input->shots[0].has_launch_center=1;
    input->shots[0].launch_center[0]=12.125f;
    input->shots[0].launch_center[1]=.125f;
    input->shots[0].launch_center[2]=-3.5f;
    input->shots[0].has_projectile_seed=1;
    input->shots[0].projectile_seed=(SyncProjectileSeed){
        .cast_origin={12.5f,1.25f,-3.5f},.age=.015f,.expires_at=2,.cast_countdown=.03f
    };
    input->shots[1]=(SyncShot){.id=43,.owner=1,.owner_generation=8,.weapon=7,.source=SYNC_SHOT_ACTOR_FOLLOWUP,
        .has_launch_motion=1,.launch_motion={0.25f,-0.5f,0.75f}};
    input->shots[2]=(SyncShot){.id=44,.owner=-1,.weapon=7,.source=SYNC_SHOT_PROJECTILE_CHILD,.depth=2};
    input->projectiles[0].id=41; input->projectiles[1].id=42;
    input->projectiles[1].velocity[2]=6.75f;
    input->projectiles[1].cast_origin[2]=-4.75f;
    input->fire_task_gate_count=8;
    input->fire_task_gates[0]=(SyncFireTaskGate){
        .slot=5,.generation=17,.character=321,.origin={1,2,3},
        .flags=SYNC_FIRE_TASK_QUEUES_SHOT,.action=92,.value=1,
        .state={.repeat=2,.timers={.5f,-.01f,.2f,.1f},.target={-1,2,3},.delta=.017f}
    };
    input->fire_task_gates[1]=input->fire_task_gates[0];
    input->fire_task_gates[1].value=0;
    input->fire_task_gates[2]=input->fire_task_gates[0];
    input->fire_task_gates[2].kind=SYNC_FIRE_ATTACK_SUPPORT;
    input->fire_task_gates[2].flags=0;
    input->fire_task_gates[2].action=0;
    input->fire_task_gates[2].value=-3;
    input->fire_task_gates[2].state=(SyncFireTaskState){0};
    input->fire_task_gates[3]=input->fire_task_gates[2];
    input->fire_task_gates[3].kind=SYNC_ACTOR_BREAKUP_VISIBILITY;
    input->fire_task_gates[3].value=1;
    input->fire_task_gates[4]=input->fire_task_gates[3];
    input->fire_task_gates[4].kind=SYNC_ACTOR_DEATH_BREAKUP;
    input->fire_task_gates[5]=input->fire_task_gates[3];
    input->fire_task_gates[5].kind=SYNC_ACTOR_FALL_VISIBILITY;
    input->fire_task_gates[6]=input->fire_task_gates[3];
    input->fire_task_gates[6].kind=SYNC_ACTOR_AIM_TASK;
    input->fire_task_gates[6].aim=(SyncAimTaskState){.target_slot=1,.target_generation=8,
        .rng_engine=0xf1234567,.clock=1550,.remaining=-.016f,.minimum=.5f,.maximum=1.5f,.task_class=0x721234};
    input->fire_task_gates[7]=input->fire_task_gates[6];
    input->fire_task_gates[7].kind=SYNC_ACTOR_RTS_COMPETITOR;
    input->fire_task_gates[7].value=0;
    input->fire_task_gates[7].competitor=(SyncRtsCompetitorState){.rng_game=123,.rng_engine=0x81234567,.clock=1550,
        .competitor_class=0x6ee004,.delta=.017f,.timers={0,.5f,.2f,0,3,-1,.1f,-2,.3f,.25f,0,1}};
    input->rts_team_timer_count=2;
    input->rts_team_timers[0]=(SyncRtsTeamTimers){.slot=1,.remaining={0,0,3.5831935f}};
    input->rts_team_timers[1]=(SyncRtsTeamTimers){.slot=3,.remaining={1.25f,0,0}};
    input->spawn_timer_choice_count=2;
    input->spawn_timer_choices[0]=(SyncSpawnTimerChoice){.kind=SYNC_SPAWN_TIMER_RTS,.owner=1,.selector=2,.remaining=3.25f};
    input->spawn_timer_choices[1]=(SyncSpawnTimerChoice){.kind=SYNC_SPAWN_TIMER_MODULE,.owner=39,.selector=14,.serial=7,.remaining=-0.25f};
    input->dormant_party[4]=332;
    uint32_t bytes=sync_frame_encode(input,wire,sizeof(*input));
    assert(bytes && bytes<sizeof(*input));
    assert(sync_frame_decode(output,wire,bytes));
    assert(output->epoch==7 && output->sequence==1);
    assert(output->actors[1].party_slot==1 && output->rng_game_after==123 && output->rng_engine_after==456);
    assert(output->tag_count==1 && output->tags[0].id==1 && output->tags[0].to_generation==8 && output->tags[0].phase==1);
    assert(!memcmp(&output->tags[0].from_identity,&input->tags[0].from_identity,2*sizeof(SyncTagIdentity)));
    input->tags[0].source=SYNC_TAG_ACTOR_UPDATE;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->tags[0].phase=0;
    bytes=sync_frame_encode(input,wire,sizeof(*input));
    assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->tags[0].source==SYNC_TAG_ACTOR_UPDATE);
    input->tags[0].source=SYNC_TAG_ACTOR_UPDATE+1;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->tags[0].source=SYNC_TAG_UNSCOPED;
    input->tags[0].phase=1;
    assert(output->actors[1].animation.current==100 && output->actors[1].animation.frames[3]==19.5f);
    assert(output->actors[1].animation.clips[2]==-1 && output->variables[0].value==1);
    assert(memcmp(output->variables,input->variables,3*sizeof(SyncVariable))==0);
    assert(output->variable_count==3);
    input->variables[2].scope=0x6677280;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->variables[2].scope=SYNC_VARIABLE_AREA_DECLARATION;
    assert(output->actors[1].position[1]==1 && output->actors[1].previous_position[1]==.5f);
    assert(!memcmp(output->actors[1].motion_origin,native_motion_origin,sizeof native_motion_origin));
    assert(output->actors[1].render_position[1]==2 && output->actors[1].previous_render_position[1]==1.5f);
    assert(output->actors[1].velocity[1]==3 && output->actors[1].render_heading==1234 && output->combat_ready==1);
    assert(output->actors[1].generation==8 && output->actors[1].spawn_tag==0x5c5cff && output->actors[1].spawn_position[2]==3.5f);
    assert(output->actors[1].spawn_source.producer==0xf29a3889 && output->actors[1].spawn_source.serial==17);
    assert(output->inputs[1].aim_x==13 && output->inputs[1].aim_y==219 && output->shots[0].owner_generation==8);
    assert(memcmp(&output->actors[1].body,&input->actors[1].body,sizeof(SyncActorBody))==0);
    assert(output->physics_choice_count==3 && memcmp(output->physics_choices,input->physics_choices,3*sizeof(SyncPhysicsChoice))==0);
    assert(output->tick_gate_count==2 && !memcmp(output->tick_gates,input->tick_gates,2*sizeof(SyncTickGate)));
    input->tick_gates[1].site=0x8889ea;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->tick_gates[1].site=0x8888cd;
    input->tick_gates[0].site++;
    assert(!sync_frame_valid(input,sync_frame_size(input)));input->tick_gates[0].site--;
    input->tick_gates[0].value=256;
    assert(!sync_frame_valid(input,sync_frame_size(input)));input->tick_gates[0].value=1;
    input->tick_gates[0].site=0x888889;
    assert(sync_frame_valid(input,sync_frame_size(input)));
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes);
    assert(sync_frame_decode(output,wire,bytes));
    assert(output->tick_gates[0].site==0x888889 && output->tick_gates[0].value==1);
    input->tick_gates[0].value=2;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->tick_gates[0].site=0x8888cd;input->tick_gates[0].value=1;
    input->tick_gates[0].site=0x889edc;input->tick_gates[0].value=UINT32_MAX;
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->tick_gates[0].value==UINT32_MAX);
    input->tick_gates[0].value=0x14;assert(sync_frame_valid(input,sync_frame_size(input)));
    input->tick_gates[0].value=0x15;assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->tick_gates[0].site=0x9dda14;input->tick_gates[0].value=34;
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->tick_gates[0].site==0x9dda14 && output->tick_gates[0].value==34);
    input->tick_gates[0].value=1;assert(sync_frame_valid(input,sync_frame_size(input)));
    input->tick_gates[0].value=3;assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->tick_gates[0].value=2*(SYNC_MAX_ACTORS+1);assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->tick_gates[0].site=0x8888cd;input->tick_gates[0].value=1;
    input->tick_gate_reserved=1;
    assert(!sync_frame_valid(input,sync_frame_size(input)));input->tick_gate_reserved=0;
    input->tick_gate_count=SYNC_MAX_TICK_GATES+1;
    assert(!sync_frame_size(input));input->tick_gate_count=2;
    SyncTickGate saved_tick[2];memcpy(saved_tick,input->tick_gates,sizeof saved_tick);
    input->tick_gate_count=3;
    input->tick_gates[0]=(SyncTickGate){.site=0x7b8ae1,.clock=14313,.value=0x12345678};
    input->tick_gates[1]=(SyncTickGate){.site=0x7b8afd,.clock=14313,.value=0x87654321};
    input->tick_gates[2]=(SyncTickGate){.site=0x7b8b08,.clock=14313,.value=0x3c23d70a};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->tick_gate_count==3 && !memcmp(output->tick_gates,input->tick_gates,3*sizeof(SyncTickGate)));
    input->tick_gates[2].value=0xbf800000;assert(sync_frame_valid(input,sync_frame_size(input)));
    input->tick_gates[2].value=0x7fc00000;assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->tick_gates[2].value=0x3c23d70a;input->tick_gates[1].clock++;
    assert(!sync_frame_valid(input,sync_frame_size(input)));input->tick_gates[1].clock--;
    input->tick_gate_count=2;assert(!sync_frame_valid(input,sync_frame_size(input)));
    memcpy(input->tick_gates,saved_tick,sizeof saved_tick);
    assert(physics_choice_same_source(input->physics_choices,input->physics_choices+1));
    input->physics_choices[1].name_hash[1]^=1;
    assert(!physics_choice_same_source(input->physics_choices,input->physics_choices+1));input->physics_choices[1].name_hash[1]^=1;
    input->physics_choices[0].flags=0x40000000;
    assert(!sync_frame_valid(input,sync_frame_size(input)));input->physics_choices[0].flags=0x40000091;
    input->physics_choice_count=SYNC_MAX_PHYSICS_CHOICES+1;
    assert(sync_frame_size(input)==0);input->physics_choice_count=3;
    input->physics_choices[2].site=0x905f39;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->physics_choices[2].site=0x905f38;
    assert(output->shots[0].id==42 && output->shots[0].origin[0]==12.25f);
    assert(output->shots[0].has_launch_center==1);
    assert(memcmp(output->shots[0].launch_center,input->shots[0].launch_center,
                  sizeof(input->shots[0].launch_center))==0);
    assert(output->shots[0].has_projectile_seed==1);
    assert(memcmp(&output->shots[0].projectile_seed,&input->shots[0].projectile_seed,sizeof(SyncProjectileSeed))==0);
    assert(shot_native_match(&output->shots[1],1,8,7,SYNC_SHOT_ACTOR_FOLLOWUP,0));
    assert(output->shots[1].has_launch_motion==1 && output->shots[1].launch_motion[1]==-0.5f);
    assert(!shot_native_match(&output->shots[1],1,8,7,SYNC_SHOT_WEAPON,0));
    assert(shot_native_match(&output->shots[2],-1,0,7,SYNC_SHOT_PROJECTILE_CHILD,2));
    assert(!shot_native_match(&output->shots[2],-1,0,7,SYNC_SHOT_PROJECTILE_CHILD,1));
    assert(output->projectiles[1].velocity[2]==6.75f && output->projectiles[1].cast_origin[2]==-4.75f);
    assert(!memcmp(&output->actors[1].rigid_body,&input->actors[1].rigid_body,sizeof(SyncRigidBody)));
    assert(output->reaction_count==4 && output->reactions[2].kind==SYNC_REACTION_DAMAGE_DRAW &&
        output->reactions[2].damage_draw==27742);
    input->reactions[2].damage_draw=65536;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->reactions[2].damage_draw=27742;
    assert(!memcmp(&output->reactions[3].range,&input->reactions[3].range,sizeof(SyncItemRange)));
    input->reactions[3].range.target_generation=0;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->reactions[3].range.target_generation=26;
    input->reactions[3].range.reach=NAN;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->reactions[3].range.reach=.1f;
    assert(output->fire_task_gate_count==8 && output->fire_task_gates[0].value==1 && output->fire_task_gates[1].value==0);
    assert(output->fire_task_gates[5].kind==SYNC_ACTOR_FALL_VISIBILITY && output->fire_task_gates[5].value==1);
    assert(output->fire_task_gates[4].kind==SYNC_ACTOR_DEATH_BREAKUP && output->fire_task_gates[4].value==1);
    assert(output->fire_task_gates[3].kind==SYNC_ACTOR_BREAKUP_VISIBILITY && output->fire_task_gates[3].value==1);
    assert(output->fire_task_gates[2].kind==SYNC_FIRE_ATTACK_SUPPORT && output->fire_task_gates[2].value==-3);
    assert(output->fire_task_gates[1].generation==17 && output->fire_task_gates[1].origin[2]==3);
    assert(!memcmp(&output->fire_task_gates[0].state,&input->fire_task_gates[0].state,sizeof(SyncFireTaskState)));
    assert(output->rts_team_timer_count==2 && output->rts_team_timers[0].slot==1);
    assert(output->rts_team_timers[0].remaining[2]==3.5831935f && output->rts_team_timers[1].remaining[0]==1.25f);
    assert(output->spawn_timer_choice_count==2 && output->spawn_timer_choices[0].selector==2 &&
        output->spawn_timer_choices[0].remaining==3.25f);
    assert(!memcmp(&output->spawn_timer_choices[1],&input->spawn_timer_choices[1],sizeof(SyncSpawnTimerChoice)));
    assert(output->dormant_party[4]==332);
    input->actors[1].spawn_source.producer=0;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->actors[1].spawn_source.producer=0xf29a3889;
    input->dormant_party[4]=4097;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->dormant_party[4]=332;
    input->dormant_party[0]=1;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->dormant_party[0]=0;
    input->spawn_timer_choices[0].selector=3;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->spawn_timer_choices[0].selector=2;
    input->spawn_timer_choices[0].remaining=4.01f;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->spawn_timer_choices[0].remaining=3.25f;
    input->spawn_timer_choices[1].owner=0;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->spawn_timer_choices[1].owner=39;
    input->rts_team_timers[1].slot=1;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->rts_team_timers[1].slot=3;
    input->rts_team_timers[1].remaining[0]=NAN;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->rts_team_timers[1].remaining[0]=1.25f;
    assert(output->fire_task_gate_count==8 && !memcmp(&output->fire_task_gates[6],&input->fire_task_gates[6],sizeof(SyncFireTaskGate)));
    SyncFireTaskGate *aim=&input->fire_task_gates[6];
    const SyncFireTaskGate valid_aim=*aim;
    aim->aim.remaining=NAN;assert(!sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    aim->aim.minimum=INFINITY;assert(!sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    aim->aim.maximum=-INFINITY;assert(!sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    aim->aim.reserved=1;assert(!sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    aim->aim.task_class=0;assert(!sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    aim->aim.target_slot=SYNC_MAX_ACTORS;assert(!sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    aim->aim.target_generation=0;assert(!sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    aim->aim.target_slot=aim->aim.target_generation=0;assert(sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    aim->value=2;assert(!sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    aim->flags=1;assert(!sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    aim->action=1;assert(!sync_frame_valid(input,sync_frame_size(input)));*aim=valid_aim;
    assert(!memcmp(&output->fire_task_gates[7],&input->fire_task_gates[7],sizeof(SyncFireTaskGate)));
    SyncFireTaskGate *competitor=&input->fire_task_gates[7];
    const SyncFireTaskGate valid_competitor=*competitor;
    competitor->competitor.delta=NAN;assert(!sync_frame_valid(input,sync_frame_size(input)));*competitor=valid_competitor;
    competitor->competitor.delta=-.1f;assert(!sync_frame_valid(input,sync_frame_size(input)));*competitor=valid_competitor;
    competitor->competitor.competitor_class=0;assert(!sync_frame_valid(input,sync_frame_size(input)));*competitor=valid_competitor;
    for (unsigned i=0;i<12;++i) {competitor->competitor.timers[i]=INFINITY;assert(!sync_frame_valid(input,sync_frame_size(input)));*competitor=valid_competitor;}
    competitor->value=1;assert(!sync_frame_valid(input,sync_frame_size(input)));*competitor=valid_competitor;
    input->fire_task_gates[6].storage[sizeof(SyncFireTaskState)]=1;assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[6].storage[sizeof(SyncFireTaskState)]=0;
    input->sequence=2;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->sequence=1;
    input->fire_task_gates[0].value=2;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->fire_task_gates[0].value=1;
    input->fire_task_gates[0].flags=0;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->fire_task_gates[0].flags=SYNC_FIRE_TASK_QUEUES_SHOT;
    input->fire_task_gates[2].value=128;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->fire_task_gates[2].value=-3;
    input->fire_task_gates[2].kind=99;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->fire_task_gates[2].kind=SYNC_FIRE_ATTACK_SUPPORT;
    input->fire_task_gates[0].state.repeat=256;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[0].state.repeat=2;
    input->fire_task_gates[0].state.delta=NAN;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[0].state.delta=.017f;
    input->fire_task_gates[0].state.timers[1]=INFINITY;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[0].state.timers[1]=-.01f;
    input->fire_task_gates[2].state.repeat=1;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[2].state.repeat=0;
    input->fire_task_gates[3].value=2;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[3].value=0;
    assert(sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[3].flags=1;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[3].flags=0;
    input->fire_task_gates[3].state.repeat=1;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[3].state.repeat=0;
    input->fire_task_gates[4].value=2;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[4].value=0;
    assert(sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[5].value=2;
    assert(!sync_frame_valid(input,sync_frame_size(input)));
    input->fire_task_gates[5].value=0;
    assert(sync_frame_valid(input,sync_frame_size(input)));
    assert(!sync_frame_decode(output,wire,bytes-1));
    wire[bytes-1]^=1; assert(!sync_frame_decode(output,wire,bytes)); wire[bytes-1]^=1;
    input->tags[0].parent=123; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->tags[0].parent=0;
    input->tags[0].to_generation=0; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->tags[0].to_generation=8;
    input->tags[0].from_identity.character=-1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->tags[0].from_identity.character=329;
    input->tags[0].to_identity.character=4096;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->tags[0].to_identity.character=189;
    input->tags[0].from_identity.spawn_source=(SyncSpawnSource){0,1};assert(!sync_frame_encode(input,wire,sizeof(*input)));input->tags[0].from_identity.spawn_source=(SyncSpawnSource){1,0};
    input->actors[1].party_slot=0; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->actors[1].party_slot=1;
    input->epoch=0; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->epoch=7;
    input->sequence=0; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->sequence=1;
    input->actors[1].animation.frames[0]=NAN;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->actors[1].animation.frames[0]=0;
    for (unsigned axis=0;axis<3;++axis) {
        input->actors[1].motion_origin[axis]=NAN;
        assert(!sync_frame_encode(input,wire,sizeof(*input)));
        memcpy(input->actors[1].motion_origin,native_motion_origin,sizeof native_motion_origin);
    }
    input->actors[1].body.active=0;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->actors[1].body.active=1;
    input->actors[1].body.velocity[1]=INFINITY;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->actors[1].body.velocity[1]=-.25f;
    input->actors[1].body.floor_height=NAN;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->actors[1].body.floor_height=.080519f;
    input->actors[0].body.floor_height=.1f;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->actors[0].body.floor_height=0;
    input->actors[1].rigid_body.active=0;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->actors[1].rigid_body.active=1;
    input->actors[1].rigid_body.reserved=1;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->actors[1].rigid_body.reserved=0;
    input->actors[1].rigid_body.transform[6]=NAN;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->actors[1].rigid_body.transform[6]=0;
    input->actors[0].rigid_body.transform[12]=1;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->actors[0].rigid_body.transform[12]=0;
    input->projectiles[0].position[0]=INFINITY;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->projectiles[0].position[0]=0;
    input->projectiles[1].cast_origin[0]=INFINITY;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->projectiles[1].cast_origin[0]=0;
    input->shots[0].projectile_seed.expires_at=NAN;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->shots[0].projectile_seed.expires_at=2;
    input->shots[0].has_projectile_seed=0;
    assert(!sync_frame_encode(input,wire,sizeof(*input))); input->shots[0].has_projectile_seed=1;
    assert(output->engine_delta==.017f && output->world_calls==1 && output->tick_calls==1);
    assert(output->actor_input_count==2 && output->actor_inputs[0].pressed==0x8000 && output->actor_inputs[1].pressed==0);
    input->actor_inputs[0].generation=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->actor_inputs[0].generation=27;
    input->actor_inputs[0].origin[0]=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->actor_inputs[0].origin[0]=0;
    assert(output->geometry_count==2 && output->geometry_calls==1 && output->geometry[1].slot==5 && output->geometry[1].bounds[3]==1 && output->geometry[1].extents[0]==.5f);
    input->geometry[1].slot=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->geometry[1].slot=5;
    input->geometry[0].bounds[0]=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->geometry[0].bounds[0]=-1;
    input->geometry[0].extents[0]=-1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->geometry[0].extents[0]=.5f;
    input->geometry_calls=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->geometry_calls=1;
    assert(output->cadence_count==1 && output->cadence[0].period==8 && output->cadence[0].phase==5 && output->cadence[0].elapsed==.05f);
    input->cadence[0].period=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->cadence[0].period=8;
    input->cadence[0].phase=256;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->cadence[0].phase=5;
    input->cadence[0].elapsed=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->cadence[0].elapsed=.05f;
    input->numeric_mxcsr=UINT32_MAX;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->numeric_mxcsr=0;
    assert(output->reaction_count==4 && output->reactions[0].clip==975 && output->reactions[0].source_id==667 && output->reactions[1].clip==-1 && output->reactions[1].old_action==20);
    input->reaction_reserved=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->reaction_reserved=0;
    input->reactions[0].clip=4096;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->reactions[0].clip=975;
    input->reactions[0].generation=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->reactions[0].generation=26;
    input->reactions[0].origin[0]=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->reactions[0].origin[0]=0;
    input->numeric_cw=0x100;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->numeric_cw=0;
    input->engine_delta=NAN; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->engine_delta=.017f;
    input->shots[0].phase=2; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->shots[0].phase=1;
    input->shots[0].delta=INFINITY; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->shots[0].delta=.015f;
    input->shots[0].has_launch_center=0; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->shots[0].has_launch_center=1;
    input->shots[0].launch_center[1]=NAN; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->shots[0].launch_center[1]=.125f;
    input->shots[2].depth=0; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->shots[2].depth=2;
    input->shots[1].phase=1; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->shots[1].phase=0;
    input->shots[1].has_launch_motion=0; assert(!sync_frame_encode(input,wire,sizeof(*input))); input->shots[1].has_launch_motion=1;
    input->shot_count=SYNC_MAX_SHOTS+1; assert(!sync_frame_size(input)); input->shot_count=3;
    input->projectile_count=SYNC_MAX_PROJECTILES+1; assert(!sync_frame_size(input));
    memset(input,0,sizeof(*input));
    input->epoch=7; input->sequence=2; input->level=12; input->delta=1.0f/60;
    input->reaction_count=1;
    input->reactions[0]=(SyncReactionChoice){.slot=1,.generation=13,.character=100,.old_action=-1,.clip=-2,
        .arena_attacker_slot=7,.arena_attacker_generation=19};
    bytes=sync_frame_encode(input,wire,sizeof(*input));
    assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->reactions[0].arena_attacker_slot==7 && output->reactions[0].arena_attacker_generation==19);
    input->level=6; assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->level=12; input->reactions[0].source_id=1; assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->reactions[0].source_id=0; input->reactions[0].arena_attacker_generation=0;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    memset(input,0,sizeof(*input));
    input->epoch=7;input->sequence=3;input->level=6;input->delta=1.0f/60;
    input->fire_task_gate_count=1;
    input->fire_task_gates[0]=(SyncFireTaskGate){.slot=5,.generation=25,.character=321,
        .kind=SYNC_ACTOR_FORCE_VISIBILITY,.value=1,.force={.caster_slot=0,.caster_generation=12,.mode=2,.clock=3307}};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->fire_task_gates[0].force.caster_generation==12 && output->fire_task_gates[0].force.clock==3307);
    input->fire_task_gates[0].force.caster_generation=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].force.caster_generation=12;
    input->fire_task_gates[0].force.caster_slot=SYNC_MAX_ACTORS;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].force.caster_slot=0;
    input->fire_task_gates[0].force.reserved[4]=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].force.reserved[4]=0;
    input->fire_task_gates[0].value=2;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].value=1;
    input->fire_task_gates[0]=(SyncFireTaskGate){.slot=5,.generation=25,.character=321,.kind=SYNC_ACTOR_FORCE_GEOMETRY,
        .force_geometry={.caster_slot=0,.caster_generation=12,.mode=1,.clock=3555,.caster_position={1,2,3},.candidate_position={4,5,6}}};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->fire_task_gates[0].force_geometry.candidate_position[2]==6);
    input->fire_task_gates[0].force_geometry.caster_position[0]=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].force_geometry.caster_position[0]=1;
    input->fire_task_gates[0].force_geometry.caster_generation=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].force_geometry.caster_generation=12;
    input->fire_task_gates[0].force_geometry.reserved=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].force_geometry.reserved=0;
    input->fire_task_gates[0].storage[sizeof(SyncForceGeometryState)]=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->fire_task_gates[0]=(SyncFireTaskGate){.slot=0,.generation=12,.character=360,.kind=SYNC_ACTOR_SPELLIT_QUERY,
        .spellit={.clock=6450,.manager_class=0x1234,.caller_site=0x457f0a,.heading=65535,.position={1,2,3},.limit=1}};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->fire_task_gates[0].spellit.position[2]==3 && output->fire_task_gates[0].spellit.heading==65535);
    input->fire_task_gates[0].spellit.limit=-1;assert(sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].spellit.limit=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].spellit.limit=1;
    input->fire_task_gates[0].spellit.heading=65536;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].spellit.heading=0;
    input->fire_task_gates[0].spellit.position[1]=INFINITY;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].spellit.position[1]=2;
    input->fire_task_gates[0].spellit.manager_class=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].spellit.manager_class=0x1234;
    input->fire_task_gates[0].spellit.reserved=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].spellit.reserved=0;
    input->fire_task_gates[0].storage[sizeof(SyncSpellItQueryState)]=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->fire_task_gates[0]=(SyncFireTaskGate){.slot=5,.generation=25,.character=321,.kind=SYNC_ACTOR_AIM_BASE,
        .aim_base={.rng_engine=123,.rng_game=451,.clock=3307,.task_class=0x84e95c,.callback_class=0x123456,.elapsed=1.2f,.remaining=-.01f,.delta=.025f}};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->fire_task_gates[0].aim_base.elapsed==1.2f && output->fire_task_gates[0].aim_base.rng_game==451);
    input->fire_task_gates[0].aim_base.elapsed=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].aim_base.elapsed=1.2f;
    input->fire_task_gates[0].aim_base.delta=-.01f;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].aim_base.delta=.025f;
    input->fire_task_gates[0].aim_base.task_class=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].aim_base.task_class=0x84e95c;
    input->fire_task_gates[0].aim_base.reserved=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].aim_base.reserved=0;
    input->fire_task_gates[0]=(SyncFireTaskGate){.slot=0,.generation=12,.character=360,.kind=SYNC_ACTOR_SPELLIT_NODE,
        .spellit_node={.clock=7885,.gizmo_class=0x1234,.receiver_class=0x820b1c,.resource_name={1,2,3,4},.poi_ordinal=95,.poi_count=500,
            .poi_name=42,.component_class=0x820fb4,.node_ordinal=0,.gizmo_ordinal=4,.position={3,-.2f,-2}}};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(!memcmp(&input->fire_task_gates[0].spellit_node,&output->fire_task_gates[0].spellit_node,sizeof(SyncSpellItNodeState)));
    for (unsigned i=0;i<3;++i) {
        float saved=input->fire_task_gates[0].spellit_node.position[i];
        input->fire_task_gates[0].spellit_node.position[i]=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));
        input->fire_task_gates[0].spellit_node.position[i]=saved;
    }
    input->fire_task_gates[0].spellit_node.poi_ordinal=500;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].spellit_node.poi_ordinal=95;
    input->fire_task_gates[0].spellit_node.reserved=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].spellit_node.reserved=0;
    input->fire_task_gates[0].flags=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].flags=0;
    input->fire_task_gates[0].spellit_node.component_class=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].spellit_node.component_class=0x820fb4;
    input->fire_task_gates[0]=(SyncFireTaskGate){.slot=0,.generation=12,.character=360,.kind=SYNC_ACTOR_CHARACTER_MOTION,
        .character_motion={.clock=2973,.body_class=0x869f1c,.velocity={-.8f,-.3f,-.2f,1},.rest_counter=6}};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(!memcmp(&input->fire_task_gates[0].character_motion,&output->fire_task_gates[0].character_motion,sizeof(SyncCharacterMotionState)));
    input->fire_task_gates[0].character_motion.rest_counter=UINT16_MAX;
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->fire_task_gates[0].character_motion.rest_counter==UINT16_MAX);
    input->fire_task_gates[0].character_motion.rest_counter=UINT16_MAX+1u;assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->fire_task_gates[0].character_motion.rest_counter=6;
    for(unsigned component=0;component<4;++component){
        const float saved=input->fire_task_gates[0].character_motion.velocity[component];
        input->fire_task_gates[0].character_motion.velocity[component]=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));
        input->fire_task_gates[0].character_motion.velocity[component]=INFINITY;assert(!sync_frame_encode(input,wire,sizeof(*input)));
        input->fire_task_gates[0].character_motion.velocity[component]=saved;
    }
    input->fire_task_gates[0].character_motion.body_class=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].character_motion.body_class=0x869f1c;
    input->fire_task_gates[0].storage[sizeof(SyncCharacterMotionState)]=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].storage[sizeof(SyncCharacterMotionState)]=0;
    input->fire_task_gates[0].value=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].value=0;
    memset(input,0,sizeof(*input));
    input->epoch=9;input->sequence=1;input->level=7;input->fire_task_gate_count=1;
    input->fire_task_gates[0]=(SyncFireTaskGate){.slot=6,.generation=18,.character=321,
        .kind=SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY,.value=1,
        .script_shoot={.clock=1627,.model_class=0x82141c,.brain_class=0x8324c4,.state_class=0x842b34,
            .brain_admission=1,.state_flags=1,.argument_count=2,.caller_rva=0x30e29b,.argument_hash={11,22,33,44}}};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(!memcmp(&input->fire_task_gates[0],&output->fire_task_gates[0],sizeof(SyncFireTaskGate)));
    SyncScriptShootState *script_shoot=&input->fire_task_gates[0].script_shoot;
    const SyncScriptShootState script_shoot_valid=*script_shoot;
    input->fire_task_gates[0].value=0;
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(!output->fire_task_gates[0].value);
    input->fire_task_gates[0].value=2;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->fire_task_gates[0].value=1;
    script_shoot->model_class=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    script_shoot->brain_class=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    script_shoot->state_class=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    script_shoot->brain_admission=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    script_shoot->brain_admission=2;assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    script_shoot->state_flags=0x10000;assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    script_shoot->argument_count=SYNC_SCRIPT_SHOOT_MAX_ARGUMENTS+1;assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    script_shoot->initialize=2;assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    script_shoot->caller_rva=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    memset(script_shoot->argument_hash,0,sizeof(script_shoot->argument_hash));assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    script_shoot->reserved=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));*script_shoot=script_shoot_valid;
    input->fire_task_gates[0].storage[sizeof(SyncScriptShootState)]=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->fire_task_gates[0].storage[sizeof(SyncScriptShootState)]=0;
    script_shoot->argument_count=0;script_shoot->initialize=1;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    script_shoot->state_flags=0;
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->fire_task_gates[0].script_shoot.initialize==1 && !output->fire_task_gates[0].script_shoot.argument_count);
    input->fire_task_gates[0]=(SyncFireTaskGate){.slot=4,.generation=23,.character=160,
        .kind=SYNC_ACTOR_PRIMARY_PERCEPTION,.perception={.clock=71,.target_slot=8,.target_generation=29,
            .target_character=321,.target_origin={2,1,-2},.distance=3.75f,.target_visible=1}};
    SyncPrimaryPerceptionState *perception=&input->fire_task_gates[0].perception;
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(!memcmp(perception,&output->fire_task_gates[0].perception,sizeof(*perception)));
    perception->target_generation=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));perception->target_generation=29;
    perception->distance=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));perception->distance=3.75f;
    perception->target_visible=2;assert(!sync_frame_encode(input,wire,sizeof(*input)));perception->target_visible=1;
    perception->target_slot=UINT32_MAX;assert(!sync_frame_encode(input,wire,sizeof(*input)));
    *perception=(SyncPrimaryPerceptionState){.clock=71,.target_slot=UINT32_MAX};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(!memcmp(perception,&output->fire_task_gates[0].perception,sizeof(*perception)));
    memset(input,0,sizeof(*input));
    input->epoch=9;input->sequence=1;input->level=7;
    input->physics_choice_count=1;
    input->physics_choices[0]=(SyncPhysicsChoice){.kind=SYNC_PHYSICS_SPELLIT_SELECTION,.site=0x840790,
        .spellit_selection={.clock=587,.engine_seed=12345,.source_name={1,2,3,4},.gizmo_class=0x8480ac,
            .gizmo_ordinal=3,.candidate_count=2,.eligibility={5,6,7,8},.piece_count=9}};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(!memcmp(input->physics_choices,output->physics_choices,sizeof(SyncPhysicsChoice)));
    output->physics_choices[0].spellit_selection.engine_seed++;
    assert(physics_choice_same_source(input->physics_choices,output->physics_choices));
    output->physics_choices[0].spellit_selection.eligibility[0]++;
    assert(!physics_choice_same_source(input->physics_choices,output->physics_choices));
    input->physics_choices[0].spellit_selection.candidate_count=10;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->physics_choices[0].spellit_selection.candidate_count=2;
    input->physics_choices[0].spellit_selection.reserved[5]=1;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->physics_choices[0].spellit_selection.reserved[5]=0;
    input->physics_choices[0].site=0x8406a7;
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    input->physics_choices[0].site=0x840b93;
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    for(unsigned kind=SYNC_PHYSICS_SPELLIT_BODY_BASIS;kind<=SYNC_PHYSICS_SPELLIT_BODY_MOTION;++kind){
        input->physics_choices[0]=(SyncPhysicsChoice){.kind=kind,.site=0x840660,
            .spellit_body={.clock=42,.key={1,2,3,4},.body_class=0x869eac,.piece_ordinal=8,.values={1,0,0,0,0,1,0,0,0,0,1,0}}};
        bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes&&sync_frame_decode(output,wire,bytes));
        assert(!memcmp(input->physics_choices,output->physics_choices,sizeof(SyncPhysicsChoice)));
        output->physics_choices[0].spellit_body.values[0]+=1;assert(physics_choice_same_source(input->physics_choices,output->physics_choices));
        output->physics_choices[0].spellit_body.key[0]++;assert(!physics_choice_same_source(input->physics_choices,output->physics_choices));
        input->physics_choices[0].spellit_body.values[0]=NAN;assert(!sync_frame_encode(input,wire,sizeof(*input)));
        input->physics_choices[0].spellit_body.values[0]=1;input->physics_choices[0].spellit_body.reserved=1;
        assert(!sync_frame_encode(input,wire,sizeof(*input)));
    }
    input->physics_choices[0]=(SyncPhysicsChoice){.kind=SYNC_PHYSICS_MODULE_SEED,.site=0x4da6d0,
        .module={.clock=8965,.value=3387502361u,.module_id=1969741825,.module_type=516652984,
            .module_generation=24,.module_class=0x6e6b3c,.burst_min=3,.burst_max=5,
            .channel_count=1,.weapon=7,.intervals={6,4,.2f}}};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(sizeof(SyncPhysicsModuleInput)==80 && sizeof(SyncPhysicsChoice)==88);
    assert(!memcmp(input->physics_choices,output->physics_choices,sizeof(SyncPhysicsChoice)));
    output->physics_choices[0].module.value=4286270884u;
    assert(physics_choice_same_source(input->physics_choices,output->physics_choices));
    output->physics_choices[0].module.module_generation++;
    assert(physics_choice_same_source(input->physics_choices,output->physics_choices));
    output->physics_choices[0].module.module_generation--;
    output->physics_choices[0].module.clock++;
    assert(!physics_choice_same_source(input->physics_choices,output->physics_choices));
    SyncPhysicsModuleInput *module=&input->physics_choices[0].module;
    module->module_id=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));module->module_id=1969741825;
    module->module_class++;assert(!sync_frame_encode(input,wire,sizeof(*input)));module->module_class--;
    module->burst_min=5;assert(!sync_frame_encode(input,wire,sizeof(*input)));module->burst_min=3;
    module->burst_max=256;assert(!sync_frame_encode(input,wire,sizeof(*input)));module->burst_max=5;
    module->channel_count=4;assert(!sync_frame_encode(input,wire,sizeof(*input)));module->channel_count=1;
    module->weapon=-129;assert(!sync_frame_encode(input,wire,sizeof(*input)));module->weapon=128;
    assert(!sync_frame_encode(input,wire,sizeof(*input)));module->weapon=-128;
    assert(sync_frame_encode(input,wire,sizeof(*input)));module->weapon=127;
    assert(sync_frame_encode(input,wire,sizeof(*input)));module->weapon=7;
    for(unsigned i=0;i<3;++i){
        float saved=module->intervals[i];module->intervals[i]=NAN;
        assert(!sync_frame_encode(input,wire,sizeof(*input)));module->intervals[i]=saved;
    }
    for(unsigned i=0;i<7;++i){module->reserved[i]=1;
        assert(!sync_frame_encode(input,wire,sizeof(*input)));module->reserved[i]=0;}
    input->physics_choices[0].site++;assert(!sync_frame_encode(input,wire,sizeof(*input)));input->physics_choices[0].site--;
    module->value=UINT32_MAX;bytes=sync_frame_encode(input,wire,sizeof(*input));
    assert(bytes && sync_frame_decode(output,wire,bytes) && output->physics_choices[0].module.value==UINT32_MAX);

    input->physics_choices[0]=(SyncPhysicsChoice){.kind=SYNC_PHYSICS_GUN_JAM_SEED,.site=0x4acb53,
        .gun_jam={.clock=228,.value=UINT32_MAX,.module_id=1969741825,.module_type=516652984,
            .module_generation=24,.member_count=2,.candidate_count=16,.clip=20,.remaining=-.01f,.minimum=6,.maximum=40}};
    bytes=sync_frame_encode(input,wire,sizeof(*input));
    assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(sizeof(SyncPhysicsGunJamInput)==80 && !memcmp(input->physics_choices,output->physics_choices,sizeof(SyncPhysicsChoice)));
    output->physics_choices[0].gun_jam.value=0;
    assert(physics_choice_same_source(input->physics_choices,output->physics_choices));
    output->physics_choices[0].gun_jam.module_generation++;
    assert(physics_choice_same_source(input->physics_choices,output->physics_choices));
    output->physics_choices[0].gun_jam.module_id++;
    assert(!physics_choice_same_source(input->physics_choices,output->physics_choices));
    output->physics_choices[0].gun_jam.module_id--;
    output->physics_choices[0].gun_jam.candidate_count++;
    assert(!physics_choice_same_source(input->physics_choices,output->physics_choices));
    SyncPhysicsGunJamInput *jam=&input->physics_choices[0].gun_jam;
    jam->member_count=13;assert(!sync_frame_encode(input,wire,sizeof(*input)));jam->member_count=2;
    jam->minimum=INFINITY;assert(!sync_frame_encode(input,wire,sizeof(*input)));jam->minimum=6;
    jam->reserved[8]=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));jam->reserved[8]=0;
    input->physics_choice_count=0;
    input->projectile_retire_count=2;
    input->projectile_retires[0]=(SyncProjectileRetireRequest){.id=177,.caller=0x85ba24};
    input->projectile_retires[1]=(SyncProjectileRetireRequest){.id=23,.caller=0x85ba24};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(bytes==offsetof(SyncFrame,actors)+2*sizeof(SyncProjectileRetireRequest));
    assert(output->projectile_retire_count==2 &&
        !memcmp(input->projectile_retires,output->projectile_retires,2*sizeof(SyncProjectileRetireRequest)));
    memset(output,0,sizeof(*output));sync_frame_copy_valid(output,input);
    assert(output->projectile_retire_count==2 && output->projectile_retires[1].id==23);
    assert(!sync_frame_decode(output,wire,bytes-1));
    input->projectile_retires[1].id=177;assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->projectile_retires[1].id=0;assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->projectile_retires[1].id=23;
    input->projectile_retires[0].caller=0x85b344;assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->projectile_retires[0].caller=0x85ba24;
    input->projectile_retires[0].effects=-1;assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->projectile_retires[0].effects=0;
    input->projectile_retires[0].flags=1;assert(!sync_frame_encode(input,wire,sizeof(*input)));
    input->projectile_retires[0].flags=0;
    input->projectile_retire_count=SYNC_MAX_PROJECTILES+1;assert(!sync_frame_size(input));
    input->projectile_retire_count=SYNC_MAX_PROJECTILES;
    for(unsigned i=0;i<SYNC_MAX_PROJECTILES;++i)
        input->projectile_retires[i]=(SyncProjectileRetireRequest){.id=i+1,.caller=0x85ba24};
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(output->projectile_retires[SYNC_MAX_PROJECTILES-1].id==SYNC_MAX_PROJECTILES);
    input->projectile_retire_count=0;
    bytes=sync_frame_encode(input,wire,sizeof(*input));assert(bytes && sync_frame_decode(output,wire,bytes));
    assert(!output->projectile_retire_count && bytes==offsetof(SyncFrame,actors));
    free(wire); free(output); free(input);
    printf("Protocol %u frame=%zu header=%zu shot=%zu\n",SYNC_PROTOCOL_VERSION,sizeof(SyncFrame),offsetof(SyncFrame,actors),sizeof(SyncShot));
    puts("Combat wire: animation, mixed arrays, shots, projectile state, checksum, bounds and finite values passed");
    return 0;
}
