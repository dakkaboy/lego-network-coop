#pragma once
#include "../net/sync_wire.h"
#include "coherent_frame_fence.h"
#ifdef __cplusplus
extern "C" {
#endif
int native_tick_install(void);
int native_tick_begin(SyncFrame *,int,const CoherentFrameToken *);
int native_tick_finish(void);
void native_tick_cancel(const CoherentFrameToken *);
uint32_t native_tick_clock_input(const uint32_t witness[2],uint32_t sample);
enum {
    NATIVE_TICK_RTS_PRODUCER_GAME_RNG = 0x562d9b, NATIVE_TICK_RTS_PRODUCER_ENGINE_RNG = 0x562da1,
    NATIVE_TICK_RTS_GAME_RNG = 0x562dd9, NATIVE_TICK_RTS_ENGINE_RNG = 0x562dde,
    NATIVE_TICK_RTS_PACK_ADMISSION = 0x547ec2,
    NATIVE_TICK_RTS_TURRET_HEADING = 0x561a65,
    NATIVE_TICK_RTS_TURRET_PILOT = 0x561a6c,
    NATIVE_TICK_RTS_TURRET_AIM = 0x561b82,
    NATIVE_TICK_PACK_ATTACK = 0x45ff57,
    NATIVE_TICK_PACK_ATTACK_WITNESS = 0x45ff79,
    NATIVE_TICK_PACK_MODE_MEMBER = 0x475753,
    NATIVE_TICK_PACK_MODE_WITNESS = 0x475757,
    NATIVE_TICK_PACK_MODE_VALUE = 0x475760,
    NATIVE_TICK_PACK_TIMER_MEMBER = 0x460424,
    NATIVE_TICK_PACK_TIMER_SEED = 0x460429,
    NATIVE_TICK_PACK_REARM_MEMBER = 0x460705,
    NATIVE_TICK_PACK_REARM_SEED = 0x46070a,
    NATIVE_TICK_PACK_FORMATION_MEMBER = 0x4604f4,
    NATIVE_TICK_PACK_FORMATION_LEAVE = 0x460508,
    NATIVE_TICK_FIRE_VISIBILITY = 0x879ea3,
    NATIVE_TICK_FIRE_VISIBILITY_ACTOR = 0x879ea8,
    NATIVE_TICK_PACK_ANIMATION_MEMBER = 0x4087a0,
    NATIVE_TICK_PACK_ANIMATION_REQUEST = 0x4087a5,
    NATIVE_TICK_PACK_ANIMATION_STATE = 0x4087bb,
    NATIVE_TICK_PACK_ANIMATION_CLOCK = 0x4087e3,
    NATIVE_TICK_PACK_ANIMATION_DELTA = 0x4087ec,
    NATIVE_TICK_PACK_MOVE_TIMER = 0x45fd0d, NATIVE_TICK_PACK_MOVE_TIMER_SEED = 0x45fd12,
    NATIVE_TICK_PACK_MOVE_HEADING = 0x45fd8a, NATIVE_TICK_PACK_MOVE_HEADING_SEED = 0x45fd8f,
    NATIVE_TICK_PACK_MOVE_CHOICE = 0x460218, NATIVE_TICK_PACK_MOVE_CHOICE_SEED = 0x46021d,
    NATIVE_TICK_PACK_POSE_QUERY = 0x47570f,
    NATIVE_TICK_PACK_POSE_COMMIT = 0x6d7670,
    NATIVE_TICK_PACK_CELL_MEMBER = 0x475716, NATIVE_TICK_PACK_CELL_FLAGS = 0x47571a,
    NATIVE_TICK_PACK_HIT_REACTION = 0x45f44e,
    NATIVE_TICK_PACK_HIT_DEBRIS = 0x45f59d,
    NATIVE_TICK_PACK_HIT_SHOCK = 0x45fa14,
    NATIVE_TICK_PACK_HIT_HEADING = 0x43356a,
    NATIVE_TICK_PACK_IMPULSE_TIMER = 0x43455b,
    NATIVE_TICK_PACK_IMPULSE_SPEED = 0x43457b,
    NATIVE_TICK_PACK_IMPULSE_HEADING = 0x4345f0
};
static inline int native_pack_hit_rng_site(uint32_t site) {
    switch(site) {
    case NATIVE_TICK_PACK_HIT_REACTION:case NATIVE_TICK_PACK_HIT_DEBRIS:
    case NATIVE_TICK_PACK_HIT_SHOCK:case NATIVE_TICK_PACK_HIT_HEADING:
    case NATIVE_TICK_PACK_IMPULSE_TIMER:case NATIVE_TICK_PACK_IMPULSE_SPEED:
    case NATIVE_TICK_PACK_IMPULSE_HEADING:return 1;
    default:return 0;
    }
}
static inline unsigned native_pack_pose_field(uint32_t site) {
    const uint32_t bases[]={NATIVE_TICK_PACK_POSE_QUERY,NATIVE_TICK_PACK_POSE_COMMIT};
    for (unsigned i=0;i<2;++i) if(site>=bases[i] && site-bases[i]<=25 && (site-bases[i])%5==0)
        return (site-bases[i])/5+1;
    return 0;
}
static inline int native_track_time_valid(uint32_t sample) {
    return (sample&0x7fffffffu)<0x7f800000u;
}
static inline int native_tick_gate_valid(const SyncTickGate *gate) {
    if(gate) {
        const unsigned field=native_pack_pose_field(gate->site);
        if(field) return field==1 || (field==6 ? gate->value<=UINT16_MAX : native_track_time_valid(gate->value));
    }
    return gate && ((gate->site==0x8888cd && gate->value<=UINT8_MAX) ||
        (gate->site==0x888889 && gate->value<=1) ||
        (gate->site==NATIVE_TICK_RTS_PACK_ADMISSION && gate->value<32) ||
        ((gate->site==NATIVE_TICK_RTS_TURRET_HEADING || gate->site==NATIVE_TICK_RTS_TURRET_AIM) && (gate->value>>16)<SYNC_MAX_ACTORS) ||
        (gate->site==NATIVE_TICK_RTS_TURRET_PILOT && gate->value!=0) ||
        (gate->site==NATIVE_TICK_FIRE_VISIBILITY && (gate->value>>8)<SYNC_MAX_ACTORS) ||
        (gate->site==NATIVE_TICK_FIRE_VISIBILITY_ACTOR && gate->value!=0) ||
        native_pack_hit_rng_site(gate->site) || native_pack_hit_rng_site(gate->site-5) ||
        gate->site==NATIVE_TICK_PACK_CELL_MEMBER ||
        (gate->site==NATIVE_TICK_PACK_CELL_FLAGS && !(gate->value&~0x60u)) ||
        gate->site==NATIVE_TICK_PACK_MOVE_TIMER || gate->site==NATIVE_TICK_PACK_MOVE_TIMER_SEED ||
        gate->site==NATIVE_TICK_PACK_MOVE_HEADING || gate->site==NATIVE_TICK_PACK_MOVE_HEADING_SEED ||
        gate->site==NATIVE_TICK_PACK_MOVE_CHOICE || gate->site==NATIVE_TICK_PACK_MOVE_CHOICE_SEED ||
        gate->site==NATIVE_TICK_PACK_ANIMATION_MEMBER || gate->site==NATIVE_TICK_PACK_ANIMATION_REQUEST ||
        (gate->site==NATIVE_TICK_PACK_ANIMATION_STATE && (gate->value&~0x1ffffu)==0) ||
        ((gate->site==NATIVE_TICK_PACK_ANIMATION_CLOCK || gate->site==NATIVE_TICK_PACK_ANIMATION_DELTA) && native_track_time_valid(gate->value)) ||
        gate->site==NATIVE_TICK_PACK_ATTACK || gate->site==NATIVE_TICK_PACK_ATTACK_WITNESS ||
        gate->site==NATIVE_TICK_PACK_MODE_MEMBER || gate->site==NATIVE_TICK_PACK_MODE_WITNESS ||
        (gate->site==NATIVE_TICK_PACK_MODE_VALUE && (gate->value&~0x3ffu)==0) ||
        gate->site==NATIVE_TICK_PACK_TIMER_MEMBER || gate->site==NATIVE_TICK_PACK_TIMER_SEED ||
        gate->site==NATIVE_TICK_PACK_REARM_MEMBER || gate->site==NATIVE_TICK_PACK_REARM_SEED ||
        gate->site==NATIVE_TICK_PACK_FORMATION_MEMBER ||
        (gate->site==NATIVE_TICK_PACK_FORMATION_LEAVE && gate->value<=1) ||
        (gate->site==0x889edc && (gate->value==UINT32_MAX || gate->value<=0x14)) ||
        (gate->site==0x9dda14 && (gate->value==1 || (!(gate->value&1) && gate->value/2<=SYNC_MAX_ACTORS))) ||
        ((gate->site==NATIVE_TICK_RTS_GAME_RNG || gate->site==NATIVE_TICK_RTS_PRODUCER_GAME_RNG) &&
         gate->value<=UINT16_MAX) ||
        gate->site==NATIVE_TICK_RTS_ENGINE_RNG || gate->site==NATIVE_TICK_RTS_PRODUCER_ENGINE_RNG ||
        gate->site==0x7b8ae1 || gate->site==0x7b8afd ||
        (gate->site==0x7b8b08 && native_track_time_valid(gate->value)));
}
static inline int native_tick_stream_valid(const SyncTickGate *gates,uint32_t count) {
    if (count>SYNC_MAX_TICK_GATES || (count && !gates)) return 0;
    for (uint32_t i=0;i<count;++i) {
        if (!native_tick_gate_valid(gates+i)) return 0;
        if (native_pack_hit_rng_site(gates[i].site)) {
            if(count-i<2 || gates[i+1].site!=gates[i].site+5 || gates[i+1].clock!=gates[i].clock)return 0;
            ++i;
        } else if(native_pack_hit_rng_site(gates[i].site-5))return 0;
        else if (native_pack_pose_field(gates[i].site)==1) {
            if(count-i<6)return 0;
            for(unsigned j=1;j<6;++j)
                if(gates[i+j].site!=gates[i].site+j*5 || gates[i+j].clock!=gates[i].clock || !native_tick_gate_valid(gates+i+j))return 0;
            i+=5;
        } else if (native_pack_pose_field(gates[i].site)) return 0;
        else if (gates[i].site==0x7b8ae1) {
            if (count-i<3 || gates[i+1].site!=0x7b8afd || gates[i+2].site!=0x7b8b08 ||
                gates[i].clock!=gates[i+1].clock || gates[i].clock!=gates[i+2].clock ||
                !native_tick_gate_valid(gates+i+2)) return 0;
            i+=2;
        } else if (gates[i].site==NATIVE_TICK_PACK_ANIMATION_MEMBER) {
            if (count-i<5 || gates[i+1].site!=NATIVE_TICK_PACK_ANIMATION_REQUEST ||
                gates[i+2].site!=NATIVE_TICK_PACK_ANIMATION_STATE || gates[i+3].site!=NATIVE_TICK_PACK_ANIMATION_CLOCK ||
                gates[i+4].site!=NATIVE_TICK_PACK_ANIMATION_DELTA) return 0;
            for (unsigned j=1;j<5;++j)
                if (gates[i+j].clock!=gates[i].clock || !native_tick_gate_valid(gates+i+j)) return 0;
            i+=4;
        } else if (gates[i].site==NATIVE_TICK_PACK_MODE_MEMBER) {
            if (count-i<3 || gates[i+1].site!=NATIVE_TICK_PACK_MODE_WITNESS || gates[i+2].site!=NATIVE_TICK_PACK_MODE_VALUE ||
                gates[i+1].clock!=gates[i].clock || gates[i+2].clock!=gates[i].clock || !native_tick_gate_valid(gates+i+2)) return 0;
            i+=2;
        } else if (gates[i].site==NATIVE_TICK_RTS_GAME_RNG || gates[i].site==NATIVE_TICK_RTS_PRODUCER_GAME_RNG) {
            const uint32_t engine_site=gates[i].site==NATIVE_TICK_RTS_GAME_RNG ?
                NATIVE_TICK_RTS_ENGINE_RNG : NATIVE_TICK_RTS_PRODUCER_ENGINE_RNG;
            if (count-i<2 || gates[i+1].site!=engine_site ||
                gates[i].clock!=gates[i+1].clock) return 0;
            ++i;
        } else if (gates[i].site==NATIVE_TICK_RTS_TURRET_HEADING || gates[i].site==NATIVE_TICK_RTS_TURRET_AIM || gates[i].site==NATIVE_TICK_PACK_ATTACK ||
                   gates[i].site==NATIVE_TICK_PACK_TIMER_MEMBER || gates[i].site==NATIVE_TICK_PACK_REARM_MEMBER ||
                   gates[i].site==NATIVE_TICK_PACK_FORMATION_MEMBER || gates[i].site==NATIVE_TICK_FIRE_VISIBILITY ||
                   gates[i].site==NATIVE_TICK_PACK_MOVE_TIMER || gates[i].site==NATIVE_TICK_PACK_MOVE_HEADING ||
                   gates[i].site==NATIVE_TICK_PACK_MOVE_CHOICE || gates[i].site==NATIVE_TICK_PACK_CELL_MEMBER) {
            uint32_t witness=NATIVE_TICK_RTS_TURRET_PILOT;
            if (gates[i].site==NATIVE_TICK_PACK_ATTACK) witness=NATIVE_TICK_PACK_ATTACK_WITNESS;
            if (gates[i].site==NATIVE_TICK_PACK_TIMER_MEMBER) witness=NATIVE_TICK_PACK_TIMER_SEED;
            if (gates[i].site==NATIVE_TICK_PACK_REARM_MEMBER) witness=NATIVE_TICK_PACK_REARM_SEED;
            if (gates[i].site==NATIVE_TICK_PACK_FORMATION_MEMBER) witness=NATIVE_TICK_PACK_FORMATION_LEAVE;
            if (gates[i].site==NATIVE_TICK_FIRE_VISIBILITY) witness=NATIVE_TICK_FIRE_VISIBILITY_ACTOR;
            if (gates[i].site==NATIVE_TICK_PACK_MOVE_TIMER) witness=NATIVE_TICK_PACK_MOVE_TIMER_SEED;
            if (gates[i].site==NATIVE_TICK_PACK_MOVE_HEADING) witness=NATIVE_TICK_PACK_MOVE_HEADING_SEED;
            if (gates[i].site==NATIVE_TICK_PACK_MOVE_CHOICE) witness=NATIVE_TICK_PACK_MOVE_CHOICE_SEED;
            if (gates[i].site==NATIVE_TICK_PACK_CELL_MEMBER) witness=NATIVE_TICK_PACK_CELL_FLAGS;
            if (count-i<2 || gates[i+1].site!=witness ||
                gates[i+1].clock!=gates[i].clock || !native_tick_gate_valid(gates+i+1)) return 0;
            ++i;
        } else if (gates[i].site==0x7b8afd || gates[i].site==0x7b8b08 ||
                   gates[i].site==NATIVE_TICK_PACK_ANIMATION_REQUEST || gates[i].site==NATIVE_TICK_PACK_ANIMATION_STATE ||
                   gates[i].site==NATIVE_TICK_PACK_ANIMATION_CLOCK || gates[i].site==NATIVE_TICK_PACK_ANIMATION_DELTA ||
                   gates[i].site==NATIVE_TICK_FIRE_VISIBILITY_ACTOR ||
                   gates[i].site==NATIVE_TICK_RTS_TURRET_PILOT || gates[i].site==NATIVE_TICK_PACK_ATTACK_WITNESS ||
                   gates[i].site==NATIVE_TICK_PACK_TIMER_SEED ||
                   gates[i].site==NATIVE_TICK_PACK_REARM_SEED ||
                   gates[i].site==NATIVE_TICK_PACK_MOVE_TIMER_SEED || gates[i].site==NATIVE_TICK_PACK_MOVE_HEADING_SEED ||
                   gates[i].site==NATIVE_TICK_PACK_MOVE_CHOICE_SEED || gates[i].site==NATIVE_TICK_PACK_CELL_FLAGS ||
                   gates[i].site==NATIVE_TICK_PACK_FORMATION_LEAVE ||
                   gates[i].site==NATIVE_TICK_PACK_MODE_WITNESS || gates[i].site==NATIVE_TICK_PACK_MODE_VALUE ||
                   gates[i].site==NATIVE_TICK_RTS_ENGINE_RNG ||
                   gates[i].site==NATIVE_TICK_RTS_PRODUCER_ENGINE_RNG) return 0;
    }
    return 1;
}
#ifdef __cplusplus
}
#endif
