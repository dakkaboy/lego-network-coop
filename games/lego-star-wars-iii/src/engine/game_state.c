#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include "game_state.h"
#include "../net/lan.h"
#include "../sync/game_sync.h"
#include "../sync/preload_state.h"
#include "../sync/profile_bootstrap_state.h"
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
static ProfileBootstrapHostState initial_profile;
static ProfileBootstrapClientState received_profile;
static unsigned char initial_profile_staging[SYNC_PROFILE_BYTES];
static uint32_t profile_session;
static int force_requested,force_loading_seen;
static uint32_t requested_native_entry=1;
static volatile LONG tick_requested=-1;
static int tick_seen_gameplay,initial_request_completed;
static uint32_t request_serial=1,accepted_serial;
static uint32_t last_gameplay_session;
static int committed_level=-1;
static int transition_waiting;
static struct {
    uint32_t session,epoch;
    int level;
} hub_return;
static void next_request_serial(void){if(!++request_serial)++request_serial;}
static void commit_target(int level,uint32_t serial,int transitioning);
static void host_publication(int current,int playing,int pending);
__declspec(dllexport) volatile LONG clonewars_transition_in_tick;
__declspec(dllexport) volatile uint32_t clonewars_transition_context[60];
__declspec(dllexport) volatile uint32_t clonewars_transition_debug[12];
__declspec(dllexport) volatile uint32_t clonewars_profile_bootstrap_debug[16];

static int accessible(const void *pointer, SIZE_T bytes) {
    MEMORY_BASIC_INFORMATION info;
    if (!pointer || !VirtualQuery(pointer,&info,sizeof(info))) return 0;
    return info.State == MEM_COMMIT && !(info.Protect & (PAGE_NOACCESS|PAGE_GUARD)) &&
           (uintptr_t)pointer+bytes <= (uintptr_t)info.BaseAddress+info.RegionSize;
}

static char *native_level_definition(int level) {
    char *catalog = *(char **)0xfb8404;
    unsigned count = *(unsigned *)0xfb8410;
    if (!catalog || level < 0 || (unsigned)level >= count || count > 4096) return NULL;
    char *definition = catalog + level * 0x1b0;
    return accessible(definition,0x1b0) && *(int16_t *)(definition+0x94) == level ? definition : NULL;
}

typedef struct NativePlayedScene {
    struct NativePlayedScene *next, *previous;
    const char *descriptor;
} NativePlayedScene;

typedef struct NativePlayedScenes {
    NativePlayedScene *first, *last;
    uint32_t count;
} NativePlayedScenes;

static int native_scene_chain_contains(const char *scene,const char *descriptor) {
    for (unsigned i=0;scene && i<=UINT16_MAX;++i) {
        if (scene==descriptor) return 1;
        if (!accessible(scene,0x24)) break;
        scene=*(const char *const *)(scene+0x20);
    }
    return 0;
}

void * __attribute__((thiscall)) game_native_scene_entry(void *manager,int level,int selector) {
    typedef void *(__attribute__((thiscall)) *FindScene)(void *,int,int);
    void *scene=((FindScene)0x7b8630)(manager,level,selector);
    const uint32_t cinematic_section_flags=0xe0;
    if (!scene || !force_requested || !force_loading_seen ||
        InterlockedCompareExchange(&requested,0,0)!=level || !game_network_level_authorized(level) ||
        manager!=*(void **)0xe901f4) return scene;
    const char *definition=native_level_definition(level);
    if (!definition || !(*(const uint32_t *)(definition+0x50)&cinematic_section_flags) ||
        !accessible(manager,0x84)) return scene;

    // Unloading an interrupted scene marks its continuations as played before this lookup runs.
    NativePlayedScenes *history=(NativePlayedScenes *)((char *)manager+0x78);
    typedef void (__attribute__((thiscall)) *Unlink)(NativePlayedScenes *,NativePlayedScene *);
    typedef void (__attribute__((thiscall)) *Clear)(NativePlayedScenes *);
    NativePlayedScene *entry=history->first;
    for (uint32_t remaining=history->count;remaining && accessible(entry,sizeof(*entry));--remaining) {
        NativePlayedScene *next=entry->next;
        if (native_scene_chain_contains(scene,entry->descriptor)) {
            ((Unlink)0x654f00)(history,entry);
            NativePlayedScenes retired={entry,entry,1};
            ((Clear)0x7e0220)(&retired);
        }
        entry=next;
    }
    return scene;
}

