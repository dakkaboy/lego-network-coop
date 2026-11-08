#include "../src/engine/native_scene_readiness.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

static unsigned checks;
static void require(bool value) { ++checks;if (!value) std::abort(); }
struct Region { uint32_t base;std::vector<unsigned char> bytes;bool writable; };
struct Memory {
    std::vector<Region> regions;
    uint32_t mutate_on=0,mutate_address=0,mutate_value=0;
    void add(uint32_t base,size_t bytes,bool writable=true) { regions.push_back({base,std::vector<unsigned char>(bytes),writable}); }
    Region *find(uint32_t address,size_t size) {
        for (auto &r:regions) if (address>=r.base && size<=r.bytes.size() && address-r.base<=r.bytes.size()-size) return &r;
        return nullptr;
    }
    template<class T> void put(uint32_t address,T value) {
        auto *r=find(address,sizeof(value));require(r!=nullptr);
        std::memcpy(r->bytes.data()+address-r->base,&value,sizeof(value));
    }
    static int range(void *p,uint32_t address,size_t size,int writable) {
        auto *r=static_cast<Memory *>(p)->find(address,size);
        return r && (!writable || r->writable);
    }
    static int read(void *p,uint32_t address,void *out,size_t size) {
        auto &m=*static_cast<Memory *>(p);auto *r=m.find(address,size);
        if (!r) return 0;
        std::memcpy(out,r->bytes.data()+address-r->base,size);
        if (m.mutate_on==address) {
            m.mutate_on=0;m.put<uint32_t>(m.mutate_address,m.mutate_value);
        }
        return 1;
    }
    NativeSceneReadOps ops() { return {this,read,range}; }
};
static constexpr uint32_t profile=0x10000000,catalog=0x11000000,areas=0x12000000;
static constexpr uint32_t records=0x13000000,registry=0x14000000,registry_entries=0x14000100;
static constexpr uint32_t definition=0x15000000,world=0x16000000,pool=0x17000000;
static constexpr uint32_t controllers=0x18000000,resources=0x19000000,devices=0x1a000000;
static Memory fixture() {
    Memory m;
    m.add(0xe00000,0x200000);m.add(0x8f02b0,1,false);m.add(0x403e80,1,false);
    m.add(profile,0xb5c0);m.add(catalog,2*0x1b0);m.add(areas,0xd80);
    m.add(records,0x20);m.add(registry,0x200);m.add(definition,0x40);
    m.add(world,0x22e8);m.add(pool,2*0x1440);m.add(controllers,0x200);
    m.add(resources,0x100);m.add(devices,0x200);
    m.put<uint32_t>(0xfbd8bc,profile);m.put<uint32_t>(profile,0x500);
    const uint32_t globals[]={0xfb519c,0xfb847c,0xfb4bdc,0xfb4cb4,0xfbc1dc,0xfbc1cc,0xfb3110};
    const uint32_t offsets[]={0x5b84,0x1c,0xb248,0x6238,0x6208,0x6210,0xb57c};
    for (unsigned i=0;i<7;++i) m.put<uint32_t>(globals[i],profile+offsets[i]);
    m.put<uint32_t>(0xfb8404,catalog);m.put<uint32_t>(0xfb8410,2);
    m.put<uint32_t>(0xfb8414,catalog);m.put<int16_t>(catalog+0x94,0);
    m.put<int16_t>(catalog+0x1b0+0x94,1);m.put<uint32_t>(world+0x220,catalog+0x1b0);
    m.put<uint32_t>(0xfb4a20,world);m.put<uint32_t>(0xfb5154,areas);m.put<uint32_t>(0xfb5160,1);
    m.put<uint32_t>(0xe6de7c,records);m.put<uint16_t>(0xe6de82,1);
    m.put<uint8_t>(records+9,2);m.put<int16_t>(records,0);
    m.put<uint32_t>(0xe6e0bc,registry);m.put<uint32_t>(registry,registry_entries);
    m.put<uint32_t>(registry+4,1);m.put<uint32_t>(registry_entries,definition);
    m.put<int8_t>(registry_entries+0xf,-1);m.put<int16_t>(registry_entries+0x10,1);
    m.put<uint32_t>(0xe6e124,0x8f02b0);m.put<uint32_t>(0xfb4d58,0x403e80);
    m.put<uint32_t>(0xfb2f60,pool);m.put<uint32_t>(0xfb2e3c,2);
    for (unsigned i=0;i<2;++i) {
        const auto actor=pool+i*0x1440;
        m.put<uint32_t>(actor+0x50,3);m.put<int16_t>(actor+0xdc0,static_cast<int16_t>(i));
        m.put<uint32_t>(actor+0xf08,resources+i*0x40);
        m.put<uint32_t>(actor+0x6cc,controllers+i*0x100);
        m.put<uint32_t>(controllers+i*0x100,devices+i*0x100);
    }
    return m;
}
static bool storage(Memory &m) { auto ops=m.ops();return native_profile_storage_bound(&ops)!=0; }
static int capability(Memory &m,int level=1,uint32_t expected=world) {
    auto ops=m.ops();return native_scene_input_capability(&ops,level,expected);
}
static void party(Memory &m) {
    m.put<uint32_t>(0xfb4940,pool);m.put<uint32_t>(0xfb4944,pool+0x1440);
}
int main() {
    auto m=fixture();require(storage(m));require(capability(m)==GAME_SCENE_NO_PARTY_INPUT);
    const uint32_t globals[]={0xfb519c,0xfb847c,0xfb4bdc,0xfb4cb4,0xfbc1dc,0xfbc1cc,0xfb3110};
    for (auto global:globals) {
        auto bad=m;bad.put<uint32_t>(global,profile+4);require(!storage(bad));
    }
    { auto bad=m;bad.put<uint32_t>(profile,0x501);require(!storage(bad)); }
    { auto bad=m;bad.put<uint32_t>(0xfbd8bc,profile+4);require(!storage(bad)); }
    { auto bad=m;bad.find(profile,0xb5c0)->writable=false;require(!storage(bad)); }
    for (auto global:{0xfb8410u,0xfb5160u,0xfbd7bcu}) {
        auto bad=m;bad.put<uint32_t>(global,UINT32_MAX);require(!storage(bad));
    }
    { auto empty=m;
      for (auto global:{0xfb8410u,0xfb5160u,0xfbd7bcu,registry+4}) empty.put<uint32_t>(global,0);
      for (auto global:{0xfb8404u,0xfb5154u,0xfbd7b8u,registry}) empty.put<uint32_t>(global,0);
      empty.put<uint16_t>(0xe6de82,0);empty.put<uint32_t>(0xe6de7c,0);
      require(storage(empty));require(capability(empty)==GAME_SCENE_NOT_READY);
    }
    { auto bad=m;bad.put<uint32_t>(0xe6e0bc,0);require(!storage(bad)); }
    { auto bad=m;bad.put<uint32_t>(registry+4,UINT32_MAX);require(!storage(bad)); }
    { auto bad=m;bad.put<uint32_t>(registry,0);require(!storage(bad)); }
    { auto bad=m;bad.put<uint32_t>(registry_entries,0);require(!storage(bad)); }
    { auto bad=m;bad.put<int8_t>(registry_entries+0xf,-2);require(!storage(bad)); }
    { auto bad=m;bad.put<int8_t>(registry_entries+0xf,1);require(!storage(bad)); }
    { auto bad=m;bad.put<int16_t>(registry_entries+0x10,2);require(!storage(bad)); }
    { auto unused=m;unused.put<uint8_t>(registry_entries+0x12,1);
      unused.put<int8_t>(registry_entries+0xf,-2);require(storage(unused)); }
    { auto bad=m;bad.put<int16_t>(records,-1);require(!storage(bad)); }
    { auto bad=m;bad.put<int16_t>(records,0x32c);require(!storage(bad)); }
    { auto last=m;last.put<int16_t>(records,0x32b);require(storage(last)); }
    { auto unused=m;unused.put<uint8_t>(records+9,0);unused.put<int16_t>(records,-1);require(storage(unused)); }
    for (auto global:{0xe6e124u,0xfb4d58u,0xfb4d60u}) {
        auto bad=m;bad.put<uint32_t>(global,0x1234);require(!storage(bad));
    }
    { auto bad=m;bad.put<uint32_t>(0xe6e124,0);require(!storage(bad)); }
    { auto allowed=m;allowed.put<uint32_t>(0xfb4d58,0);allowed.put<uint32_t>(0xfb4d60,0);require(storage(allowed)); }
    { auto bad=m;bad.put<uint32_t>(0xfbbbcc,0x1234);require(!storage(bad)); }
    { auto changed=m;changed.mutate_on=0xe6e124;changed.mutate_address=0xfb519c;changed.mutate_value=profile+4;require(!storage(changed)); }
    { auto empty=m;empty.put<uint32_t>(0xfb2e3c,0);empty.put<uint32_t>(0xfb2f60,0);require(capability(empty)==GAME_SCENE_NO_PARTY_INPUT); }
    for (auto count:{4097u,UINT32_MAX}) {
        auto bad=m;bad.put<uint32_t>(0xfb2e3c,count);require(capability(bad)==GAME_SCENE_NOT_READY);
    }
    { auto bad=m;bad.put<uint32_t>(0xfb2f60,0);require(capability(bad)==GAME_SCENE_NOT_READY); }
    { auto bad=m;bad.put<uint32_t>(0xfb2e3c,3);require(capability(bad)==GAME_SCENE_NOT_READY); }
    require(capability(m,0)==GAME_SCENE_NOT_READY);
    require(capability(m,2)==GAME_SCENE_NOT_READY);
    require(capability(m,-1)==GAME_SCENE_NOT_READY);
    require(capability(m,1,world+4)==GAME_SCENE_NOT_READY);
    { auto titles=m;titles.put<uint32_t>(0xfb8414,catalog+0x1b0);require(capability(titles)==GAME_SCENE_NOT_READY); }
    { auto titles=m;titles.put<uint32_t>(catalog+0x1b0+0x50,0x40000000);require(capability(titles)==GAME_SCENE_NOT_READY); }
    { auto bad=m;bad.put<uint32_t>(0xfb8414,0x1234);require(capability(bad)==GAME_SCENE_NOT_READY); }
    { auto bad=m;bad.put<int16_t>(catalog+0x1b0+0x94,0);require(capability(bad)==GAME_SCENE_NOT_READY); }
    { auto needs=m;needs.put<uint32_t>(catalog+0x1b0+0x50,2);require(capability(needs)==GAME_SCENE_NOT_READY);
      party(needs);require(capability(needs)==GAME_SCENE_PARTY_INPUT); }
    party(m);require(capability(m)==GAME_SCENE_PARTY_INPUT);
    { auto partial=m;partial.put<uint32_t>(0xfb4944,0);require(capability(partial)==GAME_SCENE_NOT_READY); }
    { auto partial=m;partial.put<uint32_t>(0xfb4940,0);require(capability(partial)==GAME_SCENE_NOT_READY); }
    { auto bad=m;bad.put<uint32_t>(pool+0xf08,0);require(capability(bad)==GAME_SCENE_NOT_READY); }
    { auto bad=m;bad.put<uint32_t>(pool+0x1440+0x6cc,0);require(capability(bad)==GAME_SCENE_NOT_READY); }
    { auto bad=m;bad.put<uint32_t>(0xfb4944,pool+0x1441);require(capability(bad)==GAME_SCENE_NOT_READY); }
    { auto bad=m;bad.put<int16_t>(pool+0xdc0,-1);require(capability(bad)==GAME_SCENE_NOT_READY); }
    { auto no_actors=m;no_actors.put<uint32_t>(0xfb2e3c,0);require(capability(no_actors)==GAME_SCENE_NOT_READY); }
    { auto respawn=m;
      respawn.put<uint32_t>(pool+0x50,0);respawn.put<uint32_t>(pool+0x1440+0x50,0);
      respawn.put<uint32_t>(pool+0x6cc,0);respawn.put<uint32_t>(controllers+0x100,0);
      respawn.put<int16_t>(pool+0x1440+0xdc0,-1);respawn.put<uint32_t>(pool+0x1440+0xf08,0);
      respawn.put<uint32_t>(0xfb4948,0x1234);require(capability(respawn)==GAME_SCENE_PARTY_INPUT); }
    { auto external=m;external.add(0x20000000,0x1440);external.put<uint32_t>(0xfb4944,0x20000000);
      external.put<uint32_t>(0x20000000+0x6cc,controllers+0x100);require(capability(external)==GAME_SCENE_PARTY_INPUT); }
    for (auto global:{0xfb4a20u,0xfb2f60u,0xfb2e3cu,0xfb4944u}) {
        auto changed=m;changed.mutate_on=pool+0x1440+0x6cc;changed.mutate_address=global;changed.mutate_value=0;
        require(capability(changed)==GAME_SCENE_NOT_READY);
    }
    auto ops=m.ops();require(!native_profile_storage_bound(nullptr));
    require(!native_scene_read(&ops,UINT32_MAX-1,&checks,4));
    require(!native_scene_span(&ops,UINT32_MAX-1,2,4));
    require(native_scene_span(&ops,0,0,4));
    std::printf("native scene readiness: %u checks passed\n",checks);
}
