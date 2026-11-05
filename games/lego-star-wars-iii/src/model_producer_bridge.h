#pragma once
#include <stdint.h>
typedef struct __declspec(align(16)) ModelProducerBridge {
 unsigned char in_fx[512],out_fx[512];
 uint32_t in_regs[9],out_regs[9];
 uint32_t in_error,out_error,entry_esp,saved_esp;
 void *target;uint32_t reserved;
 unsigned char helper_fx[512];
 unsigned char reserved_metadata[120];
 uint32_t actor;
 unsigned char storage[1024];
} ModelProducerBridge;
_Static_assert(__builtin_offsetof(ModelProducerBridge,target)==1112,"target");
_Static_assert(__builtin_offsetof(ModelProducerBridge,actor)==1752,"actor");
_Static_assert(__builtin_offsetof(ModelProducerBridge,storage)==1756,"storage");
_Static_assert(sizeof(ModelProducerBridge)<=3000,"bridge stack");
void __cdecl model_producer_c(ModelProducerBridge *);
void __cdecl model_producer_inner(ModelProducerBridge *);
void __cdecl model_producer_enter(ModelProducerBridge *);
void __cdecl model_producer_leave(ModelProducerBridge *,int);
void __cdecl producer_hook(void *);
