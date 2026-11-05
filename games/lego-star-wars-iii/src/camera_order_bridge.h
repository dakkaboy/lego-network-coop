#pragma once
#include <stdint.h>
typedef struct __declspec(align(16)) CameraOrderBridge {
 unsigned char in_fx[512],out_fx[512];
 uint32_t in_regs[9],out_regs[9];
 uint32_t in_error,out_error,entry_esp,saved_esp;
 void *target;uint32_t reserved;
 unsigned char helper_fx[512];
 unsigned char reserved_metadata[120];
 uint32_t argument;
 unsigned char storage[1024];
} CameraOrderBridge;
_Static_assert(__builtin_offsetof(CameraOrderBridge,target)==1112,"target");
_Static_assert(__builtin_offsetof(CameraOrderBridge,argument)==1752,"argument");
_Static_assert(__builtin_offsetof(CameraOrderBridge,storage)==1756,"storage");
_Static_assert(sizeof(CameraOrderBridge)<=3000,"bridge stack");
void __cdecl camera_order_c(CameraOrderBridge *);
void __cdecl camera_order_inner(CameraOrderBridge *);
void __cdecl camera_order_enter(CameraOrderBridge *);
void __cdecl camera_order_leave(CameraOrderBridge *,int);
uint32_t __attribute__((thiscall)) camera_order_hook(void *,void *);
