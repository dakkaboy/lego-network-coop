#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "render/camera_order_bridge.h"

static char *parent,*current,*views[2],*targets[2],*backgrounds[2],*context;
static HWND game_window=(HWND)9;
static uint32_t clonewars_camera_threads[3],clonewars_camera_fullclip=84;
static int selected;
static char *current_camera_manager(void){return current;}
static int camera_selected(void){return selected;}
static int readable(const void *p,SIZE_T n){
 MEMORY_BASIC_INFORMATION m;
 return p && VirtualQuery(p,&m,sizeof m) && m.State==MEM_COMMIT && !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
  (uintptr_t)p+n>=(uintptr_t)p && (uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static DWORD window_thread(HWND window,LPDWORD out){assert(window==game_window&&!out);return GetCurrentThreadId();}
static int personal_fullscreen(char *p){return p==current;}
#define GetWindowThreadProcessId window_thread
#include "render/camera_native_order.inc"
#undef GetWindowThreadProcessId

static void prepare(unsigned extra){
 current=parent;selected=1;memset(parent,0,0x2000);*(uintptr_t *)parent=0xc3e248;*(char **)(parent+0xc)=context;
 for(unsigned i=0;i<2;++i){
  memset(views[i],0,0xb4);memset(targets[i],0,0x1000);memset(backgrounds[i],0,0xac);
  *(uintptr_t *)views[i]=0xc3dc94;*(uint32_t *)(views[i]+0x2c)=1;*(char **)(views[i]+0x30)=context;
  *(short *)(views[i]+0xac)=(short)i;*(char **)(views[i]+0xb0)=parent;*(char **)(views[i]+0xa8)=targets[i];
  *(uintptr_t *)targets[i]=0xc3db4c;*(uintptr_t *)(targets[i]+0x10)=0xe62010;*(char **)(targets[i]+0x44)=parent;
  ((char **)(parent+0xf24))[i]=views[i];
  if(i<extra){
   *(uintptr_t *)backgrounds[i]=0xc3e21c;*(uint32_t *)(backgrounds[i]+0x2c)=2;*(char **)(backgrounds[i]+0x30)=context;
   *(char **)(views[i]+0x28)=backgrounds[i];((char **)(parent+0xf24))[i+2]=backgrounds[i];
  }
 }
 clonewars_camera_native_order_enabled=clonewars_camera_native_order_installed=1;
 clonewars_camera_threads[0]=GetCurrentThreadId();memset((void *)0xeb8390,0,0x6000);
}
static int pair(void){char *v[2],*t[2];return camera_order_pair(parent,v,t);}
static void enter(CameraOrderBridge *bridge){memset(bridge,0,sizeof *bridge);bridge->in_regs[6]=(uintptr_t)parent;camera_order_enter(bridge);}
static void native_prepare(void){
 unsigned pass=1;
 for(unsigned i=0;i<4;++i){char *view=((char **)(parent+0xf24))[i];if(view&&*(uint32_t *)(view+0x2c)==1)*(uint32_t *)(view+0x34)=pass++;}
}
static unsigned tests;
#define CHECK(x) do{++tests;assert(x);}while(0)
int main(void){
 parent=VirtualAlloc(NULL,0x2000,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);
 context=VirtualAlloc(NULL,0x1000,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);CHECK(parent&&context);
 CHECK(VirtualAlloc((void *)0xeb0000,0x10000,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE)==(void *)0xeb0000);
 for(unsigned i=0;i<2;++i){
  views[i]=VirtualAlloc(NULL,0x1000,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);targets[i]=VirtualAlloc(NULL,0x1000,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);
  char *allocation=VirtualAlloc(NULL,0x2000,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);CHECK(views[i]&&targets[i]&&allocation);
  DWORD old;CHECK(VirtualProtect(allocation+0x1000,0x1000,PAGE_NOACCESS,&old));backgrounds[i]=allocation+0x1000-0xac;
 }
 CameraOrderBridge bridge;
 for(unsigned extra=0;extra<=2;++extra)for(unsigned role=0;role<2;++role){
  prepare(extra);selected=(int)role;CHECK(pair());unsigned char before[2][0xac];
  for(unsigned i=0;i<2;++i)memcpy(before[i],backgrounds[i],0xac);
  enter(&bridge);CameraOrderScope *scope=(CameraOrderScope *)bridge.storage;CHECK(scope->admitted);
  CHECK(((char **)(parent+0xf24))[0]==views[role]);
  for(unsigned i=0;i<2;++i)CHECK(((char **)(parent+0xf24))[i+2]==(i<extra?backgrounds[i]:NULL));
  native_prepare();camera_order_leave(&bridge,0);CHECK(!camera_order_depth&&camera_order_presentation_ready(parent));
  CHECK(((char **)(parent+0xf24))[0]==views[0]&&((char **)(parent+0xf24))[1]==views[1]);
  for(unsigned i=0;i<2;++i)CHECK(!memcmp(before[i],backgrounds[i],0xac));
 }
 for(unsigned bad=0;bad<9;++bad){
  prepare(2);
  switch(bad){
   case 0:*(uintptr_t *)backgrounds[0]=0xc3dc94;break;
   case 1:*(uint32_t *)(backgrounds[0]+0x2c)=1;break;
   case 2:*(char **)(backgrounds[0]+0x30)=parent;break;
   case 3:*(char **)(views[0]+0x28)=NULL;break;
   case 4:*(char **)(views[1]+0x28)=backgrounds[0];break;
   case 5:((char **)(parent+0xf24))[3]=backgrounds[0];break;
   case 6:*(char **)(parent+0xc)=NULL;break;
   case 7:*(char **)(views[1]+0x30)=parent;break;
   case 8:((char **)(parent+0xf24))[2]=views[0];break;
  }
  CHECK(!pair());enter(&bridge);CHECK(!((CameraOrderScope *)bridge.storage)->admitted);
  native_prepare();camera_order_leave(&bridge,0);CHECK(!camera_order_depth&&!camera_order_presentation_ready(parent));
  CHECK(((char **)(parent+0xf24))[0]==views[0]&&((char **)(parent+0xf24))[1]==views[1]);
 }
 for(unsigned mutation=0;mutation<5;++mutation){
  prepare(2);enter(&bridge);CHECK(((CameraOrderScope *)bridge.storage)->swapped);native_prepare();
  DWORD old=0;
  switch(mutation){
   case 0:((char **)(parent+0xf24))[2]=NULL;break;
   case 1:*(char **)(backgrounds[0]+0x30)=parent;break;
   case 2:*(char **)(views[0]+0x28)=backgrounds[1];break;
   case 3:CHECK(VirtualProtect(backgrounds[0],0xac,PAGE_NOACCESS,&old));break;
   case 4:*(char **)(parent+0xc)=parent;break;
  }
  camera_order_leave(&bridge,0);
  CHECK(((char **)(parent+0xf24))[0]==views[0]&&((char **)(parent+0xf24))[1]==views[1]);
  CHECK(!camera_order_depth&&!camera_order_presentation_ready(parent));
  if(mutation==3)CHECK(VirtualProtect(backgrounds[0],0xac,PAGE_READWRITE,&old));
 }
 prepare(2);enter(&bridge);native_prepare();camera_order_leave(&bridge,0);CHECK(camera_order_presentation_ready(parent));
 *(char **)(views[0]+0x28)=NULL;CHECK(!camera_order_presentation_ready(parent));
 prepare(2);enter(&bridge);native_prepare();camera_order_leave(&bridge,0);CHECK(camera_order_presentation_ready(parent));
 *(char **)(views[0]+0xa8)=targets[1];CHECK(!camera_order_presentation_ready(parent));
 printf("camera family actual source: %u checks PASS; AC guard pages, auxiliary lifetime, primary restore and presentation guards\n",tests);
 return 0;
}
