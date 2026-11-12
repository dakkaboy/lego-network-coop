#include <math.h>
#include <stddef.h>
#include <string.h>
#include "sync_wire.h"
#include "../engine/character_support_input.h"
extern "C" {
#include "../sync/geometry_sync.h"
#include "../engine/native_numeric_input.h"
#include "../sync/reaction_sync.h"
#include "../sync/model_input_sync.h"
#include "../sync/physics_input_sync.h"
#include "../sync/native_tick_sync.h"
}

uint32_t sync_checksum(const void *data,uint32_t size) {
    const uint8_t *bytes=static_cast<const uint8_t *>(data);
    uint32_t result=2166136261u;
    for (uint32_t i=0;i<size;++i) result=(result^bytes[i])*16777619u;
    return result;
}
int sync_profile_valid(const SyncProfile *profile) {
    uint32_t version;
    memcpy(&version,profile->data,4);
    return profile->epoch && version==0x500 && profile->level>=0 && profile->level<4096 &&
           profile->checksum==sync_checksum(profile->data,SYNC_PROFILE_BYTES);
}

uint32_t sync_frame_size(const SyncFrame *frame) {
    if (frame->physics_choice_count>SYNC_MAX_PHYSICS_CHOICES || frame->tick_gate_count>SYNC_MAX_TICK_GATES ||
        frame->projectile_retire_count>SYNC_MAX_PROJECTILES) return 0;
    if (frame->spawn_timer_count>SYNC_MAX_SPAWN_TIMERS || frame->fire_task_gate_count>SYNC_MAX_ACTORS ||
        frame->rts_team_timer_count>SYNC_MAX_RTS_TEAMS || frame->spawn_timer_choice_count>SYNC_MAX_SPAWN_TIMER_CHOICES) return 0;
    if (frame->actor_count>SYNC_MAX_ACTORS || frame->variable_count>SYNC_MAX_VARIABLES ||
        frame->shot_count>SYNC_MAX_SHOTS || frame->projectile_count>SYNC_MAX_PROJECTILES || frame->tag_count>SYNC_MAX_TAGS || frame->actor_input_count>SYNC_MAX_ACTORS || frame->cadence_count>SYNC_MAX_ACTORS || frame->geometry_count>SYNC_MAX_ACTORS || frame->geometry_calls>64 || frame->reaction_count>SYNC_MAX_ACTORS || frame->model_input_count>SYNC_MAX_ACTORS) return 0;
    return (uint32_t)offsetof(SyncFrame,actors) + frame->actor_count*sizeof(SyncActor) + frame->variable_count*sizeof(SyncVariable) +
           frame->shot_count*sizeof(SyncShot) + frame->projectile_count*sizeof(SyncProjectile) + frame->tag_count*sizeof(SyncTag) + frame->actor_input_count*sizeof(SyncActorInput) + frame->cadence_count*sizeof(SyncCadence) + frame->geometry_count*sizeof(SyncCollider) + frame->reaction_count*sizeof(SyncReactionChoice) + frame->model_input_count*sizeof(SyncModelInput) + frame->spawn_timer_count*sizeof(SyncSpawnTimer) + frame->fire_task_gate_count*sizeof(SyncFireTaskGate) + frame->rts_team_timer_count*sizeof(SyncRtsTeamTimers) + frame->spawn_timer_choice_count*sizeof(SyncSpawnTimerChoice) + frame->physics_choice_count*sizeof(SyncPhysicsChoice) + frame->tick_gate_count*sizeof(SyncTickGate) + frame->projectile_retire_count*sizeof(SyncProjectileRetireRequest);
}

static bool spawn_source_valid(SyncSpawnSource source) {
    return source.producer || !source.serial;
}

