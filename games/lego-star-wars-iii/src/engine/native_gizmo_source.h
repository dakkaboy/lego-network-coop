#pragma once
#include <stdint.h>

struct NativeGizmoSource {
    uint32_t key[4],manager_class,gizmo_class,manager_index,ordinal,count;
    void *world,*container,*registry,*handle,*table,*manager,*gizmo,*head;
};

bool native_gizmo_source_resolve(void *manager,void *gizmo,NativeGizmoSource &source);
bool native_gizmo_source_find(void *gizmo,uintptr_t native_update,NativeGizmoSource &source);
bool native_gizmo_source_revalidate(const NativeGizmoSource &source);
