#include <stddef.h>
#include <string.h>
#include "context_relevance.h"
_Static_assert(sizeof(SyncModelInputContext)==124,"P24 context");
_Static_assert(offsetof(SyncModelInputContext,c7c_1000)==22*4,"derived group start");
_Static_assert(offsetof(SyncModelInputContext,global_fbcb88_raw)==27*4,"derived group end");
_Static_assert(offsetof(SyncModelInputContext,global_fc0e80)==28*4,"special camera gate retained");
static int finite(float value){uint32_t bits;memcpy(&bits,&value,4);return (bits&0x7f800000u)!=0x7f800000u;}
int model_context_canonicalize(const SyncModelInput *authoritative,const SyncModelInputContext *raw,SyncModelInputContext *output,uint32_t *fields){
 if(!authoritative||!raw||!output||!fields||!finite(authoritative->input_x)||!finite(authoritative->input_z)||raw->actor_4c_mask>1)return 0;
 SyncModelInputContext result=*raw;uint32_t mask=0;
 if(raw->actor_4c_mask==1){result.c7c_1000=0;result.cf4_raw=0;result.model_42=0;result.actor_309_mask=0;result.global_e63e14_raw=0;result.global_fbcb88_raw=0;mask=MODEL_UNUSED_DERIVED_MASK;}
 *output=result;*fields=mask;return 1;
}
int model_context_relevant_equal(const SyncModelInput *authoritative,const SyncModelInputContext *host,const SyncModelInputContext *local){
 if(!authoritative||!host||!local||host->actor_4c_mask!=local->actor_4c_mask)return 0;
 SyncModelInput h=*authoritative,l=*authoritative;uint32_t hm,lm;
 if(!model_context_canonicalize(authoritative,host,&h.context,&hm)||!model_context_canonicalize(authoritative,local,&l.context,&lm))return 0;
 return hm==lm&&model_input_entry_valid(&h)&&model_input_entry_valid(&l)&&!memcmp(&h.context,&l.context,sizeof(h.context));
}
