#include "entity_match.h"

int entity_match_unique(const EntityKey *wanted,const EntityKey *available,const unsigned char *claimed,unsigned count) {
    if (!wanted->spawn_source.producer) return -1;
    int match=-1;
    for (unsigned i=0;i<count;++i) {
        const EntityKey *candidate=available+i;
        if (claimed[i] || !candidate->generation || candidate->character!=wanted->character ||
            candidate->spawn_tag!=wanted->spawn_tag ||
            candidate->spawn_source.producer!=wanted->spawn_source.producer ||
            candidate->spawn_source.serial!=wanted->spawn_source.serial) continue;
        if (match>=0) return -2;
        match=(int)i;
    }
    return match;
}
