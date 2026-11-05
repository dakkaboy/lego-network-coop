#pragma once
#include "coherent_frame_fence.h"
#include "span_engine.h"
typedef enum CoreSpanDecision {CORE_SPAN_PASS=0,CORE_SPAN_RUN=1,CORE_SPAN_SKIP=2} CoreSpanDecision;
typedef enum CoreDraftBlocker {CORE_BLOCK_COHORTS=1,CORE_BLOCK_CODE_HOOKS=2,CORE_BLOCK_RESTORE=4,CORE_BLOCK_MAIN=8,CORE_BLOCK_INSTALL_POLICY=16,CORE_BLOCK_BOOTSTRAP_GUARD=32,CORE_BLOCK_LIFECYCLE_POLL=64,CORE_BLOCK_FINISH_CLOSURE=128,CORE_BLOCK_OBSERVER_FENCES=256,CORE_BLOCK_CONTROL_POLICY=512} CoreDraftBlocker;
typedef enum CoreCohort {CORE_TAG,CORE_PROJECTILES,CORE_GEOMETRY,CORE_CADENCE,CORE_MODEL,CORE_NPC,CORE_REACTION,CORE_WORLD_VARS,CORE_COHORT_COUNT} CoreCohort;
#define CORE_COHORT_ALL ((1u<<CORE_COHORT_COUNT)-1u)
#define CORE_PLAN_EARLY 1u
#define CORE_PLAN_OPTIONAL 2u
#define CORE_PLAN_MAIN 4u
typedef struct CoreCohortBinding {
 unsigned version;
 int (*ready)(void);
 int (*bind_metadata)(const CoherentFrameToken*);
 int (*valid)(const CoherentFrameToken*,uint32_t);
 void (*abort_metadata)(const CoherentFrameToken*);
} CoreCohortBinding;
int game_sync_coherent_register_actual_modules(void);
int game_sync_coherent_register_cohort(CoreCohort,const CoreCohortBinding*);
uint32_t game_sync_coherent_missing(void);
int game_sync_coherent_restore_pending(void);
uint32_t game_sync_coherent_blockers(void);
int game_sync_prepare_worker(DWORD);
