#pragma once
#include <stddef.h>
#include <stdint.h>

#define EQUIPMENT_ORACLE_LIMIT 64
typedef int (*EquipmentRead)(void *context,uint32_t address,void *destination,size_t bytes);
typedef enum EquipmentStatus {
    EQUIPMENT_UNKNOWN=0,EQUIPMENT_COMPLETE=1
} EquipmentStatus;
typedef enum EquipmentReason {
    EQUIPMENT_OK=0,EQUIPMENT_BAD_ARGUMENT,EQUIPMENT_UNREADABLE,
    EQUIPMENT_CYCLE,EQUIPMENT_TRUNCATED,EQUIPMENT_ADDRESS_OVERFLOW
} EquipmentReason;
typedef struct EquipmentOracle {
    EquipmentStatus status;
    EquipmentReason reason;
    uint32_t node_count,type3_count,held_member;
    uint32_t all_flags[4],active_flags[4];
    int cache_comparison_known,cache_matches;
} EquipmentOracle;

/* Completeness assumes the supplied reader observes a stable list. Partial
   aggregates are discarded; this routine never establishes cache freshness. */
EquipmentOracle equipment_oracle(EquipmentRead read,void *context,uint32_t actor,
                                 const uint32_t cached_all[4],const uint32_t cached_active[4]);
