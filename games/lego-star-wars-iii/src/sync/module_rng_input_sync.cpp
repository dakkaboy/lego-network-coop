#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include <cmath>
#include "module_rng_input_sync.h"
#include "physics_input_sync.h"
extern "C" {
#include "game_sync.h"
#include "../engine/constructor_lexical_seh.h"
__declspec(dllexport) volatile uint32_t clonewars_module_rng_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_module_rng_failure[12];
__declspec(dllexport) volatile uint32_t clonewars_module_rng_correction[8];
__declspec(dllexport) volatile uint32_t clonewars_gun_jam_rng_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_gun_jam_rng_correction[8];
__attribute__((used)) static volatile uintptr_t gun_jam_native_rng=0x573100;
}

namespace {
using NativeUpdate=void (__attribute__((thiscall)) *)(void *);
const auto update=reinterpret_cast<NativeUpdate>(0x4da6d0);
constexpr uintptr_t module_class=0xae6b3c;
struct Entry {uint32_t id,generation;void *object;uint32_t kind,flags;};
static_assert(sizeof(Entry)==20 && sizeof(SyncPhysicsModuleInput)==80 && sizeof(SyncPhysicsGunJamInput)==80);
struct Reference {
    uintptr_t type;
    unsigned char name[64];
    void *binding;
};
struct Witness {
    unsigned char *object,*world,*container,*world_handle,*registry;
    Entry *entry;
    Entry record;
    uint32_t type;
    Reference descriptor,references[3][3];
    uint8_t burst_min,burst_max,channel_count;
    int8_t weapon;
    uint32_t intervals[3];
};
struct MachineState {
    alignas(16) unsigned char fx[512];DWORD error;
    void capture(){__asm__ volatile("fxsave %0":"=m"(fx)::"memory");error=GetLastError();}
    void restore()const{SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx):"memory");}
};
struct Scope {
    MachineState machine;
    CoherentFrameToken token;
    Witness source;
    unsigned char *object;
    uint32_t clock,seed;
    bool bound;
};
bool installed;
bool readable(const void *pointer,size_t size){
    MEMORY_BASIC_INFORMATION m;const auto address=reinterpret_cast<uintptr_t>(pointer);
    return pointer && size && VirtualQuery(pointer,&m,sizeof(m)) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && address+size>=address &&
        address+size<=reinterpret_cast<uintptr_t>(m.BaseAddress)+m.RegionSize;
}
template<class T>T field(const unsigned char *pointer,size_t offset){T value;std::memcpy(&value,pointer+offset,sizeof value);return value;}
bool reference(const unsigned char *pointer,uintptr_t expected,Reference &out){
    if(!readable(pointer,0x54)||field<uintptr_t>(pointer,0)!=expected)return false;
    out.type=expected;std::memcpy(out.name,pointer+4,sizeof out.name);out.binding=field<void *>(pointer,0x50);
    return std::memchr(out.name,0,sizeof out.name)!=nullptr;
}
bool registered_module(unsigned char *object,uintptr_t type,size_t bytes,Witness &out){
    out={};out.object=object;out.world=*reinterpret_cast<unsigned char **>(0xfb4a20);
    out.registry=*reinterpret_cast<unsigned char **>(0xe906b0);
    if(!readable(object,bytes)||field<uintptr_t>(object,0)!=type||!readable(out.world,0x22e8)||!readable(out.registry,8+192*sizeof(Entry)))return false;
    out.container=field<unsigned char *>(out.world,0x22e4);out.world_handle=field<unsigned char *>(out.world,0x400);
    if(!readable(out.container,0x10)||field<void *>(out.container,0xc)!=out.world||!readable(out.world_handle,4))return false;
    out.entry=field<Entry *>(object,0x68);const auto first=reinterpret_cast<uintptr_t>(out.registry)+8;
    const auto offset=reinterpret_cast<uintptr_t>(out.entry)-first;
    if(offset>=192*sizeof(Entry)||offset%sizeof(Entry)||!readable(out.entry,sizeof(Entry)))return false;
    std::memcpy(&out.record,out.entry,sizeof out.record);out.type=field<uint32_t>(object,4);
    if(!out.record.id||!out.type||out.record.kind!=4||out.record.object!=object||(out.record.flags&0xff)||
       field<uint32_t>(object,8)!=out.record.id||field<uint32_t>(object,0x6c)!=out.record.generation)return false;
    for(unsigned i=0;i<192;++i){Entry other;std::memcpy(&other,out.registry+8+i*sizeof(Entry),sizeof other);
        if(other.kind==4&&!(other.flags&0xff)&&other.id==out.record.id&&other.object&&other.object!=object)return false;
    }
    return true;
}
bool witness(unsigned char *object,Witness &out){
    if(!registered_module(object,module_class,0x3e8,out)||!reference(object+0x10,0xae2df0,out.descriptor))return false;
    out.burst_min=object[0x3ca];out.burst_max=object[0x3c9];out.channel_count=object[0x3c8];out.weapon=field<int8_t>(object,0x3d0);
    if(out.burst_min>=out.burst_max||out.channel_count>3)return false;
    const size_t offsets[]={0x3d4,0x3d8,0x3e0};
    for(unsigned i=0;i<3;++i){out.intervals[i]=field<uint32_t>(object,offsets[i]);float value;std::memcpy(&value,out.intervals+i,4);if(!std::isfinite(value))return false;}
    for(unsigned i=0;i<out.channel_count;++i){
        const auto *channel=object+0x98+i*0x110;
        for(unsigned j=0;j<3;++j)if(!reference(channel+j*0x54,j==2?0xae2d50:0xae2d30,out.references[i][j]))return false;
    }
    return true;
}
bool live(const Scope &s){return coherent_frame_valid(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)) && *reinterpret_cast<uint32_t *>(0xfb4b6c)==s.clock;}
bool same_witness(const Scope &s){Witness now;return witness(s.object,now)&&!std::memcmp(&now,&s.source,sizeof now);}
void reject(const Scope &s,uint32_t reason){
    ++clonewars_module_rng_debug[3];
    if(!clonewars_module_rng_failure[2]){
        const uint32_t values[]={s.token.epoch,s.token.sequence,reason,s.clock,reinterpret_cast<uintptr_t>(s.object),
            s.source.record.id,s.source.record.generation,s.source.type,s.source.burst_min,s.source.burst_max,s.source.channel_count,s.seed};
        std::memcpy(const_cast<uint32_t *>(clonewars_module_rng_failure),values,sizeof values);
    }
    game_sync_native_fault(15);
}
SyncPhysicsChoice choice(const Scope &s){
    SyncPhysicsChoice result{};result.kind=SYNC_PHYSICS_MODULE_SEED;result.site=0x4da6d0;
    auto &m=result.module;m.clock=s.clock;m.value=s.seed;m.module_id=s.source.record.id;m.module_type=s.source.type;
    m.module_generation=s.source.record.generation;m.module_class=0x6e6b3c;m.burst_min=s.source.burst_min;
    m.burst_max=s.source.burst_max;m.channel_count=s.source.channel_count;m.weapon=s.source.weapon;
    std::memcpy(m.intervals,s.source.intervals,sizeof m.intervals);return result;
}
void *__cdecl invoke(void *opaque){
    auto &s=*static_cast<Scope *>(opaque);
    if(s.bound){
        if(!live(s)||!witness(s.object,s.source)){reject(s,1);return nullptr;}
        auto input=choice(s);auto expected=input;
        if(!live(s)||physics_module_input(&input,&s.token)!=1){reject(s,2);return nullptr;}
        expected.module.value=input.module.value;
        if(!live(s)||!same_witness(s)||*reinterpret_cast<uint32_t *>(0xea178c)!=s.seed||std::memcmp(&input,&expected,sizeof input)){reject(s,3);return nullptr;}
        *reinterpret_cast<uint32_t *>(0xea178c)=input.module.value;++clonewars_module_rng_debug[0];
        if(input.module.value!=s.seed){++clonewars_module_rng_debug[1];if(!clonewars_module_rng_correction[0]){
            const uint32_t values[]={s.token.epoch,s.token.sequence,s.clock,s.source.record.id,s.source.record.generation,s.source.type,s.seed,input.module.value};
            std::memcpy(const_cast<uint32_t *>(clonewars_module_rng_correction),values,sizeof values);
        }}
    }
    // This shared stream retains every advance performed by the original update and its children.
    s.machine.restore();update(s.object);s.machine.capture();++clonewars_module_rng_debug[2];return nullptr;
}
void __cdecl abort_update(void *opaque){auto &s=*static_cast<Scope *>(opaque);if(s.bound)reject(s,4);}
void __attribute__((fastcall)) update_hook(void *object,void *){
    Scope s;s.machine.capture();s.token={};s.source={};s.object=static_cast<unsigned char *>(object);
    s.bound=coherent_frame_get(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))!=0;
    s.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);s.seed=*reinterpret_cast<uint32_t *>(0xea178c);
    constructor_lexical_seh(&s,invoke,abort_update);s.machine.restore();
}
bool gun_jam_witness(unsigned char *object,uint32_t candidates,SyncPhysicsChoice &input){
    Witness source;
    if(!registered_module(object,0xae36e4,0xb0,source))return false;
    input={};input.kind=SYNC_PHYSICS_GUN_JAM_SEED;input.site=0x4acb53;
    auto &jam=input.gun_jam;
    jam.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
    jam.value=*reinterpret_cast<uint32_t *>(0xea178c);
    jam.module_id=source.record.id;jam.module_type=source.type;jam.module_generation=source.record.generation;
    jam.member_count=field<uint32_t>(object,0xac);jam.candidate_count=candidates;
    jam.clip=field<int16_t>(object,0xa4);
    jam.remaining=field<float>(object,0x98);jam.minimum=field<float>(object,0x9c);jam.maximum=field<float>(object,0xa0);
    return true;
}
}

