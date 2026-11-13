#pragma once
#include <stdint.h>
using RtsGeneratorOriginal=void (__attribute__((thiscall)) *)(void *,uint32_t);
void rts_generator_input_update(void *,uint32_t,RtsGeneratorOriginal);
