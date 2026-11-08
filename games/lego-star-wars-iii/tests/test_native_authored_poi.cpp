#undef NDEBUG
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <cstring>
#include "engine/native_authored_poi.h"

static const uint32_t table_a[2]={0x13572468,0xabcdef01},table_b[2]={0x24681357,0x10fedcba};
static unsigned char *arena,*resource,*runtime,*array;
static unsigned checks;
#define CHECK(x) do{++checks;assert(x);}while(0)
template<class T>static void put(void *base,size_t offset,T value){std::memcpy(static_cast<unsigned char *>(base)+offset,&value,sizeof value);}
static unsigned char *model(unsigned i){return arena+i*0x1000;}
static unsigned char *receiver(unsigned i){return arena+0x20000+i*0x1000;}
static void setup(unsigned depth){
    std::memset(arena,0,0x60000);
    resource=arena+0x40000;runtime=arena+0x41000;array=arena+0x42000;
    put(resource,0x6f8,runtime);put(runtime,0x68,129u);put(runtime,0x6c,array);
    auto *poi=array+33*0xe0;
    for(unsigned i=0;i<depth;++i){
        put(model(i),0x3c,receiver(i));put(model(i),0x48,i+1<depth?model(i+1):nullptr);
        put<uint16_t>(model(i),0x5a,i+1<depth?0x1567:0x1562);
        put(receiver(i),0,table_a);put(receiver(i),0x18,model(i));put(receiver(i),0x2c,resource);put(receiver(i),0x30,poi);
    }
    put(poi,0xd4,receiver(depth-1));
}
static void unchanged_failure(void *input){
    NativeAuthoredPoi result;std::memset(&result,0xa5,sizeof result);NativeAuthoredPoi previous=result;
    SetLastError(0x1974);CHECK(!native_authored_poi_resolve(input,&result));CHECK(GetLastError()==0x1974);CHECK(!std::memcmp(&result,&previous,sizeof result));
}
static void success(unsigned depth){
    NativeAuthoredPoi result;SetLastError(0x1965);CHECK(native_authored_poi_resolve(model(0),&result));CHECK(GetLastError()==0x1965);
    CHECK(result.model==model(0)&&result.receiver==receiver(0)&&result.authored_model==model(depth-1)&&result.authored_receiver==receiver(depth-1));
    CHECK(result.chain_count==depth&&result.poi_count==129&&result.poi_ordinal==33&&result.resource==resource&&result.runtime==runtime&&result.array==array);
    CHECK(result.poi==array+33*0xe0&&result.receiver_class==static_cast<uint32_t>(reinterpret_cast<uintptr_t>(table_a)-reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr))));
    CHECK(native_authored_poi_revalidate(&result));CHECK(GetLastError()==0x1965);
    for(unsigned i=0;i<depth;++i)CHECK(result.chain[i].model==model(i)&&result.chain[i].receiver==receiver(i));
}
int main(){
    arena=static_cast<unsigned char *>(VirtualAlloc(nullptr,0x60000,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE));CHECK(arena);
    for(unsigned n=1;n<=16;++n){setup(n);success(n);}
    setup(17);unchanged_failure(model(0));
    setup(1);put<uint32_t>(runtime,0x68,0);unchanged_failure(model(0));
    setup(1);put<uint32_t>(runtime,0x68,65537);unchanged_failure(model(0));
    setup(1);put<void *>(runtime,0x6c,nullptr);unchanged_failure(model(0));
    setup(1);put(receiver(0),0x30,array-0xe0);unchanged_failure(model(0));
    setup(1);put(receiver(0),0x30,array+129*0xe0);unchanged_failure(model(0));
    setup(1);put(receiver(0),0x30,array+33*0xe0+1);unchanged_failure(model(0));
    setup(1);put<void *>(array+33*0xe0,0xd4,nullptr);unchanged_failure(model(0));
    setup(2);put<uint16_t>(model(0),0x5a,0x1566);unchanged_failure(model(0));
    setup(2);put(receiver(0),0x18,model(1));unchanged_failure(model(0));
    setup(2);put<void *>(model(0),0x48,nullptr);unchanged_failure(model(0));
    setup(2);put(model(0),0x48,model(0));unchanged_failure(model(0));
    setup(3);put(model(1),0x3c,receiver(0));unchanged_failure(model(0));
    setup(3);put(model(1),0x48,model(0));unchanged_failure(model(0));
    setup(1);put(receiver(0),0,arena+0x50000);unchanged_failure(model(0));
    unchanged_failure(nullptr);unchanged_failure(reinterpret_cast<void *>(1));
    CHECK(!native_authored_poi_resolve(model(0),nullptr));CHECK(!native_authored_poi_revalidate(nullptr));
    for(unsigned mutation=0;mutation<17;++mutation){
        setup(3);NativeAuthoredPoi before;CHECK(native_authored_poi_resolve(model(0),&before));
        switch(mutation){
            case 0:put(model(0),0x3c,receiver(2));break;
            case 1:put(model(0),0x48,model(2));break;
            case 2:put<uint16_t>(model(0),0x5a,0x1566);break;
            case 3:put(receiver(0),0x18,model(2));break;
            case 4:put(receiver(0),0,table_b);break;
            case 5:put(receiver(0),0x2c,resource+4);break;
            case 6:put(receiver(0),0x30,array+34*0xe0);break;
            case 7:put(resource,0x6f8,runtime+4);break;
            case 8:put(runtime,0x6c,array+0xe0);break;
            case 9:put<uint32_t>(runtime,0x68,128);break;
            case 10:put(array+33*0xe0,0xd4,receiver(0));break;
            case 11:put(receiver(2),0,table_b);break;
            case 12:put(model(2),0x3c,receiver(1));break;
            case 13:put<void *>(model(2),0x48,model(0));break;
            case 14:put<uint16_t>(model(2),0x5a,0x1563);break;
            case 15:before.poi_ordinal=34;break;
            case 16:before.chain_count=17;break;
        }
        SetLastError(0x1981);CHECK(!native_authored_poi_revalidate(&before));CHECK(GetLastError()==0x1981);
    }
    setup(2);NativeAuthoredPoi reused;CHECK(native_authored_poi_resolve(model(0),&reused));
    DWORD old;CHECK(VirtualProtect(model(0),0x1000,PAGE_NOACCESS,&old));CHECK(!native_authored_poi_revalidate(&reused));
    CHECK(VirtualProtect(model(0),0x1000,PAGE_READWRITE,&old));std::memset(model(0),0,0x1000);CHECK(!native_authored_poi_revalidate(&reused));
    setup(2);put<void *>(receiver(0),0x2c,nullptr);success(2); // An authored ancestor does not require a runtime clone to own a separate resource.
    for(unsigned iteration=0;iteration<2000;++iteration){
        unsigned depth=1+iteration%16;setup(depth);success(depth);
        NativeAuthoredPoi before;CHECK(native_authored_poi_resolve(model(0),&before));
        put(runtime,0x6c,array+0xe0);CHECK(!native_authored_poi_revalidate(&before));
    }
    std::printf("actual NativeAuthoredPoi: %u checks PASS; direct/clone1..16, cycle/depth/malformed/source mutations/reuse/LastError\n",checks);
    VirtualFree(arena,0,MEM_RELEASE);return 0;
}
