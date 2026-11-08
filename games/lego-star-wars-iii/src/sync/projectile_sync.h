#pragma once
#include "../net/sync_wire.h"
#include "projectile_identity.h"
#include "coherent_frame_fence.h"
#include "projectile_control.h"
typedef struct ProjectileFrameLease {uint32_t serial;CoherentFrameToken cohort;} ProjectileFrameLease;
int projectiles_bind_cohort(const CoherentFrameToken *original);
int projectiles_cohort_valid(const CoherentFrameToken *original);
int projectiles_frame_lease_get(ProjectileFrameLease *);
int projectiles_abort_frame(const ProjectileFrameLease *);
int projectiles_frame_cancelled(const ProjectileFrameLease *captured);
typedef struct ProjectileIdentityView {
    uint32_t status,id; int32_t owner,weapon; uint32_t owner_generation,resource_local;
    uint32_t instance_serial,creation_count;
} ProjectileIdentityView;
int projectiles_observe_live(const void *object,ProjectileIdentityView *view);
int projectiles_install(void);
void projectiles_reset(void);
int projectiles_begin(SyncFrame *frame,int host);
int projectiles_dispatch_revision(const CoherentFrameToken *original,uint64_t *revision);
/* The first DISPATCH call executes queued renderer requests before native world. */
int projectiles_dispatch_pending(void);
int projectiles_dispatch_complete(void);
int projectiles_finish(void);

uint32_t projectiles_lifecycle_serial(void);

enum ProjectileCohortCapability {PROJECTILE_COHORT_FRAME=1,PROJECTILE_COHORT_CONTROL=2};
unsigned projectiles_cohort_capabilities(void);
int projectiles_control_pending_missing(void);
int projectiles_cohort_ready(void);
