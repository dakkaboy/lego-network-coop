#undef NDEBUG
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../src/sync/reaction_sync.h"
static SyncFrame frame;
int main(void) {
    SyncReactionChoice clip={.slot=3,.generation=8,.character=321,.old_action=20,.kind=SYNC_REACTION_CLIP,.clip=-1,.source_id=77,.hit={.completed=1,.health_before=4,.health_after=3,.life_before=3,.life_after=3}};
    const SyncReactionHitOutcome actual=clip.hit;
    SyncReactionChoice draw=clip;draw.kind=SYNC_REACTION_DAMAGE_DRAW;draw.damage_draw=100;memset(&draw.hit,0,sizeof draw.hit);
    ReactionJournal host,client;
    reaction_journal_begin(&host,&frame,1);assert(reaction_journal_record(&host,&draw));assert(reaction_journal_record(&host,&clip));
    reaction_journal_begin(&client,&frame,0);
    assert(!reaction_journal_complete_no_clip(&client,0,3,8,77,&actual));assert(client.cursor==0&&!reaction_journal_finish(&client));
    client.cursor=1;
    assert(!reaction_journal_complete_no_clip(&client,0,4,8,77,&actual));
    assert(!reaction_journal_complete_no_clip(&client,0,3,9,77,&actual));
    assert(!reaction_journal_complete_no_clip(&client,0,3,8,78,&actual));assert(client.cursor==1);
    assert(reaction_journal_complete_no_clip(&client,0,3,8,77,&actual));assert(client.cursor==2&&reaction_journal_finish(&client));
    assert(frame.reactions[client.cursor-1].source_id==77&&frame.reactions[client.cursor-1].clip==-1);
    assert(reaction_journal_record(&host,&clip));
    assert(!reaction_journal_complete_no_clip(&client,0,3,8,77,&actual));assert(client.cursor==2);
    assert(reaction_journal_complete_no_clip(&client,2,3,8,77,&actual));assert(client.cursor==3);
    reaction_journal_begin(&host,&frame,1);assert(reaction_journal_record(&host,&clip));assert(reaction_journal_record(&host,&clip));
    reaction_journal_begin(&client,&frame,0);uint32_t selected=12;
    assert(reaction_journal_apply(&client,reaction_journal_peek(&client),1,20,77,1,&selected));assert(selected==UINT32_MAX);
    assert(!reaction_journal_complete_no_clip(&client,0,3,8,77,&actual));assert(client.cursor==1);
    frame.reactions[1].clip=5;memset(&frame.reactions[1].hit,0,sizeof frame.reactions[1].hit);
    assert(!reaction_journal_complete_no_clip(&client,1,3,8,77,&actual));assert(!reaction_journal_finish(&client));
    frame.reactions[1]=clip;frame.reactions[1].source_id=0;frame.reactions[1].arena_attacker_slot=2;frame.reactions[1].arena_attacker_generation=9;memset(&frame.reactions[1].hit,0,sizeof frame.reactions[1].hit);
    assert(!reaction_journal_complete_no_clip(&client,1,3,8,77,&actual));assert(!reaction_journal_complete_no_clip(&client,1,3,8,0,&actual));
    frame.reactions[1]=clip;client.failed=1;assert(!reaction_journal_complete_no_clip(&client,1,3,8,77,&actual));
    client.failed=0;assert(!reaction_journal_complete_no_clip(&client,2,3,8,77,&actual));
    client.cursor=1;frame.reactions[1]=clip;
    SyncReactionHitOutcome wrong=actual;wrong.health_after=2;
    assert(reaction_journal_complete_no_clip(&client,1,3,8,77,&wrong)==-1);assert(client.cursor==1&&client.failed==11);
    client.failed=0;wrong=actual;wrong.timer_before=0.1f;
    assert(reaction_journal_complete_no_clip(&client,1,3,8,77,&wrong)==-1);assert(client.cursor==1);
    client.failed=0;wrong=actual;wrong.timer_after=NAN;
    assert(reaction_journal_complete_no_clip(&client,1,3,8,77,&wrong)==-1);assert(client.cursor==1);
    client.failed=0;wrong=actual;wrong.life_after=0;wrong.health_after=0;wrong.action_after=0;wrong.timer_after=0;
    frame.reactions[1].hit=wrong;assert(reaction_journal_complete_no_clip(&client,1,3,8,77,&wrong)==1);
    puts("Native no-animation receipts require the completed victim/source, preserve duplicate-hit evidence, and cannot consume draws, animations or arena hits.");
}
