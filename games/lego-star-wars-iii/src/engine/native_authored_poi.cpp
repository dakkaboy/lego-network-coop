#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "native_authored_poi.h"

namespace {
struct Region {
    uintptr_t first,last,allocation;
    DWORD state,protection;
};
struct ReadContext {
    Region regions[32]{};
    unsigned count=0,next=0;

    bool region(uintptr_t address,Region &out) {
        for(unsigned i=0;i<count;++i) {
            const auto &r=regions[i];
            if(address>=r.first && address<r.last) {out=r;return true;}
        }
        MEMORY_BASIC_INFORMATION m;
        if(!VirtualQuery(reinterpret_cast<void *>(address),&m,sizeof m))return false;
        const auto first=reinterpret_cast<uintptr_t>(m.BaseAddress);
        const auto last=first+m.RegionSize;
        if(last<=first || address<first || address>=last)return false;
        out={first,last,reinterpret_cast<uintptr_t>(m.AllocationBase),m.State,m.Protect};
        if(count<32)regions[count++]=out;
        else {regions[next]=out;next=(next+1)%32;}
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
    bool image_class(const void *object,uint32_t &rva) {
        if(!readable(object,4))return false;
        uintptr_t table;std::memcpy(&table,object,sizeof table);
        const auto base=reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr));
        Region r;
        if(table<=base || !region(table,r) || r.allocation!=base || r.state!=MEM_COMMIT ||
            (r.protection&(PAGE_NOACCESS|PAGE_GUARD)))return false;
        rva=static_cast<uint32_t>(table-base);return true;
    }
};

template<class T>T get(const void *pointer,size_t offset=0) {
    T result;std::memcpy(&result,static_cast<const unsigned char *>(pointer)+offset,sizeof result);return result;
}

bool snapshot(ReadContext &read,void *value,NativeAuthoredPoi &out) {
    NativeAuthoredPoi result{};
    result.model=value;
    auto *model=static_cast<unsigned char *>(value);
    for(unsigned depth=0;depth<NATIVE_AUTHORED_POI_CHAIN_CAPACITY;++depth) {
        if(!read.readable(model,0x5c))return false;
        auto &link=result.chain[depth];
        link.model=model;link.receiver=get<void *>(model,0x3c);
        if(!read.readable(link.receiver,0x34) || !read.image_class(link.receiver,link.receiver_class))return false;
        for(unsigned previous=0;previous<depth;++previous)
            if(result.chain[previous].model==model || result.chain[previous].receiver==link.receiver)return false;
        link.parent=get<void *>(model,0x48);link.model_flags=get<uint16_t>(model,0x5a);
        link.receiver_model=get<void *>(link.receiver,0x18);
        link.resource=get<void *>(link.receiver,0x2c);link.poi=get<void *>(link.receiver,0x30);
        if(!depth)result.receiver=link.receiver;
        result.chain_count=depth+1;
        if(read.readable(link.resource,0x738)) {
            link.runtime=get<void *>(link.resource,0x6f8);
            if(read.readable(link.runtime,0x70)) {
                link.readable_fields|=NATIVE_AUTHORED_POI_RUNTIME_READABLE;
                link.array=get<void *>(link.runtime,0x6c);link.poi_count=get<uint32_t>(link.runtime,0x68);
            }
        }
        if(read.readable(link.poi,0xe0)) {
            link.readable_fields|=NATIVE_AUTHORED_POI_RECORD_READABLE;
            link.poi_receiver=get<void *>(link.poi,0xd4);
        }
        const auto poi=reinterpret_cast<uintptr_t>(link.poi),array=reinterpret_cast<uintptr_t>(link.array);
        if(link.readable_fields==(NATIVE_AUTHORED_POI_RUNTIME_READABLE|NATIVE_AUTHORED_POI_RECORD_READABLE) &&
            link.poi_count && link.poi_count<=65536 && array && poi>=array &&
            static_cast<uint64_t>(poi-array)<static_cast<uint64_t>(link.poi_count)*0xe0 &&
            (poi-array)%0xe0==0 && link.poi_receiver==link.receiver) {
            result.authored_model=model;result.authored_receiver=link.receiver;
            result.resource=link.resource;result.runtime=link.runtime;result.array=link.array;result.poi=link.poi;
            result.poi_count=link.poi_count;result.poi_ordinal=static_cast<uint32_t>((poi-array)/0xe0);
            result.receiver_class=link.receiver_class;out=result;return true;
        }
        // Runtime clones retain the authored POI; only the original receiver owns its D4 backlink.
        if(!(link.model_flags&1) || link.receiver_model!=model || !link.parent)return false;
        model=static_cast<unsigned char *>(link.parent);
    }
    return false;
}
}

int native_authored_poi_resolve(void *model,NativeAuthoredPoi *out) {
    const DWORD error=GetLastError();int result=0;
    __try {
        ReadContext read;NativeAuthoredPoi first{},second{};
        if(out && snapshot(read,model,first) && snapshot(read,model,second) && !std::memcmp(&first,&second,sizeof first)) {
            *out=first;result=1;
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {result=0;}
    SetLastError(error);return result;
}

int native_authored_poi_revalidate(const NativeAuthoredPoi *witness) {
    const DWORD error=GetLastError();int result=0;
    __try {
        if(witness) {
            const NativeAuthoredPoi expected=*witness;
            ReadContext read;NativeAuthoredPoi first{},second{};
            result=snapshot(read,expected.model,first) && snapshot(read,expected.model,second) &&
                !std::memcmp(&first,&second,sizeof first) && !std::memcmp(&expected,&first,sizeof first);
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {result=0;}
    SetLastError(error);return result;
}
