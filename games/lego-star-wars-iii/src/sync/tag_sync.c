#define WIN32_LEAN_AND_MEAN
#include "tag_sync.h"
#include "entity_sync.h"
#include "game_sync.h"
#include "../net/lan.h"
#include "../engine/tag_lexical_seh.h"
#include <stdint.h>
#include <string.h>
#include <windows.h>

typedef int (*Transfer)(void *, void *, int, int, int, int, int, int);
#ifdef TAG_SYNC_TEST
extern int tag_test_original(void *, void *, int, int, int, int, int, int);
extern int tag_test_gameplay;
extern TagClock tag_test_clock;
static Transfer original_tag = tag_test_original;
#define TAG_API
#else
static Transfer original_tag = (Transfer)0x8ae680;
#define TAG_API __declspec(dllexport)
#endif
TAG_API volatile uint32_t clonewars_tag_debug[12];
static SyncFrame *current;
static SyncTag pending[SYNC_MAX_TAGS];
static unsigned pending_count;
static uint32_t epoch, next_id, last_applied, replay_cursor, active_event;
static unsigned char consumed[SYNC_MAX_TAGS];
static int host_role, active, failed, frame_complete;
static int initial_control_available = 1;
static uint32_t last_authorized_session,last_authorized_epoch,active_session;
static uint64_t scope_serial;
static uint64_t dispatch_revision;
static int scope_was_cancelled;
static unsigned replay_completed, replay_corrected;

static SpanEngineAdapter *root_adapter;
static TagSessionProvider session_provider;
static CoherentFrameToken cohort;
static int cohort_bound, cohort_cancelled;
static uint32_t bound_session;
static uint64_t binding_serial, pending_generation = 1;
typedef struct PendingProvenance {
    uint32_t epoch, release, session;
    int32_t level;
    uint64_t generation;
    unsigned committed;
} PendingProvenance;
static PendingProvenance provenance[SYNC_MAX_TAGS];
typedef struct TagGuard {
    unsigned kind;
    CoherentFrameToken frame;
    RootControlLease control;
    uint64_t serial, binding, pending_generation;
    uint32_t epoch, session;
} TagGuard;
static int same_token(const CoherentFrameToken *a, const CoherentFrameToken *b) {
    return a->owner == b->owner && a->owner_nonce == b->owner_nonce && a->cohort_nonce == b->cohort_nonce &&
           a->thread == b->thread && a->release == b->release && a->epoch == b->epoch &&
           a->sequence == b->sequence && a->frame == b->frame;
}
int tags_configure_coherent(SpanEngineAdapter *a, TagSessionProvider provider) {
    if (root_adapter || !a || !provider)
        return 0;
    root_adapter = a;
    session_provider = provider;
    return 1;
}
int tags_cohort_valid(const CoherentFrameToken *t, uint32_t phases) {
    if(!t||!cohort_bound||cohort_cancelled||!same_token(t,&cohort)||t->thread!=GetCurrentThreadId())return 0;
    TagSessionContext context;if(!session_provider||!session_provider(&context)||!bound_session||context.session!=bound_session)return 0;
    return coherent_frame_valid(t,phases);
}
int tags_bind_cohort(const CoherentFrameToken *t) {
    if (!root_adapter || !session_provider)
        return 0;
    TagSessionContext context;
    if(!t||t->thread!=GetCurrentThreadId()||!session_provider(&context)||!context.session||context.session==UINT32_MAX)return 0;
    if(cohort_bound&&same_token(t,&cohort))return tags_cohort_valid(t,COHERENT_PHASE_BIT(COHERENT_PREPARE));
    if (!coherent_frame_valid(t, COHERENT_PHASE_BIT(COHERENT_PREPARE)))return 0;
    if (cohort_bound && same_token(t, &cohort))
        return tags_cohort_valid(t, COHERENT_PHASE_BIT(COHERENT_PREPARE));
    if (cohort_bound && tags_cohort_valid(&cohort, COHERENT_ALL_PHASES))
        return 0;
    if (binding_serial == UINT64_MAX)
        return 0;
    ++binding_serial;
    cohort = *t;
    bound_session=context.session;
    cohort_bound = 1;
    cohort_cancelled = 0;
    return tags_cohort_valid(t, COHERENT_PHASE_BIT(COHERENT_PREPARE));
}
int tags_frame_binding_get(TagFrameBinding *out) {
    if (!out || !cohort_bound || cohort.thread != GetCurrentThreadId())
        return 0;
    *out = (TagFrameBinding){cohort, binding_serial};
    return 1;
}
int tags_abort_frame(const TagFrameBinding *b) {
    if (!b || !cohort_bound || b->token.thread != GetCurrentThreadId() ||
        b->binding_serial != binding_serial || !same_token(&b->token, &cohort))
        return 0;
    cohort_bound = 0;
    if (!frame_complete || failed || coherent_frame_release() != b->token.release) {
        current = NULL;
        active = 0;
        active_event = 0;
        scope_was_cancelled = 1;
        ++scope_serial;
        ++pending_generation;
        replay_completed = replay_corrected = 0;
    }
    return 1;
}
#define TAG_ALLOWED                                                                                          \
    (COHERENT_PHASE_BIT(COHERENT_PREPARE) | COHERENT_PHASE_BIT(COHERENT_DISPATCH) |                          \
     COHERENT_PHASE_BIT(COHERENT_FINISH))
