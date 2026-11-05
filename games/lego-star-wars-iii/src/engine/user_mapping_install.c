#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "user_mapping_install.h"
#include "user_mapping_internal.h"
#include "user_mapping_native_contract.h"
#include "user_mapping_native_relocations.h"
static const uintptr_t original_addresses[UM_SITE_COUNT]={0x57b1a0,0x582da0,0x57b2a0,0x57b530,0xab67f0,0x58988f,0x5898e1,0x589660};
static const unsigned lengths[UM_SITE_COUNT]={5,5,5,5,5,6,6,7};
static const unsigned char prefixes[UM_SITE_COUNT][7]={{0x56,0x8b,0x74,0x24,8},{0x56,0x8b,0x74,0x24,8},{0x68,0,9,0,0},{0x33,0xd2,0x83,0xc8,0xff},{0x32,0xc0,0x83,0xc9,0xff},{0x89,0x15,0x70,0x1a,0xeb,0},{0x89,0x15,0x70,0x1a,0xeb,0},{0x6a,0xff,0x68,0x68,0x12,0xaa,0}};
static uintptr_t addresses[UM_SITE_COUNT],image_base;
static unsigned char *slab;static uintptr_t targets[UM_SITE_COUNT];static DWORD main_thread;
__declspec(dllexport) volatile LONG clonewars_user_mapping_installed;
__attribute__((used)) static volatile uintptr_t resume_a,resume_b;
__attribute__((naked,used)) static void user0_a_thunk(void){__asm__ volatile("pushl _resume_a;jmp _user_mapping_user0_a_entry");}
__attribute__((naked,used)) static void user0_b_thunk(void){__asm__ volatile("pushl _resume_b;jmp _user_mapping_user0_b_entry");}
static int readable(const void*p,unsigned n){MEMORY_BASIC_INFORMATION m;return p&&VirtualQuery(p,&m,sizeof m)&&m.State==MEM_COMMIT&&!(m.Protect&(PAGE_NOACCESS|PAGE_GUARD))&&(uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;}
#ifdef USER_MAPPING_INSTALL_FIXTURE
extern BOOL user_mapping_test_protect(void *,SIZE_T,DWORD,DWORD*);
extern BOOL user_mapping_test_flush(HANDLE,const void*,SIZE_T);
void *user_mapping_test_slab(void){return slab;}
#define protect user_mapping_test_protect
#define flush user_mapping_test_flush
#else
#define protect VirtualProtect
#define flush FlushInstructionCache
#endif
static int32_t rel32(const void*p){int32_t v;memcpy(&v,p,4);return v;}
static void put32(void*p,uint32_t v){memcpy(p,&v,4);}
static void expected(unsigned i,unsigned char out[7]){memcpy(out,prefixes[i],7);if(i==UM_USER0_A||i==UM_USER0_B)put32(out+2,(uint32_t)(image_base+0xeb1a70-0x400000));if(i==UM_POLLER)put32(out+3,(uint32_t)(image_base+0xaa1268-0x400000));}
static int native_contract_valid(void){
 const uintptr_t original[]={0x57b1a0,0x582da0,0x57b2a0,0x57b530,0xab67f0,0x634a10,0x63a940,0x582cb0};
 const unsigned char *bytes[]={native_57b1a0,native_582da0,native_57b2a0,native_57b530,native_ab67f0,native_634a10,native_63a940,native_582cb0};
 const unsigned sizes[]={sizeof native_57b1a0,sizeof native_582da0,sizeof native_57b2a0,sizeof native_57b530,sizeof native_ab67f0,sizeof native_634a10,sizeof native_63a940,sizeof native_582cb0};
 for(unsigned i=0;i<8;++i){unsigned char expected_bytes[192];memcpy(expected_bytes,bytes[i],sizes[i]);for(unsigned r=0;r<sizeof native_relocations/sizeof native_relocations[0];++r)if(native_relocations[r]>=original[i]&&native_relocations[r]+4<=original[i]+sizes[i]){unsigned off=native_relocations[r]-original[i];put32(expected_bytes+off,(uint32_t)rel32(expected_bytes+off)+(uint32_t)(image_base-0x400000));}unsigned skip=i<5?5:0;const void*at=(void*)(image_base+original[i]-0x400000+skip);if(!readable(at,sizes[i]-skip)||memcmp(at,expected_bytes+skip,sizes[i]-skip))return 0;}
 return 1;
}
int user_mapping_install_ready(void){DWORD e=GetLastError();int ok=0;if(clonewars_user_mapping_installed!=127||GetCurrentThreadId()!=main_thread||!slab)goto done;for(unsigned i=0;i<UM_SITE_COUNT;++i){const unsigned char*p=(void*)addresses[i];if(!readable(p,lengths[i])||p[0]!=0xe9||(uintptr_t)p+5+rel32(p+1)!=targets[i])goto done;for(unsigned j=5;j<lengths[i];++j)if(p[j]!=0x90)goto done;unsigned char bytes[7];expected(i,bytes);const unsigned char*t=slab+i*16;if(!readable(t,16)||memcmp(t,bytes,lengths[i]))goto done;if(i==UM_USER0_A||i==UM_USER0_B){if(t[lengths[i]]!=0xc3)goto done;}else if(t[lengths[i]]!=0xe9||(uintptr_t)t+lengths[i]+5+rel32(t+lengths[i]+1)!=addresses[i]+lengths[i])goto done;}ok=native_contract_valid();done:SetLastError(e);return ok;}
int user_mapping_install_safe(const UserMappingInstallConfig*c){DWORD error=GetLastError();int ok=0;uintptr_t pages[UM_SITE_COUNT];DWORD old[UM_SITE_COUNT];unsigned page_count=0,protected_count=0;
 if(!c||!c->main_thread||GetCurrentThreadId()!=c->main_thread||!c->original_source_valid||!c->install_allowed||!c->install_allowed(c->user))goto done;if(clonewars_user_mapping_installed<0)goto done;if(clonewars_user_mapping_installed==127){ok=user_mapping_install_ready();goto done;}
 #ifdef USER_MAPPING_INSTALL_FIXTURE
 extern uintptr_t user_mapping_test_image_base(void);image_base=user_mapping_test_image_base();
#else
 image_base=(uintptr_t)GetModuleHandleA(NULL);if(image_base!=0x400000)goto done;
#endif
 for(unsigned i=0;i<UM_SITE_COUNT;++i)addresses[i]=image_base+original_addresses[i]-0x400000;
 resume_a=addresses[UM_USER0_A]+6;resume_b=addresses[UM_USER0_B]+6;
 for(unsigned i=0;i<UM_SITE_COUNT;++i){unsigned char bytes[7];expected(i,bytes);if(!readable((void*)addresses[i],lengths[i])||memcmp((void*)addresses[i],bytes,lengths[i]))goto done;}
 if(!native_contract_valid())goto done;
 unsigned char*new_slab=VirtualAlloc(NULL,UM_SITE_COUNT*16,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);if(!new_slab)goto done;
 void *entrypoints[UM_SITE_COUNT]={user_mapping_mapper_entry,user_mapping_setter_entry,user_mapping_reset_all_entry,user_mapping_reset_01_entry,user_mapping_initializer_entry,user0_a_thunk,user0_b_thunk,user_mapping_poller_entry};
 UserMappingConfig cfg={.version=UM_OBSERVER_API_VERSION,.main_thread=c->main_thread,.native_table=(void*)(image_base+0xeb1a70-0x400000),.native_owners=(void*)(image_base+0xead92c-0x400000),.original_source_valid=c->original_source_valid};
 for(unsigned i=0;i<UM_SITE_COUNT;++i){unsigned char*t=new_slab+i*16;unsigned char bytes[7];expected(i,bytes);memcpy(t,bytes,lengths[i]);if(i==UM_USER0_A||i==UM_USER0_B)t[lengths[i]]=0xc3;else{t[lengths[i]]=0xe9;put32(t+lengths[i]+1,(uint32_t)(addresses[i]+lengths[i]-(uintptr_t)t-lengths[i]-5));}cfg.targets[i]=t;uintptr_t page=addresses[i]&~(uintptr_t)4095;unsigned j;for(j=0;j<page_count;++j)if(pages[j]==page)break;if(j==page_count)pages[page_count++]=page;}
 for(unsigned i=0;i<page_count;++i){if(!protect((void*)pages[i],4096,PAGE_EXECUTE_READWRITE,old+i))goto rollback;++protected_count;}
 if(!c->install_allowed(c->user)||!user_mapping_configure(&cfg))goto rollback;
 slab=new_slab;main_thread=c->main_thread;for(unsigned i=0;i<UM_SITE_COUNT;++i){unsigned char*p=(void*)addresses[i];targets[i]=(uintptr_t)entrypoints[i];p[0]=0xe9;put32(p+1,(uint32_t)(targets[i]-(uintptr_t)p-5));memset(p+5,0x90,lengths[i]-5);}
 int publication_ok=1;for(unsigned i=protected_count;i>0;--i){DWORD ignored;if(!protect((void*)pages[i-1],4096,old[i-1],&ignored))publication_ok=0;}
 if(!flush(GetCurrentProcess(),new_slab,UM_SITE_COUNT*16))publication_ok=0;for(unsigned i=0;i<page_count;++i)if(!flush(GetCurrentProcess(),(void*)pages[i],4096))publication_ok=0;
 if(!publication_ok){user_mapping_invalidate_runtime();InterlockedExchange(&clonewars_user_mapping_installed,-1);goto done;}
 InterlockedExchange(&clonewars_user_mapping_installed,127);if(!user_mapping_install_ready()||!user_mapping_binding_ready(UM_REQUIRED_COVERAGE)||!user_mapping_enable()){user_mapping_invalidate_runtime();InterlockedExchange(&clonewars_user_mapping_installed,-1);goto done;}ok=1;goto done;
 rollback:{int restored=1;while(protected_count){DWORD ignored;--protected_count;if(!protect((void*)pages[protected_count],4096,old[protected_count],&ignored))restored=0;}if(!restored){user_mapping_invalidate_runtime();InterlockedExchange(&clonewars_user_mapping_installed,-1);}VirtualFree(new_slab,0,MEM_RELEASE);}
 done:SetLastError(error);return ok;}