static int native_hub_destination(void) {
    const uint32_t hub_level_flag=0x1000000;
    if (lan_status()!=LAN_CONNECTED || !lan_is_host() || game_sync_status()!=2 ||
        !game_native_profile_ready() || *(int *)0xe6e61c>=0 || *(uint8_t *)0xfbc161 ||
        InterlockedCompareExchange(&requested,0,0)>=0) return -1;
    char *root=*(char **)0xfb2e60;
    if (!accessible(root,0x1b7c) || *(int *)(root+0x1b78)!=0xe ||
        !accessible(*(void **)0xfbc114,4) || !accessible(*(void **)0xfb087c,4)) return -1;
    const uintptr_t *table=*(const uintptr_t **)root;
    if (!accessible(table,0x188) || table[0x184/4]!=0x4230e0) return -1;
    typedef const char *(__attribute__((thiscall)) *ReturnDestination)(void *);
    const char *definition=((ReturnDestination)table[0x184/4])(root);
    if (!accessible(definition,0x1b0) || !(*(const uint32_t *)(definition+0x50)&hub_level_flag)) return -1;
    const int level=*(const int16_t *)(definition+0x94);
    return level!=game_current_level() && definition==native_level_definition(level) ? level : -1;
}

int game_can_return_to_hub(void) { return native_hub_destination()>=0; }

int game_request_return_to_hub(void) {
    if (!game_can_return_to_hub()) return 0;
    hub_return.session=lan_session_serial();
    hub_return.epoch=game_sync_epoch();
    hub_return.level=game_current_level();
    return 1;
}

static int is_native_titles(int level) {
    char *titles = *(char **)0xfb8414;
    return accessible(titles,0x96) && *(int16_t *)(titles+0x94) == level;
}

static int native_profile_or_partyless_scene_ready(void) {
    if (game_native_profile_ready()) return 1;
    return game_native_scene_input_capability(game_current_level(),*(void **)0xfb4a20)==GAME_SCENE_NO_PARTY_INPUT;
}

int game_network_level_valid(int level) {
    char *definition = native_level_definition(level);
    char *titles = *(char **)0xfb8414;
    return definition && titles && definition != titles;
}
int game_network_world_valid(int level,const void *world) {
    return game_network_level_valid(level) && accessible(world,0x224) &&
        *(char *const *)((const char *)world+0x220)==native_level_definition(level);
}
int game_network_world_targeted(int level) {
    int desired=InterlockedCompareExchange(&requested,0,0);
    return desired<0 || desired==level;
}
int game_native_loader_idle(void) {
    const uint32_t queued=*(volatile uint32_t *)0xeb0d18;
    const uintptr_t active=*(volatile uintptr_t *)0xeb0d20;
    MemoryBarrier();
    return native_jobs_idle(queued,active,*(volatile uint32_t *)0xeb0d18,*(volatile uintptr_t *)0xeb0d20);
}

int game_actor_count(void) {
    unsigned int count = *(unsigned int *)0xfb2e3c;
    return count <= 4096 ? (int)count : 0;
}

