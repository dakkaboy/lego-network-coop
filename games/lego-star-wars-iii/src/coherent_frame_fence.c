#include <windows.h>
#include "coherent_frame_fence.h"
static volatile LONG main_thread,release_serial=1,disabled,pending_reasons;
static __thread CoherentFrameToken current;
static __thread uint32_t active,phase,next_nonce;
static uint32_t load(volatile LONG *p){return (uint32_t)InterlockedCompareExchange(p,0,0);}
static int main_now(void){return load(&main_thread)==GetCurrentThreadId();}
uint32_t coherent_frame_release(void){return load(&release_serial);}
uint32_t coherent_frame_pending_reasons(void){return load(&pending_reasons);}
void coherent_frame_cancel_atomic(uint32_t why){
 InterlockedOr(&pending_reasons,(LONG)why);
 for(;;){
  uint32_t prior=load(&release_serial);
  if(prior==UINT32_MAX){InterlockedExchange(&disabled,1);return;}
  if(load(&disabled))return;
  if((uint32_t)InterlockedCompareExchange(&release_serial,(LONG)(prior+1u),(LONG)prior)==prior)return;
 }
}
int coherent_frame_register_main(void){
 DWORD error=GetLastError(),thread=GetCurrentThreadId();
 LONG prior=InterlockedCompareExchange(&main_thread,(LONG)thread,0);
 SetLastError(error);return !prior||(DWORD)prior==thread;
}
static int same(const CoherentFrameToken *a,const CoherentFrameToken *b){
 return a->owner==b->owner&&a->owner_nonce==b->owner_nonce&&a->cohort_nonce==b->cohort_nonce&&a->thread==b->thread&&a->release==b->release&&a->epoch==b->epoch&&a->sequence==b->sequence&&a->frame==b->frame;
}
static int metadata(const CoherentFrameToken *t,uint32_t phases){
 if(!t||load(&disabled)||!main_now()||!active||!t->cohort_nonce||!t->epoch||!t->sequence||!t->frame)return 0;
 if(!same(t,&current)||t->thread!=GetCurrentThreadId()||coherent_frame_release()!=t->release)return 0;
 if(phase<COHERENT_PREPARE||phase>COHERENT_PUBLISH||!(phases&COHERENT_PHASE_BIT(phase)))return 0;
 return native_owner_scope_valid(t->owner,t->owner_nonce)&&coherent_frame_release()==t->release&&!load(&disabled);
}
static int valid(const CoherentFrameToken *t,uint32_t phases){
 if(!metadata(t,phases))return 0;
 const volatile uint32_t *frame=t->frame;
 uint32_t epoch=frame[0],sequence=frame[1];
 return epoch==t->epoch&&sequence==t->sequence&&metadata(t,phases);
}
int coherent_frame_valid(const CoherentFrameToken *t,uint32_t phases){
 DWORD e=GetLastError();int result=valid(t,phases);SetLastError(e);return result;
}
int coherent_frame_open(CoherentFrameToken *out,NativeOwnerScope *owner,uint32_t nonce,const void *frame,uint32_t epoch,uint32_t sequence,uint32_t release){
 DWORD e=GetLastError();int result=0;
 if(!out||load(&disabled)||!main_now()||active||!frame||!epoch||!sequence||!nonce||coherent_frame_release()!=release||!native_owner_scope_valid(owner,nonce))goto done;
 if(!++next_nonce){InterlockedExchange(&disabled,1);goto done;}
 CoherentFrameToken t={owner,nonce,next_nonce,GetCurrentThreadId(),release,epoch,sequence,frame};
 current=t;phase=COHERENT_PREPARE;active=1;
 if(!valid(&t,COHERENT_PHASE_BIT(COHERENT_PREPARE))){active=0;goto done;}
 *out=t;result=1;
 done:SetLastError(e);return result;
}
int coherent_frame_get(CoherentFrameToken *out,uint32_t phases){
 DWORD e=GetLastError();int result=0;
 if(out&&main_now()&&active){CoherentFrameToken t=current;if(valid(&t,phases)){*out=t;result=valid(&t,phases);}}
 SetLastError(e);return result;
}
int coherent_frame_set_phase(const CoherentFrameToken *t,CoherentFramePhase value){
 DWORD e=GetLastError();int result=0;
 if(value>=COHERENT_PREPARE&&value<=COHERENT_PUBLISH&&(uint32_t)value>=phase&&valid(t,COHERENT_ALL_PHASES)){phase=(uint32_t)value;result=valid(t,COHERENT_PHASE_BIT(value));}
 SetLastError(e);return result;
}
int coherent_frame_close(const CoherentFrameToken *t){
 DWORD e=GetLastError();int result=0;
 /* End/unwind may run after owner publication or frame lifetime has ended. */
 if(main_now()&&active&&t&&same(t,&current)){active=0;phase=0;result=1;}
 SetLastError(e);return result;
}

#ifdef COHERENT_FRAME_FIXTURE
int coherent_frame_test_release(uint32_t value){
 if(!value||active||load(&disabled))return 0;
 InterlockedExchange(&release_serial,(LONG)value);return 1;
}
#endif
