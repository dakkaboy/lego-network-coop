#pragma once
#include "user_mapping_observer.h"
typedef int (__cdecl *UserMappingSafeMainValid)(const void *,uint32_t,void *);
typedef uint32_t (__cdecl *UserMappingCurrentSession)(void *);
typedef struct UserMappingSessionConfig {uint32_t version,main_thread;UserMappingSafeMainValid safe_main_valid;UserMappingCurrentSession current_session;void *user;} UserMappingSessionConfig;
#define UM_SESSION_CAPACITY 32u
typedef enum UserMappingDrainResult {UM_DRAIN_IDLE,UM_DRAIN_RESTORED,UM_DRAIN_DEFERRED,UM_DRAIN_MOVED,UM_DRAIN_UNPROVED,UM_DRAIN_CONSUMED_UNWIND,UM_DRAIN_RESTORED_RECHECK} UserMappingDrainResult;
int user_mapping_session_configure(const UserMappingSessionConfig *);
int user_mapping_session_begin(uint32_t session_serial);
int user_mapping_session_owned_request(uint32_t session_serial,const UserMappingRequest *,UserMappingKey *);
int user_mapping_session_device_get(uint32_t session_serial,UserMappingObservation *);
int user_mapping_session_retire(uint32_t session_serial,uint32_t reason);
int user_mapping_session_pending(void);
int user_mapping_session_drain(const void *fresh_boundary,uint32_t bytes,uint32_t observed_current_session);
/* Installer publishes this only after all eight exact native patches validate. */
int user_mapping_install_ready(void);
typedef struct MappingSessionAcquire {void *row;uint32_t session_serial,entered,sent;UserMappingKey key;} MappingSessionAcquire;
typedef struct MappingSessionDrain {void *row;uint32_t locked,consumed,returned,boundary_bytes,observed;int32_t negative;unsigned char boundary[64];} MappingSessionDrain;
int __cdecl user_mapping_session_acquire_begin(MappingSessionAcquire *,uint32_t,const UserMappingRequest *);
void __cdecl user_mapping_session_acquire_end(MappingSessionAcquire *,int);
int __cdecl user_mapping_session_drain_begin(MappingSessionDrain *,const void *,uint32_t,uint32_t);
int __cdecl user_mapping_session_drain_complete(MappingSessionDrain *);
int __cdecl user_mapping_session_drain_end(MappingSessionDrain *,int);
