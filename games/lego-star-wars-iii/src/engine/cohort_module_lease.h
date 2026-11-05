#pragma once
#include <stdint.h>
#include "../sync/coherent_frame_fence.h"
typedef struct CohortModuleLease {uint32_t serial;CoherentFrameToken cohort;} CohortModuleLease;
