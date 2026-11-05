#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include "game_state.h"
#include "../net/lan.h"
#include "../sync/game_sync.h"
#include <string.h>

static volatile LONG requested = -1;
static volatile LONG load_status;
static int last_requested = -1;
static DWORD last_attempt;
static DWORD bootstrap_started;
static SyncProfile profile_packet;
static DWORD profile_checked,profile_sent;
static uint32_t profile_hash;
static uint32_t profile_epoch;
static uint32_t received_profile_epoch;
static int force_requested,force_loading_seen;
static volatile LONG tick_requested=-1;
static int tick_seen_gameplay,initial_request_completed;
static uint32_t request_serial=1,accepted_serial;
static int committed_level=-1;
static void next_request_serial(void){if(!++request_serial)++request_serial;}
static void commit_target(int level,uint32_t serial,int transitioning);
static void host_publication(int current,int playing,int pending);
__declspec(dllexport) volatile LONG clonewars_transition_in_tick;
__declspec(dllexport) volatile LONG clonewars_transition_api;
__declspec(dllexport) volatile LONG clonewars_transition_api_used;
__declspec(dllexport) volatile uint32_t clonewars_transition_context[60];
__declspec(dllexport) volatile uint32_t clonewars_transition_debug[12];

static int profile_ready(void);

static int accessible(const void *pointer, SIZE_T bytes) {
    MEMORY_BASIC_INFORMATION info;
    if (!pointer || !VirtualQuery(pointer,&info,sizeof(info))) return 0;
    return info.State == MEM_COMMIT && !(info.Protect & (PAGE_NOACCESS|PAGE_GUARD)) &&
           (uintptr_t)pointer+bytes <= (uintptr_t)info.BaseAddress+info.RegionSize;
}

int game_current_level(void) {
    char *area = *(char **)0xfb4a20;
    char *level = accessible(area,0x224) ? *(char **)(area+0x220) : NULL;
    return accessible(level,0x98) ? *(short *)(level+0x94) : -1;
}

int game_actor_count(void) {
    unsigned int count = *(unsigned int *)0xfb2e3c;
    return count <= 4096 ? (int)count : 0;
}

static int profile_ready(void) {
    char *player = *(char **)0xfb4940;
    return accessible(player,0x1440) && *(short *)(player+0xdc0) >= 0 &&
           accessible(*(void **)(player+0xf08),4);
}

int game_native_profile_ready(void){return profile_ready();}

void game_request_level(int level) {
    if (level >= 0 && level < 4096) {
        if (InterlockedCompareExchange(&requested,0,0)!=level){next_request_serial();accepted_serial=0;force_requested=force_loading_seen=0;lan_publish_ready(0);}
        InterlockedExchange(&requested,level);
    }
}
void game_request_reload(int level) {
    if(level<0||level>=4096)return;
    next_request_serial();accepted_serial=0;
    force_requested=1;force_loading_seen=0;last_requested=-1;
    InterlockedExchange(&requested,level);lan_publish_ready(0);
}
void game_cancel_level_request(void) {
    if(InterlockedCompareExchange(&requested,0,0)<0 && InterlockedCompareExchange(&tick_requested,0,0)<0 && !force_requested)return;
    next_request_serial();accepted_serial=0;force_requested=force_loading_seen=0;last_requested=-1;
    InterlockedExchange(&requested,-1);InterlockedExchange(&tick_requested,-1);
}
int game_network_target_level(void) {
    if(lan_status()!=LAN_CONNECTED)return -1;
    return lan_is_host()?committed_level:(game_sync_epoch()?game_sync_epoch_level():-1);
}
int game_network_level_authorized(int level) {
    if(level<0||level!=game_network_target_level()||!game_sync_epoch()||game_sync_epoch_level()!=level)return 0;
    return !lan_is_host()||InterlockedCompareExchange(&requested,0,0)<0||accepted_serial==request_serial;
}
static void commit_target(int level,uint32_t serial,int transitioning) {
    if(lan_status()!=LAN_CONNECTED||!lan_is_host()||level<0||level>=290)return;
    if(serial&&(serial!=request_serial||InterlockedCompareExchange(&requested,0,0)!=level))return;
    committed_level=level;if(serial)accepted_serial=serial;
    game_sync_poll_epoch(level,transitioning);
    lan_publish_transition(game_sync_epoch(),level);
}
static void host_publication(int current,int playing,int pending) {
    int desired=InterlockedCompareExchange(&requested,0,0);
    if(desired>=0){
        if(accepted_serial==request_serial&&committed_level==desired)commit_target(desired,request_serial,pending>=0);
        else lan_publish_ready(0);
        return;
    }
    if(pending>=0&&pending<290){commit_target(pending,0,1);return;}
    if(current>=0&&current<290&&playing&&profile_ready()){commit_target(current,0,0);return;}
    if(current>=290&&pending<0){
        committed_level=-1;accepted_serial=0;game_sync_poll_epoch(-1,0);
        lan_publish_transition(0,-1);lan_publish_ready(0);
    }
}

