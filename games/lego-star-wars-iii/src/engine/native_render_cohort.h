#pragma once
#include <cstring>
#include "native_gizmo_source.h"

struct NativeRenderCohort {
    NativeGizmoSource source{};
    uint32_t epoch=0,clock=0;
    bool valid=false;
    uint32_t primary(const NativeGizmoSource &next,uint32_t native_epoch,uint32_t native_clock,uint32_t flag) {
        if(!flag)return flag;
        const bool same=valid && epoch==native_epoch && clock==native_clock &&
            source.world==next.world && source.container==next.container && source.registry==next.registry &&
            source.handle==next.handle && source.table==next.table && source.manager==next.manager &&
            source.manager_class==next.manager_class && source.manager_index==next.manager_index &&
            !std::memcmp(source.key,next.key,sizeof source.key);
        if(same)return 0;
        source=next;epoch=native_epoch;clock=native_clock;valid=true;return flag;
    }
};
