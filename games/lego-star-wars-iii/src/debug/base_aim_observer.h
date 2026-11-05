#pragma once
#include <stdint.h>
#define BASE_AIM_CAPACITY 1024
typedef struct BaseAimContext {uint32_t serial,epoch,sequence,scope_id,caller,mode;} BaseAimContext;
typedef struct BaseAimRecord {
 uint32_t committed,id,version,thread,qpc[2],clock,valid;
 BaseAimContext context;
 uint32_t actor_local,slot,generation,local_generation,character,action,clip,dda;
 uint32_t heading_ax,vector_bits[3],weapon_def_local,weapon70,weapon74;
 uint32_t model_local,model40,resource14,character_d0,action_flags;
 uint32_t helper_actor_raw[9],helper_globals[3],character_dc,mount_local,mount_f0c;
 uint32_t f0c,flags8d8,c78,c7c,bdc_local,cca,control_word,mxcsr_control;
} BaseAimRecord;
int projectiles_base_aim_context(const void *actor,BaseAimContext *out);
int base_aim_observer_install(void);
void base_aim_checkpoint(uint32_t *saved,const void *original_fx);
