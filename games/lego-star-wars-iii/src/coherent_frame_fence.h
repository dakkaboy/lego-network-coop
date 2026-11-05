#pragma once
#include <stdint.h>
#include "native_owner.h"
typedef enum CoherentFramePhase {
 COHERENT_PREPARE=1,COHERENT_DISPATCH=2,COHERENT_FINISH=3,COHERENT_COLLECT=4,COHERENT_PUBLISH=5
} CoherentFramePhase;
#define COHERENT_PHASE_BIT(p) (1u<<(p))
#define COHERENT_ALL_PHASES 0x3eu
typedef struct CoherentFrameToken {
 NativeOwnerScope *owner;
 uint32_t owner_nonce,cohort_nonce,thread,release,epoch,sequence;
 const void *frame;
} CoherentFrameToken;
/* Helper APIs require an already captured native machine context. Frame keys are the first two DWORDs. */
int coherent_frame_register_main(void);
uint32_t coherent_frame_release(void);
void coherent_frame_cancel_atomic(uint32_t reason_bits);
uint32_t coherent_frame_pending_reasons(void);
int coherent_frame_open(CoherentFrameToken *out,NativeOwnerScope *owner,uint32_t owner_nonce,const void *frame,uint32_t epoch,uint32_t sequence,uint32_t release);
int coherent_frame_valid(const CoherentFrameToken *token,uint32_t allowed_phases);
int coherent_frame_get(CoherentFrameToken *out,uint32_t allowed_phases);
int coherent_frame_set_phase(const CoherentFrameToken *token,CoherentFramePhase phase);
int coherent_frame_close(const CoherentFrameToken *token);

#ifdef COHERENT_FRAME_FIXTURE
int coherent_frame_test_release(uint32_t value);
#endif
