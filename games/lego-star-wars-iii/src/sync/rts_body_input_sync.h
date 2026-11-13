#pragma once
#include <stdint.h>
using RtsBodyUpdate=void (__attribute__((thiscall)) *)(void *,uint32_t,uint32_t);
void rts_body_input_update(void *,uint32_t,uint32_t,RtsBodyUpdate);
using RtsVisibilityUpdate=void (__attribute__((thiscall)) *)(void *,uint32_t);
void rts_visibility_input_update(void *,uint32_t,RtsVisibilityUpdate);