int sync_frame_valid(const SyncFrame *frame, uint32_t bytes) {
    if (bytes < offsetof(SyncFrame,actors) || frame->actor_count > SYNC_MAX_ACTORS || frame->variable_count>SYNC_MAX_VARIABLES ||
        bytes != sync_frame_size(frame) || (frame->native_span_plan & ~SYNC_NATIVE_SPAN_PLAN_MASK) || (frame->native_span_calls & ~SYNC_NATIVE_SPAN_CALLS_MASK) || !frame->epoch || !frame->sequence || frame->level < 0 || frame->level >= 4096 ||
        !isfinite(frame->delta) || frame->delta < 0 || frame->delta > 0.1f ||
        !isfinite(frame->engine_delta) || frame->engine_delta<0 || frame->engine_delta>.1f || frame->engine_mode>16 || frame->world_calls>64 || frame->tick_calls>64 || frame->combat_ready>1 || !native_numeric_valid(NativeNumericInput{frame->numeric_cw,frame->numeric_mxcsr}) || frame->reaction_reserved || frame->model_input_reserved || frame->actor_input_count>SYNC_MAX_ACTORS || frame->cadence_count>SYNC_MAX_ACTORS || frame->geometry_count>SYNC_MAX_ACTORS || frame->geometry_calls>64 || frame->reaction_count>SYNC_MAX_ACTORS || frame->model_input_count>SYNC_MAX_ACTORS) return 0;
    if (frame->tick_gate_reserved) return 0;
    for (uint32_t i=0;i<frame->projectile_retire_count;++i) {
        const SyncProjectileRetireRequest &request=frame->projectile_retires[i];
        if (!request.id || request.flags || request.effects || request.caller!=0x85ba24) return 0;
        for (uint32_t j=0;j<i;++j) if (frame->projectile_retires[j].id==request.id) return 0;
    }
    if (!native_tick_stream_valid(frame->tick_gates,frame->tick_gate_count)) return 0;
    for (uint32_t i=0;i<frame->physics_choice_count;++i)
        if (!physics_choice_valid(frame->physics_choices+i)) return 0;
    if (frame->spawn_timer_reserved || frame->fire_task_gate_reserved ||
        (frame->sequence!=1 && (frame->spawn_timer_count || frame->rts_team_timer_count))) return 0;
    uint32_t rts_team_slots=0;
    for (uint32_t i=0;i<frame->rts_team_timer_count;++i) {
        const SyncRtsTeamTimers &team=frame->rts_team_timers[i];
        if (team.slot>=SYNC_MAX_RTS_TEAMS || (rts_team_slots&(1u<<team.slot))) return 0;
        rts_team_slots|=1u<<team.slot;
        for (float remaining : team.remaining) if (!isfinite(remaining)) return 0;
    }
    for (uint32_t i=0;i<frame->spawn_timer_choice_count;++i) {
        const SyncSpawnTimerChoice &choice=frame->spawn_timer_choices[i];
        if (!isfinite(choice.remaining)) return 0;
        switch (choice.kind) {
        case SYNC_SPAWN_TIMER_RTS:
            if (choice.owner>=SYNC_MAX_RTS_TEAMS || choice.selector>=3 || choice.serial ||
                choice.remaining<2.0f || choice.remaining>4.0f) return 0;
            break;
        case SYNC_SPAWN_TIMER_MODULE:
            if (!choice.owner || !choice.selector) return 0;
            break;
        default:
            return 0;
        }
    }
    for (uint32_t i=0;i<frame->spawn_timer_count;++i) {
        const SyncSpawnTimer &timer=frame->spawn_timers[i];
        if (!timer.id || !timer.type || !isfinite(timer.remaining) ||
            (i && frame->spawn_timers[i-1].id>=timer.id)) return 0;
    }
    for (uint32_t i=0;i<frame->fire_task_gate_count;++i) {
        const SyncFireTaskGate &gate=frame->fire_task_gates[i];
        if (!spawn_source_valid(gate.spawn_source) || gate.slot>=SYNC_MAX_ACTORS || !gate.generation || gate.character<0 || gate.character>=4096) return 0;
        if (gate.kind!=SYNC_ACTOR_RTS_COMPETITOR) {
            const unsigned used=gate.kind==SYNC_ACTOR_FORCE_GEOMETRY ? sizeof(SyncForceGeometryState) :
                gate.kind==SYNC_ACTOR_CHARACTER_MOTION ? sizeof(SyncCharacterMotionState) :
                gate.kind==SYNC_ACTOR_SPELLIT_NODE ? sizeof(SyncSpellItNodeState) :
                gate.kind==SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY ? sizeof(SyncScriptShootState) :
                gate.kind==SYNC_ACTOR_PRIMARY_PERCEPTION ? sizeof(SyncPrimaryPerceptionState) : sizeof(SyncFireTaskState);
            for (unsigned offset=used;offset<sizeof(gate.storage);++offset) if (gate.storage[offset]) return 0;
        }
        switch (gate.kind) {
        case SYNC_FIRE_TASK_VISIBILITY:
            if (!(gate.flags&SYNC_FIRE_TASK_QUEUES_SHOT) || gate.value<0 || gate.value>1) return 0;
            if (gate.state.repeat>UINT8_MAX || !isfinite(gate.state.delta) || gate.state.delta<0) return 0;
            for (float timer : gate.state.timers) if (!isfinite(timer)) return 0;
            for (float coordinate : gate.state.target) if (!isfinite(coordinate)) return 0;
            break;
        case SYNC_FIRE_ATTACK_SUPPORT:
            if (gate.flags || gate.action || gate.value<INT8_MIN || gate.value>INT8_MAX) return 0;
            { const SyncFireTaskState empty={}; if (memcmp(&gate.state,&empty,sizeof(empty))) return 0; }
            break;
        case SYNC_ACTOR_BREAKUP_VISIBILITY:
        case SYNC_ACTOR_DEATH_BREAKUP:
        case SYNC_ACTOR_FALL_VISIBILITY:
            if (gate.flags || gate.action || gate.value<0 || gate.value>1) return 0;
            { const SyncFireTaskState empty={}; if (memcmp(&gate.state,&empty,sizeof(empty))) return 0; }
            break;
        case SYNC_ACTOR_AIM_BASE:
            if (gate.flags || gate.action || gate.value || !gate.aim_base.task_class || gate.aim_base.reserved ||
                !isfinite(gate.aim_base.elapsed) || !isfinite(gate.aim_base.remaining) || !isfinite(gate.aim_base.delta) || gate.aim_base.delta<0) return 0;
            break;
        case SYNC_ACTOR_FORCE_VISIBILITY:
            if (gate.flags || gate.action || gate.value<0 || gate.value>1 || gate.force.caster_slot>=SYNC_MAX_ACTORS || !gate.force.caster_generation) return 0;
            for (uint32_t reserved : gate.force.reserved) if (reserved) return 0;
            break;
        case SYNC_ACTOR_FORCE_GEOMETRY:
            if (gate.flags || gate.action || gate.value || gate.force_geometry.caster_slot>=SYNC_MAX_ACTORS ||
                !gate.force_geometry.caster_generation || gate.force_geometry.reserved) return 0;
            for (float value : gate.force_geometry.caster_position) if (!isfinite(value)) return 0;
            for (float value : gate.force_geometry.candidate_position) if (!isfinite(value)) return 0;
            break;
        case SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY:
            if (gate.flags || gate.action || gate.value<0 || gate.value>1 || !gate.script_shoot.model_class ||
                !gate.script_shoot.brain_class || !gate.script_shoot.state_class || gate.script_shoot.brain_admission!=1 ||
                gate.script_shoot.state_flags>UINT16_MAX || gate.script_shoot.argument_count>SYNC_SCRIPT_SHOOT_MAX_ARGUMENTS ||
                gate.script_shoot.initialize>1 || (gate.script_shoot.initialize && gate.script_shoot.state_flags) ||
                !gate.script_shoot.caller_rva || gate.script_shoot.reserved ||
                !(gate.script_shoot.argument_hash[0]|gate.script_shoot.argument_hash[1]|gate.script_shoot.argument_hash[2]|gate.script_shoot.argument_hash[3])) return 0;
            break;
        case SYNC_ACTOR_PRIMARY_PERCEPTION: {
            const auto &source=gate.perception;
            if (gate.flags || gate.action || gate.value || source.target_visible>1 ||
                !isfinite(source.distance) || source.distance<0 || !spawn_source_valid(source.target_source)) return 0;
            for (float coordinate : source.target_origin) if (!isfinite(coordinate)) return 0;
            if (source.target_slot==UINT32_MAX) {
                const SyncPrimaryPerceptionState empty={source.clock,UINT32_MAX};
                if (memcmp(&source,&empty,sizeof source)) return 0;
            } else if (source.target_slot>=SYNC_MAX_ACTORS || !source.target_generation ||
                       source.target_character<0 || source.target_character>=4096) return 0;
            break;
        }
        case SYNC_ACTOR_CHARACTER_MOTION:
            if (gate.flags || gate.action || gate.value || !gate.character_motion.body_class || gate.character_motion.rest_counter>UINT16_MAX) return 0;
            if (!character_support_input_valid(&gate.character_motion)) return 0;
            for (float value : gate.character_motion.velocity) if (!isfinite(value)) return 0;
            break;
        case SYNC_ACTOR_SPELLIT_NODE:
            if (gate.flags || gate.action || gate.value || gate.spellit_node.reserved || !gate.spellit_node.gizmo_class ||
                !gate.spellit_node.receiver_class || !(gate.spellit_node.resource_name[0]|gate.spellit_node.resource_name[1]|gate.spellit_node.resource_name[2]|gate.spellit_node.resource_name[3]) ||
                !gate.spellit_node.poi_count || gate.spellit_node.poi_count>65536 || gate.spellit_node.poi_ordinal>=gate.spellit_node.poi_count ||
                !gate.spellit_node.poi_name || !gate.spellit_node.component_class || gate.spellit_node.node_ordinal>=65536 || gate.spellit_node.gizmo_ordinal>=65536) return 0;
            for (float value : gate.spellit_node.position) if (!isfinite(value)) return 0;
            break;
        case SYNC_ACTOR_SPELLIT_QUERY:
            if (gate.flags || gate.action || gate.value || !gate.spellit.manager_class || !gate.spellit.caller_site ||
                gate.spellit.heading>65535 || gate.spellit.reserved || !isfinite(gate.spellit.limit)) return 0;
            for (float value : gate.spellit.position) if (!isfinite(value)) return 0;
            break;
        case SYNC_ACTOR_RTS_COMPETITOR:
            if (gate.flags || gate.action || gate.value || !gate.competitor.competitor_class || !isfinite(gate.competitor.delta) || gate.competitor.delta<0) return 0;
            for (float timer : gate.competitor.timers) if (!isfinite(timer)) return 0;
            break;
        case SYNC_ACTOR_AIM_TASK:
            if (gate.flags || gate.action || gate.value<0 || gate.value>1 || gate.aim.reserved || !gate.aim.task_class ||
                (gate.aim.target_generation ? gate.aim.target_slot>=SYNC_MAX_ACTORS : gate.aim.target_slot!=0) ||
                !isfinite(gate.aim.remaining) || !isfinite(gate.aim.minimum) || !isfinite(gate.aim.maximum)) return 0;
            break;
        default: return 0;
        }
        for (float coordinate : gate.origin) if (!isfinite(coordinate)) return 0;
    }
    uint32_t party_seen=0;
    for (unsigned party=0;party<8;++party) {
        if (frame->dormant_party[party]>4096) return 0;
        if (frame->dormant_party[party]) party_seen|=1u<<party;
    }
    for (uint32_t i=0; i<frame->actor_count; ++i) {
        const SyncActor *actor = &frame->actors[i];
        if (actor->slot >= 4096 || actor->character < -1 || actor->character >= 4096 || !actor->generation || actor->player < -1 || actor->player > 1) return 0;
        if (actor->has_wallet>1 || !spawn_source_valid(actor->spawn_source)) return 0;
        if (actor->body.active>1) return 0;
        if (actor->rigid_body.active>1 || actor->rigid_body.reserved) return 0;
        for (float value : actor->rigid_body.transform)
            if (!isfinite(value) || (!actor->rigid_body.active && value!=0)) return 0;
        if (!isfinite(actor->body.floor_height) || (!actor->body.active && actor->body.floor_height!=0)) return 0;
        for (float value : actor->body.position)
            if (!isfinite(value) || (!actor->body.active && value!=0)) return 0;
        for (float value : actor->body.velocity)
            if (!isfinite(value) || (!actor->body.active && value!=0)) return 0;
        if (actor->party_slot < -1 || actor->party_slot>=8 ||
            (actor->player>=0 && actor->party_slot!=actor->player) ||
            (actor->party_slot>=0 && actor->party_slot<2 && actor->player!=actor->party_slot)) return 0;
        if (actor->party_slot>=0) {
            uint32_t bit=1u<<actor->party_slot;
            if (party_seen&bit) return 0;
            party_seen|=bit;
        }
        if (actor->animation.current < -1 || actor->animation.current>=4096) return 0;
        for (int j=0;j<5;++j) {
            if (!isfinite(actor->animation.frames[j]) || actor->animation.clips[j]<-1 || actor->animation.clips[j]>=4096) return 0;
        }
        if (i && actor->slot <= frame->actors[i-1].slot) return 0;
        for (int j=0; j<3; ++j) {
            if (!isfinite(actor->spawn_position[j]) || !isfinite(actor->position[j]) || !isfinite(actor->previous_position[j]) ||
                !isfinite(actor->render_position[j]) || !isfinite(actor->previous_render_position[j]) ||
                !isfinite(actor->velocity[j]) || !isfinite(actor->motion_origin[j])) return 0;
        }
    }
    for (uint32_t i=0;i<frame->variable_count;++i) {
        const SyncVariable *variable=&frame->variables[i];
        if (!variable->name[0] || variable->scope>SYNC_VARIABLE_AREA_DECLARATION || !isfinite(variable->value)) return 0;
    }
    for (uint32_t i=0;i<frame->shot_count;++i) {
        const SyncShot *shot=&frame->shots[i];
        if (shot->phase>1 || !isfinite(shot->delta) || shot->delta<0 || shot->delta>.1f) return 0;
        if (!shot->id || shot->owner < -1 || shot->owner>=4096 || shot->weapon<0 || shot->weapon>=128 || (shot->owner>=0 && !shot->owner_generation)) return 0;
        if (i && shot->id<=frame->shots[i-1].id) return 0;
        if (shot->reserved || shot->source>SYNC_SHOT_PROJECTILE_CHILD || (shot->phase && shot->source!=SYNC_SHOT_WEAPON)) return 0;
        if (shot->source==SYNC_SHOT_PROJECTILE_CHILD) {
            if (shot->owner!=-1 || shot->depth<1 || shot->depth>3) return 0;
        } else if (shot->depth || (shot->source==SYNC_SHOT_ACTOR_FOLLOWUP && shot->owner<0)) return 0;
        if (shot->has_launch_center>1 || shot->has_launch_motion>1 || shot->has_projectile_seed>1 ||
            ((shot->has_launch_center || shot->has_launch_motion) && shot->owner<0)) return 0;
        const SyncProjectileSeed *seed=&shot->projectile_seed;
        if (!isfinite(seed->age) || !isfinite(seed->expires_at) || !isfinite(seed->cast_countdown)) return 0;
        if (!shot->has_projectile_seed && (seed->age || seed->expires_at || seed->cast_countdown)) return 0;
        for (int j=0;j<3;++j) {
            if (!isfinite(shot->origin[j]) || !isfinite(shot->launch_center[j]) || !isfinite(seed->cast_origin[j])) return 0;
            if (!shot->has_launch_center && shot->launch_center[j]!=0) return 0;
            if (!isfinite(shot->launch_motion[j]) || (!shot->has_launch_motion && shot->launch_motion[j]!=0)) return 0;
            if (!shot->has_projectile_seed && seed->cast_origin[j]!=0) return 0;
        }
        for (int j=0;j<16;++j) if (!isfinite(shot->transform[j])) return 0;
    }
    for (uint32_t i=0;i<frame->projectile_count;++i) {
        const SyncProjectile *p=&frame->projectiles[i];
        if (!p->id || (i && p->id<=frame->projectiles[i-1].id)) return 0;
        for (int j=0;j<32;++j) if (!isfinite(p->transform[j])) return 0;
        for (int j=0;j<3;++j) if (!isfinite(p->position[j]) || !isfinite(p->previous[j]) ||
            !isfinite(p->velocity[j]) || !isfinite(p->direction[j]) || !isfinite(p->previous_direction[j]) || !isfinite(p->cast_origin[j])) return 0;
        for (int j=0;j<14;++j) if (!isfinite(p->flight[j])) return 0;
    }
    for (uint32_t i=0;i<frame->tag_count;++i) {
        const SyncTag *tag=frame->tags+i;
        if (!tag->id || tag->from<0 || tag->from>=SYNC_MAX_ACTORS || tag->to<0 || tag->to>=SYNC_MAX_ACTORS ||
            tag->from==tag->to || !tag->from_generation || !tag->to_generation || tag->phase>1 ||
            tag->source>SYNC_TAG_ACTOR_UPDATE || (tag->source && (tag->phase || tag->parent)) ||
            tag->from_identity.character<0 || tag->from_identity.character>=4096 ||
            tag->to_identity.character<0 || tag->to_identity.character>=4096 ||
            !spawn_source_valid(tag->from_identity.spawn_source) || !spawn_source_valid(tag->to_identity.spawn_source) ||
            !isfinite(tag->delta) || tag->delta<0 || tag->delta>.1f || (i && tag->id<=frame->tags[i-1].id)) return 0;
        if (tag->parent) {
            int found=0;
            for (uint32_t j=0;j<i;++j) if (frame->tags[j].id==tag->parent && frame->tags[j].phase==tag->phase) found=1;
            if (!found) return 0;
        }
    }
    for (uint32_t i=0;i<frame->actor_input_count;++i) {
        const SyncActorInput *entry=frame->actor_inputs+i;
        if (!spawn_source_valid(entry->spawn_source) || entry->slot>=SYNC_MAX_ACTORS || !entry->generation || entry->character<0 || entry->character>=4096) return 0;
        for (int j=0;j<3;++j) if (!isfinite(entry->origin[j])) return 0;
    }
    for (uint32_t i=0;i<frame->cadence_count;++i) {
        const SyncCadence *entry=frame->cadence+i;
        if (!spawn_source_valid(entry->spawn_source) || entry->slot>=SYNC_MAX_ACTORS || !entry->generation || entry->character<0 || entry->character>=4096 ||
            !entry->period || entry->period>255 || entry->phase>255 || !isfinite(entry->elapsed) || entry->elapsed<0) return 0;
        for (int j=0;j<3;++j) if (!isfinite(entry->origin[j])) return 0;
    }
    for (uint32_t i=0;i<frame->geometry_count;++i) {
        const SyncCollider *entry=frame->geometry+i;
        if (!spawn_source_valid(entry->spawn_source) || !geometry_entry_valid(entry) || entry->manager_ordinal>frame->geometry_calls || (i && (entry->manager_ordinal<frame->geometry[i-1].manager_ordinal || (entry->manager_ordinal==frame->geometry[i-1].manager_ordinal && entry->slot<=frame->geometry[i-1].slot)))) return 0;
    }
    for (uint32_t i=0;i<frame->reaction_count;++i) if (!reaction_entry_valid(frame->reactions+i) ||
        !spawn_source_valid(frame->reactions[i].spawn_source) ||
        (frame->reactions[i].kind==SYNC_REACTION_CLIP && frame->reactions[i].arena_attacker_generation &&
         frame->level!=12)) return 0;
    for (uint32_t i=0;i<frame->model_input_count;++i)
        if (!model_input_entry_valid(frame->model_inputs+i) || !spawn_source_valid(frame->model_inputs[i].spawn_source)) return 0;
    return 1;
}

