#pragma once
#include "../sync/model_input_sync.h"
#define MODEL_UNUSED_DERIVED_MASK UINT32_C(0x0fc00000)
int model_context_canonicalize(const SyncModelInput *authoritative,const SyncModelInputContext *raw,SyncModelInputContext *output,uint32_t *canonicalized_fields);
int model_context_relevant_equal(const SyncModelInput *authoritative,const SyncModelInputContext *host,const SyncModelInputContext *local);
