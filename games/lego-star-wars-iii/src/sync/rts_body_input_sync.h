#pragma once
#include <stdint.h>
using RtsBodyUpdate=void (__attribute__((thiscall)) *)(void *,uint32_t,uint32_t);
void rts_body_input_update(void *,uint32_t,uint32_t,RtsBodyUpdate);
using RtsVisibilityUpdate=void (__attribute__((thiscall)) *)(void *,uint32_t);
void rts_visibility_input_update(void *,uint32_t,RtsVisibilityUpdate,uint32_t site=0x5525e0);
int rts_visibility_attack_install(void);
