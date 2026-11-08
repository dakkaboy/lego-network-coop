#include "camera_order_bridge.h"
__declspec(dllexport) volatile LONG clonewars_camera_native_order_enabled=1;
__declspec(dllexport) volatile LONG clonewars_camera_native_order_installed;
__declspec(dllexport) volatile uint32_t clonewars_camera_native_order_debug[16];
__attribute__((used)) const uint32_t camera_order_default_mxcsr=0x1f80;
static __thread unsigned camera_order_depth;
static __thread unsigned camera_order_nested;
static char *camera_order_prepared_parent;
static char *camera_order_prepared_views[2];
static char *camera_order_prepared_targets[2];
static char *camera_order_prepared_backgrounds[2],*camera_order_prepared_children[2];
static char *camera_order_prepared_context;
static int camera_order_prepared_role=-1;
typedef struct CameraOrderScope {
 char *parent,*views[2],*targets[2],*backgrounds[2],*children[2],*context;
 uint32_t thread,entered,admitted,swapped,selected;
} CameraOrderScope;
_Static_assert(sizeof(CameraOrderScope)<=sizeof(((CameraOrderBridge *)0)->storage),"order scope storage");
static int camera_order_family(char *parent,char **views,char **targets,char **backgrounds,char **children,char **context) {
 if(!readable(parent,0x1420) || parent!=current_camera_manager() || *(uintptr_t *)parent!=0xc3e248)return 0;
 char **slots=(char **)(parent+0xf24);
 if(!slots[0] || !slots[1] || slots[0]==slots[1])return 0;
 unsigned roles=0;
 for(unsigned i=0;i<2;++i){
  char *v=slots[i];if(!readable(v,0xb4) || *(uintptr_t *)v!=0xc3dc94 || *(uint32_t *)(v+0x2c)!=1 || *(char **)(v+0xb0)!=parent)return 0;
  int role=*(short *)(v+0xac);if(role<0 || role>1 || (roles&(1u<<role)))return 0;roles|=1u<<role;
  char *t=*(char **)(v+0xa8);if(!readable(t,0x48) || *(uintptr_t *)t!=0xc3db4c || *(char **)(t+0x44)!=parent || *(uintptr_t *)(t+0x10)!=0xe62010)return 0;
  views[i]=v;targets[i]=t;
 }
 if(roles!=3)return 0;
 *context=NULL;
 for(unsigned i=0;i<2;++i){backgrounds[i]=slots[i+2];children[i]=*(char **)(views[i]+0x28);}
 if(!backgrounds[0] && !backgrounds[1])return !children[0] && !children[1];
 *context=*(char **)(parent+0xc);
 if(!readable(*context,4) || (backgrounds[0] && backgrounds[0]==backgrounds[1]))return 0;
 for(unsigned i=0;i<2;++i) {
  if(*(char **)(views[i]+0x30)!=*context)return 0;
  if(children[i] && children[i]!=backgrounds[0] && children[i]!=backgrounds[1])return 0;
  char *background=backgrounds[i];
  if(!background)continue;
  if(background==views[0] || background==views[1] || !readable(background,0xac) ||
     *(uintptr_t *)background!=0xc3e21c || *(uint32_t *)(background+0x2c)!=2 ||
     *(char **)(background+0x30)!=*context ||
     (unsigned)(children[0]==background)+(unsigned)(children[1]==background)!=1)return 0;
 }
 return 1;
}
static int camera_order_pair(char *parent,char **views,char **targets) {
 char *backgrounds[2],*children[2],*context;
 return camera_order_family(parent,views,targets,backgrounds,children,&context);
}
static int camera_order_restore_live(CameraOrderScope *s) {
 if(s->parent!=current_camera_manager() || !readable(s->parent,0x1420) || *(uintptr_t *)s->parent!=0xc3e248)return 0;
 char **slots=(char **)(s->parent+0xf24);
 if(slots[0]!=s->views[1] || slots[1]!=s->views[0])return 0;
 for(unsigned i=0;i<2;++i){char *v=s->views[i],*t=s->targets[i];
  if(!readable(v,0xb4) || *(uintptr_t *)v!=0xc3dc94 || *(char **)(v+0xb0)!=s->parent || *(char **)(v+0xa8)!=t ||
     !readable(t,0x48) || *(uintptr_t *)t!=0xc3db4c || *(char **)(t+0x44)!=s->parent)return 0;
 }
 return 1;
}
void __cdecl camera_order_enter(CameraOrderBridge *bridge) {
 CameraOrderScope *s=(CameraOrderScope *)bridge->storage;memset(s,0,sizeof(*s));bridge->target=(void *)0x77fe40;
 s->entered=1;s->thread=GetCurrentThreadId();++camera_order_depth;
 if(camera_order_depth>1){camera_order_nested=1;return;}camera_order_nested=0;
 if(camera_order_depth!=1 || s->thread!=clonewars_camera_threads[0] || s->thread!=GetWindowThreadProcessId(game_window,NULL))return;
 camera_order_prepared_parent=NULL;camera_order_prepared_role=-1;
 if(!clonewars_camera_native_order_enabled || clonewars_camera_native_order_installed!=1)return;
 char *parent=(char *)(uintptr_t)bridge->in_regs[6];
 if(s->thread!=clonewars_camera_threads[0] || s->thread!=GetWindowThreadProcessId(game_window,NULL) || !personal_fullscreen(parent))return;
 char *views[2],*targets[2],*backgrounds[2],*children[2],*context;
 if(!camera_order_family(parent,views,targets,backgrounds,children,&context))return;
 int selected_role=camera_selected();if(selected_role<0 || selected_role>1)return;
 s->parent=parent;s->views[0]=views[0];s->views[1]=views[1];s->targets[0]=targets[0];s->targets[1]=targets[1];s->selected=(uint32_t)selected_role;s->admitted=1;
 for(unsigned i=0;i<2;++i){s->backgrounds[i]=backgrounds[i];s->children[i]=children[i];}s->context=context;
 int copy_resolved_view=(clonewars_camera_fullclip&16)!=0;
 int selected_first=*(short *)(views[0]+0xac)==selected_role;
 if(copy_resolved_view!=selected_first){
  char **slots=(char **)(parent+0xf24);slots[0]=views[1];slots[1]=views[0];s->swapped=1;++clonewars_camera_native_order_debug[0];
 }
 ++clonewars_camera_native_order_debug[1];
}
static void camera_move_native_hud(const CameraOrderScope *s) {
 if(!(clonewars_camera_fullclip&16))return;
 char *first_view=s->views[s->swapped];
 char *last_view=s->views[!s->swapped];
 if(*(short *)(first_view+0xac)!=s->selected ||
    *(uint32_t *)(first_view+0x34)!=1 || *(uint32_t *)(last_view+0x34)!=2)return;
 char *first=(char *)0xeb8390+0x14f0;
 char *last=first+0x14f0;
 if(*(uintptr_t *)(first+0x40) || *(uintptr_t *)(first+0x64) ||
    *(uintptr_t *)(last+0x40)!=0x7560b0 || *(char **)(last+0x64)!=last_view)return;
 // The copied world surface has to include the engine's UI event before the resolve.
 *(char **)(first+0x64)=first_view;
 *(uintptr_t *)(first+0x40)=0x7560b0;
 *(uintptr_t *)(last+0x40)=0;
 *(uintptr_t *)(last+0x64)=0;
 ++clonewars_camera_native_order_debug[7];
}
void __cdecl camera_order_leave(CameraOrderBridge *bridge,int unwound) {
 CameraOrderScope *s=(CameraOrderScope *)bridge->storage;
 int restored=1;
 if(s->swapped){
  restored=camera_order_restore_live(s);
  if(restored){char **slots=(char **)(s->parent+0xf24);slots[0]=s->views[0];slots[1]=s->views[1];++clonewars_camera_native_order_debug[2];}
  else ++clonewars_camera_native_order_debug[3];
 }
 if(s->admitted && !camera_order_nested && !unwound && restored && clonewars_camera_native_order_enabled && s->parent==current_camera_manager()){
  char *views[2],*targets[2],*backgrounds[2],*children[2],*context;
  if(camera_order_family(s->parent,views,targets,backgrounds,children,&context) &&
     views[0]==s->views[0] && views[1]==s->views[1] && targets[0]==s->targets[0] && targets[1]==s->targets[1] &&
     backgrounds[0]==s->backgrounds[0] && backgrounds[1]==s->backgrounds[1] &&
     children[0]==s->children[0] && children[1]==s->children[1] && context==s->context && camera_selected()==(int)s->selected){
   camera_move_native_hud(s);
   camera_order_prepared_parent=s->parent;camera_order_prepared_views[0]=s->views[0];camera_order_prepared_views[1]=s->views[1];camera_order_prepared_role=(int)s->selected;
   for(unsigned i=0;i<2;++i){camera_order_prepared_targets[i]=targets[i];camera_order_prepared_backgrounds[i]=backgrounds[i];camera_order_prepared_children[i]=children[i];}
   camera_order_prepared_context=context;
   clonewars_camera_native_order_debug[4]=bridge->out_regs[7];++clonewars_camera_native_order_debug[5];
  }
 }
 if(unwound)++clonewars_camera_native_order_debug[6];
 if(s->entered && camera_order_depth)--camera_order_depth;
}
static int camera_order_presentation_ready(char *parent) {
 if(!clonewars_camera_native_order_enabled || clonewars_camera_native_order_installed!=1 || camera_order_depth ||
    parent!=camera_order_prepared_parent || camera_order_prepared_role!=camera_selected())return 0;
 char *views[2],*targets[2],*backgrounds[2],*children[2],*context;
 return camera_order_family(parent,views,targets,backgrounds,children,&context) &&
  views[0]==camera_order_prepared_views[0] && views[1]==camera_order_prepared_views[1] &&
  targets[0]==camera_order_prepared_targets[0] && targets[1]==camera_order_prepared_targets[1] &&
  backgrounds[0]==camera_order_prepared_backgrounds[0] && backgrounds[1]==camera_order_prepared_backgrounds[1] &&
  children[0]==camera_order_prepared_children[0] && children[1]==camera_order_prepared_children[1] && context==camera_order_prepared_context;
}