int game_load_status(void) { return InterlockedCompareExchange(&load_status,0,0); }
int game_network_profile_ready(void) {
    int level=game_network_target_level();
    return game_network_level_authorized(level) && (lan_is_host() || received_profile_epoch==game_sync_epoch());
}

int game_target_level(void) {
    int level=InterlockedCompareExchange(&requested,0,0);
    if (level>=0) return level;
    level=*(int *)0xe6e61c;
    if (level>=0 && level<4096) return level;
    level=game_current_level();
    if (level>=0) return level;
    level=*(int *)0xfb8438;
    return level>=0 && level<4096 ? level : -1;
}

static void poll_profile(void) {
    if (lan_status()!=LAN_CONNECTED) { profile_hash=0; profile_sent=0; profile_epoch=received_profile_epoch=0; return; }
    uint32_t epoch=game_sync_epoch();
    if (!epoch) return;
    unsigned char *profile=*(unsigned char **)0xfbd8bc;
    if (!accessible(profile,SYNC_PROFILE_BYTES) || *(uint32_t *)profile!=0x500) return;
    if (lan_is_host()) {
        DWORD now=GetTickCount();
        if (now-profile_checked<250) return;
        profile_checked=now;
        int level=game_network_target_level();
        if(!game_network_level_authorized(level))return;
        uint32_t hash=sync_checksum(profile+0x40,SYNC_PROFILE_BYTES-0x40);
        if (profile_epoch==epoch && profile_sent && hash==profile_hash && now-profile_sent<2000) return;
        profile_packet.epoch=epoch; profile_packet.sequence=game_sync_sequence(); profile_packet.level=level;
        memcpy(profile_packet.data,profile,SYNC_PROFILE_BYTES);
        profile_packet.checksum=sync_checksum(profile_packet.data,SYNC_PROFILE_BYTES);
        lan_publish_profile(&profile_packet); profile_hash=hash; profile_sent=now; profile_epoch=epoch;
    } else if (profile_ready()) {
        uint32_t sequence=game_sync_sequence();
        if (!sequence) sequence=UINT32_MAX;
        if (lan_receive_profile(&profile_packet,sequence) && profile_packet.level==game_network_target_level() &&
            profile_packet.epoch==game_sync_epoch()) {
            /* The native save stream writes this pointer-free block verbatim.
               The configuration header remains local; bootstrap uses no save slot. */
            if (memcmp(profile+0x40,profile_packet.data+0x40,SYNC_PROFILE_BYTES-0x40)) {
                memcpy(profile+0x40,profile_packet.data+0x40,SYNC_PROFILE_BYTES-0x40);
                ((void (*)(void))0x928f10)();
            }
            received_profile_epoch=epoch;
        }
    }
}

