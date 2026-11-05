#pragma once
#include <stdint.h>
#include "coherent_frame_fence.h"
#define HIT_ENTRY_CAPACITY 512
typedef struct HitEntryActor { uint32_t local,slot,generation,allocation,character,health,model,valid; } HitEntryActor;
typedef struct HitEntryRecord {
 uint32_t committed,id,session,epoch,sequence,clock,thread,caller,qpc[2],cw,mxcsr;
 uint32_t arguments[6];
 HitEntryActor attacker,victim;
 uint32_t source_local,source_status,shot_id,shot_owner,shot_generation,weapon,instance_serial,creation_count;
} HitEntryRecord;
int hit_entry_install(const CoherentFrameToken *original);
void hit_entry_poll(const CoherentFrameToken *original);