void game_request_level(int level) {
    if (level >= 0 && level < 4096) {
        if (InterlockedCompareExchange(&requested,0,0)!=level){
            next_request_serial();accepted_serial=0;force_requested=force_loading_seen=0;requested_native_entry=1;
            if(!lan_is_host())lan_publish_ready(0);
        }
        InterlockedExchange(&requested,level);
    }
}
void game_request_reload(int level) {
    if(level<0||level>=4096)return;
    next_request_serial();accepted_serial=0;
    force_requested=1;force_loading_seen=0;last_requested=-1;
    requested_native_entry=1;
    InterlockedExchange(&requested,level);
    if(!lan_is_host())lan_publish_ready(0);
}
void game_cancel_level_request(void) {
    if(InterlockedCompareExchange(&requested,0,0)<0 && InterlockedCompareExchange(&tick_requested,0,0)<0 && !force_requested)return;
    next_request_serial();accepted_serial=0;force_requested=force_loading_seen=0;last_requested=-1;
    requested_native_entry=1;
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
    if(lan_status()!=LAN_CONNECTED||!lan_is_host()||!game_network_level_valid(level))return;
    if(serial&&(serial!=request_serial||InterlockedCompareExchange(&requested,0,0)!=level))return;
    // The outgoing native tick may have queued assets for the destination.
    if(game_sync_transition_waiting(level,transitioning)){transition_waiting=1;return;}
    const uint32_t session=lan_session_serial(),previous_epoch=game_sync_epoch();
    const int capture=transitioning || !initial_profile.captured || initial_profile.context.session!=session ||
        initial_profile.context.epoch!=previous_epoch || initial_profile.context.level!=level;
    int source_level=-1,source_phase=-1;uint32_t source_clock=0;
    if(capture){
        unsigned char *profile=*(unsigned char **)0xfbd8bc;
        if(!game_native_profile_storage_ready() || !accessible(profile,SYNC_PROFILE_BYTES) ||
           profile!=*(unsigned char **)0xfbd8bc){lan_publish_ready(0);++clonewars_profile_bootstrap_debug[13];return;}
        memcpy(initial_profile_staging,profile,SYNC_PROFILE_BYTES);
        source_level=game_current_level();source_clock=*(uint32_t *)0xfb4b6c;
        char *root=*(char **)0xfb2e60;
        if(accessible(root,0x1b7c))source_phase=*(int *)(root+0x1b78);
    }
    committed_level=level;if(serial)accepted_serial=serial;
    game_sync_poll_epoch(level,transitioning);
    const ProfileBootstrapContext context={session,game_sync_epoch(),level};
    if(session!=lan_session_serial() || !profile_bootstrap_context_valid(&context)){lan_publish_ready(0);return;}
    if(!initial_profile.captured || initial_profile.context.session!=session || initial_profile.context.epoch!=context.epoch || initial_profile.context.level!=level){
        if(!capture || !profile_bootstrap_host_bind(&initial_profile,&context) ||
           !profile_bootstrap_host_capture(&initial_profile,&context,initial_profile_staging,SYNC_PROFILE_BYTES,0)){
            lan_publish_ready(0);++clonewars_profile_bootstrap_debug[13];return;
        }
        profile_checked=profile_sent=profile_epoch=profile_hash=0;
        clonewars_profile_bootstrap_debug[0]=context.epoch;clonewars_profile_bootstrap_debug[1]=level;
        clonewars_profile_bootstrap_debug[2]=session;clonewars_profile_bootstrap_debug[3]=source_level;
        clonewars_profile_bootstrap_debug[4]=source_phase;clonewars_profile_bootstrap_debug[5]=source_clock;
        clonewars_profile_bootstrap_debug[6]=initial_profile.initial.checksum;
        clonewars_profile_bootstrap_debug[7]=initial_profile.initial.sequence;
    }
    lan_publish_transition(game_sync_epoch(),level,game_sync_transition_entry());
}
static void host_publication(int current,int playing,int pending) {
    int desired=InterlockedCompareExchange(&requested,0,0);
    if(desired>=0){
        if(accepted_serial==request_serial&&committed_level==desired)commit_target(desired,request_serial,pending>=0);
        else if(game_sync_transition_waiting(desired,1))transition_waiting=1;
        else if(pending==desired)commit_target(desired,request_serial,1);
        else lan_publish_ready(0);
        return;
    }
    if(game_network_level_valid(pending)){commit_target(pending,0,1);return;}
    if(playing&&native_profile_or_partyless_scene_ready()&&game_network_level_valid(current)){commit_target(current,0,0);return;}
    if(pending<0&&is_native_titles(current)){
        committed_level=-1;accepted_serial=0;game_sync_poll_epoch(-1,0);
        lan_publish_transition(0,-1,0);lan_publish_ready(0);
    }
}

