#pragma once
#include <stdint.h>
#include "native_gizmo_source.h"
struct NativeRtsBodySource {void *object,*pad,*team,*world,*model,*receiver,*body,*dynamics;uint32_t ordinal,body_class,key[4];NativeGizmoSource pad_source;};
int native_rts_body_source(void *,uint32_t,NativeRtsBodySource &);
struct NativeRtsObjectSource {void *object,*pad,*team,*world;uint32_t ordinal,object_class,key[4];NativeGizmoSource pad_source;};
int native_rts_object_source(void *,NativeRtsObjectSource &);
