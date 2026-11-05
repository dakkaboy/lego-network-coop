#pragma once
#include <windows.h>
#include <stdint.h>
#include "cohort_module_lease.h"
#define MODULE_COHORT_PHASES (COHERENT_PHASE_BIT(COHERENT_PREPARE)|COHERENT_PHASE_BIT(COHERENT_DISPATCH)|COHERENT_PHASE_BIT(COHERENT_FINISH))
typedef struct ModuleCohortBinding {CohortModuleLease lease;uint32_t serial,initialized;int bound,retired_valid;CoherentFrameToken retired;} ModuleCohortBinding;
static inline int module_cohort_same(const CoherentFrameToken*a,const CoherentFrameToken*b){return a->owner==b->owner&&a->owner_nonce==b->owner_nonce&&a->cohort_nonce==b->cohort_nonce&&a->thread==b->thread&&a->release==b->release&&a->epoch==b->epoch&&a->sequence==b->sequence&&a->frame==b->frame;}
static inline int module_lease_same(const ModuleCohortBinding*b,const CohortModuleLease*l){return l&&b->bound&&b->lease.serial==l->serial&&module_cohort_same(&b->lease.cohort,&l->cohort);}
static inline int module_binding_get(const ModuleCohortBinding*b,CohortModuleLease*out){DWORD e=GetLastError();int ok=out&&b->bound&&b->lease.cohort.thread==GetCurrentThreadId();if(ok)*out=b->lease;SetLastError(e);return ok;}
static inline int module_binding_live(const ModuleCohortBinding*b,const CohortModuleLease*l){return module_lease_same(b,l)&&coherent_frame_valid(&l->cohort,MODULE_COHORT_PHASES);}
static inline int module_binding_cancelled(const ModuleCohortBinding*b,const CohortModuleLease*l){return !module_lease_same(b,l)||!coherent_frame_valid(&l->cohort,COHERENT_ALL_PHASES);}
static inline int module_binding_bind(ModuleCohortBinding*b,const CoherentFrameToken*original){
 if(b->bound||b->serial==UINT32_MAX||!original||(b->retired_valid&&module_cohort_same(original,&b->retired))||!coherent_frame_valid(original,COHERENT_PHASE_BIT(COHERENT_PREPARE)))return 0;
 b->lease=(CohortModuleLease){++b->serial,*original};b->initialized=0;b->bound=1;return 1;
}
static inline int module_binding_begin(ModuleCohortBinding*b,const void*frame){
 if(!b->bound||b->initialized==b->lease.serial||b->lease.cohort.frame!=frame||!coherent_frame_valid(&b->lease.cohort,COHERENT_PHASE_BIT(COHERENT_PREPARE)))return 0;
 b->initialized=b->lease.serial;return module_binding_live(b,&b->lease);
}
static inline int module_binding_detach(ModuleCohortBinding*b,const CohortModuleLease*l){
 DWORD e=GetLastError();int ok=l&&l->cohort.thread==GetCurrentThreadId()&&module_lease_same(b,l);
 if(ok){b->retired=b->lease.cohort;b->retired_valid=1;b->bound=0;}SetLastError(e);return ok;
}
