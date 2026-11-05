#include <windows.h>
#include <string.h>
#include "native_owner_internal.h"
static volatile LONG configured,disabled,nonce,pending_fault;
static DWORD key=TLS_OUT_OF_INDEXES;
static void *target;
static NativeOwnerCallbacks callbacks;
const unsigned native_owner_default_mxcsr=0x1f80;
#ifdef NATIVE_OWNER_FIXTURE
static volatile LONG fail_set,fail_get,raise_after_set;
void native_owner_test_fail_set(unsigned ordinal){InterlockedExchange(&fail_set,(LONG)ordinal);}
void native_owner_test_nonce(unsigned value){InterlockedExchange(&nonce,(LONG)value);}
void native_owner_test_fail_get(unsigned ordinal){InterlockedExchange(&fail_get,(LONG)ordinal);}
void native_owner_test_raise_after_set(unsigned ordinal){InterlockedExchange(&raise_after_set,(LONG)ordinal);}
#endif
static unsigned error_read(void){unsigned v;__asm__ volatile("movl %%fs:52,%0":"=r"(v));return v;}
static void error_write(unsigned v){__asm__ volatile("movl %0,%%fs:52"::"r"(v));}
static void helper_environment(void){__asm__ volatile("fninit;ldmxcsr %0;cld"::"m"(native_owner_default_mxcsr):"cc");}
static void disable_publication(NativeOwnerReject why){
 InterlockedExchange(&disabled,1);InterlockedCompareExchange(&pending_fault,(LONG)why+1,0);
}
static NativeOwnerScope *checked_get(void){
 NativeOwnerScope *value;
#ifdef NATIVE_OWNER_FIXTURE
 LONG n=InterlockedCompareExchange(&fail_get,0,0);
 if(n>0&&InterlockedDecrement(&fail_get)==0){SetLastError(ERROR_INVALID_PARAMETER);value=NULL;}
 else
#endif
 {value=TlsGetValue(key);}
 if(!value&&GetLastError()!=ERROR_SUCCESS)disable_publication(OWNER_TLS_FAILURE);
 return InterlockedCompareExchange(&disabled,0,0)?NULL:value;
}
static int publish(NativeOwnerScope *scope){
#ifdef NATIVE_OWNER_FIXTURE
 LONG n=InterlockedCompareExchange(&fail_set,0,0);
 if(n>0&&InterlockedDecrement(&fail_set)==0)return 0;
#endif
 int ok=TlsSetValue(key,scope)!=0;
#ifdef NATIVE_OWNER_FIXTURE
 LONG raised=InterlockedCompareExchange(&raise_after_set,0,0);
 if(ok&&raised>0&&InterlockedDecrement(&raise_after_set)==0)RaiseException(0xe0011234,0,0,NULL);
#endif
 return ok;
}
int native_owner_configure(void *native,const NativeOwnerCallbacks *cb){
 unsigned e=error_read();int ok=0;
 if(!native||!cb||cb->version!=1||!cb->begin||!cb->end||!cb->reject)goto done;
 if(InterlockedCompareExchange(&configured,-1,0)!=0)goto done;
 key=TlsAlloc();
 if(key==TLS_OUT_OF_INDEXES){InterlockedExchange(&configured,0);goto done;}
 target=native;callbacks=*cb;InterlockedExchange(&configured,1);ok=1;
done:error_write(e);return ok;
}
NativeOwnerScope *native_owner_current(void){
 unsigned e=error_read();NativeOwnerScope *p=NULL;
 if(!InterlockedCompareExchange(&disabled,0,0)&&InterlockedCompareExchange(&configured,0,0)==1)p=checked_get();
 if(InterlockedCompareExchange(&disabled,0,0))p=NULL;
 error_write(e);return p;
}
static NativeOwnerScope *find_live(const NativeOwnerScope *candidate){
 NativeOwnerScope *p=native_owner_current();
 for(unsigned n=0;p&&n<64;++n,p=p->parent)if(p==candidate)return p;
 return NULL;
}
unsigned native_owner_scope_nonce(const NativeOwnerScope *s){
 NativeOwnerScope *p=find_live(s);unsigned result=p?p->nonce:0;
 return InterlockedCompareExchange(&disabled,0,0)?0:result;
}
int native_owner_scope_usable(const NativeOwnerScope *s){
 unsigned e=error_read();NativeOwnerScope *p=find_live(s);
 int result=p&&p->thread==GetCurrentThreadId()&&p->usable&&!InterlockedCompareExchange(&disabled,0,0);
 error_write(e);return result;
}
int native_owner_scope_valid(const NativeOwnerScope *s,unsigned token){
 unsigned e=error_read();
 NativeOwnerScope *p=native_owner_current();
 int result=p==s&&p&&p->thread==GetCurrentThreadId()&&p->usable&&token&&p->nonce==token&&!InterlockedCompareExchange(&disabled,0,0);
 error_write(e);return result;
}
OwnerU32 native_owner_scope_delegate_esp(const NativeOwnerScope *s,unsigned token){
 unsigned e=error_read();OwnerU32 result=0;
 NativeOwnerScope *p=native_owner_current();
 if(p==s&&p&&p->thread==GetCurrentThreadId()&&p->usable&&token&&p->nonce==token&&p->delegate_active){
  result=p->delegate_esp;
  if(!p->delegate_active||InterlockedCompareExchange(&disabled,0,0))result=0;
 }
 error_write(e);return result;
}
static void reject(NativeOwnerScope *s,NativeOwnerReject why){
 s->usable=0;helper_environment();s->callbacks.reject(s,s->parent,why,s->storage);helper_environment();
}
static int notify_pending(NativeOwnerScope *s){
 LONG fault=InterlockedExchange(&pending_fault,0);
 if(!fault)return 0;
 if(s)reject(s,(NativeOwnerReject)(fault-1));
 else {helper_environment();callbacks.reject(NULL,NULL,(NativeOwnerReject)(fault-1),NULL);helper_environment();}
 return 1;
}
int native_owner_poll_fault(void){
 unsigned e=error_read();unsigned char fx[512] __attribute__((aligned(16)));
 __asm__ volatile("fxsave %0":"=m"(fx));int result=notify_pending(NULL);
 __asm__ volatile("fxrstor %0"::"m"(fx));error_write(e);return result;
}
void owner_enter(NativeOwnerScope *s){
 s->target=target;s->callbacks=callbacks;
 s->parent=NULL;s->nonce=0;s->thread=GetCurrentThreadId();s->depth=1;
 s->linked=s->usable=s->begin_entered=s->end_done=0;memset(s->storage,0,sizeof(s->storage));
 s->delegate_esp=s->delegate_active=0;
 if(InterlockedCompareExchange(&disabled,0,0)){if(!notify_pending(s))reject(s,OWNER_TLS_FAILURE);return;}
 s->parent=native_owner_current();s->depth=s->parent?s->parent->depth+1:1;
 if(InterlockedCompareExchange(&disabled,0,0)){if(!notify_pending(s))reject(s,OWNER_TLS_FAILURE);return;}
 LONG next=InterlockedIncrement(&nonce);
 if(!next){disable_publication(OWNER_NONCE_EXHAUSTED);notify_pending(s);return;}
 s->nonce=(unsigned)next;
 s->linked=1;
 if(!publish(s)){disable_publication(OWNER_TLS_FAILURE);notify_pending(s);return;}
 s->usable=s->depth<=8;
 if(!s->usable)reject(s,OWNER_DEPTH_BARRIER);
 if(InterlockedCompareExchange(&disabled,0,0)){if(!notify_pending(s))reject(s,OWNER_TLS_FAILURE);return;}
 NativeOwnerInput input={s->in_fx,s->in_regs,s->in_error,s->entry_esp};
 s->begin_entered=1;helper_environment();s->callbacks.begin(s,&input,s->storage);helper_environment();
 notify_pending(s);
}
void owner_leave(NativeOwnerScope *s,int unwind){
 unsigned e=error_read();
 s->delegate_active=0;
 helper_environment();
 if(s->end_done)goto done;
 s->end_done=1;
 notify_pending(s);
 if(s->begin_entered){s->callbacks.end(s,unwind?OWNER_UNWIND:OWNER_NORMAL,s->storage);helper_environment();}
 if(s->linked){
  if(InterlockedCompareExchange(&disabled,0,0)||!publish(s->parent)){
   disable_publication(OWNER_TLS_FAILURE);notify_pending(s);
  }
  s->linked=0;
 }
done:helper_environment();error_write(e);
}