static void capture_transition_context(volatile uint32_t *out,int desired) {
    char *definition=*(char **)0xfb8414;
    uint32_t values[20]={
        (uint32_t)desired,(uint32_t)game_current_level(),
        accessible(definition,0x96) ? (uint32_t)*(int16_t *)(definition+0x94) : UINT32_MAX,
        *(uint32_t *)0xfb840c,*(uint32_t *)0xfc16b0,
        *(uint32_t *)0xfb4c80,*(uint32_t *)0xfb4c84,*(uint32_t *)0xfb4c88,
        *(uint32_t *)0xfb4c94,*(uint32_t *)0xfb4c98,*(uint32_t *)0xfb4c9c,
        *(uint32_t *)0xe6bcc8,*(uint32_t *)0xe6be2c,*(uint32_t *)0xe6be30,
        *(uint32_t *)0xe6c5f0,*(uint32_t *)0xfb8484,*(uint32_t *)0xe6e61c,
        *(uint32_t *)0xfb4a20,*(uint32_t *)0xfb4a1c,*(uint8_t *)0xfbc161
    };
    for (unsigned i=0;i<20;++i) out[i]=values[i];
}
static void native_transition(int desired,int stage) {
    if (desired<0 || InterlockedCompareExchange(&requested,0,0)!=desired || !profile_ready()) return;
    if(lan_status()==LAN_CONNECTED&&!lan_is_host()&&!game_network_profile_ready())return;
    uint32_t serial=request_serial;
    char *root = *(char **)0xfb2e60;
    char *catalog = *(char **)0xfb8404;
    unsigned int count = *(unsigned int *)0xfb8410;
    if (!accessible(root,0x1b7c) || !catalog || desired >= (int)count ||
        !*(void **)0xfbd8bc || !*(void **)0xfb8414) return;
    char *definition = catalog+desired*0x1b0;
    if (!accessible(definition,0x1b0) || *(short *)(definition+0x94) != desired) {
        InterlockedExchange(&load_status,-1);
        InterlockedExchange(&requested,-1);
        return;
    }
    int phase = *(int *)(root+0x1b78);
    if (phase != 0xd && phase != 0xe) return;
    if (last_requested == desired && GetTickCount()-last_attempt < 3000) return;
    clonewars_transition_debug[0]=(uint32_t)stage;
    clonewars_transition_debug[4]++;
    clonewars_transition_debug[6]=(uint32_t)desired;
    clonewars_transition_debug[7]=(uint32_t)phase;
    clonewars_transition_debug[8]=GetCurrentThreadId();
    clonewars_transition_debug[11]=*(uint32_t *)0xfb4b6c;
    if (stage) ++clonewars_transition_debug[2];
    capture_transition_context(clonewars_transition_context,desired);
    for (unsigned i=40;i<60;++i) clonewars_transition_context[i]=UINT32_MAX;
    // Arena requires the mission wrapper's load context before native restoration.
    const int geonosian_arena_level=12;
    int api=desired==geonosian_arena_level || clonewars_transition_api==1;
    clonewars_transition_api_used=api;
    unsigned char accepted;
    if (api) {
        typedef void (__attribute__((cdecl)) *EnterMission)(void *,int,int,int);
        ((EnterMission)0x8bd740)(definition,-1,-1,0);
        accepted=*(int *)0xe6e61c==desired;
    } else {
        typedef unsigned char (__attribute__((thiscall)) *ChangeLevel)(void *,int,int);
        accepted=((ChangeLevel)0x9097e0)((void *)0xe6e618,desired,1);
    }
    capture_transition_context(clonewars_transition_context+20,desired);
    if(serial!=request_serial||InterlockedCompareExchange(&requested,0,0)!=desired)return;
    if (accepted){++clonewars_transition_debug[3];commit_target(desired,serial,1);}
    if (accepted && force_requested) force_loading_seen=1;
    last_requested = desired;
    last_attempt = GetTickCount();
    InterlockedExchange(&load_status,1);
}
void game_native_tick(void) {
    char *root=*(char **)0xfb2e60;
    if (accessible(root,0x1b7c) && *(int *)(root+0x1b78)==0xe && game_actor_count()>0 && profile_ready())
        tick_seen_gameplay=1;
    clonewars_transition_debug[5]=(uint32_t)tick_seen_gameplay;
    clonewars_transition_debug[10]=(uint32_t)initial_request_completed;
    if (!clonewars_transition_in_tick) return;
    int desired=(int)InterlockedExchange(&tick_requested,-1);
    clonewars_transition_debug[9]=UINT32_MAX;
    if (desired>=0) native_transition(desired,1);
}