static uint32_t frame_checksum(const uint8_t *buffer,uint32_t bytes) {
    uint32_t checksum=2166136261u;
    for (uint32_t i=0;i<bytes;++i) {
        uint8_t value=i>=offsetof(SyncFrame,checksum) && i<offsetof(SyncFrame,checksum)+4 ? 0 : buffer[i];
        checksum=(checksum^value)*16777619u;
    }
    return checksum;
}
void sync_frame_copy_valid(SyncFrame *destination, const SyncFrame *source) {
    memcpy(destination, source, offsetof(SyncFrame, actors));
    const auto copy = [](auto &to, const auto &from, uint32_t count) {
        memcpy(to, from, count * sizeof(from[0]));
    };
    copy(destination->actors, source->actors, source->actor_count);
    copy(destination->variables, source->variables, source->variable_count);
    copy(destination->shots, source->shots, source->shot_count);
    copy(destination->projectiles, source->projectiles, source->projectile_count);
    copy(destination->tags, source->tags, source->tag_count);
    copy(destination->actor_inputs, source->actor_inputs, source->actor_input_count);
    copy(destination->cadence, source->cadence, source->cadence_count);
    copy(destination->geometry, source->geometry, source->geometry_count);
    copy(destination->reactions, source->reactions, source->reaction_count);
    copy(destination->model_inputs, source->model_inputs, source->model_input_count);
    copy(destination->spawn_timers, source->spawn_timers, source->spawn_timer_count);
    copy(destination->fire_task_gates, source->fire_task_gates, source->fire_task_gate_count);
    copy(destination->rts_team_timers, source->rts_team_timers, source->rts_team_timer_count);
    copy(destination->spawn_timer_choices, source->spawn_timer_choices, source->spawn_timer_choice_count);
    copy(destination->physics_choices, source->physics_choices, source->physics_choice_count);
    copy(destination->tick_gates, source->tick_gates, source->tick_gate_count);
    copy(destination->projectile_retires, source->projectile_retires, source->projectile_retire_count);
}