int game_load_status(void) { return InterlockedCompareExchange(&load_status,0,0); }
int game_network_profile_ready(void) {
    int level=game_network_target_level();
    const ProfileBootstrapContext context={lan_session_serial(),game_sync_epoch(),level};
    if(!game_network_level_authorized(level))return 0;
    if(lan_is_host())return initial_profile.captured==1 && initial_profile.context.session==context.session &&
        initial_profile.context.epoch==context.epoch && initial_profile.context.level==level;
    return profile_bootstrap_client_is_applied(&received_profile,&context);
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
    if (lan_status()!=LAN_CONNECTED) {
        profile_hash=profile_sent=profile_checked=profile_epoch=profile_session=0;
        profile_bootstrap_host_reset(&initial_profile);profile_bootstrap_client_reset(&received_profile);return;
    }
    const uint32_t session=lan_session_serial();
    if(profile_session!=session){profile_hash=profile_sent=profile_checked=profile_epoch=0;profile_session=session;}
    uint32_t epoch=game_sync_epoch();
    if (!epoch) return;
    const int level=game_network_target_level();
    const ProfileBootstrapContext context={session,epoch,level};
    if(!profile_bootstrap_context_valid(&context)||!game_network_level_authorized(level))return;
    unsigned char *profile=*(unsigned char **)0xfbd8bc;
    if (!game_native_profile_storage_ready() || !accessible(profile,SYNC_PROFILE_BYTES)) return;
    if (lan_is_host()) {
        DWORD now=GetTickCount();
        if (now-profile_checked<250) return;
        profile_checked=now;
        const SyncProfile *initial=profile_bootstrap_host_initial(&initial_profile,&context);
        if(!initial)return;
        const int live=game_sync_scene_ready(level) && game_sync_sequence()>0;
        const unsigned char *data=live?profile:initial->data;
        uint32_t hash=sync_checksum(data+0x40,SYNC_PROFILE_BYTES-0x40);
        if (profile_epoch==epoch && profile_sent && hash==profile_hash && now-profile_sent<2000) return;
        profile_packet.epoch=epoch; profile_packet.sequence=live?game_sync_sequence():0; profile_packet.level=level;
        memcpy(profile_packet.data,data,SYNC_PROFILE_BYTES);
        profile_packet.checksum=sync_checksum(profile_packet.data,SYNC_PROFILE_BYTES);
        lan_publish_profile(&profile_packet); profile_hash=hash; profile_sent=now; profile_epoch=epoch;
        clonewars_profile_bootstrap_debug[8]=profile_packet.checksum;clonewars_profile_bootstrap_debug[11]=live;
    } else if (native_profile_or_partyless_scene_ready()) {
        if(received_profile.context.session!=session || received_profile.context.epoch!=epoch || received_profile.context.level!=level){
            clonewars_profile_bootstrap_debug[0]=epoch;clonewars_profile_bootstrap_debug[1]=level;
            clonewars_profile_bootstrap_debug[2]=session;
            clonewars_profile_bootstrap_debug[10]=clonewars_profile_bootstrap_debug[14]=clonewars_profile_bootstrap_debug[15]=0;
        }
        if(!profile_bootstrap_client_bind(&received_profile,&context))return;
        const int sealed=game_sync_scene_ready(level);
        if(!profile_bootstrap_client_should_apply(&received_profile,&context,sealed))return;
        uint32_t sequence=game_sync_sequence();
        if (!sequence) sequence=UINT32_MAX;
        if (lan_receive_profile(&profile_packet,sequence) && profile_packet.level==game_network_target_level() &&
            profile_packet.epoch==game_sync_epoch() &&
            profile_bootstrap_client_accepts_packet(&received_profile,&context,&profile_packet,sealed)) {
            /* The native save stream writes this pointer-free block verbatim.
               The configuration header remains local; bootstrap uses no save slot. */
            if (memcmp(profile+0x40,profile_packet.data+0x40,SYNC_PROFILE_BYTES-0x40)) {
                memcpy(profile+0x40,profile_packet.data+0x40,SYNC_PROFILE_BYTES-0x40);
                ((void (*)(void))0x928f10)();
            }
            if(session==lan_session_serial() && epoch==game_sync_epoch() && level==game_network_target_level() &&
               profile_bootstrap_client_mark_applied(&received_profile,&context)){
                clonewars_profile_bootstrap_debug[9]=profile_packet.checksum;
                ++clonewars_profile_bootstrap_debug[10];clonewars_profile_bootstrap_debug[12]=profile_packet.sequence;
                if(!profile_packet.sequence){
                    ++clonewars_profile_bootstrap_debug[14];clonewars_profile_bootstrap_debug[6]=profile_packet.checksum;
                    clonewars_profile_bootstrap_debug[3]=game_current_level();clonewars_profile_bootstrap_debug[5]=*(uint32_t *)0xfb4b6c;
                    char *root=*(char **)0xfb2e60;
                    if(accessible(root,0x1b7c))clonewars_profile_bootstrap_debug[4]=*(uint32_t *)(root+0x1b78);
                }else ++clonewars_profile_bootstrap_debug[15];
            }
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
static void accept_native_transition(int desired,uint32_t serial) {
    if (serial!=request_serial || InterlockedCompareExchange(&requested,0,0)!=desired) return;
    commit_target(desired,serial,1);
    if (force_requested) force_loading_seen=1;
    InterlockedExchange(&load_status,1);
}
static void native_transition(int desired,int stage) {
    if (desired<0 || InterlockedCompareExchange(&requested,0,0)!=desired || !native_profile_or_partyless_scene_ready()) return;
    if(lan_status()==LAN_CONNECTED&&!lan_is_host()&&!game_network_profile_ready())return;
    uint32_t serial=request_serial;
    int pending=*(int *)0xe6e61c;
    if (pending>=0) {
        // The stock trigger can already have queued the destination on this peer.
        if (pending==desired) accept_native_transition(desired,serial);
        return;
    }
    char *root = *(char **)0xfb2e60;
    char *catalog = *(char **)0xfb8404;
    unsigned int count = *(unsigned int *)0xfb8410;
    if (!accessible(root,0x1b7c) || !catalog || desired >= (int)count ||
        !*(void **)0xfbd8bc || !*(void **)0xfb8414) return;
    char *definition = native_level_definition(desired);
    if (!definition) {
        InterlockedExchange(&load_status,-1);
        InterlockedExchange(&requested,-1);
        return;
    }
    int phase = *(int *)(root+0x1b78);
    if (phase != 0xd && phase != 0xe) return;
    if (last_requested == desired && GetTickCount()-last_attempt < 3000) return;
    const int restarting=force_requested && game_current_level()==desired;
    clonewars_transition_debug[0]=(uint32_t)stage;
    clonewars_transition_debug[4]++;
    clonewars_transition_debug[6]=(uint32_t)desired;
    clonewars_transition_debug[7]=(uint32_t)phase;
    clonewars_transition_debug[8]=GetCurrentThreadId();
    clonewars_transition_debug[11]=*(uint32_t *)0xfb4b6c;
    if (stage) ++clonewars_transition_debug[2];
    capture_transition_context(clonewars_transition_context,desired);
    for (unsigned i=40;i<60;++i) clonewars_transition_context[i]=UINT32_MAX;
    if (!requested_native_entry) {
        // A section exit preserves the party; 8BD740 marks a fresh mission and discards that path.
        typedef unsigned char (__attribute__((thiscall)) *QueueSection)(void *,int,int);
        ((QueueSection)0x9097e0)((void *)0xe6e618,desired,0);
    } else {
        typedef void (__attribute__((cdecl)) *EnterMission)(void *,int,int,int);
        ((EnterMission)0x8bd740)(definition,-1,-1,0);
    }
    int accepted=*(int *)0xe6e61c==desired;
    // A fresh Story start retires cached LevelProgress before the loader rebuilds the component list.
    if (accepted && restarting && !*(uint32_t *)0xfb5170) *(uint32_t *)0xfb5170=1;
    capture_transition_context(clonewars_transition_context+20,desired);
    if(serial!=request_serial||InterlockedCompareExchange(&requested,0,0)!=desired)return;
    if (accepted) {
        ++clonewars_transition_debug[3];
        accept_native_transition(desired,serial);
    } else {
        InterlockedExchange(&load_status,1);
    }
    last_requested = desired;
    last_attempt = GetTickCount();
}
void game_native_tick(void) {
    char *root=*(char **)0xfb2e60;
    if (accessible(root,0x1b7c) && *(int *)(root+0x1b78)==0xe && native_profile_or_partyless_scene_ready())
        tick_seen_gameplay=1;
    clonewars_transition_debug[5]=(uint32_t)tick_seen_gameplay;
    clonewars_transition_debug[10]=(uint32_t)initial_request_completed;
    if (hub_return.session) {
        const uint32_t session=hub_return.session;
        hub_return.session=0;
        if (session==lan_session_serial() && hub_return.epoch==game_sync_epoch() &&
            hub_return.level==game_current_level()) {
            const int destination=native_hub_destination();
            static const unsigned char return_prefix[]={0x51,0x8b,0x0d,0x60,0x2e,0xfb,0x00};
            if (destination>=0 && !memcmp((const void *)0x8bc790,return_prefix,sizeof(return_prefix))) {
                ((void (__cdecl *)(void))0x8bc790)();
                if (*(int *)0xe6e61c==destination) host_publication(hub_return.level,1,destination);
                if (transition_waiting) return;
            }
        }
    }
    if (!clonewars_transition_in_tick) return;
    int desired=(int)InterlockedExchange(&tick_requested,-1);
    clonewars_transition_debug[9]=UINT32_MAX;
    if (desired>=0) native_transition(desired,1);
}

static void poll_client_transition(int current,int world_active) {
    const int previous=game_network_target_level();
    const int changed=game_sync_poll_epoch(-1,0);
    const int destination=game_network_target_level();
    if (destination<0) { game_cancel_level_request();return; }
    // Native triggers can arrive before the host publication. The previous target must not pull them back.
    if (!changed) return;
    if (destination!=current) {
        game_request_level(destination);
        if (previous>=0 && !force_requested) requested_native_entry=game_sync_transition_entry();
        return;
    }
    if (world_active && (previous<0 || destination==previous)) {
        game_request_reload(destination);
        return;
    }
    // A new section already loaded natively needs the new epoch, not a second allocation of its world.
    game_cancel_level_request();
}

void game_poll(void) {
    transition_waiting=0;
    int current = game_current_level();
    char *flow_state=*(char **)0xfb2e60;
    int playing=accessible(flow_state,0x1b7c) && *(int *)(flow_state+0x1b78)==0xe;
    int starting=accessible(flow_state,0x1b7c) && *(int *)(flow_state+0x1b78)==0xd &&
        game_network_world_valid(current,*(void **)0xfb4a20);
    if (bootstrap_started && lan_status()==LAN_CONNECTED && !*(unsigned char *)0xeb1a74) {
        int device=*(int *)0xeb1a70;
        if (device>=0 && device<14 && *(unsigned char *)(0xead928+device*144)) {
            typedef void (*Assign)(int,int);
            ((Assign)0x582da0)(0,device);
        }
    }
    int pending_level=*(int *)0xe6e61c;
    if (lan_status() == LAN_CONNECTED) {
        const uint32_t session=lan_session_serial();
        const uint32_t published_epoch=lan_epoch();
        if (published_epoch && published_epoch==game_sync_epoch() && game_sync_status()==2)
            last_gameplay_session=session;
        if (lan_is_host()) {
            // A client joining again loads a new world. The host must bootstrap from the same entry.
            if (session && last_gameplay_session && last_gameplay_session!=session && !published_epoch &&
                (playing||starting) && pending_level<0 && game_network_level_valid(current) &&
                InterlockedCompareExchange(&requested,0,0)<0)
                game_request_reload(current);
            host_publication(current,playing||starting,pending_level);
        } else {
            poll_client_transition(current,playing||starting);
            if(game_network_level_valid(pending_level) && game_sync_epoch_level()==current &&
               game_sync_sequence()){
                transition_waiting=1;
            }
        }
    } else {game_sync_poll_epoch(-1,0);committed_level=-1;accepted_serial=0;}
    if(transition_waiting)return;
    poll_profile();
    lan_publish_ready(game_sync_epoch() && game_network_profile_ready() && (playing||starting||game_sync_scene_ready(current)) &&
                      (game_sync_scene_ready(current)||game_native_loader_idle()) &&
                      ((game_native_profile_ready() && game_actor_count()>0) ||
                       game_native_scene_input_capability(current,*(void **)0xfb4a20)==GAME_SCENE_NO_PARTY_INPUT) &&
                      game_network_level_authorized(current) && game_load_status()!=1 && pending_level<0 && !force_requested);
    int desired = InterlockedCompareExchange(&requested,0,0);
    if (desired < 0) return;
    if (!native_profile_or_partyless_scene_ready()) {
        char *frontend = *(char **)0xfb087c;
        char *storage = *(char **)0xfb0864;
        char *flow = *(char **)0xfb2e60;
        int phase = accessible(flow,0x1b7c) ? *(int *)(flow+0x1b78) : -1;
        if ((!bootstrap_started || (is_native_titles(current) && GetTickCount()-bootstrap_started>3000)) && current >= 0 && (phase == 0xd || phase == 0xe) &&
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
    if (force_requested && pending_level==desired) force_loading_seen=1;
    if (current == desired && pending_level<0 &&
        (playing || (starting && game_sync_scene_initialized(current) && game_native_loader_idle())) &&
        (!force_requested || force_loading_seen)) {
        commit_target(desired,request_serial,0);
        InterlockedExchange(&requested,-1);
        InterlockedExchange(&load_status,2);
        last_requested = -1;
        force_requested=force_loading_seen=0;
        initial_request_completed=1;
        capture_transition_context(clonewars_transition_context+40,desired);
        return;
    }
    if (current==desired && pending_level<0 && starting && (!force_requested||force_loading_seen)) {
        if(lan_status()==LAN_CONNECTED&&lan_is_host()&&accepted_serial!=request_serial)
            commit_target(desired,request_serial,force_requested);
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
int game_transition_waiting(void) { return transition_waiting; }
