#include <string.h>
#include "model_input_sync.h"
static uint32_t bits(float value){uint32_t v;memcpy(&v,&value,4);return v;}
static int finite_bits(uint32_t v){return (v&0x7f800000u)!=0x7f800000u;}
int model_input_entry_valid(const SyncModelInput *e){
 if(!e || e->slot>=SYNC_MAX_ACTORS || !e->generation || e->character<0 || e->character>=4096 || !e->period || e->period>255 || e->phase>255 ||
 !finite_bits(bits(e->input_x)) || !finite_bits(bits(e->input_z)) || !finite_bits(bits(e->elapsed)) || ((bits(e->elapsed)&0x80000000u) && (bits(e->elapsed)&0x7fffffffu)))return 0;
 for(unsigned i=0;i<3;++i)if(!finite_bits(bits(e->origin[i])))return 0;
 const SyncModelInputContext *c=&e->context;
 if(c->actor_4c_mask==1 && (c->c7c_1000 || c->cf4_raw || c->model_42 || c->actor_309_mask || c->global_e63e14_raw || c->global_fbcb88_raw))return 0;
 if((c->role_mask&~0xa00u) || (c->role_mask&0x200) || c->life_54 || c->axis_1dd!=255 || c->provider_190_bit || c->action>65535 || c->substate_2fa>255 ||
 c->c7c_block || c->byte_110a>255 || c->byte_110a==1 || (c->c84_mask&~0x104000u) || (c->c84_mask&0x4000) ||
 (c->action==0x16 && !(c->c84_mask&0x100000)) || c->c00_present>1 || c->actor_76>65535 || c->actor_1c8_mask>1 || c->motion_alternate>1 || c->resource_d8_bit>1)return 0;
 if(c->c00_present || c->global_fc0e80 || c->actor_4c_mask>1 || c->c7c_1000>1 || c->model_42>255 || c->actor_309_mask>1 || (c->numeric_cw&~0x1f3fu) || (c->numeric_mxcsr&~0xffc0u))return 0;
 if(!finite_bits(c->cf4_raw)||!finite_bits(c->global_e63e14_raw)||!finite_bits(c->global_fbcb88_raw))return 0;
 if(!finite_bits(c->override_c44) || !finite_bits(c->override_c48))return 0;
 for(unsigned i=0;i<4;++i)if(!finite_bits(c->resource_speed[i]))return 0;
 return 1;
}
void model_input_journal_begin(ModelInputJournal *j,SyncFrame *frame,int host){*j=(ModelInputJournal){.frame=frame,.host=host};if(host)frame->model_input_count=frame->model_input_reserved=0;}
int model_input_journal_record(ModelInputJournal *j,const SyncModelInput *e){
 if(j->failed || !j->host || j->frame->model_input_count>=SYNC_MAX_ACTORS || !model_input_entry_valid(e)){j->failed=4;return 0;}
 j->frame->model_inputs[j->frame->model_input_count++]=*e;return 1;
}
const SyncModelInput *model_input_journal_peek(const ModelInputJournal *j){return !j->failed && j->cursor<j->frame->model_input_count?j->frame->model_inputs+j->cursor:0;}
int model_input_journal_validate(ModelInputJournal *j,const SyncModelInput *e,int owner_matches,const SyncModelInput *local){
 if(j->failed)return 0;
 if(!e || e!=model_input_journal_peek(j)){j->failed=3;return 0;}
 if(!owner_matches){j->failed=1;return 0;}
 if(!model_input_entry_valid(e) || !model_input_entry_valid(local)){j->failed=4;return 0;}
 if(e->native_clock!=local->native_clock || e->period!=local->period || e->phase!=local->phase || memcmp(&e->elapsed,&local->elapsed,4)){j->failed=6;return 0;}
 if(memcmp(&e->context,&local->context,sizeof(e->context))){j->failed=9;return 0;}
 ++j->cursor;return 1;
}
int model_input_journal_finish(const ModelInputJournal *j){return !j->failed && (j->host || j->cursor==j->frame->model_input_count);}