extern "C" __attribute__((used,noinline)) void gun_jam_rng_checkpoint(unsigned char *object,uint32_t candidates){
    const DWORD error=GetLastError();
    CoherentFrameToken token;
    if(coherent_frame_get(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))){
        SyncPhysicsChoice input,observed;
        if(!gun_jam_witness(object,candidates,input) || physics_module_input(&input,&token)!=1 ||
           !gun_jam_witness(object,candidates,observed) ||
           input.gun_jam.module_generation!=observed.gun_jam.module_generation ||
           !physics_choice_same_source(&input,&observed) ||
           !coherent_frame_valid(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))){
            ++clonewars_gun_jam_rng_debug[2];game_sync_native_fault(15);
        } else {
            const auto &source=input.gun_jam;
            *reinterpret_cast<uint32_t *>(0xea178c)=source.value;
            ++clonewars_gun_jam_rng_debug[0];clonewars_gun_jam_rng_debug[3]=source.clock;
            if(source.value!=observed.gun_jam.value){
                ++clonewars_gun_jam_rng_debug[1];
                if(!clonewars_gun_jam_rng_correction[0]){
                    const uint32_t correction[]={token.epoch,token.sequence,source.clock,source.module_id,
                        observed.gun_jam.value,source.value,source.candidate_count,static_cast<uint32_t>(source.clip)};
                    std::memcpy(const_cast<uint32_t *>(clonewars_gun_jam_rng_correction),correction,sizeof correction);
                }
            }
        }
    }
    SetLastError(error);
}
__attribute__((naked,used)) static void gun_jam_rng_thunk(){
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $8,%esp\n\tpushl 16(%eax)\n\tpushl 8(%eax)\n\tcall _gun_jam_rng_checkpoint\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"
        "pushl $0x4acb58\n\tjmp *_gun_jam_native_rng\n\t");
}

