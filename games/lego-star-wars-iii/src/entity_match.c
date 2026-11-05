#include <math.h>
#include "entity_match.h"
int entity_match_unique(const EntityKey *wanted,const EntityKey *available,const unsigned char *claimed,unsigned count) {
    int found=-1;
    for (unsigned i=0;i<count;++i) {
        const EntityKey *candidate=available+i;
        if (claimed[i] || !candidate->generation || candidate->character!=wanted->character || candidate->spawn_tag!=wanted->spawn_tag) continue;
        float distance=0;
        for (int axis=0;axis<3;++axis) {
            float delta=candidate->origin[axis]-wanted->origin[axis];
            distance+=delta*delta;
        }
        if (!isfinite(distance) || distance>.25f*.25f) continue;
        if (found>=0) return -2;
        found=(int)i;
    }
    return found;
}