uint32_t sync_frame_encode(const SyncFrame *frame,void *buffer,uint32_t capacity) {
    uint32_t bytes=sync_frame_size(frame),header=(uint32_t)offsetof(SyncFrame,actors);
    if (!bytes || bytes>capacity || !sync_frame_valid(frame,bytes)) return 0;
    uint8_t *wire=static_cast<uint8_t *>(buffer);
    memcpy(wire,frame,header);
    memcpy(wire+header,frame->actors,frame->actor_count*sizeof(SyncActor));
    memcpy(wire+header+frame->actor_count*sizeof(SyncActor),frame->variables,frame->variable_count*sizeof(SyncVariable));
    uint32_t tail=header+frame->actor_count*sizeof(SyncActor)+frame->variable_count*sizeof(SyncVariable);
    memcpy(wire+tail,frame->shots,frame->shot_count*sizeof(SyncShot)); tail+=frame->shot_count*sizeof(SyncShot);
    memcpy(wire+tail,frame->projectiles,frame->projectile_count*sizeof(SyncProjectile));
    tail+=frame->projectile_count*sizeof(SyncProjectile);
    memcpy(wire+tail,frame->tags,frame->tag_count*sizeof(SyncTag)); tail+=frame->tag_count*sizeof(SyncTag);
    memcpy(wire+tail,frame->actor_inputs,frame->actor_input_count*sizeof(SyncActorInput));tail+=frame->actor_input_count*sizeof(SyncActorInput);
    memcpy(wire+tail,frame->cadence,frame->cadence_count*sizeof(SyncCadence));tail+=frame->cadence_count*sizeof(SyncCadence);
    memcpy(wire+tail,frame->geometry,frame->geometry_count*sizeof(SyncCollider));tail+=frame->geometry_count*sizeof(SyncCollider);
    memcpy(wire+tail,frame->reactions,frame->reaction_count*sizeof(SyncReactionChoice));tail+=frame->reaction_count*sizeof(SyncReactionChoice);
    memcpy(wire+tail,frame->model_inputs,frame->model_input_count*sizeof(SyncModelInput));
    tail+=frame->model_input_count*sizeof(SyncModelInput);
    memcpy(wire+tail,frame->spawn_timers,frame->spawn_timer_count*sizeof(SyncSpawnTimer));
    tail+=frame->spawn_timer_count*sizeof(SyncSpawnTimer);
    memcpy(wire+tail,frame->fire_task_gates,frame->fire_task_gate_count*sizeof(SyncFireTaskGate));
    tail+=frame->fire_task_gate_count*sizeof(SyncFireTaskGate);
    memcpy(wire+tail,frame->rts_team_timers,frame->rts_team_timer_count*sizeof(SyncRtsTeamTimers));
    tail+=frame->rts_team_timer_count*sizeof(SyncRtsTeamTimers);
    memcpy(wire+tail,frame->spawn_timer_choices,frame->spawn_timer_choice_count*sizeof(SyncSpawnTimerChoice));
    tail+=frame->spawn_timer_choice_count*sizeof(SyncSpawnTimerChoice);
    memcpy(wire+tail,frame->physics_choices,frame->physics_choice_count*sizeof(SyncPhysicsChoice));
    tail+=frame->physics_choice_count*sizeof(SyncPhysicsChoice);
    memcpy(wire+tail,frame->tick_gates,frame->tick_gate_count*sizeof(SyncTickGate));
    tail+=frame->tick_gate_count*sizeof(SyncTickGate);
    memcpy(wire+tail,frame->projectile_retires,frame->projectile_retire_count*sizeof(SyncProjectileRetireRequest));
    uint32_t checksum=frame_checksum(wire,bytes);
    memcpy(wire+offsetof(SyncFrame,checksum),&checksum,4);
    return bytes;
}
int sync_frame_decode(SyncFrame *frame,const void *buffer,uint32_t bytes) {
    uint32_t header=(uint32_t)offsetof(SyncFrame,actors);
    if (bytes<header) return 0;
    const uint8_t *wire=static_cast<const uint8_t *>(buffer);
    memcpy(frame,wire,header);
    if (sync_frame_size(frame)!=bytes || frame->checksum!=frame_checksum(wire,bytes)) return 0;
    memcpy(frame->actors,wire+header,frame->actor_count*sizeof(SyncActor));
    memcpy(frame->variables,wire+header+frame->actor_count*sizeof(SyncActor),frame->variable_count*sizeof(SyncVariable));
    uint32_t tail=header+frame->actor_count*sizeof(SyncActor)+frame->variable_count*sizeof(SyncVariable);
    memcpy(frame->shots,wire+tail,frame->shot_count*sizeof(SyncShot)); tail+=frame->shot_count*sizeof(SyncShot);
    memcpy(frame->projectiles,wire+tail,frame->projectile_count*sizeof(SyncProjectile));
    tail+=frame->projectile_count*sizeof(SyncProjectile);
    memcpy(frame->tags,wire+tail,frame->tag_count*sizeof(SyncTag)); tail+=frame->tag_count*sizeof(SyncTag);
    memcpy(frame->actor_inputs,wire+tail,frame->actor_input_count*sizeof(SyncActorInput));tail+=frame->actor_input_count*sizeof(SyncActorInput);
    memcpy(frame->cadence,wire+tail,frame->cadence_count*sizeof(SyncCadence));tail+=frame->cadence_count*sizeof(SyncCadence);
    memcpy(frame->geometry,wire+tail,frame->geometry_count*sizeof(SyncCollider));tail+=frame->geometry_count*sizeof(SyncCollider);
    memcpy(frame->reactions,wire+tail,frame->reaction_count*sizeof(SyncReactionChoice));tail+=frame->reaction_count*sizeof(SyncReactionChoice);
    memcpy(frame->model_inputs,wire+tail,frame->model_input_count*sizeof(SyncModelInput));
    tail+=frame->model_input_count*sizeof(SyncModelInput);
    memcpy(frame->spawn_timers,wire+tail,frame->spawn_timer_count*sizeof(SyncSpawnTimer));
    tail+=frame->spawn_timer_count*sizeof(SyncSpawnTimer);
    memcpy(frame->fire_task_gates,wire+tail,frame->fire_task_gate_count*sizeof(SyncFireTaskGate));
    tail+=frame->fire_task_gate_count*sizeof(SyncFireTaskGate);
    memcpy(frame->rts_team_timers,wire+tail,frame->rts_team_timer_count*sizeof(SyncRtsTeamTimers));
    tail+=frame->rts_team_timer_count*sizeof(SyncRtsTeamTimers);
    memcpy(frame->spawn_timer_choices,wire+tail,frame->spawn_timer_choice_count*sizeof(SyncSpawnTimerChoice));
    tail+=frame->spawn_timer_choice_count*sizeof(SyncSpawnTimerChoice);
    memcpy(frame->physics_choices,wire+tail,frame->physics_choice_count*sizeof(SyncPhysicsChoice));
    tail+=frame->physics_choice_count*sizeof(SyncPhysicsChoice);
    memcpy(frame->tick_gates,wire+tail,frame->tick_gate_count*sizeof(SyncTickGate));
    tail+=frame->tick_gate_count*sizeof(SyncTickGate);
    memcpy(frame->projectile_retires,wire+tail,frame->projectile_retire_count*sizeof(SyncProjectileRetireRequest));
    return sync_frame_valid(frame,bytes);
}
