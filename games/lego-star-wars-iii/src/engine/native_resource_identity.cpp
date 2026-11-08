#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "native_resource_identity.h"

namespace {
using Byte=unsigned char;
struct Region {
    uintptr_t first,last,allocation;
    DWORD state,protection;
};
struct ReadContext {
    Region regions[64]{};
    unsigned count=0,next=0;
    const uintptr_t image=reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr));

    bool region(uintptr_t address,Region &out) {
        for(unsigned i=0;i<count;++i) {
            const auto &r=regions[i];
            if(address>=r.first && address<r.last) {out=r;return true;}
        }
        MEMORY_BASIC_INFORMATION m;
        if(!VirtualQuery(reinterpret_cast<void *>(address),&m,sizeof m))return false;
        const uintptr_t first=reinterpret_cast<uintptr_t>(m.BaseAddress);
        const uintptr_t last=first+m.RegionSize;
        if(last<=first || address<first || address>=last)return false;
        out={first,last,reinterpret_cast<uintptr_t>(m.AllocationBase),m.State,m.Protect};
        if(count<64)regions[count++]=out;
        else {regions[next]=out;next=(next+1)%64;}
        return true;
    }
    bool readable(const void *pointer,size_t length) {
        auto first=reinterpret_cast<uintptr_t>(pointer);
        const auto last=first+length;
        if(!pointer || !length || last<first)return false;
        while(first<last) {
            Region r;
            if(!region(first,r) || r.state!=MEM_COMMIT || (r.protection&(PAGE_NOACCESS|PAGE_GUARD)))return false;
            first=r.last<last?r.last:last;
        }
        return true;
    }
    bool image_offset(const void *pointer,uint32_t &offset) {
        const auto address=reinterpret_cast<uintptr_t>(pointer);
        Region r;
        if(address<=image || !region(address,r) || r.state!=MEM_COMMIT || r.allocation!=image ||
            (r.protection&(PAGE_NOACCESS|PAGE_GUARD)))return false;
        offset=static_cast<uint32_t>(address-image);return true;
    }
    unsigned name_length(const Byte *name) {
        if(!name)return 0;
        unsigned length=0;
        while(length<1024) {
            Region r;
            if(!region(reinterpret_cast<uintptr_t>(name+length),r) || r.state!=MEM_COMMIT ||
                (r.protection&(PAGE_NOACCESS|PAGE_GUARD)))return 0;
            const auto available=r.last-reinterpret_cast<uintptr_t>(name+length);
            const unsigned limit=available>1024-length?1024:length+static_cast<unsigned>(available);
            while(length<limit)if(!name[length++])return length>1?length:0;
        }
        return 0;
    }
    Byte *native(uint32_t address)const{return reinterpret_cast<Byte *>(image+address-0x400000u);}
};
template<class T>T get(const void *pointer,size_t offset=0) {
    T value;std::memcpy(&value,static_cast<const Byte *>(pointer)+offset,sizeof value);return value;
}
void key_bytes(const void *pointer,unsigned length,uint32_t key[4]) {
    const auto *bytes=static_cast<const Byte *>(pointer);
    for(unsigned n=0;n<length;++n)
        for(unsigned i=0;i<4;++i)key[i]=(key[i]^bytes[n])*(16777619u+2u*i);
}
void key_word(uint32_t value,uint32_t key[4]) {
    for(unsigned byte=0;byte<4;++byte)
        for(unsigned i=0;i<4;++i)key[i]=(key[i]^((value>>(byte*8))&255u))*(16777619u+2u*i);
}
bool same_name(ReadContext &read,const Byte *first,const Byte *second) {
    const unsigned length=read.name_length(first);
    return length && read.name_length(second)==length && !std::memcmp(first,second,length);
}
bool snapshot(ReadContext &read,void *current_world,void *value,NativeResourceIdentity &out) {
    NativeResourceIdentity result{};
    result.world=current_world;result.actual_resource=value;
    if(!read.readable(read.native(0xfb4a20),4) || get<void *>(read.native(0xfb4a20))!=current_world ||
        !read.readable(read.native(0xf9dd10),4))return false;
    result.registry=get<void *>(read.native(0xf9dd10));
    if(!read.readable(value,0x738) || !read.readable(result.registry,8+199*4) || !read.readable(current_world,0x82))return false;
    result.runtime=get<void *>(value,0x6f8);result.root_resource=get<void *>(value,0x734);
    if(result.root_resource) {
        if(!read.readable(result.root_resource,0x6fc) || get<void *>(result.root_resource,0x6f8)!=result.runtime)return false;
    }else result.root_resource=value;
    for(unsigned i=0;i<199;++i) {
        auto *entry=get<Byte *>(result.registry,8+i*4);
        if(!entry)continue;
        if(!read.readable(entry,0x58))return false;
        if(get<void *>(entry,0x4c)!=result.root_resource)continue;
        if(result.entry)return false;
        result.entry=entry;
    }
    if(!result.entry)return false;
    auto *table=get<void *>(result.entry);
    uint32_t getter;
    if(!read.readable(table,8) || !read.image_offset(get<void *>(table,4),getter) || getter!=0x5cf20 ||
        !read.readable(result.runtime,0x70))return false;
    result.name=get<void *>(result.entry,0x40);result.filename=get<void *>(result.entry,0x34);
    result.container=get<void *>(result.entry,0x54);
    if(!read.readable(result.container,0x10) || !read.image_offset(get<void *>(result.container),result.container_class))return false;
    result.source_world=get<void *>(result.container,0xc);result.source_world_present=result.source_world!=nullptr;
    if(result.source_world && (!read.readable(result.source_world,0x22e8) || get<void *>(result.source_world,0x22e4)!=result.container))return false;
    result.array=get<void *>(result.runtime,0x6c);
    for(unsigned i=0;i<199;++i) {
        auto *other=get<Byte *>(result.registry,8+i*4);
        if(!other || other==result.entry)continue;
        if(!read.readable(other,0x58))return false;
        if(!get<void *>(other,0x4c))continue;
        if(!same_name(read,static_cast<Byte *>(result.filename),get<Byte *>(other,0x34)) ||
            !same_name(read,static_cast<Byte *>(result.name),get<Byte *>(other,0x40)))continue;
        auto *owner=get<Byte *>(other,0x54);
        uint32_t owner_class;
        if(!read.readable(owner,0x10) || !read.image_offset(get<void *>(owner),owner_class))return false;
        auto *area=get<Byte *>(owner,0xc);
        if(area && (!read.readable(area,0x22e8) || get<void *>(area,0x22e4)!=owner))return false;
        if(owner_class==result.container_class && (!!area==!!result.source_world) &&
            (!area || same_name(read,static_cast<Byte *>(result.source_world)+0x81,area+0x81)))return false;
    }
    result.key[0]=2166136261u;result.key[1]=0x9e3779b9u;result.key[2]=0x85ebca6bu;result.key[3]=0xc2b2ae35u;
    key_word(result.container_class,result.key);key_word(result.source_world_present,result.key);
    result.world_name_length=read.name_length(static_cast<Byte *>(result.world)+0x81);
    if(!result.world_name_length)return false;
    key_bytes(static_cast<Byte *>(result.world)+0x81,result.world_name_length,result.key);
    if(result.source_world) {
        result.source_world_name_length=read.name_length(static_cast<Byte *>(result.source_world)+0x81);
        if(!result.source_world_name_length)return false;
        key_bytes(static_cast<Byte *>(result.source_world)+0x81,result.source_world_name_length,result.key);
    }
    result.filename_length=read.name_length(static_cast<Byte *>(result.filename));
    result.name_length=read.name_length(static_cast<Byte *>(result.name));
    if(!result.filename_length || !result.name_length)return false;
    key_bytes(result.filename,result.filename_length,result.key);key_bytes(result.name,result.name_length,result.key);
    out=result;return true;
}
}

int native_resource_identity_resolve(void *current_world,void *resource,NativeResourceIdentity *out) {
    const DWORD error=GetLastError();int result=0;
    __try {
        ReadContext read;NativeResourceIdentity first{},second{};
        if(out && snapshot(read,current_world,resource,first) && snapshot(read,current_world,resource,second) &&
            !std::memcmp(&first,&second,sizeof first)) {*out=first;result=1;}
    } __except(EXCEPTION_EXECUTE_HANDLER) {result=0;}
    SetLastError(error);return result;
}

int native_resource_identity_revalidate(const NativeResourceIdentity *witness) {
    const DWORD error=GetLastError();int result=0;
    __try {
        if(witness) {
            const NativeResourceIdentity expected=*witness;
            ReadContext read;NativeResourceIdentity first{},second{};
            result=snapshot(read,expected.world,expected.actual_resource,first) &&
                snapshot(read,expected.world,expected.actual_resource,second) &&
                !std::memcmp(&first,&second,sizeof first) && !std::memcmp(&expected,&first,sizeof first);
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {result=0;}
    SetLastError(error);return result;
}