static int guard_valid(const TagGuard *g) {
    if (!g || g->serial != scope_serial || g->epoch != epoch)
        return 0;
    TagSessionContext session_now;if(!session_provider||!session_provider(&session_now)||session_now.session!=g->session)return 0;
    if (g->kind == 1)
        return g->binding == binding_serial && current == g->frame.frame &&
               tags_cohort_valid(&g->frame, TAG_ALLOWED);
    if (g->kind == 2) {
        TagSessionContext now;
        return current == NULL && session_provider && session_provider(&now) && now.session==g->session && g->pending_generation == pending_generation && root_adapter &&
               span_engine_control_valid(root_adapter, &g->control);
    }
    return 0;
}
static int frame_guard(TagGuard *out) {
    if (!active || !current || !cohort_bound || cohort.frame != current ||
        !tags_cohort_valid(&cohort, TAG_ALLOWED))
        return 0;
    *out = (TagGuard){.kind = 1,
                      .frame = cohort,
                      .serial = scope_serial,
                      .binding = binding_serial,
                      .pending_generation = pending_generation,
                      .epoch = epoch,.session=active_session};
    return guard_valid(out);
}
static void reject_atomic(unsigned why) { coherent_frame_cancel_atomic(1u << (why % 31)); }
static int tag_progress(void){if(dispatch_revision==UINT64_MAX){failed=4;reject_atomic(22);return 0;}++dispatch_revision;return 1;}
static int scope_valid(uint64_t serial, const SyncFrame *frame) {
    TagGuard g;
    return scope_serial == serial && current == frame && frame_guard(&g);
}
static TagClock clock_read(void) {
#ifdef TAG_SYNC_TEST
    return tag_test_clock;
#else
    return (TagClock){*(uint32_t *)0xfb4b6c, *(uint32_t *)0xe637b4, *(uint32_t *)0xea178c,
                      *(float *)0xfb4b74};
#endif
}
static void clock_write(TagClock state) {
#ifdef TAG_SYNC_TEST
    tag_test_clock = state;
#else
    *(uint32_t *)0xfb4b6c = state.clock;
    *(uint32_t *)0xe637b4 = state.rng_game;
    *(uint32_t *)0xea178c = state.rng_engine;
    *(float *)0xfb4b74 = state.delta;
#endif
}
typedef struct TagControllerScope {
    struct TagControllerScope *previous;
    void *actors[2], *controllers[2];
    uint32_t generations[2];
    uint64_t serial, registration, assignment_version;
    int valid;
    TagGuard authority;
} TagControllerScope;
static __thread TagControllerScope *controller_scope;
static TagAssignmentVersion assignment_version;
static TagAssignmentRemap assignment_remap;
static DWORD assignment_thread;
static uint64_t assignment_registration;
static int lease_readable(const void *p, SIZE_T size) {
    MEMORY_BASIC_INFORMATION m;
    return p && VirtualQuery(p, &m, sizeof(m)) && m.State == MEM_COMMIT &&
           !(m.Protect & (PAGE_NOACCESS | PAGE_GUARD)) &&
           (uintptr_t)p + size <= (uintptr_t)m.BaseAddress + m.RegionSize;
}
static int lease_live(void *actor, uint32_t generation) {
#ifdef TAG_SYNC_TEST
#ifdef TAG_LEASE_TEST
    extern int tag_lease_test_live(void *, uint32_t);
    return tag_lease_test_live(actor, generation);
#else
    (void)actor;
    (void)generation;
    return 0;
#endif
#else
    return entities_allocation_live(actor, generation);
#endif
}
void tags_observe_controller_handoffs(TagAssignmentVersion version, TagAssignmentRemap remap) {
    assignment_version = version;
    assignment_remap = remap;
    assignment_thread = GetCurrentThreadId();
    ++assignment_registration;
}
static int resolve_controller_owner(void *actor, uint32_t generation, void *controller, void **owner,
                                    uint32_t *owner_generation) {
    if (!owner || !owner_generation || GetCurrentThreadId() != assignment_thread)
        return 0;
    for (TagControllerScope *s = controller_scope; s; s = s->previous) {
        if (!s->valid || s->serial != scope_serial || s->registration != assignment_registration ||
            !guard_valid(&s->authority))
            continue;
        int index = s->actors[0] == actor && s->generations[0] == generation   ? 0
                    : s->actors[1] == actor && s->generations[1] == generation ? 1
                                                                               : -1;
        if (index < 0 || s->controllers[index] != controller ||
            !lease_live(s->actors[0], s->generations[0]) || !lease_live(s->actors[1], s->generations[1]))
            continue;
        if (!guard_valid(&s->authority))
            continue;
        void *now0 = *(void **)((char *)s->actors[0] + 0x6cc),
             *now1 = *(void **)((char *)s->actors[1] + 0x6cc);
        int swapped = now0 == s->controllers[1] && now1 == s->controllers[0];
        int unchanged = now0 == s->controllers[0] && now1 == s->controllers[1];
        if (!guard_valid(&s->authority))
            continue;
        if (!swapped && !unchanged)
            continue;
        int resolved = swapped ? 1 - index : index;
        *owner = s->actors[resolved];
        *owner_generation = s->generations[resolved];
        return 1;
    }
    return 0;
}
int tags_resolve_controller_owner(void *actor, uint32_t generation, void *controller, void **owner,
                                  uint32_t *owner_generation) {
    DWORD error = GetLastError();
    int result = resolve_controller_owner(actor, generation, controller, owner, owner_generation);
    SetLastError(error);
    return result;
}
typedef struct TagOutcome {
    unsigned char fx[512] __attribute__((aligned(16)));
    DWORD error;
    int seen;
} TagOutcome;
typedef struct TagCall {
    TagControllerScope scope;
    TagGuard authority;
    void *from, *to;
    int32_t args[6];
    int linked, keyed;
    unsigned char incoming[512] __attribute__((aligned(16))), outgoing[512] __attribute__((aligned(16)));
    DWORD incoming_error, outgoing_error;
    TagOutcome *outcome;
} TagCall;
static int __cdecl native_tag_invoke(void *raw) {
    TagCall *c = raw;
    if (c->keyed && guard_valid(&c->authority) && assignment_version && assignment_remap &&
        GetCurrentThreadId() == assignment_thread) {
        if (controller_scope && guard_valid(&controller_scope->authority))
            assignment_remap(assignment_version());
        c->scope.registration = assignment_registration;
        c->scope.assignment_version = assignment_version();
    }
    c->scope.previous = controller_scope;
    c->scope.serial = scope_serial;
    c->scope.authority = c->authority;
    c->scope.actors[0] = c->from;
    c->scope.actors[1] = c->to;
    controller_scope = &c->scope;
    c->linked = 1;
    if (c->keyed && guard_valid(&c->authority) && assignment_version && assignment_remap &&
        GetCurrentThreadId() == assignment_thread) {
        c->scope.generations[0] = entities_local_generation(c->from);
        if (!guard_valid(&c->authority))
            goto native;
        c->scope.generations[1] = entities_local_generation(c->to);
        if (!guard_valid(&c->authority))
            goto native;
        if (c->from != c->to && lease_live(c->from, c->scope.generations[0]) &&
            lease_live(c->to, c->scope.generations[1])) {
            if (!guard_valid(&c->authority))
                goto native;
            c->scope.controllers[0] = *(void **)((char *)c->from + 0x6cc);
            c->scope.controllers[1] = *(void **)((char *)c->to + 0x6cc);
            c->scope.valid = c->scope.controllers[0] != c->scope.controllers[1] &&
                             lease_readable(c->scope.controllers[0], 4) &&
                             lease_readable(c->scope.controllers[1], 4);
        }
    }
native:
    SetLastError(c->incoming_error);
    __asm__ volatile("fxrstor %0" ::"m"(c->incoming));
    int result =
        original_tag(c->from, c->to, c->args[0], c->args[1], c->args[2], c->args[3], c->args[4], c->args[5]);
    __asm__ volatile("fxsave %0" : "=m"(c->outgoing));
    c->outgoing_error = GetLastError();
    if (c->outcome) {
        memcpy(c->outcome->fx, c->outgoing, 512);
        c->outcome->error = c->outgoing_error;
        c->outcome->seen = 1;
    }
    if (c->scope.valid && guard_valid(&c->authority) && c->scope.serial == scope_serial &&
        c->scope.registration == assignment_registration)
        assignment_remap(c->scope.assignment_version);
    return result;
}
static void __cdecl native_tag_leave(void *raw, int completed) {
    TagCall *c = raw;
    unsigned char fx[512] __attribute__((aligned(16)));
    __asm__ volatile("fxsave %0" : "=m"(fx));
    DWORD error = GetLastError();
    if (c->linked) {
        if (controller_scope == &c->scope)
            controller_scope = c->scope.previous;
        else
            reject_atomic(23);
    }
    if (!completed && c->keyed) {
        int matched = c->authority.serial == scope_serial && c->authority.epoch == epoch;
        if (c->authority.kind == 1)
            matched = matched && cohort_bound && c->authority.binding == binding_serial &&
                      same_token(&c->authority.frame, &cohort) &&
                      coherent_frame_release() == c->authority.frame.release;
        else
            matched =
                matched && root_adapter && span_engine_control_valid(root_adapter, &c->authority.control);
        if (matched) {
            failed = 8;
            scope_was_cancelled = 1;
            reject_atomic(22);
        }
    }
    SetLastError(error);
    __asm__ volatile("fxrstor %0" ::"m"(fx));
}
static int call_original(void *from, void *to, const int32_t *args, const TagGuard *g, TagOutcome *outcome) {
    TagCall c;
    unsigned char incoming[512] __attribute__((aligned(16)));
    __asm__ volatile("fxsave %0" : "=m"(incoming));
    DWORD error = GetLastError();
    memset(&c, 0, sizeof c);
    memcpy(c.incoming, incoming, 512);
    c.incoming_error = error;
    c.outcome = outcome;
    if (outcome && !outcome->seen) {
        memcpy(c.incoming, outcome->fx, 512);
        c.incoming_error = outcome->error;
    }
    c.from = from;
    c.to = to;
    memcpy(c.args, args, sizeof c.args);
    if (g)
        c.authority = *g;
    c.keyed = g && g->kind;
    int result = tag_lexical_seh(&c, native_tag_invoke, native_tag_leave);
    SetLastError(c.outgoing_error);
    __asm__ volatile("fxrstor %0" ::"m"(c.outgoing));
    return result;
}
static int replay(unsigned index, int preserve_context, TagOutcome *outcome) {
    TagGuard guard;
    if (!frame_guard(&guard))
        return 0;
    SyncFrame *frame = current;
    if (index >= frame->tag_count || index >= SYNC_MAX_TAGS)
        return 0;
    SyncTag saved = frame->tags[index];
    SyncTag *tag = &saved;
    if (consumed[index])
        return 1;
    if (tag->id <= replay_cursor) {
        if(!tag_progress())return 0;
        consumed[index] = 1;
        return 1;
    }
    if (tag->id != replay_cursor + 1 || tag->parent != active_event) {
        failed = 1;
        return 0;
    }
    void *from = entities_resolve_identity(frame, (uint32_t)tag->from, tag->from_generation);
    if (!guard_valid(&guard))
        return 0;
    void *to = entities_resolve_identity(frame, (uint32_t)tag->to, tag->to_generation);
    if (!guard_valid(&guard))
        return 0;
    if (!from || !to || from == to) {
        failed = 2;
        return 0;
    }
    TagClock previous = clock_read();
    if (!guard_valid(&guard))
        return 0;
    clock_write((TagClock){tag->clock, tag->rng_game, tag->rng_engine, tag->delta});
    uint32_t parent = active_event;
    active_event = tag->id;
    if(!tag_progress())return 0;
    consumed[index] = 1;
    replay_cursor = tag->id;
    int result = call_original(from, to, tag->arguments, &guard, outcome);
    if (!guard_valid(&guard))
        return 0;
    active_event = parent;
    if (preserve_context)
        clock_write(previous);
    if (result != 1) {
        failed = 3;
        return 0;
    }
    for (unsigned i = index + 1; i < frame->tag_count; ++i) {
        if (!guard_valid(&guard))
            return 0;
        if (!consumed[i] && frame->tags[i].parent == tag->id) {
            failed = 6;
            return 0;
        }
    }
    ++replay_completed;
    if (!parent) {
        last_applied = replay_cursor;
        clonewars_tag_debug[1] += replay_completed;
        clonewars_tag_debug[9] += replay_corrected;
        clonewars_tag_debug[5] = last_applied;
        clonewars_tag_debug[7] = (uint32_t)tag->from;
        clonewars_tag_debug[8] = (uint32_t)tag->to;
        replay_completed = replay_corrected = 0;
    }
    return 1;
}
static int tag_hook_impl(void *from, void *to, int a, int b, int c, int d, int e, int f,
                         TagOutcome *outcome) {
    int32_t args[6] = {a, b, c, d, e, f};
    TagGuard guard = {0};
    TagSessionContext session = {0};
    int frame = frame_guard(&guard);
    if (!frame) {
        int classified = session_provider && session_provider(&session);
        if (!classified || session.classification == TAG_SESSION_UNAVAILABLE) {
            reject_atomic(20);
            return lan_is_host() ? call_original(from, to, args, NULL, outcome) : 0;
        }
        if (session.classification == TAG_SESSION_OFFLINE ||
            session.classification == TAG_SESSION_BOOTSTRAP ||
            session.classification == TAG_SESSION_TRANSITION)
            return call_original(from, to, args, NULL, outcome);
        if (session.classification != TAG_SESSION_ESTABLISHED) {
            reject_atomic(20);
            return lan_is_host() ? call_original(from, to, args, NULL, outcome) : 0;
        }
        if (!lan_is_host()) {
            ++clonewars_tag_debug[2];
            return 0;
        }
        RootControlLease control;
        if (failed || current || !session.session || session.session==UINT32_MAX || !root_adapter ||
            !span_engine_control_get(root_adapter, &control) || control.epoch != session.epoch ||
            control.level != session.level ||
            ((!active || epoch != control.epoch) &&
             !((initial_control_available || session.session>last_authorized_session || (session.session==last_authorized_session && control.epoch>last_authorized_epoch)) && !epoch && !next_id && !pending_count))) {
            reject_atomic(21);
            return call_original(from, to, args, NULL, outcome);
        }
        if (!active) {
            epoch = control.epoch;
            active_session=last_authorized_session=session.session;
            last_authorized_epoch=control.epoch;
            host_role = 1;
            active = 1;
            initial_control_available = 0;
        }
        guard = (TagGuard){.kind = 2,
                           .control = control,
                           .serial = scope_serial,
                           .pending_generation = pending_generation,
                           .epoch = epoch,.session=session.session};
    }
    if (!guard_valid(&guard)) {
        reject_atomic(21);
        return lan_is_host() ? call_original(from, to, args, NULL, outcome) : 0;
    }
    if (frame && !host_role) {
        SyncFrame *borrowed = current;
        for (unsigned i = 0; guard_valid(&guard) && i < borrowed->tag_count; ++i) {
            if (consumed[i])
                continue;
            SyncTag tag = borrowed->tags[i];
            if (tag.parent != active_event || (tag.phase && !active_event))
                break;
            void *expected_from =
                entities_resolve_identity(borrowed, (uint32_t)tag.from, tag.from_generation);
            if (!guard_valid(&guard))
                return 0;
            if (expected_from == from) {
                void *expected_to = entities_resolve_identity(borrowed, (uint32_t)tag.to, tag.to_generation);
                if (!guard_valid(&guard))
                    return 0;
                int different = expected_to && expected_to != to;
                int result = replay(i, 0, outcome);
                if (result && guard_valid(&guard) && different) {
                    if (active_event)
                        ++replay_corrected;
                    else
                        ++clonewars_tag_debug[9];
                }
                return result;
            }
            break;
        }
        ++clonewars_tag_debug[2];
        return 0;
    }
    entities_update();
    if (!guard_valid(&guard))
        return call_original(from, to, args, NULL, outcome);
    SyncTag tag = {.parent = active_event, .phase = frame ? 0u : 1u};
    tag.from = entities_slot(from);
    if (!guard_valid(&guard))
        return call_original(from, to, args, NULL, outcome);
    tag.to = entities_slot(to);
    if (!guard_valid(&guard))
        return call_original(from, to, args, NULL, outcome);
    tag.from_generation = entities_local_generation(from);
    if (!guard_valid(&guard))
        return call_original(from, to, args, NULL, outcome);
    tag.to_generation = entities_local_generation(to);
    if (!guard_valid(&guard))
        return call_original(from, to, args, NULL, outcome);
    memcpy(tag.arguments, args, sizeof args);
    TagClock context = clock_read();
    tag.clock = context.clock;
    tag.rng_game = context.rng_game;
    tag.rng_engine = context.rng_engine;
    tag.delta = context.delta;
    unsigned count = frame ? current->tag_count : pending_count;
    if (count == SYNC_MAX_TAGS || tag.from < 0 || tag.to < 0 || tag.from == tag.to || !tag.from_generation ||
        !tag.to_generation || next_id == UINT32_MAX) {
        failed = 4;
        reject_atomic(21);
        return call_original(from, to, args, NULL, outcome);
    }
    tag.id = ++next_id;
    SyncTag *destination = frame ? current->tags + current->tag_count++ : pending + pending_count++;
    *destination = tag;
    if (!frame)
        provenance[count] = (PendingProvenance){guard.control.epoch, guard.control.release, guard.session,
                                                guard.control.level, pending_generation, 0};
    uint32_t parent = active_event;
    active_event = tag.id;
    int result = call_original(from, to, args, &guard, outcome);
    if (!guard_valid(&guard))
        return result;
    active_event = parent;
    if (result != 1) {
        if (next_id == tag.id) {
            --next_id;
            if (frame)
                --current->tag_count;
            else
                --pending_count;
        } else
            failed = 7;
        return result;
    }
    if (!frame)
        provenance[count].committed = 1;
    if(!tag_progress())return result;
    ++clonewars_tag_debug[0];
    clonewars_tag_debug[6] = next_id;
    clonewars_tag_debug[4] = pending_count;
    return result;
}
static int tag_hook(void *from, void *to, int a, int b, int c, int d, int e, int f) {
    TagOutcome outcome;
    __asm__ volatile("fxsave %0" : "=m"(outcome.fx));
    outcome.error = GetLastError();
    outcome.seen = 0;
    int result = tag_hook_impl(from, to, a, b, c, d, e, f, &outcome);
    SetLastError(outcome.error);
    __asm__ volatile("fxrstor %0" ::"m"(outcome.fx) : "memory");
    return result;
}
static void reset_state(void) {
    initial_control_available = 0;
    scope_was_cancelled = scope_was_cancelled || current != NULL;
    ++scope_serial;
    ++pending_generation;
    current = NULL;
    pending_count = 0;
    epoch = next_id = last_applied = replay_cursor = 0;
    active = failed = frame_complete = 0;
    active_event = 0;
    replay_completed = replay_corrected = 0;
    cohort_bound = 0;
}
void tags_reset(void) {
    if (root_adapter && GetCurrentThreadId() != root_adapter->window_thread) {
        reject_atomic(19);
        return;
    }
    if (active || pending_count || epoch)
        reject_atomic(19);
    reset_state();
}
int tags_begin(SyncFrame *frame, int host) {
    CoherentFrameToken captured = cohort;
    uint64_t original_binding = binding_serial;
    if (!cohort_bound || captured.frame != frame ||
        !tags_cohort_valid(&captured, COHERENT_PHASE_BIT(COHERENT_PREPARE)))
        return TAG_FRAME_CANCELLED;
    TagSessionContext begin_session;
    if(!session_provider||!session_provider(&begin_session)||!begin_session.session||begin_session.session==UINT32_MAX)return TAG_FRAME_CANCELLED;
    if (epoch != frame->epoch || (active_session && active_session!=begin_session.session)) {
        if(pending_count || (last_authorized_session && (begin_session.session<last_authorized_session || (begin_session.session==last_authorized_session && captured.epoch<=last_authorized_epoch)))){reject_atomic(23);return TAG_FRAME_CANCELLED;}
        reset_state();
        epoch = frame->epoch;
        cohort = captured;
        binding_serial = original_binding;
        cohort_bound = 1;
        cohort_cancelled = 0;
    }
    active_session=last_authorized_session=begin_session.session;last_authorized_epoch=captured.epoch;
    frame_complete = 0;
    if (frame->tag_count > SYNC_MAX_TAGS)
        return TAG_FRAME_FAILED;
    ++scope_serial;
    uint64_t serial = scope_serial;
    current = frame;
    host_role = host;
    active = 1;
    frame_complete = 0;
    scope_was_cancelled = 0;
    active_event = 0;
    replay_completed = replay_corrected = 0;
    memset(consumed, 0, sizeof consumed);
    if (host) {
        for (unsigned i = 0; i < pending_count; ++i)
            if (!provenance[i].committed || provenance[i].epoch != captured.epoch ||
                provenance[i].level != frame->level || provenance[i].session!=begin_session.session || provenance[i].release != captured.release ||
                provenance[i].generation != pending_generation) {
                scope_was_cancelled = 1;
                current = NULL;
                return TAG_FRAME_CANCELLED;
            }
        frame->tag_count = pending_count;
        memcpy(frame->tags, pending, pending_count * sizeof(SyncTag));
        pending_count = 0;
    } else
        for (unsigned i = 0; scope_valid(serial, frame) && i < frame->tag_count; ++i) {
            if (frame->tags[i].id <= replay_cursor)
                consumed[i] = 1;
            else if (frame->tags[i].phase && !replay(i, 1, NULL))
                break;
        }
    if (!scope_valid(serial, frame))
        return TAG_FRAME_CANCELLED;
    clonewars_tag_debug[3] = failed;
    clonewars_tag_debug[4] = pending_count;
    clonewars_tag_debug[10] = frame->sequence;
    if (failed)
        current = NULL;
    return !failed;
}
void tags_cancel(void) {
    if (root_adapter && GetCurrentThreadId() != root_adapter->window_thread) {
        reject_atomic(19);
        return;
    }
    if (active || cohort_bound || pending_count)
        reject_atomic(19);
    cohort_cancelled = 1;
    scope_was_cancelled = scope_was_cancelled || current != NULL;
    ++scope_serial;
    ++pending_generation;
    current = NULL;
    active = 0;
    active_event = 0;
    replay_completed = replay_corrected = 0;
}
int tags_dispatch_revision(const CoherentFrameToken*original,uint64_t*out){
 if(!out||!tags_cohort_valid(original,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;
 *out=dispatch_revision;return tags_cohort_valid(original,COHERENT_PHASE_BIT(COHERENT_DISPATCH));
}
int tags_dispatch_pending(void){
 TagGuard guard;if(!frame_guard(&guard)||!coherent_frame_valid(&guard.frame,COHERENT_PHASE_BIT(COHERENT_DISPATCH))||failed)return -1;
 if(host_role)return 0;SyncFrame*f=current;if(f->tag_count>SYNC_MAX_TAGS)return -1;
 for(unsigned i=0;i<f->tag_count;++i)if(!consumed[i])return 1;return 0;
}
int tags_dispatch_complete(void){
 TagGuard guard;if(!frame_guard(&guard)||!coherent_frame_valid(&guard.frame,COHERENT_PHASE_BIT(COHERENT_DISPATCH))||failed)return TAG_FRAME_CANCELLED;
 if(!host_role){SyncFrame*f=current;for(unsigned i=0;guard_valid(&guard)&&i<f->tag_count;++i)if(!consumed[i]&&!replay(i,1,NULL))break;}
 if(!guard_valid(&guard))return TAG_FRAME_CANCELLED;return failed?TAG_FRAME_FAILED:TAG_FRAME_OK;
}
int tags_finish(void) {
    SyncFrame *frame = current;
    uint64_t serial = scope_serial;
    if (!frame)
        return scope_was_cancelled ? TAG_FRAME_CANCELLED : TAG_FRAME_FAILED;
    if (!scope_valid(serial, frame))
        return TAG_FRAME_CANCELLED;
    if (!host_role)for(unsigned i=0;i<frame->tag_count;++i)if(!consumed[i]){failed=6;break;}
    if (!scope_valid(serial, frame))
        return TAG_FRAME_CANCELLED;
    if (!host_role && !failed && !entities_party_matches(frame))
        failed = 5;
    if (!scope_valid(serial, frame))
        return TAG_FRAME_CANCELLED;
    clonewars_tag_debug[11] = failed == 5;
    clonewars_tag_debug[3] = failed;
    frame_complete = !failed;
    current = NULL;
    return !failed;
}
int tags_install(void) {
#ifdef TAG_SYNC_TEST
    return root_adapter && session_provider;
#else
    if (!root_adapter || !session_provider)
        return 0;
    unsigned char *target = (unsigned char *)0x8ae680;
    const unsigned char expected[] = {0x83, 0xec, 0x28, 0x56, 0x8b, 0x74, 0x24, 0x30};
    if (memcmp(target, expected, 8))
        return 0;
    unsigned char *trampoline = VirtualAlloc(NULL, 13, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    DWORD old;
    if (!trampoline || !VirtualProtect(target, 8, PAGE_EXECUTE_READWRITE, &old))
        return 0;
    memcpy(trampoline, target, 8);
    trampoline[8] = 0xe9;
    *(int32_t *)(trampoline + 9) = (int32_t)((uintptr_t)target + 8 - (uintptr_t)trampoline - 13);
    original_tag = (Transfer)trampoline;
    target[0] = 0xe9;
    *(int32_t *)(target + 1) = (int32_t)((uintptr_t)tag_hook - (uintptr_t)target - 5);
    memset(target + 5, 0x90, 3);
    FlushInstructionCache(GetCurrentProcess(), trampoline, 13);
    FlushInstructionCache(GetCurrentProcess(), target, 8);
    VirtualProtect(target, 8, old, &old);
    return 1;
#endif
}
#ifdef TAG_SYNC_TEST
int tags_test_call(void *from, void *to, int a, int b, int c, int d, int e, int f) {
    return tag_hook(from, to, a, b, c, d, e, f);
}
#endif

#ifdef TAG_SYNC_TEST
uintptr_t tags_test_controller_head(void) { return (uintptr_t)controller_scope; }
uint32_t tags_test_next_id(void) { return next_id; }
unsigned tags_test_pending_count(void) { return pending_count; }
#endif

#ifdef TAG_SYNC_TEST
void *tags_test_entry(void) { return tag_hook; }
#endif
