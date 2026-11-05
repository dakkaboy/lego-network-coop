#pragma once
#include <stdint.h>
typedef struct ActionLease {uint32_t nonce,release,thread,epoch,sequence,frame_local;} ActionLease;
typedef struct ActionState {uint32_t action,clip,timer,duration,raw2f1,raw2f8,raw2fa,raw2fb;} ActionState;
typedef struct ActionTransitionRecord {
 uint32_t committed,id,scope,parent,thread,keyed,reason;
 ActionLease lease;
 uint32_t caller,state_local,requested_raw,returned_raw,flags_before,flags_after;
 uint32_t slot,generation,local_generation,character,actor_valid;
 uint32_t clock_before,clock_after,qpc_before[2],qpc_after[2];
 ActionState before,after;
} ActionTransitionRecord;
int game_sync_action_lease_get(ActionLease *out);
int game_sync_action_lease_valid(const ActionLease *lease);
uint32_t game_sync_action_lifecycle(void);
int action_transition_install(void);
