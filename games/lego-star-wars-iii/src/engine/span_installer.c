#include "span_installer.h"
#include <string.h>
static int protect(SpanInstaller*s,void*p,SIZE_T n,DWORD mode,DWORD*old){return s->ops.protect?s->ops.protect(s->ops.context,p,n,mode,old):VirtualProtect(p,n,mode,old);}
static int flush(SpanInstaller*s,const void*p,SIZE_T n){return s->ops.flush?s->ops.flush(s->ops.context,p,n):FlushInstructionCache(GetCurrentProcess(),p,n);}
static int write_bytes(SpanInstaller*s,void*p,const void*b,SIZE_T n){if(s->ops.write)return s->ops.write(s->ops.context,p,b,n);memcpy(p,b,n);return 1;}
static int equal(SpanInstaller*s,const void*p,const void*b,SIZE_T n){return s->ops.equal?s->ops.equal(s->ops.context,p,b,n):!memcmp(p,b,n);}
static int overlap(uintptr_t a,SIZE_T an,uintptr_t b,SIZE_T bn){return an&&bn&&a<b+bn&&b<a+an;}
static int readable(const void*p,SIZE_T n){MEMORY_BASIC_INFORMATION m;if(!p||!n||(uintptr_t)p+n<(uintptr_t)p||!VirtualQuery(p,&m,sizeof m)||m.State!=MEM_COMMIT||(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)))return 0;return (uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;}
static void*slot_read(SpanInstaller*s){void*p=*s->slot;MemoryBarrier();return p;}
static int schema(SpanInstaller*s){if(!s->slot||((uintptr_t)s->slot&3)||!readable((const void*)s->slot,sizeof(void*)))return 0;SYSTEM_INFO info;GetSystemInfo(&info);uintptr_t page=(uintptr_t)s->code_page;if(!page||s->code_size!=info.dwPageSize||page%info.dwPageSize||!readable(s->code_page,s->code_size))return 0;
 if(s->forbidden_size&&(!s->forbidden||!readable(s->forbidden,s->forbidden_size)||(uintptr_t)s->forbidden+s->forbidden_size<(uintptr_t)s->forbidden))return 0;
 for(unsigned i=0;i<4;++i){SpanPatch*p=&s->sites[i];uintptr_t a=(uintptr_t)p->address;if(p->length<5||p->length>8||a<page||a+p->length<a||a+p->length>page+s->code_size||overlap(a,p->length,(uintptr_t)s->forbidden,s->forbidden_size))return 0;for(unsigned j=0;j<i;++j)if(overlap(a,p->length,(uintptr_t)s->sites[j].address,s->sites[j].length))return 0;}
 return 1;
}
static int all_bytes(SpanInstaller*s,int installed){for(unsigned i=0;i<4;++i){SpanPatch*p=&s->sites[i];if(!equal(s,p->address,installed?p->replacement:p->original,p->length))return 0;}return 1;}
static int qualified(SpanInstaller*s,const SpanQualification*q){return q&&q->generation==s->generation&&q->thread&&q->thread==GetCurrentThreadId()&&q->thread==s->main_thread&&q->caller_verified&&q->quiescent&&q->owner_configured;}
static void fail(SpanInstaller*s,unsigned phase,int terminal){InterlockedExchange(&s->ready,0);s->failure_phase=phase;if(terminal)s->terminal=1;InterlockedExchange(&s->state,SPAN_FAILED);}
int span_installer_bootstrap(SpanInstaller*s,unsigned owner_configured){if(!s||!owner_configured)return SPAN_INSTALL_DEFER;if(InterlockedCompareExchange(&s->busy,1,0))return SPAN_INSTALL_DEFER;int result=SPAN_INSTALL_ERROR;DWORD old,ignored;void*seen;
 if(s->terminal||!s->slot||((uintptr_t)s->slot&3)||!s->original_target||!s->owner_target||s->owner_target==s->original_target||!readable((const void*)s->slot,sizeof(void*))){fail(s,1,0);goto done;}
 seen=slot_read(s);
 if(seen==s->owner_target&&s->state>=SPAN_BOOTSTRAPPED&&s->state<=SPAN_READY){result=SPAN_INSTALL_OK;goto done;}
 if(seen!=s->original_target){fail(s,2,0);goto done;}
 InterlockedExchange(&s->ready,0);
 if(!protect(s,(void*)s->slot,sizeof(void*),PAGE_READWRITE,&old)){fail(s,3,0);goto done;}
 seen=InterlockedCompareExchangePointer(s->slot,s->owner_target,s->original_target);
 if(seen!=s->original_target){int restored=protect(s,(void*)s->slot,sizeof(void*),old,&ignored);fail(s,4,!restored);goto done;}
 if(!protect(s,(void*)s->slot,sizeof(void*),old,&ignored)){
  int rollback=InterlockedCompareExchangePointer(s->slot,s->original_target,s->owner_target)==s->owner_target;
  int restored=protect(s,(void*)s->slot,sizeof(void*),old,&ignored);fail(s,5,!rollback||!restored);goto done;
 }
 InterlockedExchange(&s->state,SPAN_BOOTSTRAPPED);result=SPAN_INSTALL_OK;
 done:InterlockedExchange(&s->busy,0);return result;
}
int span_installer_code(SpanInstaller*s,const SpanQualification*q){if(!s||!qualified(s,q))return SPAN_INSTALL_DEFER;if(InterlockedCompareExchange(&s->busy,1,0))return SPAN_INSTALL_DEFER;int result=SPAN_INSTALL_ERROR,protected=0;DWORD old=0,ignored;unsigned phase=0;
 if(s->terminal||!schema(s)||slot_read(s)!=s->owner_target){fail(s,10,0);goto done;}
 if(s->state==SPAN_INSTALLED||s->state==SPAN_READY){if(all_bytes(s,1)){result=SPAN_INSTALL_OK;goto done;}fail(s,11,1);goto done;}
 if(s->state!=SPAN_BOOTSTRAPPED||!all_bytes(s,0)){fail(s,12,0);goto done;}
 InterlockedExchange(&s->ready,0);InterlockedExchange(&s->state,SPAN_INSTALLING);s->rollback_verified=0;
 if(!protect(s,s->code_page,s->code_size,PAGE_EXECUTE_READWRITE,&old)){fail(s,13,0);goto done;}protected=1;
 for(unsigned i=0;i<4;++i){SpanPatch*p=&s->sites[i];if(!write_bytes(s,p->address,p->replacement,p->length)){phase=20+i;goto rollback;}}
 if(!all_bytes(s,1)){phase=24;goto rollback;}
 if(!flush(s,s->code_page,s->code_size)){phase=25;goto rollback;}
 if(!protect(s,s->code_page,s->code_size,old,&ignored)){phase=26;goto rollback;}protected=0;
 InterlockedExchange(&s->state,SPAN_INSTALLED);result=SPAN_INSTALL_OK;goto done;
 rollback:{int ok=1;if(!protected){if(!protect(s,s->code_page,s->code_size,PAGE_EXECUTE_READWRITE,&ignored))ok=0;else protected=1;}
  if(protected){for(unsigned i=0;i<4;++i){SpanPatch*p=&s->sites[i];if(!write_bytes(s,p->address,p->original,p->length))ok=0;}if(!all_bytes(s,0))ok=0;if(!flush(s,s->code_page,s->code_size))ok=0;if(!protect(s,s->code_page,s->code_size,old,&ignored))ok=0;else protected=0;}
  s->rollback_verified=ok;fail(s,phase,!ok);
 }
 done:InterlockedExchange(&s->busy,0);return result;
}
int span_installer_confirm(SpanInstaller*s,const SpanQualification*q){if(!s||!qualified(s,q)||!q->main_confirmed)return SPAN_INSTALL_DEFER;if(InterlockedCompareExchange(&s->busy,1,0))return SPAN_INSTALL_DEFER;int result=SPAN_INSTALL_ERROR;
 if(!s->terminal&&(s->state==SPAN_INSTALLED||s->state==SPAN_READY)&&schema(s)&&slot_read(s)==s->owner_target&&all_bytes(s,1)){InterlockedExchange(&s->state,SPAN_READY);InterlockedExchange(&s->ready,1);result=SPAN_INSTALL_OK;}else fail(s,30,1);
 InterlockedExchange(&s->busy,0);return result;
}

