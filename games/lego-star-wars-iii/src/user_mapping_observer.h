#pragma once
#include <stdint.h>
#define UM_OBSERVER_API_VERSION 2u
#define UM_TICKETS 64u
#define UM_PROOF_BYTES 64u
typedef enum UserMappingSite {UM_MAPPER,UM_SETTER,UM_RESET_ALL,UM_RESET_01,UM_INITIALIZER,UM_USER0_A,UM_USER0_B,UM_POLLER,UM_SITE_COUNT} UserMappingSite;
#define UM_COVER_MAPPER 1u
#define UM_COVER_SETTER 2u
#define UM_COVER_RESET_ALL 4u
#define UM_COVER_RESET_01 8u
#define UM_COVER_INITIALIZER 16u
#define UM_COVER_USER0_STORES 32u
#define UM_COVER_POLLER 64u
#define UM_REQUIRED_COVERAGE 127u
typedef struct UserMappingStamp {uint32_t assignment,epoch,level,release,owner_nonce,root_serial;} UserMappingStamp;
typedef struct UserMappingProvenance {uint32_t assignment,epoch,level,release,owner_nonce,root_serial;uint32_t proof_bytes;unsigned char proof[UM_PROOF_BYTES];} UserMappingProvenance;
typedef int (__cdecl *UserMappingSourceValid)(const void *,uint32_t);
typedef struct UserMappingConfig {uint32_t version,main_thread;void *targets[UM_SITE_COUNT];const volatile int32_t *native_table;const unsigned char *native_owners;UserMappingSourceValid original_source_valid;} UserMappingConfig;
typedef struct UserMappingRequest {int32_t user,requested,saved_negative;UserMappingProvenance source;} UserMappingRequest;
typedef struct UserMappingKey {uint32_t slot,id;} UserMappingKey;
#define UM_T_MAPPING_COMMITTED 1u
#define UM_T_SETTER_RETURNED 2u
#define UM_T_SETTER_UNWOUND 4u
#define UM_T_SOURCE_EXPIRED 8u
#define UM_T_CANCELLED 16u
#define UM_T_RETIRED 32u
#define UM_T_CLAIM_SEEN 64u
#define UM_T_NOT_SENT 128u
#define UM_T_MAPPING_PRECONDITION 256u
typedef struct UserMappingTicket {UserMappingKey key;UserMappingStamp source;int32_t user,requested,saved_negative,actual;uint32_t generation,reset_generation,flags;} UserMappingTicket;
typedef struct UserMappingObservation {UserMappingTicket ticket;uint32_t generation,committed_generation,reset_generation,setter_depth,writer_depth,poller_depth,disabled,quality;int32_t current_actual;} UserMappingObservation;
#define UM_Q_METADATA 1u
#define UM_Q_CURRENT_GENERATION 2u
#define UM_Q_CURRENT_VALUE 4u
#define UM_Q_IDLE 8u
int user_mapping_configure(const UserMappingConfig *);
int user_mapping_binding_ready(uint32_t declared_coverage);
int user_mapping_enable(void);
void __cdecl user_mapping_user0_a_entry(void);
void __cdecl user_mapping_user0_b_entry(void);
void __cdecl user_mapping_poller_entry(void);
int user_mapping_owned_request(const UserMappingRequest *,UserMappingKey *);
int user_mapping_ticket_get(UserMappingKey,UserMappingTicket *);
int user_mapping_inspect(UserMappingKey,UserMappingObservation *);
int user_mapping_cancel(UserMappingKey);
int user_mapping_retire(UserMappingKey);
void user_mapping_user0_store_event(void);
void __cdecl user_mapping_mapper_entry(int32_t,int32_t);
void __cdecl user_mapping_setter_entry(int32_t,int32_t);
void __cdecl user_mapping_reset_all_entry(void);
void __cdecl user_mapping_reset_01_entry(int32_t);
void __cdecl user_mapping_initializer_entry(void);

int user_mapping_install_ready(void);
