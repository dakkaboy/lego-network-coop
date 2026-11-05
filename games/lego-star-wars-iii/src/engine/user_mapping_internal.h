#pragma once
#include "../debug/user_mapping_observer.h"
typedef struct __declspec(align(16)) UserMappingBridge {
 unsigned char in_fx[512],out_fx[512];uint32_t in_regs[9],out_regs[9];
 uint32_t in_error,out_error,entry_esp,saved_esp;void *target;uint32_t reserved;
 unsigned char helper_fx[512],reserved_metadata[120];uint32_t site;int32_t args[2];unsigned char storage[1024];
} UserMappingBridge;
_Static_assert(__builtin_offsetof(UserMappingBridge,target)==1112,"target");
_Static_assert(__builtin_offsetof(UserMappingBridge,site)==1752,"site");
_Static_assert(__builtin_offsetof(UserMappingBridge,args)==1756,"args");
_Static_assert(__builtin_offsetof(UserMappingBridge,storage)==1764,"storage");
_Static_assert(sizeof(UserMappingBridge)<=3000,"stack");
typedef struct MappingMarker {struct MappingMarker *previous,*previous_physical;UserMappingRequest request;UserMappingKey key;uint32_t entered,linked,admitted,claimed;} MappingMarker;
void __cdecl user_mapping_bridge_c(UserMappingBridge *);
void __cdecl user_mapping_bridge_inner(UserMappingBridge *);
void __cdecl user_mapping_bridge_begin(UserMappingBridge *);
void __cdecl user_mapping_bridge_end(UserMappingBridge *,int);
void __cdecl user_mapping_request_begin(MappingMarker *,const UserMappingRequest *,UserMappingKey *);
void __cdecl user_mapping_request_end(MappingMarker *,int);

int user_mapping_mutation_try(void);
void user_mapping_mutation_unlock(void);
void __cdecl user_mapping_bridge_unlock(UserMappingBridge *);
int user_mapping_cleanup_owned(UserMappingKey,int32_t *negative);
int user_mapping_cleanup_consume(UserMappingKey);
int user_mapping_native_saved_matches(int32_t);

int user_mapping_runtime_ready(void);

void user_mapping_invalidate_runtime(void);
