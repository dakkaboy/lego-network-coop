#pragma once
#include <stddef.h>
#include <stdint.h>
#include "game_state.h"

typedef struct NativeSceneReadOps {
    void *context;
    int (*read)(void *context,uint32_t address,void *out,size_t bytes);
    int (*range)(void *context,uint32_t address,size_t bytes,int writable);
} NativeSceneReadOps;

static inline int native_scene_read(const NativeSceneReadOps *ops,uint32_t address,void *out,size_t bytes) {
    return ops && ops->read && ops->range && address && bytes && bytes<=UINT32_MAX-address &&
        ops->range(ops->context,address,bytes,0) && ops->read(ops->context,address,out,bytes);
}
static inline int native_scene_u32(const NativeSceneReadOps *ops,uint32_t address,uint32_t *out) {
    return native_scene_read(ops,address,out,sizeof(*out));
}
static inline int native_scene_span(const NativeSceneReadOps *ops,uint32_t base,uint32_t count,uint32_t stride) {
    if (!count) return 1;
    return base && stride && count<=(UINT32_MAX-base)/stride &&
        ops->range(ops->context,base,(size_t)count*stride,0);
}
static inline int native_scene_table(const NativeSceneReadOps *ops,uint32_t base_global,uint32_t count_global,
                                      uint32_t maximum,uint32_t stride,uint32_t *base,uint32_t *count) {
    return native_scene_u32(ops,base_global,base) && native_scene_u32(ops,count_global,count) &&
        *count<=maximum && native_scene_span(ops,*base,*count,stride);
}

static inline int native_profile_storage_bound(const NativeSceneReadOps *ops) {
    const uint32_t alias_globals[]={0xfb519c,0xfb847c,0xfb4bdc,0xfb4cb4,0xfbc1dc,0xfbc1cc,0xfb3110};
    const uint32_t offsets[]={0x5b84,0x1c,0xb248,0x6238,0x6208,0x6210,0xb57c};
    uint32_t profile,magic,alias,levels,level_count,areas,area_count,extra,extra_count;
    uint32_t records,registry,registry_base,registry_count,callback,optional;
    uint16_t record_count;
    if (!native_scene_u32(ops,0xfbd8bc,&profile) || !profile || profile>UINT32_MAX-0xb5c0 ||
        !ops->range(ops->context,profile,0xb5c0,1) || !native_scene_u32(ops,profile,&magic) || magic!=0x500) return 0;
    for (unsigned i=0;i<sizeof(offsets)/sizeof(offsets[0]);++i)
        if (!native_scene_u32(ops,alias_globals[i],&alias) || alias!=profile+offsets[i]) return 0;
    if (!native_scene_table(ops,0xfb8404,0xfb8410,0x1c2,0x1b0,&levels,&level_count) ||
        !native_scene_table(ops,0xfb5154,0xfb5160,0x48,0xd80,&areas,&area_count) ||
        !native_scene_table(ops,0xfbd7b8,0xfbd7bc,8,0x18,&extra,&extra_count) ||
        !native_scene_u32(ops,0xe6de7c,&records) || !native_scene_read(ops,0xe6de82,&record_count,2) ||
        !native_scene_span(ops,records,record_count,0x20)) return 0;
    for (uint32_t i=0;i<record_count;++i) {
        uint8_t flags;int16_t index;
        if (!native_scene_read(ops,records+i*0x20+9,&flags,1)) return 0;
        if ((flags&2) && (!native_scene_read(ops,records+i*0x20,&index,2) || index<0 || index>=0x32c)) return 0;
    }
    if (!native_scene_u32(ops,0xe6e0bc,&registry) || !native_scene_u32(ops,registry,&registry_base) ||
        !native_scene_u32(ops,registry+4,&registry_count) || registry_count>INT32_MAX ||
        !native_scene_span(ops,registry_base,registry_count,0x18)) return 0;
    for (uint32_t i=0;i<registry_count;++i) {
        uint32_t definition;uint8_t standalone;int8_t area_index;int16_t level_index;
        const uint32_t record=registry_base+i*0x18;
        if (!native_scene_u32(ops,record,&definition) || !definition || definition>UINT32_MAX-12 || !native_scene_u32(ops,definition+8,&alias) ||
            !native_scene_read(ops,record+0x12,&standalone,1)) return 0;
        if (!standalone) {
            if (!native_scene_read(ops,record+0xf,&area_index,1)) return 0;
            if (area_index!=-1) { if (area_index<0 || (uint32_t)area_index>=area_count) return 0; }
            else if (!native_scene_read(ops,record+0x10,&level_index,2) ||
                     (level_index!=-1 && (level_index<0 || (uint32_t)level_index>=level_count))) return 0;
        }
    }
    if (!native_scene_u32(ops,0xe6e124,&callback) || callback!=0x8f02b0 || !ops->range(ops->context,callback,1,0)) return 0;
    for (unsigned i=0;i<2;++i)
        if (!native_scene_u32(ops,0xfb4d58+i*8,&callback) ||
            (callback && (callback!=0x403e80 || !ops->range(ops->context,callback,1,0)))) return 0;
    if (!native_scene_u32(ops,0xfbbbcc,&optional)) return 0;
    if (optional) {
        uint8_t count;
        if (optional>UINT32_MAX-0x21 || !native_scene_read(ops,optional+0x20,&count,1)) return 0;
    }
    /* Capture bindings again: readiness is not a lease across a later native callback. */
    if (!native_scene_u32(ops,0xfbd8bc,&alias) || alias!=profile) return 0;
    for (unsigned i=0;i<sizeof(offsets)/sizeof(offsets[0]);++i)
        if (!native_scene_u32(ops,alias_globals[i],&alias) || alias!=profile+offsets[i]) return 0;
    return 1;
}

