#undef NDEBUG
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include "sync/entity_sync.h"
#include "sync/entity_match.h"

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
    EntityKey requested={.generation=12,.spawn_tag=5,.character=171,.spawn_source={0xe033ae01,2}};
    EntityKey candidates[]={
        {.generation=21,.spawn_tag=5,.character=171,.spawn_source={0xe033ae01,3}},
        {.generation=22,.spawn_tag=5,.character=171,.spawn_source={0xa212f067,2}},
        {.generation=23,.spawn_tag=5,.character=171,.spawn_source={0xe033ae01,2}},
    };
    unsigned char unavailable[3]={0};
    assert(entity_match_unique(&requested,candidates,unavailable,3)==2);
    unavailable[2]=1;
    assert(entity_match_unique(&requested,candidates,unavailable,3)==-1);
    unavailable[2]=0;
    candidates[1]=candidates[2];
    assert(entity_match_unique(&requested,candidates,unavailable,3)==-2);
    requested.spawn_source=(SyncSpawnSource){0};
    assert(entity_match_unique(&requested,candidates,unavailable,3)==-1);

    entity_test_pool=calloc(ACTOR_COUNT,ACTOR_STRIDE);
    SyncFrame *frame=calloc(1,sizeof(*frame));
    assert(entity_test_pool && frame);
    prepare_party(frame);

    assert(entities_bind(frame) && entities_party_matches(frame));
    assert(entities_actor(2,102)==entity_test_players[2]);
    assert(entities_actor(3,103)==entity_test_players[3]);
    frame->sequence=2;
    assert(entities_bind(frame) && entities_party_matches(frame));

    char *from=entity_test_players[0],*to=entity_test_players[2];
    frame->actors[0].player=-1;
    frame->actors[0].party_slot=2;
    frame->actors[2].player=0;
    frame->actors[2].party_slot=0;
    assert(entities_bind(frame));
    assert(!entities_party_matches(frame));
    assert(entities_actor(0,100)==from && entities_actor(2,102)==to);
    assert(entities_slot(from)==0 && entities_generation(from)==100);
    assert(entities_slot(to)==2 && entities_generation(to)==102);
    entity_test_players[0]=to;
    entity_test_players[2]=from;
    from[0x55]=2;
    to[0x55]=0;
    assert(entities_bind(frame) && entities_party_matches(frame));
    assert(entities_actor(0,100)==from && entities_actor(2,102)==to);
    frame->actors[0].player=0;
    frame->actors[0].party_slot=0;
    frame->actors[2].player=-1;
    frame->actors[2].party_slot=2;
    assert(entities_bind(frame) && !entities_party_matches(frame));
    entity_test_players[0]=from;
    entity_test_players[2]=to;
    from[0x55]=0;
    to[0x55]=2;
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

    entities_reset_bindings();
    prepare_party(frame);
    const uint32_t allocated=1;
    char *reserve=entity_test_players[3];
    memcpy(reserve+0x50,&allocated,sizeof(allocated));
    --frame->actor_count;
    assert(entities_collect_dormant_party(frame));
    assert(frame->dormant_party[3]==139);
    assert(entities_bind(frame) && entities_party_matches(frame));
    entity_test_players[3]=NULL;
    assert(!entities_party_matches(frame));
    entity_test_players[3]=reserve;
    ++frame->dormant_party[3];
    assert(!entities_party_matches(frame));
    --frame->dormant_party[3];
    reserve[0x55]=2;
    assert(!entities_party_matches(frame) && !entities_collect_dormant_party(frame));
    reserve[0x55]=3;
    const uint32_t active=3;
    memcpy(reserve+0x50,&active,sizeof(active));
    assert(!entities_party_matches(frame));
    ++frame->actor_count;
    assert(entities_collect_dormant_party(frame) && frame->dormant_party[3]==0);
    assert(entities_bind(frame) && entities_party_matches(frame));

    const int16_t replacement_character=200;
    memcpy(entity_test_players[0]+0xdc0,&replacement_character,sizeof(replacement_character));
    assert(!entities_bind(frame));
    assert(!entities_actor(0,100));

    free(frame);
    free(entity_test_pool);
    return 0;
}
