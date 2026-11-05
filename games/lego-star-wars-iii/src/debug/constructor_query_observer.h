#pragma once
#include <stdint.h>
#include <stddef.h>
#include "constructor_observer.h"
#define CONSTRUCTOR_QUERY_CAPACITY 2048u
#define CONSTRUCTOR_SOURCE_COUNT_CAP 65536u
typedef struct ConstructorSourceLinks {
 uint32_t descriptor_vtable,descriptor_type_word18,descriptor_name1c_raw,descriptor_receiver28_raw,descriptor_wrapper30_raw;
 uint32_t receiver_vtable,receiver_descriptor1a0_raw,receiver_name1a4_raw,receiver_resource2c_raw,receiver_poi30_raw;
 uint32_t resource_runtime6f8_raw,runtime_count68_raw,runtime_array6c_raw,record_bindingd4_raw,record_nameb4_raw;
} ConstructorSourceLinks;
typedef struct ConstructorQuerySource {
 uint32_t status,valid_mask,reason,count_cap,poi_ordinal,clock_before,clock_after,sample_release_serial,association_kind;
 uint32_t name_size,name_flags,receiver14_local_raw,receiver198_byte_raw,component_vtable_local_raw;
 ConstructorSourceLinks first,second;
 unsigned char name_raw[64];
} ConstructorQuerySource;
enum ConstructorSourceReason {CQS_NONE,CQS_NOT_ACCEPTED,CQS_UNSUPPORTED_BODY,CQS_NO_RECEIVER,CQS_UNREADABLE_RECEIVER,CQS_UNSUPPORTED_RECEIVER,CQS_REVERSE_PAIR_MISMATCH,CQS_NO_HANDLE,CQS_UNREADABLE_RESOURCE,CQS_NO_RUNTIME,CQS_UNREADABLE_RUNTIME,CQS_INVALID_COUNT,CQS_COUNT_CAP,CQS_TABLE_OVERFLOW,CQS_NO_ARRAY,CQS_RECORD_OUT_OF_RANGE,CQS_RECORD_MISALIGNED,CQS_UNREADABLE_RECORD,CQS_D4_NOT_SELF_BOUND,CQS_CHANGED,CQS_CANCELLED,CQS_CLOCK_CHANGED,CQS_UNREADABLE_DESCRIPTOR,CQS_EMPTY_TABLE};
enum ConstructorSourceName {CQS_NAME_PREFIX=1,CQS_NAME_NUL=2,CQS_NAME_TRUNCATED=4,CQS_NAME_UNREADABLE=8,CQS_NAME_CHANGED=16,CQS_NAME_NULL=32};
typedef struct ConstructorColliderIdentity {
 uint32_t status,valid_mask,reason,descriptor_local,wrapper_local,wrapper_vtable_local,wrapper_class_method_local;
 uint32_t nuanim_local,api_local,userdata_local,actor_local,actor_local_generation;
 uint32_t actor_network_slot,actor_network_generation,actor_character,actor_model_local;
 uint32_t allocation_live_before,allocation_live_after,clock_before,clock_after,association_kind,sample_release_serial,reserved0,reserved1;
} ConstructorColliderIdentity;
enum ConstructorColliderReason {CCI_NONE,CCI_NOT_ACCEPTED,CCI_UNSUPPORTED_BODY,CCI_NO_WRAPPER,CCI_UNSUPPORTED_WRAPPER,CCI_UNREADABLE,CCI_BAD_USERDATA,CCI_UNOBSERVED_ACTOR,CCI_ALLOCATION_NOT_LIVE,CCI_API_MISMATCH,CCI_UNMAPPED,CCI_CHANGED,CCI_CANCELLED};
typedef struct ConstructorQueryRecord {
 uint32_t committed,id,version,thread,qpc_before[2],qpc_after[2],clock_before,clock_after;
 uint32_t constructor_scope,constructor_parent_scope,query_ordinal,query_caller,valid_mask;
 uint32_t lease_serial,lease_nonce,frame_local,epoch,sequence,frame_valid;
 uint32_t constructor_kind,constructor_caller,birth_known,shot_id,shot_phase;
 uint32_t owner_slot,owner_generation,owner_local_generation,owner_character,owner_local,input_flags,input_weapon;
 uint32_t native_ebp,native_esp,native_esi,native_eax,parent_ebp,parent_caller;
 uint32_t native_arguments[8],query_s30_raw[13],start_raw[3],displacement_raw[3];
 uint32_t result_vtable,fraction_raw,candidate_context_local,selected_descriptor_local,reported_shape_raw;
 uint32_t category_raw,subtype_raw,mask_word_raw,point_raw[4],normal_raw[4];
 uint32_t selected_descriptor_raw[32];
 uint32_t root_shape_local,root_shape_vtable,root_ray_target_local,root_radius_target_local;
 uint32_t root_shape_header_raw[16],native_control_word,native_mxcsr;
 uint32_t caller_esi_raw;
 ConstructorColliderIdentity collider_identity;
 ConstructorQuerySource source_witness;
} ConstructorQueryRecord;
typedef struct ConstructorQueryScope {
 struct ConstructorQueryScope *previous;
 uint32_t ready,linked,thread,id,parent,ordinal,owner_valid;
 ConstructorInput input;
 uint32_t owner_slot,owner_generation,owner_local_generation,owner_character;
 CoherentFrameToken cohort;
 RootControlLease control;ProjectileSessionContext control_session;uint64_t reset_generation;uint32_t capability;
 uint32_t cleanup_stamp;
} ConstructorQueryScope;
enum ConstructorQueryValid {CQ_FRAME_ARGS=1,CQ_QUERY=2,CQ_START=4,CQ_DISPLACEMENT=8,CQ_GLOBAL=16,CQ_DESCRIPTOR=32,CQ_ROOT=64,CQ_ROOT_VTABLE=128,CQ_PARENT=256,CQ_OWNER=512,CQ_CALLER_ESI=1024};
void constructor_query_scope_begin(ConstructorQueryScope *,const ConstructorScope *);
void constructor_query_scope_end(ConstructorQueryScope *,void *);
int constructor_query_install(void);
_Static_assert(sizeof(ConstructorColliderIdentity)==96,"identity append layout");
_Static_assert(sizeof(ConstructorSourceLinks)==60,"source links layout");
_Static_assert(sizeof(ConstructorQuerySource)==240,"source append layout");
_Static_assert(sizeof(ConstructorQueryRecord)==884,"query record layout");
_Static_assert(offsetof(ConstructorQueryRecord,source_witness)==644,"source append offset");
_Static_assert(offsetof(ConstructorQueryRecord,source_witness.first)==700,"source first offset");
_Static_assert(offsetof(ConstructorQueryRecord,source_witness.second)==760,"source second offset");
_Static_assert(offsetof(ConstructorQueryRecord,source_witness.name_raw)==820,"source name offset");
_Static_assert(offsetof(ConstructorQueryRecord,collider_identity)==548,"identity append offset");
_Static_assert(offsetof(ConstructorQueryRecord,query_s30_raw)==188,"query offset");
_Static_assert(offsetof(ConstructorQueryRecord,selected_descriptor_raw)==328,"descriptor offset");
_Static_assert(offsetof(ConstructorQueryRecord,root_shape_header_raw)==472,"root offset");
_Static_assert(offsetof(ConstructorQueryRecord,native_control_word)==536,"native FX offset");
_Static_assert(offsetof(ConstructorQueryRecord,caller_esi_raw)==544,"caller ESI offset");

int constructor_query_abort_cohort(const CoherentFrameToken *captured);

int constructor_query_abort_control(const RootControlLease*,uint64_t);
