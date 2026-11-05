#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include "loading.h"
#include "../net/lan.h"
#include "game_state.h"
#include "../render/overlay.h"

static SyncLoading own={.level=-1};
typedef unsigned char (__attribute__((thiscall)) *Complete)(void *,int);
static Complete original_complete;
static int was_loading;
static int readable(const void *p,SIZE_T size) {
    MEMORY_BASIC_INFORMATION m;
    return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT &&
           !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
           (uintptr_t)p+size <= (uintptr_t)m.BaseAddress+m.RegionSize;
}
static void update_clock(char *root,int level) {
    SyncLoading peer=lan_remote_loading();
    int phase=*(int *)(root+0x1b78);
    int in_loading=phase>=1 && phase<=3;
    uint32_t epoch=lan_epoch();
    if (own.epoch!=epoch || own.level!=level || (in_loading && !was_loading)) own=(SyncLoading){.epoch=epoch,.level=level};
    was_loading=in_loading;
    unsigned char *flags=(unsigned char *)(root+0x3130);
    own.active=(*flags&1)!=0;
    if (!own.active) return;
    int skip=(*flags&4)!=0;
    if (lan_status()==LAN_CONNECTED && peer.epoch==own.epoch && peer.level==level) {
        skip|=peer.skip!=0;
        if (!lan_is_host() && peer.active && isfinite(peer.elapsed))
            *(float *)(root+0x3128)=peer.elapsed;
    }
    if (skip) *flags|=4;
    own.skip=skip;
    float elapsed=*(float *)(root+0x3128);
    own.elapsed=isfinite(elapsed) && elapsed>=0 && elapsed<86400 ? elapsed : 0;
}
static unsigned char __attribute__((fastcall)) complete_hook(void *self,void *unused,int kind) {
    (void)unused;
    char *root=self;
    if (kind!=4 || !readable(root,0x3134)) return original_complete(self,kind);
    int level=*(int *)0xfb8438;
    update_clock(root,level);
    unsigned char ready=original_complete(self,kind);
    own.ready=ready!=0;
    lan_publish_loading(&own,0);
    if (!ready || lan_status()!=LAN_CONNECTED) return ready;
    int target=game_network_target_level();
    SyncLoading peer=lan_remote_loading();
    if (level==target && (peer.epoch!=own.epoch || peer.level!=level || !peer.ready)) return 0;
    return ready;
}
void loading_poll(void) {
    char *root=*(char **)0xfb2e60;
    if (!readable(root,0x3134)) return;
    uint32_t epoch=lan_epoch();
    if (own.epoch!=epoch) {
        own=(SyncLoading){.epoch=epoch,.level=-1};
        was_loading=0;
    }
    int phase=*(int *)(root+0x1b78);
    if (phase>=1 && phase<=3) update_clock(root,*(int *)0xfb8438);
    else if (phase==0xe && game_current_level()>=0) {
        own.level=game_current_level(); own.ready=*(int *)0xe6e61c<0 && game_load_status()!=1; own.active=0;
        was_loading=0;
    }
    lan_publish_loading(&own,0);
}
int loading_install(void) {
    void **slot=(void **)0xadc2cc;
    if (*slot!=(void *)0x423ef0) return 0;
    DWORD old;
    if (!VirtualProtect(slot,4,PAGE_READWRITE,&old)) return 0;
    original_complete=(Complete)*slot;
    InterlockedExchangePointer(slot,complete_hook);
    VirtualProtect(slot,4,old,&old);
    return 1;
}
