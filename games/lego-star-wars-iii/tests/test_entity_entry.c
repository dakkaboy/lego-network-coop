#undef NDEBUG
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include "sync/entity_sync.h"
#include "sync/entity_match.h"
#include "sync/tag_identity.h"
#include "sync/native_tick_sync.h"

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

static SyncTagIdentity operand_identity(char *actor) {
    SyncActor described={0};
    entities_describe(&described,actor);
    described.character=*(int16_t *)(actor+0xdc0);
    return (SyncTagIdentity){described.character,described.spawn_tag,described.spawn_source};
}
static void test_retiring_tag_operands(void) {
    char *saved_pool=entity_test_pool,*saved_players[8];
    memcpy(saved_players,entity_test_players,sizeof saved_players);
    entity_test_pool=calloc(ACTOR_COUNT,ACTOR_STRIDE);
    memset(entity_test_players,0,sizeof entity_test_players);
    assert(entity_test_pool);
    char *from=entity_test_pool,*duplicate=from+ACTOR_STRIDE,*to=from+2*ACTOR_STRIDE,*last=from+3*ACTOR_STRIDE;
    const uint32_t active=3,inactive=0;
    const int16_t characters[4]={329,329,189,183};
    for(int slot=0;slot<4;++slot){
        char *actor=entity_test_pool+slot*ACTOR_STRIDE;
        memcpy(actor+0xdc0,characters+slot,2);
        memcpy(actor+0x50,slot==1?&inactive:&active,4);
        actor[0x55]=-1;
    }
    entities_update();
    entities_note_spawn_source(from,0x5c5ef6,(SyncSpawnSource){1,0});
    entities_note_spawn_source(to,0x5c5ce6,(SyncSpawnSource){0xe101,2});
    entities_note_spawn_source(last,0x5c5ce6,(SyncSpawnSource){0xe101,3});
    const SyncTagIdentity from_key=operand_identity(from),to_key=operand_identity(to),last_key=operand_identity(last);
    SyncActor from_reference,to_reference,last_reference;
    assert(tag_identity_reference(&from_reference,70,900,&from_key));
    assert(tag_identity_reference(&to_reference,71,901,&to_key));
    assert(tag_identity_reference(&last_reference,72,902,&last_key));
    from_reference.player=to_reference.player=last_reference.player=-1;
    from_reference.party_slot=to_reference.party_slot=last_reference.party_slot=-1;
    from_reference.health=to_reference.health=last_reference.health=4;
    SyncFrame *post=calloc(1,sizeof *post);
    assert(post);
    post->sequence=2;post->actor_count=2;
    post->actors[0]=from_reference;post->actors[1]=to_reference;
    assert(entities_bind(post));
    post->actor_count=1;post->actors[0]=to_reference;
    assert(entities_bind(post));
    assert(!entities_resolve_identity(post,70,900));
    assert(entities_resolve_reference(&from_reference)==from);
    assert(entities_resolve_reference(&to_reference)==to);
    SyncActor wrong=from_reference;
    ++wrong.generation;assert(!entities_resolve_reference(&wrong));
    wrong=from_reference;
    ++wrong.character;assert(!entities_resolve_reference(&wrong));
    wrong=from_reference;++wrong.spawn_source.serial;assert(!entities_resolve_reference(&wrong));
    wrong=from_reference;++wrong.spawn_source.producer;assert(!entities_resolve_reference(&wrong));
    wrong=from_reference;++wrong.spawn_tag;assert(!entities_resolve_reference(&wrong));
    const int16_t changed=330;
    memcpy(from+0xdc0,&changed,2);entities_update();
    assert(!entities_resolve_reference(&from_reference));
    memcpy(from+0xdc0,characters,2);entities_update();
    assert(!entities_resolve_reference(&from_reference));
    entities_reset_bindings();
    assert(entities_resolve_reference(&from_reference)==from);
    memcpy(duplicate+0x50,&active,4);entities_update();
    entities_note_spawn_source(duplicate,from_key.spawn_tag,from_key.spawn_source);
    assert(!entities_resolve_reference(&from_reference));
    memcpy(duplicate+0x50,&inactive,4);entities_update();
    assert(entities_resolve_reference(&from_reference)==from);
    SyncTagIdentity missing_source=to_key;missing_source.spawn_source=(SyncSpawnSource){0};
    SyncActor unsupported;
    assert(tag_identity_reference(&unsupported,71,901,&missing_source));
    assert(!entities_resolve_reference(&unsupported));
    assert(!tag_identity_reference(&unsupported,-1,901,&to_key));
    assert(!tag_identity_reference(&unsupported,SYNC_MAX_ACTORS,901,&to_key));
    assert(!tag_identity_reference(&unsupported,71,0,&to_key));
    SyncTagIdentity invalid=to_key;invalid.character=-1;
    assert(!tag_identity_reference(&unsupported,71,901,&invalid));
    invalid.character=4096;assert(!tag_identity_reference(&unsupported,71,901,&invalid));
    /* A nested command may use the first target after the first source has retired. */
    post->actor_count=1;post->actors[0]=last_reference;
    memcpy(from+0x50,&inactive,4);entities_update();
    assert(!entities_resolve_reference(&from_reference));
    assert(!entities_resolve_identity(post,71,901));
    assert(entities_resolve_reference(&to_reference)==to);
    assert(entities_resolve_reference(&last_reference)==last);
    memcpy(to+0x50,&inactive,4);entities_update();
    assert(!entities_resolve_reference(&to_reference));
    assert(entities_resolve_reference(&last_reference)==last);
    free(post);free(entity_test_pool);
    entity_test_pool=saved_pool;
    memcpy(entity_test_players,saved_players,sizeof saved_players);
    entities_update();
}
static void test_last_native_weapon_command(void) {
    char *saved_pool=entity_test_pool,*saved_players[8];
    memcpy(saved_players,entity_test_players,sizeof saved_players);
    entity_test_pool=calloc(ACTOR_COUNT,ACTOR_STRIDE);assert(entity_test_pool);
    memset(entity_test_players,0,sizeof entity_test_players);
    char *actor=entity_test_pool;const uint32_t active=3,inactive=0;const int16_t character=381;
    memcpy(actor+0x50,&active,4);memcpy(actor+0xdc0,&character,2);actor[0x55]=-1;
    entities_update();entities_note_spawn_source(actor,123,(SyncSpawnSource){1,2});
    SyncFrame *post=calloc(1,sizeof *post);assert(post);post->sequence=2;post->actor_count=1;
    entities_describe(post->actors,actor);post->actors[0].slot=70;post->actors[0].generation=900;
    post->actors[0].player=post->actors[0].party_slot=-1;post->actors[0].health=2;post->actors[0].character=character;
    const SyncActor original=post->actors[0];assert(entities_bind(post));
    post->actor_count=0;post->tick_gate_count=3;
    post->tick_gates[0]=(SyncTickGate){NATIVE_TICK_WEAPON_COMMAND_ACTOR,100,70};
    post->tick_gates[1]=(SyncTickGate){NATIVE_TICK_WEAPON_COMMAND_GENERATION,100,900};
    post->tick_gates[2]=(SyncTickGate){NATIVE_TICK_WEAPON_COMMAND_VALUE,100,0xfffefe03};
    assert(entities_bind_tick(post) && entities_actor(70,900)==actor && entities_generation(actor)==900);
    post->tick_gate_count=2;assert(!entities_bind_tick(post) && entities_actor(70,900)==actor);
    post->tick_gate_count=3;
    assert(entities_bind(post) && !entities_actor(70,900) && !entities_generation(actor));
    post->actors[0]=original;post->actor_count=1;assert(entities_bind(post));
    post->actors[0].generation=901;
    assert(entities_bind_tick(post) && entities_actor(70,900)==actor && !entities_actor(70,901));
    memcpy(actor+0x50,&inactive,4);entities_update();
    memcpy(actor+0x50,&active,4);entities_update();entities_note_spawn_source(actor,123,(SyncSpawnSource){1,2});
    assert(entities_bind(post) && entities_actor(70,901)==actor && !entities_actor(70,900));
    memcpy(actor+0x50,&inactive,4);entities_update();post->actor_count=0;
    assert(entities_bind_tick(post) && !entities_actor(70,900));
    char *newborn=entity_test_pool+2*ACTOR_STRIDE;const int16_t newborn_character=357;
    post->actor_count=1;post->actors[0]=original;post->actors[0].slot=72;post->actors[0].generation=904;
    post->actors[0].character=newborn_character;post->actors[0].spawn_source=(SyncSpawnSource){5,3};
    assert(!entities_bind(post));assert(!entities_bind_native_actor(post,newborn));
    memcpy(newborn+0x50,&active,4);memcpy(newborn+0xdc0,&newborn_character,2);newborn[0x55]=-1;
    entities_update();entities_note_spawn_source(newborn,original.spawn_tag,(SyncSpawnSource){5,3});
    post->actor_count=2;post->actors[1]=post->actors[0];post->actors[1].slot=73;
    assert(!entities_bind_native_actor(post,newborn));post->actor_count=1;
    assert(entities_bind_native_actor(post,newborn) && entities_actor(72,904)==newborn && entities_generation(newborn)==904);
    memcpy(newborn+0x50,&inactive,4);entities_update();assert(!entities_bind_native_actor(post,newborn));
    free(post);free(entity_test_pool);entity_test_pool=saved_pool;
    memcpy(entity_test_players,saved_players,sizeof saved_players);entities_update();
}
static void test_cold_tag_binding(void) {
    char *saved_pool=entity_test_pool,*saved_players[8];
    memcpy(saved_players,entity_test_players,sizeof saved_players);
    entity_test_pool=calloc(ACTOR_COUNT,ACTOR_STRIDE);
    memset(entity_test_players,0,sizeof entity_test_players);
    assert(entity_test_pool);
    const int16_t characters[4]={329,330,189,183};
    for(int slot=0;slot<4;++slot){
        char *actor=entity_test_pool+slot*ACTOR_STRIDE;
        *(uint32_t *)(actor+0x50)=3;*(int16_t *)(actor+0xdc0)=characters[slot];
        actor[0x55]=slot<2?(char)slot:-1;
    }
    entity_test_players[0]=entity_test_pool;entity_test_players[1]=entity_test_pool+ACTOR_STRIDE;
    entities_update();
    for(unsigned slot=0;slot<4;++slot)
        entities_note_spawn_source(entity_test_pool+slot*ACTOR_STRIDE,slot<2?0x5c5ef6:0x5c5ce6,
            (SyncSpawnSource){slot<2?1:2,slot%2});
    SyncFrame *frame=calloc(1,sizeof *frame);assert(frame);
    frame->sequence=1;frame->actor_count=2;frame->tag_count=2;
    for(unsigned i=0;i<2;++i){
        unsigned source=1-i,target=2+i;
        SyncTag *tag=frame->tags+i;
        *tag=(SyncTag){.id=i+1,.from=(int32_t)source,.to=(int32_t)target,
            .from_generation=100+source,.to_generation=100+target,
            .from_identity=operand_identity(entity_test_pool+source*ACTOR_STRIDE),
            .to_identity=operand_identity(entity_test_pool+target*ACTOR_STRIDE)};
        SyncActor *post=frame->actors+i;
        assert(tag_identity_reference(post,(int32_t)target,100+target,&tag->to_identity));
        post->player=post->party_slot=(int16_t)source;post->health=4;
    }
    assert(entities_bind(frame));
    for(unsigned slot=0;slot<4;++slot)
        assert(entities_actor(slot,100+slot)==entity_test_pool+slot*ACTOR_STRIDE);
    assert(!entities_party_matches(frame));
    for(unsigned slot=0;slot<2;++slot) *(uint32_t *)(entity_test_pool+slot*ACTOR_STRIDE+0x50)=0;
    entity_test_players[0]=entity_test_pool+3*ACTOR_STRIDE;entity_test_players[1]=entity_test_pool+2*ACTOR_STRIDE;
    entity_test_players[0][0x55]=0;entity_test_players[1][0x55]=1;
    assert(entities_bind(frame)&&entities_party_matches(frame));
    assert(!entities_actor(0,100)&&!entities_actor(1,101));
    assert(entities_actor(2,102)==entity_test_players[1]&&entities_actor(3,103)==entity_test_players[0]);
    frame->tags[0].from=2;frame->tags[0].from_generation=999;
    frame->tags[0].from_identity=frame->tags[0].to_identity;
    assert(entities_bind(frame));
    assert(entities_actor(2,102)==entity_test_players[1]&&!entities_actor(2,999));
    free(frame);free(entity_test_pool);entity_test_pool=saved_pool;
    memcpy(entity_test_players,saved_players,sizeof saved_players);entities_update();
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
    assert(entities_bind(frame));
    const uint32_t allocated=1;
    char *reserve=entity_test_players[3];
    memcpy(reserve+0x50,&allocated,sizeof(allocated));
    --frame->actor_count;
    assert(entities_collect_dormant_party(frame));
    assert(frame->dormant_party[3]==139);
    const uint32_t active=3;
    memcpy(reserve+0x50,&active,sizeof(active));
    assert(entities_bind(frame) && !entities_party_matches(frame));
    uint32_t slot,generation;
    assert(entities_observed_identity(reserve,&slot,&generation) && slot==3 && generation==103);
    assert(entities_resolve_reference(frame->actors+3)==reserve);
    memcpy(reserve+0x50,&allocated,sizeof(allocated));
    assert(entities_bind(frame) && entities_party_matches(frame));
    assert(!entities_observed_identity(reserve,&slot,&generation));
    entity_test_players[3]=NULL;
    assert(!entities_party_matches(frame));
    entity_test_players[3]=reserve;
    ++frame->dormant_party[3];
    assert(!entities_party_matches(frame));
    --frame->dormant_party[3];
    reserve[0x55]=2;
    assert(!entities_party_matches(frame) && !entities_collect_dormant_party(frame));
    reserve[0x55]=3;
    memcpy(reserve+0x50,&active,sizeof(active));
    assert(!entities_party_matches(frame));
    ++frame->actor_count;
    assert(entities_collect_dormant_party(frame) && frame->dormant_party[3]==0);
    assert(entities_bind(frame) && entities_party_matches(frame));

    const int16_t replacement_character=200;
    memcpy(entity_test_players[0]+0xdc0,&replacement_character,sizeof(replacement_character));
    assert(!entities_bind(frame));
    assert(!entities_actor(0,100));

    test_retiring_tag_operands();
    test_cold_tag_binding();
    test_last_native_weapon_command();

    free(frame);
    free(entity_test_pool);
    return 0;
}
