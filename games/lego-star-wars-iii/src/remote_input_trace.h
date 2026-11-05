#pragma once
#include "sync_wire.h"
#define REMOTE_INPUT_TRACE_CAPACITY 512
void remote_input_trace_reset(void);
void remote_input_trace_begin(const SyncFrame *,int,const SyncInput *,void *);
int remote_input_trace_before(void *,int);
void remote_input_trace_after(void *,int);
void remote_input_trace_finish(unsigned,void *);
