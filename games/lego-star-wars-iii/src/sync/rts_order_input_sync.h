#pragma once
#include <stdint.h>
using RtsOrderOriginal=void (__attribute__((thiscall)) *)(void *,uint32_t);
void rts_order_input_update(void *,uint32_t,RtsOrderOriginal);
int rts_order_input_install();
