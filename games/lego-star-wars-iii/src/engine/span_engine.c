#include "span_engine.h"
#include "native_owner_internal.h"
#include "native_numeric_input.h"
#include "native_span_thunk.proposed.h"
#include "../sync/coherent_marker.h"
#include <string.h>
typedef struct ScopeState {struct ScopeState*parent;NativeOwnerScope*scope;void*receiver;unsigned nonce,serial,main,optional;unsigned char qualified,entered,run,closed,deny,finishing;uint32_t control_release;SpanControlContext control;NativeNumericScope numeric;} ScopeState;
typedef char state_size[sizeof(ScopeState)<=64?1:-1];
static SpanEngineAdapter*adapter;static __thread ScopeState*top;
void*native_span_run_resume,*native_span_skip_target,*native_span_exit_resume,*optional_target,*main_target;
static unsigned char*va(unsigned offset){return adapter->image760000+offset;}
static int readable(const void*p,SIZE_T n){MEMORY_BASIC_INFORMATION m;return p&&n&&(uintptr_t)p+n>=(uintptr_t)p&&VirtualQuery(p,&m,sizeof m)&&m.State==MEM_COMMIT&&!(m.Protect&(PAGE_NOACCESS|PAGE_GUARD))&&(uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;}
static int outer_qualified(const NativeOwnerInput*i){uintptr_t s=i->caller_esp;void*receiver=(void*)(uintptr_t)i->regs[6];return GetCurrentThreadId()==adapter->window_thread&&readable((void*)s,12)&&*(uintptr_t*)s==(uintptr_t)va(0x3db1)&&*(uintptr_t*)(s+8)==(uintptr_t)va(0x3eac)&&readable((const void*)adapter->root_global,4)&&*adapter->root_global==receiver&&readable(receiver,4)&&*(void**)receiver==adapter->expected_vt;}
static unsigned serial_read(void){return (unsigned)InterlockedCompareExchange(&adapter->serial,0,0);}
static void revoke(unsigned reason,int sticky){unsigned old,next;int exhausted=0;do {old=serial_read();if(old==0xffffffffu){exhausted=1;break;}next=old+1;exhausted=next==0xffffffffu;}while((unsigned)InterlockedCompareExchange(&adapter->serial,(LONG)next,(LONG)old)!=old);if(sticky||exhausted)InterlockedExchange(&adapter->sticky,1);InterlockedIncrement(&adapter->rejected);adapter->callbacks.reject_atomic(reason,adapter->callbacks.user);if(exhausted&&reason!=SPAN_REJECT_SERIAL_EXHAUSTED)adapter->callbacks.reject_atomic(SPAN_REJECT_SERIAL_EXHAUSTED,adapter->callbacks.user);}
static int active_parent(void){for(ScopeState*p=top;p;p=p->parent)if((p->entered&&!p->closed)||p->finishing)return 1;return 0;}
static void begin(NativeOwnerScope*s,const NativeOwnerInput*i,void*storage){ScopeState*p=storage;memset(p,0,sizeof *p);p->parent=top;p->scope=s;p->nonce=native_owner_scope_nonce(s);p->serial=serial_read();p->qualified=outer_qualified(i);p->deny=top!=NULL;if(p->deny)revoke(SPAN_REJECT_WRAPPED_CHILD,0);p->receiver=(void*)(uintptr_t)i->regs[6];top=p;
 if(!p->nonce||!native_owner_scope_valid(s,p->nonce)){p->deny=1;revoke(SPAN_REJECT_SCOPE,1);return;}
 if(!p->qualified||p->deny){InterlockedIncrement(&adapter->unowned);return;}InterlockedIncrement(&adapter->qualified);p->control_release=coherent_frame_release();if(!adapter->callbacks.control_context(&p->control,adapter->callbacks.user)||p->control_release!=coherent_frame_release())p->control.established=0;
 SpanQualification q={adapter->installer.generation,GetCurrentThreadId(),1,0,1,0};
 if(adapter->callbacks.install_safe((void*)(uintptr_t)i->regs[6],i,adapter->callbacks.user)){q.quiescent=1;if(span_installer_code(&adapter->installer,&q)==1){if(!adapter->sticky&&adapter->callbacks.dependencies_ready(adapter->callbacks.user)&&adapter->callbacks.main_confirmed(GetCurrentThreadId(),adapter->callbacks.user)){q.main_confirmed=1;span_installer_confirm(&adapter->installer,&q);}else InterlockedExchange(&adapter->installer.ready,0);}}
}
static void end(NativeOwnerScope*s,NativeOwnerExit x,void*storage){ScopeState*p=storage;native_numeric_restore(&p->numeric,s->out_fx);if(top==p)top=p->parent;if(p->entered)adapter->callbacks.end(s,p->nonce,x,(p->serial!=serial_read())||((p->run&&!p->closed)||p->finishing),adapter->callbacks.user);}
static void reject(NativeOwnerScope*s,NativeOwnerScope*p,NativeOwnerReject reason,void*storage){(void)s;(void)p;(void)storage;revoke(SPAN_REJECT_OWNER_DEPTH+(unsigned)reason,1);}
static ScopeState*bound(uintptr_t stack){ScopeState*p=top;NativeOwnerScope*s=native_owner_current();if(!p||s!=p->scope||!p->qualified||p->serial!=serial_read()||!native_owner_scope_valid(s,p->nonce))return NULL;uintptr_t d=native_owner_scope_delegate_esp(s,p->nonce);if(!d||stack!=d-0x4c){InterlockedIncrement(&adapter->bad_stack);return NULL;}return p;}
__attribute__((used,noinline)) unsigned native_span_enter(OwnerU32*b,void*fx){
 if(top&&top->deny)return 2;
 ScopeState*p=bound((uintptr_t)b+36);
 if(!p){
  if(active_parent()){revoke(SPAN_REJECT_UNWRAPPED_CHILD,0);return 2;}
  if(top&&top->qualified){
   if(top->serial!=serial_read())return 2;
   NativeOwnerScope*s=native_owner_current();
   if(s==top->scope&&native_owner_scope_valid(s,top->nonce)){revoke(SPAN_REJECT_UNWRAPPED_CHILD,0);return 2;}
   revoke(SPAN_REJECT_SCOPE,1);return 2;
  }
  return 0;
 }
 if((void*)(uintptr_t)b[1]!=p->receiver){InterlockedIncrement(&adapter->bad_stack);revoke(SPAN_REJECT_UNWRAPPED_CHILD,0);return 2;}
 if(adapter->sticky)return 2;
 if(p->entered){InterlockedIncrement(&adapter->duplicates);revoke(SPAN_REJECT_UNWRAPPED_CHILD,0);return 2;}
 unsigned ready=span_engine_ready(adapter);p->entered=1;
 NativeNumericInput local_numeric=native_numeric_read(fx);
 unsigned plan=adapter->callbacks.enter(p->scope,p->nonce,(void*)((uintptr_t)b+36+0x28),(void*)(uintptr_t)b[1],b,fx,ready,adapter->callbacks.user);
 native_numeric_borrow(&p->numeric,local_numeric,fx);
 if(plan>2){InterlockedIncrement(&adapter->invalid_plan);revoke(SPAN_REJECT_INVALID_PLAN,0);plan=2;}
 if(plan==1&&(!ready||!span_engine_ready(adapter))){revoke(SPAN_REJECT_UNREADY_RUN,0);plan=2;}
 if(p->serial!=serial_read()||!native_owner_scope_valid(p->scope,p->nonce)){p->closed=1;native_numeric_restore(&p->numeric,fx);return 2;}
 p->run=plan==1;p->closed=plan!=1;
 if(!p->run)native_numeric_restore(&p->numeric,fx);
 return plan;
}
__attribute__((used,noinline)) void native_span_exit(OwnerU32*b,void*fx){ScopeState*p=bound((uintptr_t)b+36);if(p&&(void*)(uintptr_t)b[1]!=p->receiver){InterlockedIncrement(&adapter->bad_stack);revoke(SPAN_REJECT_MARKER,0);return;}if(p&&p->run&&!p->closed){p->closed=1;p->finishing=1;adapter->callbacks.finish(p->scope,p->nonce,adapter->callbacks.user);native_numeric_restore(&p->numeric,fx);p->finishing=0;}}
static void marker(OwnerU32*b,unsigned kind,unsigned pushed){ScopeState*p=bound((uintptr_t)b+36+4+pushed);if(p&&(void*)(uintptr_t)b[1]!=p->receiver){InterlockedIncrement(&adapter->bad_stack);revoke(SPAN_REJECT_MARKER,0);return;}if(p&&kind==1&&(*(OwnerU32*)((uintptr_t)b+40)!=(uintptr_t)b+44+0x28||(uintptr_t)b[6]!=(uintptr_t)p->receiver+0x10)){InterlockedIncrement(&adapter->bad_stack);revoke(SPAN_REJECT_MARKER,0);return;}if(p&&p->run&&!p->closed){if(kind==1){++p->main;InterlockedIncrement(&adapter->main_count);}else{++p->optional;InterlockedIncrement(&adapter->optional_count);}adapter->callbacks.marker(p->scope,p->nonce,kind,adapter->callbacks.user);}}
__attribute__((used,noinline)) void optional_enter(OwnerU32*b,const void*fx){(void)fx;marker(b,2,0);}
__attribute__((used,noinline)) void main_enter(OwnerU32*b,const void*fx){(void)fx;marker(b,1,4);}
__attribute__((naked)) static void entry_thunk(void){__asm__ volatile(NATIVE_SPAN_ENTRY_PROPOSED_ASM);}
__attribute__((naked)) static void exit_thunk(void){__asm__ volatile(NATIVE_SPAN_EXIT_PROPOSED_ASM);}
__attribute__((naked)) static void optional_thunk(void){__asm__ volatile(COHERENT_MARKER_ASM("_optional_enter","_optional_target"));}
__attribute__((naked)) static void main_thunk(void){__asm__ volatile(COHERENT_MARKER_ASM("_main_enter","_main_target"));}
static void patch(SpanPatch*p,unsigned char*where,unsigned n,const unsigned char*old,void*target,unsigned opcode){p->address=where;p->length=n;memcpy(p->original,old,n);memset(p->replacement,0x90,n);p->replacement[0]=(unsigned char)opcode;int32_t rel=(int32_t)((uintptr_t)target-(uintptr_t)where-5);memcpy(p->replacement+1,&rel,4);}
int span_engine_prepare(SpanEngineAdapter*a,unsigned char*image,void*volatile*slot,void*vt,void*volatile*global,DWORD main,unsigned generation,const SpanEngineCallbacks*cb){if(adapter||!a||!image||!slot||!vt||!global||!main||!generation||!cb||cb->version!=5||!cb->reject_atomic||!cb->install_safe||!cb->dependencies_ready||!cb->main_confirmed||!cb->control_context||!cb->enter||!cb->marker||!cb->finish||!cb->end||slot!=(void*volatile*)((char*)vt+0x1c)||!readable(image+0x1380,7)||memcmp(image+0x1380,"\x6a\xff\x68\xe0\xdb\xaa\x00",7))return 0;memset(a,0,sizeof *a);a->callbacks=*cb;a->image760000=image;a->expected_vt=vt;a->root_global=global;a->window_thread=main;a->serial=1;
 SpanInstaller*s=&a->installer;s->slot=slot;s->original_target=image+0x1380;s->owner_target=native_owner_entry;s->code_page=image+0x1000;s->code_size=0x1000;s->forbidden=image+0x1380;s->forbidden_size=7;s->main_thread=main;s->generation=generation;
 patch(&s->sites[0],image+0x1557,8,(const unsigned char*)"\xf6\x40\x4d\x02\x89\x6c\x24\x48",entry_thunk,0xe9);
 patch(&s->sites[1],image+0x15a2,5,(const unsigned char*)"\xe8\xc9\xec\xff\xff",optional_thunk,0xe8);
 patch(&s->sites[2],image+0x15bc,5,(const unsigned char*)"\xe8\xbf\xf7\xff\xff",main_thunk,0xe8);
 patch(&s->sites[3],image+0x15c1,5,(const unsigned char*)"\x8b\x16\x8b\x42\x30",exit_thunk,0xe9);
 native_span_run_resume=image+0x155f;native_span_skip_target=image+0x15c1;native_span_exit_resume=image+0x15c6;optional_target=image+0x270;main_target=image+0xd80;
 NativeOwnerCallbacks owner={1,begin,end,reject};if(!native_owner_configure(s->original_target,&owner))return 0;adapter=a;return 1;}
int span_engine_publish_bootstrap(SpanEngineAdapter*a){return a&&a==adapter?span_installer_bootstrap(&a->installer,1):SPAN_INSTALL_ERROR;}
void span_engine_cancel(SpanEngineAdapter*a){if(a&&a==adapter){unsigned old,next;do{old=serial_read();if(old==0xffffffffu){revoke(SPAN_REJECT_SERIAL_EXHAUSTED,1);return;}next=old+1;}while((unsigned)InterlockedCompareExchange(&a->serial,(LONG)next,(LONG)old)!=old);if(next==0xffffffffu){InterlockedExchange(&a->sticky,1);InterlockedIncrement(&a->rejected);a->callbacks.reject_atomic(SPAN_REJECT_SERIAL_EXHAUSTED,a->callbacks.user);}}}

int span_engine_ready(SpanEngineAdapter*a){return a&&a==adapter&&!InterlockedCompareExchange(&a->sticky,0,0)&&InterlockedCompareExchange(&a->installer.ready,0,0)&&a->callbacks.dependencies_ready(a->callbacks.user)&&a->callbacks.main_confirmed(GetCurrentThreadId(),a->callbacks.user);}

static int control_binding(RootControlLease*out){
 ScopeState*p=top;if(!p||!p->qualified||p->deny||adapter->sticky||GetCurrentThreadId()!=adapter->window_thread||p->serial!=serial_read())return 0;
 NativeOwnerScope*s=native_owner_current();if(s!=p->scope||!native_owner_scope_valid(s,p->nonce))return 0;
 uintptr_t d=native_owner_scope_delegate_esp(s,p->nonce);if(!d||!adapter->callbacks.main_confirmed(GetCurrentThreadId(),adapter->callbacks.user))return 0;
 uint32_t release=p->control_release;if(!release||release==UINT32_MAX||coherent_frame_release()!=release||p->control.established!=1)return 0;
 SpanControlContext a={0},b={0};if(!adapter->callbacks.control_context(&a,adapter->callbacks.user)||a.established!=1||!a.epoch||a.epoch!=p->control.epoch||a.level!=p->control.level||a.established!=p->control.established||a.level<0||a.level>=4096)return 0;
 RootControlLease value={s,p->nonce,GetCurrentThreadId(),p->serial,release,a.epoch,a.level,d};
 if(!native_owner_scope_valid(s,p->nonce)||native_owner_scope_delegate_esp(s,p->nonce)!=d||adapter->sticky||p!=top||p->serial!=serial_read()||coherent_frame_release()!=release)return 0;
 if(!adapter->callbacks.control_context(&b,adapter->callbacks.user)||a.epoch!=b.epoch||a.level!=b.level||a.established!=b.established)return 0;
 if(!native_owner_scope_valid(s,p->nonce)||native_owner_scope_delegate_esp(s,p->nonce)!=d||p!=top||p->serial!=serial_read()||adapter->sticky||coherent_frame_release()!=release)return 0;
 *out=value;return 1;
}
int span_engine_control_get(SpanEngineAdapter*a,RootControlLease*out){DWORD error=GetLastError();int result=0;RootControlLease value;if(a&&a==adapter&&out&&control_binding(&value)){*out=value;result=1;}SetLastError(error);return result;}
int span_engine_control_valid(SpanEngineAdapter*a,const RootControlLease*lease){DWORD error=GetLastError();int result=0;RootControlLease value;if(a&&a==adapter&&lease&&control_binding(&value))result=lease->owner==value.owner&&lease->owner_nonce==value.owner_nonce&&lease->thread==value.thread&&lease->root_serial==value.root_serial&&lease->release==value.release&&lease->epoch==value.epoch&&lease->level==value.level&&lease->delegate_esp==value.delegate_esp;SetLastError(error);return result;}
