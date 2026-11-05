#pragma once
#include "../net/sync_wire.h"

typedef enum TagFrameResult {
    TAG_FRAME_FAILED = 0,
    TAG_FRAME_OK = 1,
    TAG_FRAME_CANCELLED = -1
} TagFrameResult;

typedef struct TagClock {
    uint32_t clock, rng_game, rng_engine;
    float delta;
} TagClock;

int tags_install(void);
void tags_reset(void);
int tags_begin(SyncFrame *frame, int host);
int tags_finish(void);
void tags_cancel(void);

#ifdef TAG_SYNC_TEST
int tags_test_call(void *from, void *to, int a, int b, int c, int d, int e, int f);
#endif

typedef uint64_t (*TagAssignmentVersion)(void);
typedef void (*TagAssignmentRemap)(uint64_t version);
void tags_observe_controller_handoffs(TagAssignmentVersion version, TagAssignmentRemap remap);
int tags_resolve_controller_owner(void *actor, uint32_t generation, void *controller, void **owner,
                                  uint32_t *owner_generation);
#include "coherent_frame_fence.h"
#include "../engine/span_engine.h"
typedef enum TagSessionClass {
    TAG_SESSION_UNAVAILABLE,
    TAG_SESSION_OFFLINE,
    TAG_SESSION_BOOTSTRAP,
    TAG_SESSION_TRANSITION,
    TAG_SESSION_ESTABLISHED
} TagSessionClass;
typedef struct TagSessionContext {
    uint32_t epoch;
    int32_t level;
    TagSessionClass classification;
    uint32_t session;
} TagSessionContext;
typedef int (*TagSessionProvider)(TagSessionContext *);
typedef struct TagFrameBinding {
    CoherentFrameToken token;
    uint64_t binding_serial;
} TagFrameBinding;
int tags_configure_coherent(SpanEngineAdapter *, TagSessionProvider);
int tags_bind_cohort(const CoherentFrameToken *);
int tags_cohort_valid(const CoherentFrameToken *, uint32_t);
int tags_frame_binding_get(TagFrameBinding *);
int tags_abort_frame(const TagFrameBinding *);

int tags_dispatch_pending(void);
int tags_dispatch_complete(void);
int tags_dispatch_revision(const CoherentFrameToken*,uint64_t*);
