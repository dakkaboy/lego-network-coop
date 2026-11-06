#undef NDEBUG
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include "sync/entity_sync.h"

enum { ACTOR_COUNT = 4, ACTOR_STRIDE = 0x1440 };

char *entity_test_pool,*entity_test_players[8];

int lan_is_host(void) { return 0; }
int game_actor_count(void) { return ACTOR_COUNT; }

static void prepare_party(SyncFrame *frame) {
    const int16_t characters[ACTOR_COUNT]={199,176,138,138};
    const uint32_t active=3;
    for (int party=0;party<ACTOR_COUNT;++party) {
        char *actor=entity_test_pool+party*ACTOR_STRIDE;
        const float x=1.0f+party;
        entity_test_players[party]=actor;
        actor[0x55]=(char)party;
        memcpy(actor+0x24,&x,sizeof(x));
        memcpy(actor+0x50,&active,sizeof(active));
        memcpy(actor+0xdc0,&characters[party],sizeof(characters[party]));
    }
    entities_update();
    frame->sequence=1;
    frame->actor_count=ACTOR_COUNT;
    for (int party=0;party<ACTOR_COUNT;++party) {
        SyncActor *state=frame->actors+party;
        entities_describe(state,entity_test_players[party]);
        state->slot=(uint32_t)party;
        state->generation=100u+(uint32_t)party;
        state->character=characters[party];
        state->health=4;
    }
    frame->actors[2].spawn_position[0]-=0.49f;
    frame->actors[3].spawn_position[0]+=0.75f;
}

int main(void) {
    entity_test_pool=calloc(ACTOR_COUNT,ACTOR_STRIDE);
    SyncFrame *frame=calloc(1,sizeof(*frame));
    assert(entity_test_pool && frame);
    prepare_party(frame);

    assert(entities_bind(frame) && entities_party_matches(frame));
    assert(entities_actor(2,102)==entity_test_players[2]);
    assert(entities_actor(3,103)==entity_test_players[3]);
    frame->sequence=2;
    assert(entities_bind(frame) && entities_party_matches(frame));
    entities_reset_bindings();
    assert(!entities_bind(frame));

    entities_reset_bindings();
    frame->sequence=1;
    entity_test_players[2][0x55]=-1;
    assert(!entities_bind(frame) && !entities_actor(2,102));

    entities_reset_bindings();
    entity_test_players[2][0x55]=2;
    ++frame->actors[2].spawn_tag;
    assert(!entities_bind(frame) && !entities_actor(2,102));

    free(frame);
    free(entity_test_pool);
    return 0;
}
