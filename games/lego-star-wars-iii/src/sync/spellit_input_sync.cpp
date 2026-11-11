#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include <cmath>
#include "spellit_input_sync.h"
#include "physics_input_sync.h"
#include "../engine/native_spellit_source.h"
extern "C" {
#include "game_sync.h"
#include "../engine/constructor_lexical_seh.h"
__declspec(dllexport) volatile uint32_t clonewars_spellit_hop_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_spellit_hop_failure[12];
__declspec(dllexport) volatile uint32_t clonewars_spellit_hop_correction[12];
__declspec(dllexport) volatile uint32_t clonewars_spellit_native_count;
__declspec(dllexport) volatile uint32_t clonewars_spellit_native_batch[256][40];
__attribute__((used)) static volatile uintptr_t spellit_target_resume=0x8406b8;
}

namespace {
using NativeHop=void (__attribute__((thiscall)) *)(void *,uint32_t);
using NativeQuery=uint32_t (__attribute__((thiscall)) *)(void *);
const auto native_hop=reinterpret_cast<NativeHop>(0x840660);
const auto native_entity=reinterpret_cast<NativeQuery>(0x7ab040);
struct MachineState {
    alignas(16) unsigned char fx[512];DWORD error;
    void capture(){__asm__ volatile("fxsave %0":"=m"(fx)::"memory");error=GetLastError();}
    void restore()const{SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx):"memory");}
};
struct HopScope {
    HopScope *previous;
    CoherentFrameToken token;
    NativeSpellItSource source;
    void *gizmo;
    float delta;
    uint32_t clock;
    bool bound;
    MachineState machine;
};
thread_local HopScope *current;
bool installed;
bool trace_native;
static_assert(sizeof(NativeSpellItSourceKey)==24 && sizeof(NativeSpellItPieceKey)==48);
static_assert(sizeof(SyncPhysicsWorldInput)==80 && sizeof(SyncPhysicsChoice)==88);
static_assert(sizeof(SyncPhysicsSpellItPoseInput)==80);
static_assert(sizeof(SyncPhysicsSpellItStepInput)==80);
bool probe_readable(void *pointer,size_t size) {
    MEMORY_BASIC_INFORMATION m;const auto address=reinterpret_cast<uintptr_t>(pointer);
    return pointer && VirtualQuery(pointer,&m,sizeof m) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && address+size>=address &&
        address+size<=reinterpret_cast<uintptr_t>(m.BaseAddress)+m.RegionSize;
}
void snapshot_native(const HopScope &s) {
    uint32_t row[40]={0,s.token.epoch,s.token.sequence,s.clock};
    std::memcpy(row+4,&s.source.key,sizeof s.source.key);
    auto *g=static_cast<unsigned char *>(s.gizmo);void *selected;
    std::memcpy(row+10,g+0x218,4);std::memcpy(row+11,g+0xd0,12);
    std::memcpy(&selected,g+0x21c,4);row[14]=reinterpret_cast<uintptr_t>(selected);
    if(probe_readable(selected,0x114)) {
        auto *p=static_cast<unsigned char *>(selected);
        std::memcpy(row+15,p+0x110,4);std::memcpy(row+16,p+0xd0,12);
        std::memcpy(row+38,p+0x88,4);
        NativeSpellItPiece piece{};
        if(native_spellit_piece_resolve(&s.source,selected,&piece)) {
            row[23]=1;std::memcpy(row+24,&piece.key,sizeof piece.key);
        }
    }
    std::memcpy(row+19,g+0x16c,4);row[20]=*reinterpret_cast<uint32_t *>(0xea178c);
    row[21]=*reinterpret_cast<uint16_t *>(0xe637b4);std::memcpy(row+22,&s.delta,4);
    row[36]=reinterpret_cast<uintptr_t>(s.gizmo);
    std::memcpy(row+37,g+0x150,4);
    uint16_t control;uint32_t mxcsr;
    std::memcpy(&control,s.machine.fx,2);std::memcpy(&mxcsr,s.machine.fx+24,4);
    row[39]=control | (mxcsr<<16);
    const uint32_t serial=++clonewars_spellit_native_count;
    auto *out=clonewars_spellit_native_batch+(serial-1)%256;
    (*out)[0]=0;std::memcpy(const_cast<uint32_t *>(*out)+1,row+1,sizeof row-4);
    MemoryBarrier();(*out)[0]=serial;
}
bool live(const HopScope &s) {
    return s.bound && coherent_frame_valid(&s.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH)) &&
        *reinterpret_cast<uint32_t *>(0xfb4b6c)==s.clock;
}
void reject(const HopScope &s,unsigned reason,unsigned kind=0) {
    ++clonewars_spellit_hop_debug[3];
    if (!clonewars_spellit_hop_failure[2]) {
        const uint32_t values[]={s.token.epoch,s.token.sequence,reason,kind,s.clock,
            reinterpret_cast<uintptr_t>(s.gizmo),s.source.key.gizmo_class,s.source.key.gizmo_ordinal,
            s.source.key.name[0],s.source.key.name[1],s.source.key.name[2],s.source.key.name[3]};
        std::memcpy(const_cast<uint32_t *>(clonewars_spellit_hop_failure),values,sizeof(values));
    }
    game_sync_native_fault(15);
}
SyncPhysicsChoice choice(const HopScope &s,unsigned kind,uint32_t value,const NativeSpellItPiece *piece=nullptr) {
    SyncPhysicsChoice result{};result.kind=kind;
    result.site=kind==SYNC_PHYSICS_SPELLIT_SEED?0x86101e:kind==SYNC_PHYSICS_SPELLIT_ENTITY?0x8407d4:0x84085b;
    result.world.clock=s.clock;result.world.value=value;
    std::memcpy(result.world.source_name,&s.source.key,sizeof(s.source.key));
    if (piece) std::memcpy(result.world.resource_name,&piece->key,sizeof(piece->key));
    return result;
}
bool resolve_input(const HopScope &s,SyncPhysicsChoice &input,const NativeSpellItPiece *piece=nullptr) {
    const uint32_t local=input.world.value;
    if (!live(s) || !native_spellit_source_revalidate(&s.source) ||
        (piece && !native_spellit_piece_revalidate(&s.source,piece))) {reject(s,3,input.kind);return false;}
    if (physics_world_input(&input,&s.token)!=1) {reject(s,4,input.kind);return false;}
    if (!live(s) || !native_spellit_source_revalidate(&s.source) ||
        (piece && !native_spellit_piece_revalidate(&s.source,piece))) {reject(s,5,input.kind);return false;}
    if (piece) {
        void *selected;std::memcpy(&selected,static_cast<unsigned char *>(s.gizmo)+0x21c,4);
        if (selected!=piece->piece) {reject(s,5,input.kind);return false;}
    }
    ++clonewars_spellit_hop_debug[1];
    if (input.world.value!=local) {
        ++clonewars_spellit_hop_debug[2];
        if (!clonewars_spellit_hop_correction[0]) {
            const uint32_t values[]={s.token.epoch,s.token.sequence,s.clock,input.kind,local,input.world.value,
                s.source.key.gizmo_class,s.source.key.gizmo_ordinal,piece?piece->key.piece_ordinal:0,
                piece?piece->key.poi_ordinal:0,piece?piece->key.receiver_class:0,input.site};
            std::memcpy(const_cast<uint32_t *>(clonewars_spellit_hop_correction),values,sizeof(values));
        }
    }
    return true;
}
void *__cdecl invoke_hop(void *raw) {
    auto &s=*static_cast<HopScope *>(raw);
    if (s.bound) {
        if (!live(s) || !std::isfinite(s.delta) || s.delta<0 || s.delta>.1f ||
            !native_spellit_source_resolve(s.gizmo,&s.source)) {reject(s,1);return nullptr;}
        if(trace_native)snapshot_native(s);
        SyncPhysicsChoice input{};input.kind=SYNC_PHYSICS_SPELLIT_STEP;input.site=0x86101e;
        auto &step=input.spellit_step;step.clock=s.clock;step.delta=s.delta;
        step.engine_seed=*reinterpret_cast<uint32_t *>(0xea178c);step.game_seed=*reinterpret_cast<uint16_t *>(0xe637b4);
        std::memcpy(&step.timer,static_cast<unsigned char *>(s.gizmo)+0x218,4);
        std::memcpy(step.source_name,s.source.key.name,sizeof step.source_name);
        step.gizmo_class=s.source.key.gizmo_class;step.gizmo_ordinal=s.source.key.gizmo_ordinal;
        const auto before=input;
        if(physics_world_input(&input,&s.token)!=1) {reject(s,4,input.kind);return nullptr;}
        if(!live(s) || !native_spellit_source_revalidate(&s.source) || !physics_choice_same_source(&before,&input) ||
           std::memcmp(static_cast<unsigned char *>(s.gizmo)+0x218,&before.spellit_step.timer,4) ||
           *reinterpret_cast<uint32_t *>(0xea178c)!=before.spellit_step.engine_seed ||
           *reinterpret_cast<uint16_t *>(0xe637b4)!=before.spellit_step.game_seed) {reject(s,5,input.kind);return nullptr;}
        *reinterpret_cast<uint32_t *>(0xea178c)=step.engine_seed;
        *reinterpret_cast<uint16_t *>(0xe637b4)=static_cast<uint16_t>(step.game_seed);
        std::memcpy(static_cast<unsigned char *>(s.gizmo)+0x218,&step.timer,4);s.delta=step.delta;
        ++clonewars_spellit_hop_debug[1];
        if(before.spellit_step.engine_seed!=step.engine_seed || before.spellit_step.game_seed!=step.game_seed ||
           std::memcmp(&before.spellit_step.delta,&step.delta,8))++clonewars_spellit_hop_debug[2];
        ++clonewars_spellit_hop_debug[0];
    }
    uint32_t delta_bits;std::memcpy(&delta_bits,&s.delta,4);
    // The native stack argument is unchanged; integer marshalling preserves incoming XMM registers.
    s.machine.restore();native_hop(s.gizmo,delta_bits);s.machine.capture();return nullptr;
}
void __cdecl abort_hop(void *raw) {current=static_cast<HopScope *>(raw)->previous;}
extern "C" void __cdecl native_spellit_pose_input(void *gizmo) {
    const DWORD error=GetLastError();HopScope *scope=current;
    do {
        if(!scope || !scope->bound)break;
        if(scope->gizmo!=gizmo || !live(*scope) || !native_spellit_source_revalidate(&scope->source)) {
            reject(*scope,9,SYNC_PHYSICS_SPELLIT_POSE);break;
        }
        void *selected;std::memcpy(&selected,static_cast<unsigned char *>(gizmo)+0x21c,4);
        NativeSpellItPiece piece{};
        if(!native_spellit_piece_resolve(&scope->source,selected,&piece)) {
            reject(*scope,10,SYNC_PHYSICS_SPELLIT_POSE);break;
        }
        SyncPhysicsChoice input{};input.kind=SYNC_PHYSICS_SPELLIT_POSE;input.site=0x8406b2;
        auto &pose=input.spellit_pose;pose.clock=scope->clock;
        std::memcpy(pose.position,static_cast<unsigned char *>(selected)+0xd0,sizeof pose.position);
        std::memcpy(&pose.last_time,static_cast<unsigned char *>(selected)+0xf4,4);
        std::memcpy(pose.source_name,scope->source.key.name,sizeof pose.source_name);
        pose.gizmo_class=scope->source.key.gizmo_class;pose.gizmo_ordinal=scope->source.key.gizmo_ordinal;
        std::memcpy(pose.resource_name,piece.key.resource,sizeof pose.resource_name);
        std::memcpy(pose.poi_name,piece.key.poi_name,sizeof pose.poi_name);
        pose.poi_ordinal=static_cast<uint16_t>(piece.key.poi_ordinal);pose.piece_ordinal=static_cast<uint16_t>(piece.key.piece_ordinal);
        const auto before=input;
        if(physics_world_input(&input,&scope->token)!=1) {reject(*scope,11,input.kind);break;}
        if(!live(*scope)) {reject(*scope,12,input.kind);break;}
        void *now;std::memcpy(&now,static_cast<unsigned char *>(gizmo)+0x21c,4);
        if(now!=selected || !native_spellit_source_revalidate(&scope->source) ||
           !native_spellit_piece_revalidate(&scope->source,&piece) || !physics_choice_same_source(&before,&input) ||
           std::memcmp(before.spellit_pose.position,static_cast<unsigned char *>(selected)+0xd0,sizeof pose.position) ||
           std::memcmp(&before.spellit_pose.last_time,static_cast<unsigned char *>(selected)+0xf4,4)) {
            reject(*scope,12,input.kind);break;
        }
        ++clonewars_spellit_hop_debug[1];
        if(std::memcmp(pose.position,before.spellit_pose.position,sizeof pose.position))++clonewars_spellit_hop_debug[2];
        std::memcpy(static_cast<unsigned char *>(selected)+0xd0,pose.position,sizeof pose.position);
        std::memcpy(static_cast<unsigned char *>(selected)+0xf4,&pose.last_time,4);
    } while(false);
    SetLastError(error);
}
extern "C" __attribute__((naked)) void native_spellit_pose_bridge(void) {
    __asm__ volatile(
        "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t"
        "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t"
        "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t"
        "subl $12,%esp\n\tpushl 16(%eax)\n\tcall _native_spellit_pose_input\n\taddl $16,%esp\n\t"
        "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"
        "movl 0x21c(%ebx),%ecx\n\tjmp *_spellit_target_resume");
}
void __attribute__((fastcall)) hop_hook(void *gizmo,void *,float delta) {
    HopScope scope;scope.machine.capture();scope.source={};scope.token={};
    scope.previous=current;scope.gizmo=gizmo;scope.delta=delta;
    scope.bound=coherent_frame_get(&scope.token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))!=0;
    scope.clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);current=&scope;
    constructor_lexical_seh(&scope,invoke_hop,abort_hop);current=scope.previous;scope.machine.restore();
}
uint32_t query(void *target,NativeQuery original,unsigned kind) {
    MachineState machine;machine.capture();HopScope *scope=current;
    NativeSpellItPiece piece{};bool bound=scope && scope->bound;
    if (bound) {
        if (!live(*scope) || !native_spellit_source_revalidate(&scope->source)) {reject(*scope,6,kind);machine.restore();return 0;}
        void *selected;std::memcpy(&selected,static_cast<unsigned char *>(scope->gizmo)+0x21c,4);
        if (!native_spellit_piece_resolve(&scope->source,selected,&piece) ||
            target!=(kind==SYNC_PHYSICS_SPELLIT_ENTITY?piece.live_record:piece.receiver)) {
            reject(*scope,7,kind);machine.restore();return 0;
        }
    }
    machine.restore();uint32_t result=original(target);machine.capture();
    if (bound) {
        void *selected=nullptr;
        if (live(*scope) && native_spellit_source_revalidate(&scope->source))
            std::memcpy(&selected,static_cast<unsigned char *>(scope->gizmo)+0x21c,4);
        if (selected!=piece.piece) {reject(*scope,8,kind);machine.restore();return result;}
        auto input=choice(*scope,kind,result!=0,&piece);
        if (resolve_input(*scope,input,&piece)) result=input.world.value;
    }
    machine.restore();return result;
}
uint32_t __attribute__((fastcall)) entity_hook(void *record,void *) {
    return query(record,native_entity,SYNC_PHYSICS_SPELLIT_ENTITY);
}
uint32_t __attribute__((fastcall)) enabled_hook(void *receiver,void *table) {
    NativeQuery original;std::memcpy(&original,static_cast<unsigned char *>(table)+0x1c,4);
    return query(receiver,original,SYNC_PHYSICS_SPELLIT_ENABLED);
}
}

