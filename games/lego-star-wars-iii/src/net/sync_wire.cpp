#include <math.h>
#include <stddef.h>
#include <string.h>
#include "sync_wire.h"
extern "C" {
#include "../sync/geometry_sync.h"
#include "../sync/reaction_sync.h"
#include "../sync/model_input_sync.h"
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
    if (frame->spawn_timer_count>SYNC_MAX_SPAWN_TIMERS) return 0;
    if (frame->actor_count>SYNC_MAX_ACTORS || frame->variable_count>SYNC_MAX_VARIABLES ||
        frame->shot_count>SYNC_MAX_SHOTS || frame->projectile_count>SYNC_MAX_PROJECTILES || frame->tag_count>SYNC_MAX_TAGS || frame->actor_input_count>SYNC_MAX_ACTORS || frame->cadence_count>SYNC_MAX_ACTORS || frame->geometry_count>SYNC_MAX_ACTORS || frame->geometry_calls>64 || frame->reaction_count>SYNC_MAX_ACTORS || frame->model_input_count>SYNC_MAX_ACTORS) return 0;
    return (uint32_t)offsetof(SyncFrame,actors) + frame->actor_count*sizeof(SyncActor) + frame->variable_count*sizeof(SyncVariable) +
           frame->shot_count*sizeof(SyncShot) + frame->projectile_count*sizeof(SyncProjectile) + frame->tag_count*sizeof(SyncTag) + frame->actor_input_count*sizeof(SyncActorInput) + frame->cadence_count*sizeof(SyncCadence) + frame->geometry_count*sizeof(SyncCollider) + frame->reaction_count*sizeof(SyncReactionChoice) + frame->model_input_count*sizeof(SyncModelInput) + frame->spawn_timer_count*sizeof(SyncSpawnTimer);
}

