#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "native_global_pack_source.h"

namespace {
bool readable(const void *p,size_t size){
    MEMORY_BASIC_INFORMATION m;const auto address=reinterpret_cast<uintptr_t>(p);
    return p && size<=UINTPTR_MAX-address && VirtualQuery(p,&m,sizeof m) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && address>=reinterpret_cast<uintptr_t>(m.BaseAddress) &&
        address+size-reinterpret_cast<uintptr_t>(m.BaseAddress)<=m.RegionSize;
}
template<class T>T field(const void *p,unsigned offset){T value;std::memcpy(&value,static_cast<const unsigned char *>(p)+offset,sizeof value);return value;}
}

unsigned native_global_pack_registry_count(){
    const auto *bound=reinterpret_cast<const unsigned char *>(0x47699b);
    // The constructor's loop bound describes the native faction registry.
    return readable(bound,3) && bound[0]==0x83 && bound[1]==0xfe && bound[2] && bound[2]<0x80 ? bound[2] : 0;
}

int native_global_pack_source(const void *pack,NativeGlobalPackSource *out){
    const auto count=native_global_pack_registry_count();
    if(!out || !count || !readable(pack,0x144) || field<uint32_t>(pack,0)!=0xadcef0)return 0;
    NativeGlobalPackSource s{};s.pack=pack;s.manager=field<void *>(pack,0xb8);
    s.pool=field<void *>(pack,0xb0);s.definition=field<void *>(pack,0xb4);
    if(!readable(s.manager,0x180+count*4) || field<uint32_t>(s.manager,0)!=0xaded84 ||
       !readable(s.pool,0x24) || field<void *>(s.pool,8)!=s.manager ||
       !readable(s.definition,0x34) || field<uint32_t>(s.definition,0)!=0xad7f74 ||
       field<void *>(s.definition,4)!=s.pool || field<void *>(s.definition,0x10)!=pack ||
       field<void *>(s.definition,0x30)!=s.manager)return 0;
    s.faction=field<uint32_t>(s.definition,0x18);
    if(s.faction>=count || field<void *>(s.manager,0x180+s.faction*4)!=s.definition ||
       field<uint32_t>(pack,0x140)!=s.faction || field<uint32_t>(pack,0x13c)!=field<uint32_t>(s.definition,0x1c))return 0;
    const auto pool_count=field<uint32_t>(s.manager,0x28);
    if(!pool_count || pool_count>UINT16_MAX)return 0;
    const void *node=field<void *>(s.manager,0x20);unsigned matches=0;
    for(unsigned i=0;i<pool_count;++i){
        if(!readable(node,0xc) || field<void *>(node,8)!=s.manager)return 0;
        matches+=node==s.pool;node=field<void *>(node,4);
    }
    if(node || matches!=1)return 0;
    *out=s;return 1;
}
