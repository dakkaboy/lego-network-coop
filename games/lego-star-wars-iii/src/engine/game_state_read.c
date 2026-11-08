#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string.h>
#include "native_scene_readiness.h"

int game_read_current_level(void) {
    const char *area = *(const char *volatile *)0xfb4a20;
    if (!area) return -1;
    const char *level = *(const char *volatile *)(area + 0x220);
    return level ? *(const volatile short *)(level + 0x94) : -1;
}

int game_read_native_profile_ready(void) {
    const char *player = *(const char *volatile *)0xfb4940;
    if (!player || *(const volatile short *)(player + 0xdc0) < 0) return 0;
    const volatile unsigned *resource = *(const volatile unsigned *volatile *)(player + 0xf08);
    if (!resource) return 0;
    (void)*resource;
    return 1;
}

typedef struct NativeReadRegion {
    uintptr_t begin,end;
    int writable;
} NativeReadRegion;
typedef struct NativeReadContext {
    NativeReadRegion regions[32];
    unsigned count,next;
} NativeReadContext;

static int native_read_region(NativeReadContext *context,uintptr_t address,NativeReadRegion *out) {
    for (unsigned i=0;i<context->count;++i) {
        const NativeReadRegion *region=context->regions+i;
        if (address>=region->begin && address<region->end) { *out=*region;return 1; }
    }
    MEMORY_BASIC_INFORMATION memory;
    if (!VirtualQuery((const void *)address,&memory,sizeof(memory)) || memory.State!=MEM_COMMIT ||
        (memory.Protect&(PAGE_GUARD|PAGE_NOACCESS))) return 0;
    DWORD protection=memory.Protect&0xff;
    int writable=protection==PAGE_READWRITE || protection==PAGE_WRITECOPY ||
        protection==PAGE_EXECUTE_READWRITE || protection==PAGE_EXECUTE_WRITECOPY;
    if (!writable && protection!=PAGE_READONLY && protection!=PAGE_EXECUTE_READ) return 0;
    NativeReadRegion region={(uintptr_t)memory.BaseAddress,(uintptr_t)memory.BaseAddress+memory.RegionSize,writable};
    if (region.begin>address || region.end<=address) return 0;
    unsigned slot;
    if (context->count<32) slot=context->count++;
    else {slot=context->next;context->next=(context->next+1)%32;}
    context->regions[slot]=region;
    *out=region;
    return 1;
}
static int native_read_range(void *user,uint32_t address,size_t bytes,int writable) {
    NativeReadContext *context=(NativeReadContext *)user;
    if (!address || !bytes || bytes>UINT32_MAX-address) return 0;
    const uintptr_t end=(uintptr_t)address+bytes;
    uintptr_t cursor=address;
    while (cursor<end) {
        NativeReadRegion region;
        if (!native_read_region(context,cursor,&region) || (writable && !region.writable)) return 0;
        cursor=region.end;
    }
    return 1;
}
static int native_read_bytes(void *context,uint32_t address,void *out,size_t bytes) {
    (void)context;
    memcpy(out,(const void *)(uintptr_t)address,bytes);
    return 1;
}
int game_read_native_profile_storage_ready(void) {
    NativeReadContext context={0};
    const NativeSceneReadOps ops={&context,native_read_bytes,native_read_range};
    return native_profile_storage_bound(&ops);
}
int game_read_native_scene_input_capability(int level,const void *world) {
    NativeReadContext context={0};
    const NativeSceneReadOps ops={&context,native_read_bytes,native_read_range};
    if ((uintptr_t)world>UINT32_MAX) return GAME_SCENE_NOT_READY;
    return native_scene_input_capability(&ops,level,(uint32_t)(uintptr_t)world);
}
