static void outcome(const ModelInputFrameLease *op){
 if(!op_live(op))return;
 if(!clonewars_model_input_first_correction[0] || clonewars_model_input_first_outcome.committed || clonewars_model_input_first_correction[0]!=journal.frame->epoch || clonewars_model_input_first_correction[1]!=journal.frame->sequence)return;
 ModelInputOutcome r={.hero_role=UINT32_MAX};r.sequence=journal.frame->sequence;r.ordinal=clonewars_model_input_first_correction[2];r.slot=clonewars_model_input_first_correction[3];r.generation=clonewars_model_input_first_correction[4];
 r.actor_local=first_actor;r.controller_local=first_controller;r.clock=global_word(0xfb4b6c);LARGE_INTEGER q;QueryPerformanceCounter(&q);r.qpc[0]=q.LowPart;r.qpc[1]=q.HighPart;
 unsigned char *p=(void *)(uintptr_t)first_actor,*c=(void *)(uintptr_t)first_controller;
 if(!valid(p,0x1440) || !valid(c,0x60))r.reason=1;
 else if((read32(p+0x50)&3)!=3 || !first_local_generation || entities_observed_generation(p)!=first_local_generation)r.reason=2;
 else if(!op_live(op))return;
 else if(*(void **)(p+0x6cc)!=c)r.reason=3;
 else{r.valid=1;r.actor_heading=read16(p+0x6c);r.controller_heading=read16(c+0x26);r.magnitude=read32(c+0x28);r.direction[0]=read32(c+0x2c);r.direction[1]=read32(c+0x30);
  r.previous_heading=read16(c+0x5a);r.previous_magnitude=read32(c+0x38);r.last_heading=read16(c+0x5e);r.last_magnitude=read32(c+0x34);r.action=read16(p+0x2f4);r.substate=p[0x2fa];r.clip=read16(p+0x2e8);r.timer=read32(p+0x2a0);r.life_54=p[0x54];r.flags_50=read32(p+0x50);r.hero_role=p==hero(0)?0:p==hero(1)?1:UINT32_MAX;memcpy(r.position,p+0x24,12);}
 if(!op_live(op))return;
 memcpy((void *)&clonewars_model_input_first_outcome,&r,sizeof(r));MemoryBarrier();clonewars_model_input_first_outcome.committed=journal.frame->epoch;
}