int sync_frame_valid(const SyncFrame *frame, uint32_t bytes) {
    if (bytes < offsetof(SyncFrame,actors) || frame->actor_count > SYNC_MAX_ACTORS || frame->variable_count>SYNC_MAX_VARIABLES ||
        bytes != sync_frame_size(frame) || (frame->native_span_plan & ~SYNC_NATIVE_SPAN_PLAN_MASK) || (frame->native_span_calls & ~SYNC_NATIVE_SPAN_CALLS_MASK) || !frame->epoch || !frame->sequence || frame->level < 0 || frame->level >= 4096 ||
        !isfinite(frame->delta) || frame->delta < 0 || frame->delta > 0.1f ||
        !isfinite(frame->engine_delta) || frame->engine_delta<0 || frame->engine_delta>.1f || frame->engine_mode>16 || frame->world_calls>64 || frame->tick_calls>64 || frame->combat_ready>1 || frame->actor_input_reserved || frame->cadence_reserved || frame->reaction_reserved || frame->model_input_reserved || frame->actor_input_count>SYNC_MAX_ACTORS || frame->cadence_count>SYNC_MAX_ACTORS || frame->geometry_count>SYNC_MAX_ACTORS || frame->geometry_calls>64 || frame->reaction_count>SYNC_MAX_ACTORS || frame->model_input_count>SYNC_MAX_ACTORS) return 0;
    if (frame->spawn_timer_reserved || (frame->sequence!=1 && frame->spawn_timer_count)) return 0;
    for (uint32_t i=0;i<frame->spawn_timer_count;++i) {
        const SyncSpawnTimer &timer=frame->spawn_timers[i];
        if (!timer.id || !timer.type || !isfinite(timer.remaining) ||
            (i && frame->spawn_timers[i-1].id>=timer.id)) return 0;
    }
    uint32_t party_seen=0;
    for (uint32_t i=0; i<frame->actor_count; ++i) {
        const SyncActor *actor = &frame->actors[i];
        if (actor->slot >= 4096 || actor->character < -1 || actor->character >= 4096 || !actor->generation || actor->player < -1 || actor->player > 1) return 0;
        if (actor->has_wallet>1) return 0;
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
                !isfinite(actor->velocity[j])) return 0;
        }
    }
    for (uint32_t i=0;i<frame->variable_count;++i) {
        const SyncVariable *variable=&frame->variables[i];
        if (!variable->name[0] || variable->scope>1 || !isfinite(variable->value)) return 0;
    }
    for (uint32_t i=0;i<frame->shot_count;++i) {
        const SyncShot *shot=&frame->shots[i];
        if (shot->phase>1 || !isfinite(shot->delta) || shot->delta<0 || shot->delta>.1f) return 0;
        if (!shot->id || shot->owner < -1 || shot->owner>=4096 || shot->weapon<0 || shot->weapon>=128 || (shot->owner>=0 && !shot->owner_generation)) return 0;
        if (i && shot->id<=frame->shots[i-1].id) return 0;
        for (int j=0;j<3;++j) if (!isfinite(shot->origin[j])) return 0;
        for (int j=0;j<16;++j) if (!isfinite(shot->transform[j])) return 0;
    }
    for (uint32_t i=0;i<frame->projectile_count;++i) {
        const SyncProjectile *p=&frame->projectiles[i];
        if (!p->id || (i && p->id<=frame->projectiles[i-1].id)) return 0;
        for (int j=0;j<32;++j) if (!isfinite(p->transform[j])) return 0;
        for (int j=0;j<3;++j) if (!isfinite(p->position[j]) || !isfinite(p->previous[j]) ||
            !isfinite(p->velocity[j]) || !isfinite(p->direction[j]) || !isfinite(p->previous_direction[j])) return 0;
        for (int j=0;j<14;++j) if (!isfinite(p->flight[j])) return 0;
    }
    for (uint32_t i=0;i<frame->tag_count;++i) {
        const SyncTag *tag=frame->tags+i;
        if (!tag->id || tag->from<0 || tag->from>=SYNC_MAX_ACTORS || tag->to<0 || tag->to>=SYNC_MAX_ACTORS ||
            tag->from==tag->to || !tag->from_generation || !tag->to_generation || tag->phase>1 ||
            !isfinite(tag->delta) || tag->delta<0 || tag->delta>.1f || (i && tag->id<=frame->tags[i-1].id)) return 0;
        if (tag->parent) {
            int found=0;
            for (uint32_t j=0;j<i;++j) if (frame->tags[j].id==tag->parent && frame->tags[j].phase==tag->phase) found=1;
            if (!found) return 0;
        }
    }
    for (uint32_t i=0;i<frame->actor_input_count;++i) {
        const SyncActorInput *entry=frame->actor_inputs+i;
        if (entry->slot>=SYNC_MAX_ACTORS || !entry->generation || entry->character<0 || entry->character>=4096) return 0;
        for (int j=0;j<3;++j) if (!isfinite(entry->origin[j])) return 0;
    }
    for (uint32_t i=0;i<frame->cadence_count;++i) {
        const SyncCadence *entry=frame->cadence+i;
        if (entry->slot>=SYNC_MAX_ACTORS || !entry->generation || entry->character<0 || entry->character>=4096 ||
            !entry->period || entry->period>255 || entry->phase>255 || !isfinite(entry->elapsed) || entry->elapsed<0) return 0;
        for (int j=0;j<3;++j) if (!isfinite(entry->origin[j])) return 0;
    }
    for (uint32_t i=0;i<frame->geometry_count;++i) {
        const SyncCollider *entry=frame->geometry+i;
        if (!geometry_entry_valid(entry) || entry->manager_ordinal>frame->geometry_calls || (i && (entry->manager_ordinal<frame->geometry[i-1].manager_ordinal || (entry->manager_ordinal==frame->geometry[i-1].manager_ordinal && entry->slot<=frame->geometry[i-1].slot)))) return 0;
    }
    for (uint32_t i=0;i<frame->reaction_count;++i) if (!reaction_entry_valid(frame->reactions+i) ||
        (frame->reactions[i].arena_attacker_generation && frame->level!=12)) return 0;
    for (uint32_t i=0;i<frame->model_input_count;++i) if (!model_input_entry_valid(frame->model_inputs+i)) return 0;
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
    return sync_frame_valid(frame,bytes);
}
