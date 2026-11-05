#include <math.h>
#include <string.h>
#include "steering_sync.h"
static int finite_bits(uint32_t bits){float value;memcpy(&value,&bits,4);return isfinite(value);}
static int source_valid(const SyncSteeringSource *s){
 if(s->path!=1 || s->role_mask&~0xa00u || s->life_54>255 || s->c84_mask&~0x104000u || s->c7c_block>1 || s->byte_110a>255 ||
 s->action>65535 || s->c00_present>1 || s->provider_190_bit>1 || s->source_has_base>1 || (!s->source_has_base && s->source_base_heading) ||
 s->source_previous_heading>65535 || s->source_last_heading>65535 || s->actor_76>65535 || s->actor_1c8_mask>1 ||
 s->derived_c7c_bit>1 || s->join_action>65535 || s->substate_2fa>255 || s->alternate_motion>1 || s->resource_d8_bit>1)return 0;
 const uint32_t fields[]={s->source_previous_magnitude,s->source_last_magnitude,s->override_c44,s->override_c48,s->lock_10d8,
 s->resource_speed[0],s->resource_speed[1],s->resource_speed[2],s->resource_speed[3]};
 for(unsigned i=0;i<sizeof(fields)/sizeof(fields[0]);++i)if(!finite_bits(fields[i]))return 0;
 return 1;
}
int steering_entry_valid(const SyncSteering *entry) {
    if (!entry || !source_valid(&entry->source) || entry->slot>=SYNC_MAX_ACTORS || !entry->generation || entry->character<0 || entry->character>=4096 ||
        entry->has_base>1 || (!entry->has_base && entry->base_heading) || entry->heading>65535 || entry->previous_heading>65535 || entry->last_heading>65535 ||
        !entry->period || entry->period>255 || entry->phase>255 || !isfinite(entry->elapsed) || entry->elapsed<0 ||
        !isfinite(entry->magnitude) || entry->magnitude<0 || !isfinite(entry->direction[0]) || !isfinite(entry->direction[1]) ||
        !isfinite(entry->previous_magnitude) || entry->previous_magnitude<0 || !isfinite(entry->last_magnitude) || entry->last_magnitude<0) return 0;
    for (unsigned i=0;i<3;++i) if (!isfinite(entry->origin[i])) return 0;
    return 1;
}
void steering_journal_begin(SteeringJournal *journal,SyncFrame *frame,int host) {
    *journal=(SteeringJournal){.frame=frame,.host=host};
    if(host)frame->steering_count=frame->steering_reserved=0;
}
int steering_journal_record(SteeringJournal *journal,const SyncSteering *entry) {
    if(journal->failed || !journal->host || journal->frame->steering_count>=SYNC_MAX_ACTORS || !steering_entry_valid(entry)) {journal->failed=4;return 0;}
    journal->frame->steering[journal->frame->steering_count++]=*entry;return 1;
}
const SyncSteering *steering_journal_peek(const SteeringJournal *journal) {
    return !journal->failed && journal->cursor<journal->frame->steering_count ? journal->frame->steering+journal->cursor : 0;
}
int steering_journal_validate(SteeringJournal *journal,const SyncSteering *entry,int owner_matches,const SyncSteering *local) {
    if(journal->failed)return 0;
    if(!entry || entry!=steering_journal_peek(journal)){journal->failed=3;return 0;}
    if(!owner_matches){journal->failed=1;return 0;}
    if(!steering_entry_valid(entry) || !steering_entry_valid(local)){journal->failed=4;return 0;}
    if(entry->has_base!=local->has_base || entry->base_heading!=local->base_heading){journal->failed=5;return 0;}
    if(entry->period!=local->period || entry->phase!=local->phase || memcmp(&entry->elapsed,&local->elapsed,4)){journal->failed=6;return 0;}
    if(entry->previous_heading!=local->previous_heading || entry->last_heading!=local->last_heading ||
       memcmp(&entry->previous_magnitude,&local->previous_magnitude,4) || memcmp(&entry->last_magnitude,&local->last_magnitude,4)){journal->failed=7;return 0;}
    if(memcmp(&entry->source,&local->source,sizeof(entry->source))){journal->failed=9;return 0;}
    const SyncSteeringSource *s=&entry->source;
    int positive_lock=!(s->lock_10d8&0x80000000u) && (s->lock_10d8&0x7fffffffu);
    int action_exit=s->join_action==0x37 || s->join_action==0x35 || (s->join_action==0x74 && !s->substate_2fa);
    int blocked=s->c7c_block || s->byte_110a==1 || (s->action==0x16 && !(s->c84_mask&0x100000)) || s->c00_present || positive_lock || action_exit;
    if(blocked && (entry->heading!=local->heading || memcmp(&entry->magnitude,&local->magnitude,12))){journal->failed=11;return 0;}
    ++journal->cursor;return 1;
}
int steering_journal_finish(const SteeringJournal *journal) {return !journal->failed && (journal->host || journal->cursor==journal->frame->steering_count);}
