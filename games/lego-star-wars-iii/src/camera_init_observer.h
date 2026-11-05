#pragma once
#include <stdint.h>
#define CAMERA_INIT_CAPACITY 128u
#define CAMERA_LATE_CAPACITY 64u
typedef struct CameraInitView {
    uint32_t pointer_local,raw_valid,type_raw,role_raw,target_local,target_raw_valid;
    uint8_t raw[0xb4],target_raw[0xe0];
} CameraInitView;
typedef struct CameraInitRole {
    uint32_t wrapper_local,wrapper_raw_valid,actor_local,actor_flags_raw;
    uint32_t controller_local,device_local,join_raw,fields_valid;
    uint8_t wrapper_raw[0x64];
} CameraInitRole;
typedef struct CameraInitRecord {
    uint32_t committed,id,stage,thread,qpc_low,qpc_high,clock,epoch,sequence;
    uint32_t phase,parent_local,parent_valid,state_local,mode_raw,focus_raw,script_phase_raw;
    uint32_t selected_role_raw,cinematic_raw,pending_level_raw,native_view_count_raw;
    uint32_t user1_device_raw,user1_flags_raw,device13_available_raw,globals_valid;
    CameraInitView views[4];
    CameraInitRole roles[2];
} CameraInitRecord;
void camera_init_observer_snapshot(const void *parent,uint32_t stage,int selected_role);
