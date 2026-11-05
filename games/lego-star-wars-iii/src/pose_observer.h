#pragma once
#include <stdint.h>
#include "sync_wire.h"
enum PoseBoundary {POSE_HOST_DISPATCH_COMPLETE=1,POSE_HOST_COLLECT_COMPLETE=2,POSE_CLIENT_DISPATCH_COMPLETE=3,POSE_CLIENT_PRE_CORRECT=4,POSE_CLIENT_POST_CORRECT=5};
#define POSE_OBSERVER_CAPACITY 4096u
typedef struct PoseRecord {
 uint32_t committed,id,epoch,sequence,stage,clock_before,clock_after,thread,qpc_before[2],qpc_after[2],lease,player;
 uint32_t slot,generation,local_generation,character,actor_local,controller_local,flags50,valid,invalid_reason;
 uint32_t position24[3],heading6c,headingf0c,matrix_f90_xyz[3],controller26,controller28,animation2e8,raw_ee0_f03[9],resource_f04_local;
 uint32_t model_local,model40,model_valid,actor_dda_raw,resource14,resource_valid;
} PoseRecord;
void pose_observer_capture(const SyncFrame *frame,uint32_t stage,uint32_t lease);
int game_sync_pose_valid(uint32_t lease);
void *game_sync_pose_player(unsigned role);