void game_poll(void) {
    int current = game_current_level();
    char *flow_state=*(char **)0xfb2e60;
    int playing=accessible(flow_state,0x1b7c) && *(int *)(flow_state+0x1b78)==0xe;
    if (bootstrap_started && lan_status()==LAN_CONNECTED && !*(unsigned char *)0xeb1a74) {
        int device=*(int *)0xeb1a70;
        if (device>=0 && device<14 && *(unsigned char *)(0xead928+device*144)) {
            typedef void (*Assign)(int,int);
            ((Assign)0x582da0)(0,device);
        }
    }
    int pending_level=*(int *)0xe6e61c;
    if (lan_status() == LAN_CONNECTED) {
        if (lan_is_host()) {
            host_publication(current,playing,pending_level);
        } else {
            int changed=game_sync_poll_epoch(-1,0);
            int destination=game_network_target_level();
            if(destination<0){game_cancel_level_request();}
            else if (changed && destination==current && playing) game_request_reload(destination);
            else if (destination >= 0 && destination != current) game_request_level(destination);
        }
    } else {game_sync_poll_epoch(-1,0);committed_level=-1;accepted_serial=0;}
    poll_profile();
    lan_publish_ready(game_sync_epoch() && game_network_profile_ready() && playing && profile_ready() && game_actor_count()>0 &&
                      game_network_level_authorized(current) && game_load_status()!=1 && pending_level<0 && !force_requested);
    int desired = InterlockedCompareExchange(&requested,0,0);
    if (desired < 0) return;
    if (!profile_ready()) {
        char *frontend = *(char **)0xfb087c;
        char *storage = *(char **)0xfb0864;
        char *flow = *(char **)0xfb2e60;
        int phase = accessible(flow,0x1b7c) ? *(int *)(flow+0x1b78) : -1;
        if ((!bootstrap_started || (current==290 && GetTickCount()-bootstrap_started>3000)) && current >= 0 && (phase == 0xd || phase == 0xe) &&
            accessible(frontend,0x428) && accessible(storage,0x24)) {
            typedef void (__attribute__((thiscall)) *WithoutSaving)(void *);
            int local_device=*(int *)0xeb1a70;
            if (local_device>=0 && local_device<14 && *(unsigned char *)(0xead928+local_device*144))
                ((void (*)(int,int))0x582da0)(0,local_device);
            *(int *)(frontend+0x414) = 3;
            *(int *)0xe6059c = -1;
            ((WithoutSaving)0x756ea0)(frontend);
            bootstrap_started = GetTickCount();
            InterlockedExchange(&load_status,3);
        }
        return;
    }
    if (force_requested && (pending_level>=0 || !playing)) force_loading_seen=1;
    if (current == desired && pending_level<0 && playing && (!force_requested || force_loading_seen)) {
        commit_target(desired,request_serial,0);
        InterlockedExchange(&requested,-1);
        InterlockedExchange(&load_status,2);
        last_requested = -1;
        force_requested=force_loading_seen=0;
        initial_request_completed=1;
        capture_transition_context(clonewars_transition_context+40,desired);
        return;
    }
    if (last_requested == desired && GetTickCount()-last_attempt < 3000) return;
    if (clonewars_transition_in_tick && tick_seen_gameplay && initial_request_completed) {
        int previous=(int)InterlockedExchange(&tick_requested,desired);
        if (previous!=desired) ++clonewars_transition_debug[1];
        clonewars_transition_debug[9]=(uint32_t)desired;
        return;
    }
    InterlockedExchange(&tick_requested,-1);
    clonewars_transition_debug[9]=UINT32_MAX;
    native_transition(desired,0);
}
