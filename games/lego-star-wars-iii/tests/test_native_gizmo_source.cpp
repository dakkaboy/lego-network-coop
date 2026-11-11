#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstring>
#include "../src/engine/native_gizmo_source.h"

__attribute__((used)) static unsigned char native_image[0x1200000];
static unsigned char manager_class[0x44],gizmo_class[16];
static void put(void *p,unsigned offset,uintptr_t value){std::memcpy(static_cast<unsigned char *>(p)+offset,&value,4);}
struct World {
    unsigned char world[0x22e8]{},container[16]{},registry[0x2c]{},manager[0x28]{},gizmos[2][0x80]{};
    void *table[3]{},*handle=table;
    World() {
        put(world,0x22e4,reinterpret_cast<uintptr_t>(container));put(container,12,reinterpret_cast<uintptr_t>(world));
        put(world,0x400,reinterpret_cast<uintptr_t>(&handle));put(registry,0x28,3);
        std::memcpy(world+0x81,"NativeMission",14);put(manager,0,reinterpret_cast<uintptr_t>(manager_class));
        table[1]=manager;put(manager,0x24,reinterpret_cast<uintptr_t>(gizmos[0]));
        for(auto &g:gizmos){put(g,0,reinterpret_cast<uintptr_t>(gizmo_class));std::memcpy(g+0x30,"SameAuthoredName",17);}
        put(gizmos[0],0x24,reinterpret_cast<uintptr_t>(gizmos[1]));
    }
    void bind(){put(reinterpret_cast<void *>(0xfb4a20),0,reinterpret_cast<uintptr_t>(world));put(reinterpret_cast<void *>(0xe90184),0,reinterpret_cast<uintptr_t>(registry));}
};
int main() {
    assert(reinterpret_cast<uintptr_t>(native_image)<0xfb0000 && reinterpret_cast<uintptr_t>(native_image)+sizeof native_image>0xfc0000);
    World a,b;NativeGizmoSource first,second,relocated;
    a.bind();SetLastError(123);
    put(manager_class,0x40,0x838260);
    assert(native_gizmo_source_find(a.gizmos[0],0x838260,relocated) && GetLastError()==123);
    assert(!native_gizmo_source_find(a.gizmos[0],0x838261,relocated));
    assert(native_gizmo_source_resolve(a.manager,a.gizmos[0],first) && GetLastError()==123 && first.ordinal==0 && first.count==2);
    assert(native_gizmo_source_resolve(a.manager,a.gizmos[1],second) && second.ordinal==1 && std::memcmp(first.key,second.key,sizeof first.key));
    assert(native_gizmo_source_revalidate(first));a.gizmos[0][0x62]=3;assert(native_gizmo_source_revalidate(first));
    b.bind();assert(!native_gizmo_source_revalidate(first));
    assert(native_gizmo_source_resolve(b.manager,b.gizmos[0],relocated) && !std::memcmp(first.key,relocated.key,sizeof first.key));
    b.world[0x81]='X';assert(native_gizmo_source_resolve(b.manager,b.gizmos[0],relocated) && std::memcmp(first.key,relocated.key,sizeof first.key));
    b.world[0x81]='N';
    b.table[0]=b.manager;assert(!native_gizmo_source_resolve(b.manager,b.gizmos[0],relocated));b.table[0]=nullptr;
    put(b.container,12,0);assert(!native_gizmo_source_resolve(b.manager,b.gizmos[0],relocated));put(b.container,12,reinterpret_cast<uintptr_t>(b.world));
    assert(!native_gizmo_source_resolve(b.manager,a.gizmos[0],relocated));
    put(b.gizmos[1],0x24,reinterpret_cast<uintptr_t>(b.gizmos[0]));assert(!native_gizmo_source_resolve(b.manager,b.gizmos[0],relocated));
    put(b.gizmos[1],0x24,0);put(b.gizmos[0],0,1);assert(!native_gizmo_source_resolve(b.manager,b.gizmos[0],relocated));
    puts("Native gizmo identity: relocated peers, duplicate names, native membership, world ownership and stale witnesses passed.");
}
