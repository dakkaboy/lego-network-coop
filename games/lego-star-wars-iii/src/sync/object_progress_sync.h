#pragma once
#ifdef __cplusplus
extern "C" {
#endif
#include "coherent_frame_fence.h"
int object_progress_install(void);
int object_progress_world_complete(void *world,const CoherentFrameToken *token);
#ifdef __cplusplus
}
#endif
