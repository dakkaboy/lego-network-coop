#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "geometry_sync.h"
#include "entity_sync.h"
#include "game_sync.h"
#include "module_cohort_binding.h"
#include "game_state.h"
#ifdef GEOMETRY_SYNC_TEST
extern char *geometry_test_pool;
#define GEOMETRY_POOL geometry_test_pool
#else
#define GEOMETRY_POOL (*(char **)0xfb2f60)
#endif
static GeometryJournal journal;
static int active;
static int cancelled;
static ModuleCohortBinding binding;
static int op_live(const GeometryFrameLease *op){return module_binding_live(&binding,op)&&journal.frame==op->cohort.frame;}
int geometry_bind_cohort(const CoherentFrameToken *original){return module_binding_bind(&binding,original);}
int geometry_frame_lease_get(GeometryFrameLease*out){return module_binding_get(&binding,out);}
int geometry_frame_cancelled(const GeometryFrameLease*op){return module_binding_cancelled(&binding,op);}
int geometry_abort_frame(const GeometryFrameLease*op){if(!module_binding_detach(&binding,op))return 0;active=0;cancelled=1;memset(&journal,0,sizeof(journal));return 1;}

static uint32_t last_epoch;
__declspec(dllexport) volatile LONG clonewars_geometry_installed;
__declspec(dllexport) volatile uint32_t clonewars_geometry_debug[20];
__declspec(dllexport) volatile uint32_t clonewars_geometry_failure[14];
static int valid(const void *p,unsigned size) {
    MEMORY_BASIC_INFORMATION m;return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT && !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
        (uintptr_t)p+size>=(uintptr_t)p && (uintptr_t)p+size<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static int fail(const GeometryFrameLease *op,const SyncCollider *entry,void *actual,uint32_t mode,uint32_t batch_count,uint32_t active_count,int reason) {
    if(!op_live(op))return 0;
    if (!journal.failed) journal.failed=reason;
    if (!clonewars_geometry_failure[0]) {
        uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(actual,&slot,&generation);if(!op_live(op))return 0;
        uint32_t local_generation=entities_observed_generation(actual);if(!op_live(op))return 0;
        uint32_t values[]={journal.frame->epoch,journal.frame->sequence,journal.ordinal,(uint32_t)journal.failed,
            entry ? entry->slot : UINT32_MAX,entry ? entry->generation : 0,slot,generation,local_generation,batch_count,active_count,mode,journal.cursor,journal.validated};
        memcpy((void *)clonewars_geometry_failure,values,sizeof(values));clonewars_geometry_debug[15]=journal.frame->sequence;clonewars_geometry_debug[16]=(uint32_t)journal.failed;
    }
    if(!op_live(op))return 0;++clonewars_geometry_debug[5];game_sync_native_fault(15);return 0;
}
void geometry_manager_ready(void) { InterlockedExchange(&clonewars_geometry_installed,1); }
int geometry_ready(void) { return clonewars_geometry_installed==1; }
void geometry_cancel(void) { if(binding.bound||!binding.lease.cohort.thread||binding.lease.cohort.thread!=GetCurrentThreadId())return;active=0;cancelled=1;memset(&journal,0,sizeof(journal)); }
int geometry_begin(SyncFrame *frame,int host) {
    if(!module_binding_begin(&binding,frame))return 0;
    GeometryFrameLease op=binding.lease;if(!module_binding_live(&binding,&op))return 0;
    cancelled=0;
    if (last_epoch!=op.cohort.epoch) { memset((void *)clonewars_geometry_failure,0,sizeof(clonewars_geometry_failure));last_epoch=op.cohort.epoch; }
    geometry_journal_begin(&journal,frame,host);active=1;return op_live(&op);
}
int geometry_phase(uint32_t mode) {
    if (!active) return binding.bound?0:1;
    GeometryFrameLease op;if(!geometry_frame_lease_get(&op)||!op_live(&op))return 0;
    if (journal.failed) return 0;
    GeometryBatch batch;
    if (!geometry_journal_phase(&journal,mode,&batch)) return fail(&op,NULL,NULL,mode,0,0,3);
    ++clonewars_geometry_debug[journal.host ? 6 : 7];
    if (mode) {
        ++clonewars_geometry_debug[8];
        return journal.host || geometry_journal_commit(&journal,&batch) ? 1 : fail(&op,NULL,NULL,mode,batch.count,0,3);
    }
    entities_update();if(!op_live(&op))return 0;char *pool=GEOMETRY_POOL;int count=game_actor_count();if(!op_live(&op))return 0;
    if (count<0 || count>SYNC_MAX_ACTORS || (count && !valid(pool,(unsigned)count*0x1440))) return fail(&op,NULL,NULL,mode,batch.count,0,4);
    if (journal.host) {
        unsigned recorded=0;
        for (int slot=0;slot<count;++slot) {
            if(!op_live(&op))return 0;char *actor=pool+slot*0x1440;if ((*(uint32_t *)(actor+0x50)&3)!=3) continue;
            SyncActor identity={0};entities_describe(&identity,actor);if(!op_live(&op))return 0;
            SyncCollider entry={.manager_ordinal=journal.ordinal,.slot=(uint32_t)slot,.generation=identity.generation,.spawn_tag=identity.spawn_tag,.character=*(int16_t *)(actor+0xdc0)};
            memcpy(entry.origin,identity.spawn_position,12);memcpy(entry.bounds,actor+0x30,24);memcpy(entry.center,actor+0xf28,12);memcpy(entry.extents,actor+0x1088,8);
            if (!geometry_journal_record(&journal,&entry)) return fail(&op,&entry,actor,mode,recorded,recorded,2);
            ++recorded;++clonewars_geometry_debug[0];
        }
        clonewars_geometry_debug[17]=recorded;clonewars_geometry_debug[18]=recorded;return 1;
    }
    void *resolved[SYNC_MAX_ACTORS];uint32_t resolved_generation[SYNC_MAX_ACTORS];unsigned char claimed[SYNC_MAX_ACTORS]={0};unsigned active_count=0;
    for (uint32_t index=0;index<batch.count;++index) {
        if(!op_live(&op))return 0;const SyncCollider *entry=journal.frame->geometry+batch.start+index;
        SyncActor identity={.slot=entry->slot,.generation=entry->generation,.spawn_tag=entry->spawn_tag,.character=entry->character};memcpy(identity.spawn_position,entry->origin,12);
        char *actor=entities_resolve_reference(&identity);if(!op_live(&op))return 0;resolved[index]=actor;
        uintptr_t offset=(uintptr_t)actor-(uintptr_t)pool;
        int owner_matches=actor && offset%0x1440==0 && offset/0x1440<(unsigned)count && valid(actor,0x1440) && (*(uint32_t *)(actor+0x50)&3)==3;
        if (!geometry_journal_validate(&journal,entry,owner_matches)) return fail(&op,entry,actor,mode,batch.count,0,journal.failed);
        unsigned local_slot=(unsigned)(offset/0x1440);
        if (claimed[local_slot]) return fail(&op,entry,actor,mode,batch.count,0,5);
        claimed[local_slot]=1;resolved_generation[index]=entities_observed_generation(actor);
    }
    for (int slot=0;slot<count;++slot) if ((*(uint32_t *)(pool+slot*0x1440+0x50)&3)==3) {
        ++active_count;if (!claimed[slot]) return fail(&op,NULL,pool+slot*0x1440,mode,batch.count,active_count,6);
    }
    for (uint32_t index=0;index<batch.count;++index) {
        if(!op_live(&op))return 0;
        char *actor=resolved[index];
        if (!valid(actor,0x1440) || (*(uint32_t *)(actor+0x50)&3)!=3 || !resolved_generation[index] || entities_observed_generation(actor)!=resolved_generation[index])
            return fail(&op,journal.frame->geometry+batch.start+index,actor,mode,batch.count,active_count,4);
    }
    if(!op_live(&op))return 0;
    if (active_count!=batch.count || !geometry_journal_commit(&journal,&batch)) return fail(&op,NULL,NULL,mode,batch.count,active_count,3);
    for (uint32_t index=0;index<batch.count;++index) {
        if(!op_live(&op))return 0;const SyncCollider *entry=journal.frame->geometry+batch.start+index;char *actor=resolved[index];
        clonewars_geometry_debug[2]+=memcmp(actor+0x30,entry->bounds,24)!=0;clonewars_geometry_debug[3]+=memcmp(actor+0xf28,entry->center,12)!=0;clonewars_geometry_debug[4]+=memcmp(actor+0x1088,entry->extents,8)!=0;
        memcpy(actor+0x30,entry->bounds,24);memcpy(actor+0xf28,entry->center,12);memcpy(actor+0x1088,entry->extents,8);
        ++clonewars_geometry_debug[1];clonewars_geometry_debug[13]=entry->slot;clonewars_geometry_debug[14]=entry->generation;
    }
    clonewars_geometry_debug[11]=journal.frame->sequence;clonewars_geometry_debug[12]=journal.ordinal;clonewars_geometry_debug[17]=batch.count;clonewars_geometry_debug[18]=active_count;return 1;
}
int geometry_finish(void) {
    GeometryFrameLease op;if(!geometry_frame_lease_get(&op)||!op_live(&op)||!active)return 0;
    if (cancelled) return 0;
    active=0;++clonewars_geometry_debug[9];
    if (!geometry_journal_finish(&journal)) { ++clonewars_geometry_debug[10];if (!journal.failed) return fail(&op,NULL,NULL,0,0,0,7);return 0; }return 1;
}
