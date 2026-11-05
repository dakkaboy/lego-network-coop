#pragma once
#include <stdint.h>
#define INTENT_FRAME_CAPACITY 8192
enum IntentFrameEvent {
 INTENT_SCOPE_BEGIN=1,INTENT_SCOPE_END,INTENT_WRITER_TRANSFORMED,INTENT_WRITER_MODEL,
 INTENT_WRITER_SPECIAL,INTENT_DUMMY_ZERO,INTENT_HISTORY_PREVIOUS,INTENT_HISTORY_LAST,
 INTENT_CONSUMER_DEFAULT,INTENT_CONSUMER_CALLBACK
};
enum IntentAngleKind {INTENT_ANGLE_UNKNOWN,INTENT_ANGLE_FRESH,INTENT_ANGLE_DUMMY};
typedef struct IntentFrameSnapshot {
 uint32_t valid,actor_local,controller_local,identity_valid,slot,generation,character;
 uint32_t base_local,has_base,base_valid,base_heading;
 uint32_t heading,magnitude,direction[2],previous_heading,previous_magnitude,last_heading,last_magnitude;
 uint32_t action,raw_2f1,flags_50,c7c,c84,c80,period,phase,elapsed;
} IntentFrameSnapshot;
typedef struct IntentFrameRecord {
 uint32_t committed,id,parent,event,thread,site,epoch,sequence,clock,rng_game,rng_engine,qpc[2];
 IntentFrameSnapshot snapshot;
 uint32_t stack_valid,registers_valid,native_words[4],result_raw,callback_angle_valid,callback_angle;
 uint32_t current_writer,previous_writer,last_writer,pending_writer,angle_kind,encoding_basis_valid,encoding_basis,association_confidence;
 uint32_t source_path;
} IntentFrameRecord;
uint32_t intent_frame_scope_begin(void *actor,void *controller,uint32_t native_caller);
void intent_frame_scope_model(void *actor,void *controller);
void intent_frame_scope_end(uint32_t token);
void intent_frame_scope_binding_ready(void);
__declspec(dllexport) extern volatile long clonewars_intent_frame_enabled;
int intent_frame_observer_install(void);
