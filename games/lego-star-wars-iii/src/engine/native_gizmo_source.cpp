#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "native_gizmo_source.h"

namespace {
using Byte=unsigned char;
struct ReadContext {
    struct Region {uintptr_t first,last,allocation;DWORD state,protection;};
    Region regions[32]{};
    unsigned count=0;
    uintptr_t image=reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr));
    bool region(uintptr_t address,Region &result) {
        for(unsigned i=0;i<count;++i) if(address>=regions[i].first && address<regions[i].last) {
            result=regions[i];return true;
        }
        MEMORY_BASIC_INFORMATION m;
        if(!VirtualQuery(reinterpret_cast<const void *>(address),&m,sizeof m))return false;
        const uintptr_t first=reinterpret_cast<uintptr_t>(m.BaseAddress),last=first+m.RegionSize;
        if(last<=first)return false;
        result={first,last,reinterpret_cast<uintptr_t>(m.AllocationBase),m.State,m.Protect};
        if(count<32)regions[count++]=result;
        return true;
    }
    bool readable(const void *pointer,size_t bytes) {
        auto first=reinterpret_cast<uintptr_t>(pointer);const auto last=first+bytes;
        if(!pointer || !bytes || last<first)return false;
        while(first<last) {
            Region r;
            if(!region(first,r) || r.state!=MEM_COMMIT || (r.protection&(PAGE_GUARD|PAGE_NOACCESS)))return false;
            first=r.last<last?r.last:last;
        }
        return true;
    }
    template<class T>T get(const void *pointer,size_t offset=0) {
        T value;std::memcpy(&value,static_cast<const Byte *>(pointer)+offset,sizeof value);return value;
    }
    Byte *pointer(const void *base,size_t offset=0){return get<Byte *>(base,offset);}
    bool image_class(const void *object,uint32_t &rva) {
        if(!readable(object,4))return false;
        const auto address=get<uintptr_t>(object);Region r;
        if(address<=image || !region(address,r) || r.allocation!=image || r.state!=MEM_COMMIT ||
           (r.protection&(PAGE_GUARD|PAGE_NOACCESS)))return false;
        rva=static_cast<uint32_t>(address-image);return true;
    }
};
struct Hash {
    uint32_t words[4]={2166136261u,0x9e3779b9u,0x85ebca6bu,0xc2b2ae35u};
    void byte(unsigned char value){for(unsigned i=0;i<4;++i)words[i]=(words[i]^value)*(16777619u+2*i);}
    void number(uint32_t value){for(unsigned i=0;i<4;++i)byte(value>>(8*i));}
    bool text(ReadContext &read,const Byte *value,unsigned capacity,bool require_terminator) {
        unsigned length=0;
        for(;length<capacity;++length) {
            if(!read.readable(value+length,1))return false;
            if(!value[length])break;
        }
        if(require_terminator && (!length || length==capacity))return false;
        number(length);for(unsigned i=0;i<length;++i)byte(value[i]);return true;
    }
};
bool snapshot(void *manager,void *gizmo,NativeGizmoSource &s) {
    s={};ReadContext read;
    s.world=read.pointer(reinterpret_cast<void *>(0xfb4a20));
    s.registry=read.pointer(reinterpret_cast<void *>(0xe90184));
    s.manager=manager;s.gizmo=gizmo;
    if(!read.readable(s.world,0x22e8) || !read.readable(s.registry,0x2c) ||
       !read.readable(gizmo,0x80) || !read.readable(manager,0x28) ||
       !read.image_class(gizmo,s.gizmo_class) || !read.image_class(manager,s.manager_class))return false;
    s.container=read.pointer(s.world,0x22e4);s.handle=read.pointer(s.world,0x400);
    if(!read.readable(s.container,0x10) || read.pointer(s.container,0xc)!=s.world || !read.readable(s.handle,4))return false;
    s.table=read.pointer(s.handle);
    const auto count=read.get<uint32_t>(s.registry,0x28);
    if(!count || count>4096 || !read.readable(s.table,count*4))return false;
    unsigned managers=0;
    for(unsigned i=0;i<count;++i)if(read.pointer(s.table,i*4)==manager){s.manager_index=i;++managers;}
    if(managers!=1)return false;
    s.head=read.pointer(manager,0x24);
    auto *node=static_cast<Byte *>(s.head);unsigned matches=0;
    while(node && s.count<65536) {
        if(!read.readable(node,0x28))return false;
        if(node==gizmo){s.ordinal=s.count;++matches;}
        node=read.pointer(node,0x24);++s.count;
    }
    if(node || matches!=1)return false;
    Hash hash;
    if(!hash.text(read,static_cast<Byte *>(s.world)+0x81,512,true) ||
       !hash.text(read,static_cast<Byte *>(gizmo)+0x30,32,false))return false;
    hash.number(s.manager_class);hash.number(s.gizmo_class);hash.number(s.manager_index);hash.number(s.ordinal);
    std::memcpy(s.key,hash.words,sizeof s.key);return true;
}
}
bool native_gizmo_source_resolve(void *manager,void *gizmo,NativeGizmoSource &source) {
    const DWORD error=GetLastError();const bool result=snapshot(manager,gizmo,source);SetLastError(error);return result;
}
bool native_gizmo_source_revalidate(const NativeGizmoSource &source) {
    const DWORD error=GetLastError();NativeGizmoSource current;
    const bool result=snapshot(source.manager,source.gizmo,current) && !std::memcmp(&source,&current,sizeof source);
    SetLastError(error);return result;
}
bool native_gizmo_source_find(void *gizmo,uintptr_t native_update,NativeGizmoSource &source) {
    const DWORD error=GetLastError();ReadContext read;source={};bool found=false;
    auto *world=read.pointer(reinterpret_cast<void *>(0xfb4a20));
    auto *registry=read.pointer(reinterpret_cast<void *>(0xe90184));
    if(read.readable(world,0x404) && read.readable(registry,0x2c)) {
        auto *handle=read.pointer(world,0x400);
        const auto count=read.get<uint32_t>(registry,0x28);
        if(read.readable(handle,4) && count && count<=4096) {
            auto *table=read.pointer(handle);
            if(read.readable(table,count*4))for(unsigned i=0;i<count;++i) {
                auto *manager=read.pointer(table,i*4);uint32_t type;
                if(!read.image_class(manager,type))continue;
                auto *vtable=read.pointer(manager);
                if(!read.readable(vtable,0x44) || read.get<uintptr_t>(vtable,0x40)!=native_update)continue;
                NativeGizmoSource candidate;
                if(!snapshot(manager,gizmo,candidate))continue;
                if(found){found=false;source={};break;}
                source=candidate;found=true;
            }
        }
    }
    SetLastError(error);return found;
}
