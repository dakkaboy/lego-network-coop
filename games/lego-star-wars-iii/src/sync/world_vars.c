#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include "world_vars.h"
#include "../engine/constructor_lexical_seh.h"

static CoherentFrameToken binding;
static int bound;
static CoherentFrameToken retired;
static int retired_valid;
static void *native_address(uintptr_t address) {
#ifdef WORLD_VARS_COHORT_TEST
    extern void *world_vars_test_address(uintptr_t);
    return world_vars_test_address(address);
#else
    return (void *)address;
#endif
}
static int same_token(const CoherentFrameToken *a,const CoherentFrameToken *b) {
    return a->owner==b->owner && a->owner_nonce==b->owner_nonce && a->cohort_nonce==b->cohort_nonce &&
        a->thread==b->thread && a->release==b->release && a->epoch==b->epoch &&
        a->sequence==b->sequence && a->frame==b->frame;
}
int world_vars_cohort_valid(const CoherentFrameToken *token,uint32_t phases) {
    return token && bound && token->thread==GetCurrentThreadId() && same_token(token,&binding) &&
        coherent_frame_valid(token,phases);
}
int world_vars_bind_cohort(const CoherentFrameToken *token) {
    if(!token || !coherent_frame_valid(token,COHERENT_PHASE_BIT(COHERENT_PREPARE)))return 0;
    if(retired_valid && same_token(token,&retired))return 0;
    if(bound && !same_token(token,&binding) && coherent_frame_valid(&binding,COHERENT_ALL_PHASES))return 0;
    binding=*token;bound=1;return world_vars_cohort_valid(token,COHERENT_PHASE_BIT(COHERENT_PREPARE));
}
int world_vars_abort_cohort(const CoherentFrameToken *token) {
    if(!token || !bound || token->thread!=GetCurrentThreadId() || !same_token(token,&binding))return 0;
    retired=*token;retired_valid=1;bound=0;return 1;
}
static int live(const CoherentFrameToken *token,const SyncFrame *frame) {
    return token && token->frame==frame && world_vars_cohort_valid(token,COHERENT_PHASE_BIT(COHERENT_PREPARE));
}

static int readable(const void *p,SIZE_T size) {
    MEMORY_BASIC_INFORMATION m;
    return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT &&
           !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
           (uint64_t)(uintptr_t)p+size <= (uint64_t)(uintptr_t)m.BaseAddress+m.RegionSize;
}
static char *global_registry(char *manager) {
    return readable(manager,0x4c) ? *(char **)(manager+0x48) : NULL;
}
static char *area_registry(char *manager) {
    char *area=*(char **)native_address(0xfb4a20);
    int index=readable(manager,0x3c) ? *(int *)(manager+0x38) : -1;
    char *slots_owner=*(char **)native_address(0xe90184);
    int count=readable(slots_owner,0x2c) ? *(int *)(slots_owner+0x28) : 0;
    if (index<0 || index>=count || index>4096 || !readable(area,0x404)) return NULL;
    char ***handle=*(char ****)(area+0x400);
    if (!readable(handle,4) || !readable(*handle,(SIZE_T)(index+1)*4)) return NULL;
    return (char *)(*handle)[index];
}
static int collect_registry(const CoherentFrameToken *token,SyncFrame *frame,char *registry) {
    if(!live(token,frame))return 0;
    if (!registry) return 1;
    if (!readable(registry,0x64)) return 0;
    char *node=*(char **)(registry+0x58);
    uint32_t expected=*(uint32_t *)(registry+0x60),visited=0;
    if (expected>SYNC_MAX_VARIABLES) return 0;
    while (node) {
        if(!live(token,frame))return 0;
        if (++visited>expected+1 || !readable(node,0x4c) || frame->variable_count==SYNC_MAX_VARIABLES) return 0;
        uint32_t scope=*(uint32_t *)(node+0x34);
        float value=*(float *)(node+0x38);
        if (scope>1 || !isfinite(value) || !node[0x14]) return 0;
        SyncVariable *variable=&frame->variables[frame->variable_count++];
        memset(variable->name,0,32);
        const char *end=memchr(node+0x14,0,32);
        memcpy(variable->name,node+0x14,end ? (SIZE_T)(end-node-0x14) : 32);
        variable->scope=scope; variable->value=value;
        node=*(char **)(node+8);
    }
    return live(token,frame);
}
static int compare_variables(const void *left,const void *right) {
    const SyncVariable *a=left,*b=right;
    if (a->scope!=b->scope) return a->scope<b->scope ? -1 : 1;
    return strncmp(a->name,b->name,32);
}
int world_vars_collect(SyncFrame *frame) {
    CoherentFrameToken token=binding;
    if(!bound || !live(&token,frame))return 0;
    char *manager=*(char **)native_address(0xe901cc);
    char *global=global_registry(manager),*area=area_registry(manager);
    frame->variable_count=0;
    if (!collect_registry(&token,frame,global) || (area!=global && !collect_registry(&token,frame,area)) || !live(&token,frame)) return 0;
    qsort(frame->variables,frame->variable_count,sizeof(SyncVariable),compare_variables);
    return live(&token,frame);
}
typedef char *(__attribute__((thiscall)) *GetVariable)(void *,void *,const char *,int,void *);
typedef struct LookupContext {
    CoherentFrameToken token;
    char *manager,*area;
    const char *name;
    int scope;
} LookupContext;
static void * __cdecl lookup_invoke(void *raw) {
    LookupContext *call=raw;
#ifdef WORLD_VARS_COHORT_TEST
    extern void world_vars_test_before_lookup(void);
    world_vars_test_before_lookup();
#endif
    if(!live(&call->token,call->token.frame))return NULL;
#ifdef WORLD_VARS_COHORT_TEST
    extern char *world_vars_test_lookup(void *,void *,const char *,int,void *);
    return world_vars_test_lookup(call->manager,call->scope?call->area:NULL,call->name,call->scope,NULL);
#else
    return ((GetVariable)0x83c9c0)(call->manager,call->scope?call->area:NULL,call->name,call->scope,NULL);
#endif
}
static void __cdecl lookup_abort(void *raw) {
    LookupContext *call=raw;
    if(bound && call->token.thread==GetCurrentThreadId() && same_token(&call->token,&binding))
        coherent_frame_cancel_atomic(0x10000u);
}
int world_vars_apply(const SyncFrame *frame) {
    CoherentFrameToken token=binding;
    if(!bound || !live(&token,frame))return 0;
    char *manager=*(char **)native_address(0xe901cc),*area=*(char **)native_address(0xfb4a20);
    if (!readable(manager,0x4c)) return 0;
    if(frame->variable_count>SYNC_MAX_VARIABLES)return 0;
    for (uint32_t i=0;i<frame->variable_count;++i) {
        if(!live(&token,frame))return 0;
        const SyncVariable *variable=&frame->variables[i];
        char name[33]; memcpy(name,variable->name,32); name[32]=0;
        if(variable->scope>1)return 0;
        LookupContext call={token,manager,area,name,(int)variable->scope};
        char *node=constructor_lexical_seh(&call,lookup_invoke,lookup_abort);
        if(!live(&token,frame))return 0;
        if(*(char **)native_address(0xe901cc)!=manager || *(char **)native_address(0xfb4a20)!=area){coherent_frame_cancel_atomic(0x20000u);return 0;}
        if (!readable(node,0x4c)) return 0;
        if(!live(&token,frame))return 0;
        *(float *)(node+0x38)=variable->value;
    }
    return live(&token,frame);
}