int module_rng_input_install(void){
    if(installed)return true;
    auto *slot=reinterpret_cast<uintptr_t *>(0xae6b64);
    const unsigned char expected[]={0x51,0xd9,0x05,0x74,0x4b,0xfb,0x00,0x53,0x56,0xd9,0x5c,0x24,0x08};
    const auto *entry=reinterpret_cast<const unsigned char *>(0x4da6d0);
    auto *draw=reinterpret_cast<unsigned char *>(0x4acb53);
    const unsigned char draw_call[]={0xe8,0xa8,0x65,0x0c,0x00};
    if(!readable(slot,4)||*slot!=reinterpret_cast<uintptr_t>(update)||!readable(entry,sizeof expected)||std::memcmp(entry,expected,sizeof expected)||
       !readable(draw,sizeof draw_call)||std::memcmp(draw,draw_call,sizeof draw_call))return false;
    DWORD protection,ignored;if(!VirtualProtect(slot,4,PAGE_READWRITE,&protection))return false;
    DWORD draw_protection;
    if(!VirtualProtect(draw,sizeof draw_call,PAGE_EXECUTE_READWRITE,&draw_protection)){
        VirtualProtect(slot,4,protection,&ignored);return false;
    }
    const auto prior=InterlockedCompareExchange(reinterpret_cast<volatile LONG *>(slot),reinterpret_cast<LONG>(update_hook),reinterpret_cast<LONG>(update));
    VirtualProtect(slot,4,protection,&ignored);
    if(static_cast<uintptr_t>(prior)!=reinterpret_cast<uintptr_t>(update)){
        VirtualProtect(draw,sizeof draw_call,draw_protection,&ignored);return false;
    }
    const auto relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(gun_jam_rng_thunk)-0x4acb58);
    draw[0]=0xe9;std::memcpy(draw+1,&relative,sizeof relative);
    FlushInstructionCache(GetCurrentProcess(),draw,sizeof draw_call);
    VirtualProtect(draw,sizeof draw_call,draw_protection,&ignored);
    installed=true;return true;
}
