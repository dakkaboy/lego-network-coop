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
static_assert(sizeof(NativeSpellItSourceKey)==24 && sizeof(NativeSpellItPieceKey)==48);
static_assert(sizeof(SyncPhysicsWorldInput)==80 && sizeof(SyncPhysicsChoice)==88);
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
        auto input=choice(s,SYNC_PHYSICS_SPELLIT_SEED,*reinterpret_cast<uint32_t *>(0xea178c));
        if (!resolve_input(s,input)) return nullptr;
        // This is the game's shared stream; keep the original hop's subsequent advances.
        *reinterpret_cast<uint32_t *>(0xea178c)=input.world.value;
        ++clonewars_spellit_hop_debug[0];
    }
    uint32_t delta_bits;std::memcpy(&delta_bits,&s.delta,4);
    // The native stack argument is unchanged; integer marshalling preserves incoming XMM registers.
    s.machine.restore();native_hop(s.gizmo,delta_bits);s.machine.capture();return nullptr;
}
void __cdecl abort_hop(void *raw) {current=static_cast<HopScope *>(raw)->previous;}
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
    struct Patch {uintptr_t address;unsigned char expected[5];void *target;DWORD protection;};
    Patch patches[]={
        {0x861019,{0xe8,0x42,0xf6,0xfd,0xff},reinterpret_cast<void *>(hop_hook),0},
        {0x8407cf,{0xe8,0x6c,0xa8,0xf6,0xff},reinterpret_cast<void *>(entity_hook),0},
        {0x840856,{0x8b,0x42,0x1c,0xff,0xd0},reinterpret_cast<void *>(enabled_hook),0}
    };
    for (const auto &patch:patches) if (std::memcmp(reinterpret_cast<void *>(patch.address),patch.expected,5)) return 0;
    unsigned acquired=0;DWORD ignored;
    for (;acquired<3;++acquired) if (!VirtualProtect(reinterpret_cast<void *>(patches[acquired].address),5,
        PAGE_EXECUTE_READWRITE,&patches[acquired].protection)) break;
    if (acquired!=3) {
        while (acquired) {--acquired;auto &p=patches[acquired];VirtualProtect(reinterpret_cast<void *>(p.address),5,p.protection,&ignored);}
        return 0;
    }
    for (const auto &p:patches) {
        auto *code=reinterpret_cast<unsigned char *>(p.address);
        const int32_t relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(p.target)-p.address-5);
        code[0]=0xe8;std::memcpy(code+1,&relative,4);FlushInstructionCache(GetCurrentProcess(),code,5);
    }
    for (const auto &p:patches) VirtualProtect(reinterpret_cast<void *>(p.address),5,p.protection,&ignored);
    installed=true;return 1;
}
