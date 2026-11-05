#pragma once
#include <stdint.h>
#define POOL_BIRTH_CAPACITY 256
#define POOL_DESCRIPTOR_BYTES 250
#define POOL_PAYLOAD_BYTES 552
typedef struct PoolBirthRecord {
 uint32_t committed,id,parent,thread,caller,epoch,sequence;
 uint32_t clock_before,rng_game_before,rng_engine_before,qpc_before[2];
 uint32_t clock_after,rng_game_after,rng_engine_after,qpc_after[2];
 uint32_t descriptor_local,second_raw,descriptor_valid;
 unsigned char descriptor[252];
 uint32_t pool_before,capacity_before,cursor_before,pool_after,capacity_after,cursor_after;
 uint32_t result_local,pool_index_valid,pool_index,payload_valid;
 unsigned char payload[POOL_PAYLOAD_BYTES];
} PoolBirthRecord;
int pool_birth_observer_install(void);
