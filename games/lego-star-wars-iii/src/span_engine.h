#pragma once
#include "native_owner.h"
#include "span_installer.h"
#include "coherent_frame_fence.h"
typedef struct SpanControlContext {uint32_t epoch;int32_t level;uint32_t established;} SpanControlContext;
typedef struct RootControlLease {NativeOwnerScope*owner;uint32_t owner_nonce,thread,root_serial,release,epoch;int32_t level;uintptr_t delegate_esp;} RootControlLease;
typedef enum SpanEngineReject {SPAN_REJECT_WRAPPED_CHILD=1,SPAN_REJECT_UNWRAPPED_CHILD,SPAN_REJECT_INVALID_PLAN,SPAN_REJECT_SERIAL_EXHAUSTED,SPAN_REJECT_MARKER,SPAN_REJECT_SCOPE,SPAN_REJECT_UNREADY_RUN,SPAN_REJECT_OWNER_DEPTH=16,SPAN_REJECT_OWNER_TLS,SPAN_REJECT_OWNER_NONCE} SpanEngineReject;
typedef struct SpanEngineCallbacks {
 unsigned version;void*user;
 void (*reject_atomic)(unsigned,void*);
 int (*install_safe)(void*,const NativeOwnerInput*,void*);
 int (*dependencies_ready)(void*);
 int (*main_confirmed)(DWORD,void*);
 int (*control_context)(SpanControlContext*,void*);
 unsigned (*enter)(NativeOwnerScope*,unsigned,void*,void*,const OwnerU32*,const void*,unsigned,void*);
 void (*marker)(NativeOwnerScope*,unsigned,unsigned,void*);
 void (*finish)(NativeOwnerScope*,unsigned,void*);
 void (*end)(NativeOwnerScope*,unsigned,NativeOwnerExit,unsigned,void*);
} SpanEngineCallbacks;
typedef struct SpanEngineAdapter {
 SpanInstaller installer;SpanEngineCallbacks callbacks;
 unsigned char*image760000;void*expected_vt;void*volatile*root_global;
 DWORD window_thread;volatile LONG serial,sticky;
 volatile LONG qualified,unowned,bad_stack,invalid_plan,duplicates,main_count,optional_count,rejected;
} SpanEngineAdapter;
int span_engine_prepare(SpanEngineAdapter*,unsigned char*,void*volatile*,void*,void*volatile*,DWORD,unsigned,const SpanEngineCallbacks*);
int span_engine_publish_bootstrap(SpanEngineAdapter*);
void span_engine_cancel(SpanEngineAdapter*);

int span_engine_ready(SpanEngineAdapter*);

int span_engine_control_get(SpanEngineAdapter*,RootControlLease*);
int span_engine_control_valid(SpanEngineAdapter*,const RootControlLease*);
