#ifdef NDEBUG
#undef NDEBUG
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cassert>
#include <cstdint>
#include <cstring>
#include "engine/native_resource_identity.h"

namespace {
volatile unsigned char image_span[0x70000];
uint32_t image_classes[8];
unsigned char world[0x2300],source_world[0x2300],container[0x20],other_container[0x20];
unsigned char registry[8+199*4],entry[0x58],other_entry[0x58],resource[0x738],other_resource[0x738],runtime[0x70];
uint32_t file_table[3],array[8];
char filename[128]="levels\\library\\prefab.gsc",logical_name[64]="prefab_scene";
void pointer(void *base,size_t offset,void *value){std::memcpy(static_cast<unsigned char *>(base)+offset,&value,4);}
void setup(bool bound){
    std::memset(world,0,sizeof world);std::memset(source_world,0,sizeof source_world);
    std::memset(container,0,sizeof container);std::memset(other_container,0,sizeof other_container);
    std::memset(registry,0,sizeof registry);std::memset(entry,0,sizeof entry);std::memset(other_entry,0,sizeof other_entry);
    std::memset(resource,0,sizeof resource);std::memset(other_resource,0,sizeof other_resource);std::memset(runtime,0,sizeof runtime);
    std::memcpy(world+0x81,"CurrentArea",sizeof "CurrentArea");
    std::memcpy(source_world+0x81,"SourceArea",sizeof "SourceArea");
    std::memcpy(filename,"levels\\library\\prefab.gsc",sizeof "levels\\library\\prefab.gsc");
    pointer(reinterpret_cast<void *>(0xfb4a20),0,world);pointer(reinterpret_cast<void *>(0xf9dd10),0,registry);
    pointer(container,0,image_classes);pointer(container,0xc,bound?source_world:nullptr);
    pointer(source_world,0x22e4,container);pointer(world,0x22e4,container);
    pointer(registry,8,entry);pointer(entry,0,file_table);pointer(entry,0x34,filename);pointer(entry,0x40,logical_name);
    pointer(entry,0x4c,resource);pointer(entry,0x54,container);
    pointer(resource,0x6f8,runtime);pointer(runtime,0x6c,array);
    file_table[1]=static_cast<uint32_t>(reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr))+0x5cf20);
}
void duplicate(bool bound,bool different_class){
    std::memcpy(other_entry,entry,sizeof entry);std::memcpy(other_container,container,sizeof container);
    pointer(registry,12,other_entry);pointer(other_entry,0x4c,other_resource);pointer(other_entry,0x54,other_container);
    pointer(other_container,0,different_class?image_classes+1:image_classes);
    pointer(other_container,0xc,bound?source_world:nullptr);
    if(bound)pointer(source_world,0x22e4,other_container);
}
}

int main(){
    image_span[0]=1;image_span[sizeof image_span-1]=1;
    void *world_page=VirtualAlloc(reinterpret_cast<void *>(0xfb0000),0x10000,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE);
    void *registry_page=VirtualAlloc(reinterpret_cast<void *>(0xf90000),0x10000,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE);
    assert(world_page==reinterpret_cast<void *>(0xfb0000)&&registry_page==reinterpret_cast<void *>(0xf90000));
    NativeResourceIdentity library{},bound{},changed{};
    setup(false);SetLastError(761);assert(native_resource_identity_resolve(world,resource,&library)&&GetLastError()==761);
    assert(!library.source_world_present&&!library.source_world&&native_resource_identity_revalidate(&library));
    setup(true);assert(native_resource_identity_resolve(world,resource,&bound));
    assert(bound.source_world_present&&bound.source_world==source_world&&std::memcmp(bound.key,library.key,sizeof bound.key));
    pointer(container,0xc,nullptr);assert(!native_resource_identity_revalidate(&bound));
    setup(false);assert(native_resource_identity_resolve(world,resource,&library));
    filename[0]='L';assert(!native_resource_identity_revalidate(&library));
    assert(native_resource_identity_resolve(world,resource,&changed)&&std::memcmp(library.key,changed.key,sizeof library.key));
    setup(false);assert(native_resource_identity_resolve(world,resource,&library));
    duplicate(false,false);assert(!native_resource_identity_revalidate(&library));
    assert(!native_resource_identity_resolve(world,resource,&changed));
    setup(false);duplicate(false,true);assert(native_resource_identity_resolve(world,resource,&changed));
    setup(false);duplicate(true,false);assert(native_resource_identity_resolve(world,resource,&changed));
    setup(false);assert(native_resource_identity_resolve(world,resource,&library));
    pointer(container,0xc,source_world);assert(!native_resource_identity_revalidate(&library));
    setup(false);assert(native_resource_identity_resolve(world,resource,&library));
    pointer(container,0,image_classes+1);assert(!native_resource_identity_revalidate(&library));
    setup(true);pointer(source_world,0x22e4,nullptr);assert(!native_resource_identity_resolve(world,resource,&changed));
    setup(false);assert(!native_resource_identity_resolve(source_world,resource,&changed));
    setup(false);assert(native_resource_identity_resolve(world,resource,&library));
    pointer(reinterpret_cast<void *>(0xfb4a20),0,source_world);assert(!native_resource_identity_revalidate(&library));
    setup(false);pointer(resource,0x734,other_resource);assert(!native_resource_identity_resolve(world,resource,&changed));
    pointer(other_resource,0x6f8,runtime);pointer(entry,0x4c,other_resource);
    assert(native_resource_identity_resolve(world,resource,&changed)&&changed.actual_resource==resource&&changed.root_resource==other_resource);
    setup(false);SetLastError(762);std::memset(&changed,0xa5,sizeof changed);const auto before=changed;
    assert(!native_resource_identity_resolve(world,reinterpret_cast<void *>(1),&changed)&&GetLastError()==762);
    assert(!std::memcmp(&changed,&before,sizeof changed));
    VirtualFree(world_page,0,MEM_RELEASE);VirtualFree(registry_page,0,MEM_RELEASE);
}
