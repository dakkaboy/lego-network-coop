#pragma once
#include <stdint.h>
#include "native_authored_poi.h"
#include "native_resource_identity.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NativeSpellItSourceKey {
    uint32_t name[4],gizmo_class,gizmo_ordinal;
} NativeSpellItSourceKey;

typedef struct NativeSpellItPieceKey {
    uint32_t resource[4],poi_name[4];
    uint32_t poi_ordinal,poi_count,receiver_class,piece_ordinal;
} NativeSpellItPieceKey;

typedef struct NativeSpellItSource {
    NativeSpellItSourceKey key;
    void *world,*container,*provider,*manager_registry,*handle,*table,*manager,*gizmo;
    void *scene,*piece_head,*piece_tail,*adapter,*counted_name;
    uint32_t manager_index,manager_count,manager_class,piece_count,adapter_count;
} NativeSpellItSource;

typedef struct NativeSpellItPiece {
    NativeSpellItPieceKey key;
    void *piece,*previous,*next,*source_entity,*model,*live_record,*receiver;
    void *resource,*root_resource,*runtime,*array,*poi,*registry,*entry,*container,*source_world;
    void *filename,*logical_name,*poi_name;
    void *models[16],*receivers[16],*chain_resources[16],*chain_pois[16];
    uint32_t chain_count,authored_receiver_class;
    NativeAuthoredPoi authored;
    NativeResourceIdentity resource_identity;
} NativeSpellItPiece;

typedef struct NativeSpellItBody {
    uint32_t key[4],name_key[4],body_class,piece_ordinal;
    void *piece,*model,*receiver,*body,*dynamics,*name;
} NativeSpellItBody;

typedef struct NativeSpellItBodyState {
    float basis[12],position[4],linear[4],angular[4];
} NativeSpellItBodyState;

int native_spellit_source_resolve(void *gizmo,NativeSpellItSource *out);
int native_spellit_source_revalidate(const NativeSpellItSource *source);
int native_spellit_piece_resolve(const NativeSpellItSource *source,void *piece,NativeSpellItPiece *out);
int native_spellit_piece_revalidate(const NativeSpellItSource *source,const NativeSpellItPiece *piece);
int native_spellit_selection_snapshot(const NativeSpellItSource *source,uint32_t *count,uint32_t eligibility[4]);
int native_spellit_body_resolve(const NativeSpellItSource *source,void *piece,NativeSpellItBody *out);
int native_spellit_body_matches(const NativeSpellItSource *source,const NativeSpellItBody *body);
int native_spellit_body_read(const NativeSpellItSource *source,const NativeSpellItBody *body,NativeSpellItBodyState *state);
int native_spellit_body_apply(const NativeSpellItSource *source,const NativeSpellItBody *body,const NativeSpellItBodyState *state,int (*live)(void *),void *context);

#ifdef __cplusplus
}
#endif
