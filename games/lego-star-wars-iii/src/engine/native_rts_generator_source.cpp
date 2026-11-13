#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "native_rts_generator_source.h"
#include "../net/sync_wire.h"
namespace {
bool readable(const void *p,size_t size){
    auto a=reinterpret_cast<uintptr_t>(p);if(!p || size>UINTPTR_MAX-a)return false;
    const auto end=a+size;
    while(a<end){
        MEMORY_BASIC_INFORMATION m;
        if(!VirtualQuery(reinterpret_cast<void *>(a),&m,sizeof m) || m.State!=MEM_COMMIT || (m.Protect&(PAGE_GUARD|PAGE_NOACCESS)))return false;
        const auto begin=reinterpret_cast<uintptr_t>(m.BaseAddress);
        if(m.RegionSize>UINTPTR_MAX-begin || begin+m.RegionSize<=a)return false;
        a=begin+m.RegionSize;
    }
    return true;
}
template<class T>T field(const void *p,unsigned offset){T value;std::memcpy(&value,static_cast<const unsigned char *>(p)+offset,sizeof value);return value;}
}
int native_rts_generator_source(void *object,NativeRtsGeneratorSource *out){
 if(!out || !readable(object,0x2a8))return 0;
 NativeRtsGeneratorSource s{};s.object=object;s.object_class=field<uint32_t>(object,0);
 s.team=field<void *>(object,0x28);s.index=field<uint32_t>(object,0x250);s.side=field<uint32_t>(object,0x254);
 if(s.object_class<0x400000 || s.object_class>=0xb00000 || s.index>=8 || s.side>=2 ||
    !readable(s.team,0x10d4) || field<uint32_t>(s.team,0)!=0xaef0fc)return 0;
 s.descriptor=field<void *>(s.team,0x1c);s.resource=field<void *>(s.team,0x10d0);
 s.world=*reinterpret_cast<void **>(0xfb4a20);s.engine=*reinterpret_cast<void **>(0xfb0afc);
 if(!readable(s.engine,0xe10) || !s.world || !readable(s.descriptor,0x34) || !readable(s.resource,0x10) || field<void *>(s.resource,0xc)!=s.world)return 0;
 s.team_slot=field<uint32_t>(s.descriptor,0x30);if(s.team_slot>=SYNC_MAX_RTS_TEAMS)return 0;
 *out=s;return 1;
}
int native_rts_generator_source_live(const NativeRtsGeneratorSource *s){
 NativeRtsGeneratorSource now{};return s && native_rts_generator_source(s->object,&now) && !std::memcmp(s,&now,sizeof now);
}