int spellit_input_install(void) {
    if (installed) return 1;
    char trace[8];trace_native=GetEnvironmentVariableA("CLONEWARS_SPELLIT_SOURCE_TRACE",trace,sizeof trace)>0;
    struct Patch {uintptr_t address;unsigned char expected[6];void *target;DWORD protection;unsigned size;};
    Patch patches[]={
        {0x861019,{0xe8,0x42,0xf6,0xfd,0xff},reinterpret_cast<void *>(hop_hook),0,5},
        {0x8407cf,{0xe8,0x6c,0xa8,0xf6,0xff},reinterpret_cast<void *>(entity_hook),0,5},
        {0x840856,{0x8b,0x42,0x1c,0xff,0xd0},reinterpret_cast<void *>(enabled_hook),0,5},
        {0x8406b2,{0x8b,0x8b,0x1c,0x02,0,0},reinterpret_cast<void *>(native_spellit_pose_bridge),0,6}
    };
    for (const auto &patch:patches) if (std::memcmp(reinterpret_cast<void *>(patch.address),patch.expected,patch.size)) return 0;
    unsigned acquired=0;DWORD ignored;
    for (;acquired<4;++acquired) if (!VirtualProtect(reinterpret_cast<void *>(patches[acquired].address),patches[acquired].size,
        PAGE_EXECUTE_READWRITE,&patches[acquired].protection)) break;
    if (acquired!=4) {
        while (acquired) {--acquired;auto &p=patches[acquired];VirtualProtect(reinterpret_cast<void *>(p.address),p.size,p.protection,&ignored);}
        return 0;
    }
    for (const auto &p:patches) {
        auto *code=reinterpret_cast<unsigned char *>(p.address);
        const int32_t relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(p.target)-p.address-5);
        code[0]=p.address==0x8406b2?0xe9:0xe8;std::memcpy(code+1,&relative,4);
        if(p.size>5)std::memset(code+5,0x90,p.size-5);
        FlushInstructionCache(GetCurrentProcess(),code,p.size);
    }
    for (const auto &p:patches) VirtualProtect(reinterpret_cast<void *>(p.address),p.size,p.protection,&ignored);
    installed=true;return 1;
}