static inline int native_scene_party_bound(const NativeSceneReadOps *ops,const uint32_t party[8]) {
    uint32_t resource,value,controller;int16_t character;
    if (!party[0] || !party[1] || party[0]>UINT32_MAX-0x1440 || party[1]>UINT32_MAX-0x1440 ||
        !ops->range(ops->context,party[0],0x1440,0) || !ops->range(ops->context,party[1],0x1440,0) ||
        !native_scene_read(ops,party[0]+0xdc0,&character,2) || character<0 ||
        !native_scene_u32(ops,party[0]+0xf08,&resource) || !native_scene_u32(ops,resource,&value)) return 0;
    return native_scene_u32(ops,party[1]+0x6cc,&controller) && controller &&
        controller<=UINT32_MAX-0x60 && ops->range(ops->context,controller,0x60,0);
}

static inline int native_scene_input_capability(const NativeSceneReadOps *ops,int expected_level,uint32_t expected_world) {
    uint32_t world,definition,titles,catalog,count,flags,pool,actor_count,party[8],again;
    int16_t level;
    if (expected_level<0 || !expected_world ||
        !native_scene_u32(ops,0xfb4a20,&world) || world!=expected_world ||
        !ops->range(ops->context,world,0x22e8,0) || !native_scene_u32(ops,world+0x220,&definition) ||
        !native_scene_table(ops,0xfb8404,0xfb8410,0x1c2,0x1b0,&catalog,&count) ||
        (uint32_t)expected_level>=count || definition!=catalog+(uint32_t)expected_level*0x1b0 ||
        !native_scene_u32(ops,0xfb8414,&titles) || !titles || definition==titles ||
        !ops->range(ops->context,titles,0x96,0) ||
        !native_scene_read(ops,definition+0x94,&level,2) || level!=expected_level ||
        !native_scene_u32(ops,definition+0x50,&flags) || (flags&0x40000000u) ||
        !native_scene_u32(ops,0xfb2f60,&pool) || !native_scene_u32(ops,0xfb2e3c,&actor_count) || actor_count>4096 ||
        !native_scene_span(ops,pool,actor_count,0x1440) || !native_scene_read(ops,0xfb4940,party,sizeof(party))) return GAME_SCENE_NOT_READY;
    unsigned present=0;
    for (unsigned i=0;i<8;++i) if (party[i]) ++present;
    int result=GAME_SCENE_NO_PARTY_INPUT;
    if ((flags&2) || present) {
        if (!actor_count || !native_scene_party_bound(ops,party)) return GAME_SCENE_NOT_READY;
        result=GAME_SCENE_PARTY_INPUT;
    }
    if (!native_scene_u32(ops,0xfb4a20,&again) || again!=world ||
        !native_scene_u32(ops,world+0x220,&again) || again!=definition ||
        !native_scene_u32(ops,definition+0x50,&again) || again!=flags ||
        !native_scene_u32(ops,0xfb8404,&again) || again!=catalog ||
        !native_scene_u32(ops,0xfb8410,&again) || again!=count ||
        !native_scene_u32(ops,0xfb2f60,&again) || again!=pool ||
        !native_scene_u32(ops,0xfb2e3c,&again) || again!=actor_count) return GAME_SCENE_NOT_READY;
    for (unsigned i=0;i<8;++i)
        if (!native_scene_u32(ops,0xfb4940+i*4,&again) || again!=party[i]) return GAME_SCENE_NOT_READY;
    return result;
}
