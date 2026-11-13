#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <map>
#include <vector>
#include "spellit_input_sync.h"
#include "physics_input_sync.h"
#include "../engine/native_spellit_source.h"
#include "../engine/spellit_completion_thunk.h"
extern "C" {
#include "game_sync.h"
#include "../engine/constructor_lexical_seh.h"
__declspec(dllexport) volatile uint32_t clonewars_spellit_hop_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_spellit_hop_failure[12];
__declspec(dllexport) volatile uint32_t clonewars_spellit_hop_correction[12];
__declspec(dllexport) volatile uint32_t clonewars_spellit_native_count;
__declspec(dllexport) volatile uint32_t clonewars_spellit_native_batch[256][40];
__declspec(dllexport) volatile uint32_t clonewars_spellit_body_debug[4],clonewars_spellit_body_correction[8];
__attribute__((used)) static volatile uintptr_t spellit_target_resume=0x8406b8;
__attribute__((used)) static volatile uintptr_t spellit_timeout_flags_resume=0x812d81,spellit_finish_flags_resume=0x812df7;
__declspec(dllexport) volatile uint32_t clonewars_spellit_completion_debug[8];
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
static_assert(sizeof(SyncPhysicsSpellItSelectionInput)==80);
static_assert(sizeof(SyncPhysicsSpellItBodyInput)==80 && sizeof(NativeSpellItBodyState)==96);
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

struct BodyCache {NativeSpellItSource source{};std::vector<NativeSpellItBody> bindings;};
thread_local std::map<void *,BodyCache> body_cache;
thread_local uint32_t body_cache_release,body_cache_epoch;
bool same_bodies(const HopScope &s,const BodyCache &cache) {
    if(std::memcmp(&s.source,&cache.source,sizeof s.source)||cache.bindings.size()!=s.source.piece_count)return false;
    auto *piece=static_cast<unsigned char *>(s.source.piece_head);void *previous=nullptr;
    for(const auto &body:cache.bindings){
        if(!live(s)||piece!=body.piece||!probe_readable(piece,0x104))return false;
        void *prior,*next;std::memcpy(&prior,piece,4);std::memcpy(&next,piece+4,4);
        if(prior!=previous||!native_spellit_body_matches(&s.source,&body))return false;
        previous=piece;piece=static_cast<unsigned char *>(next);
    }
    return !piece&&previous==s.source.piece_tail;
}
int body_guard(void *context){return live(*static_cast<HopScope *>(context));}
bool body_inputs(HopScope &s) {
    const auto failure=[&](){if(live(s)){++clonewars_spellit_body_debug[3];reject(s,20,SYNC_PHYSICS_SPELLIT_BODY_BASIS);}return false;};
    if(!live(s))return false;
    if(body_cache_release!=s.token.release||body_cache_epoch!=s.token.epoch){body_cache.clear();body_cache_release=s.token.release;body_cache_epoch=s.token.epoch;}
    auto &cache=body_cache[s.gizmo];
    if(!same_bodies(s,cache)){
        BodyCache next;next.source=s.source;next.bindings.reserve(s.source.piece_count);
        auto *piece=static_cast<unsigned char *>(s.source.piece_head);
        for(uint32_t i=0;i<s.source.piece_count;++i){
            if(!live(s)||!probe_readable(piece,0x104))return failure();
            NativeSpellItBody body{};if(native_spellit_body_resolve(&s.source,piece,&body)<0)return failure();
            if(!live(s))return false;
            next.bindings.push_back(body);std::memcpy(&piece,piece+4,4);
        }
        if(!same_bodies(s,next))return failure();
        cache=std::move(next);
    }
    const auto bindings=cache.bindings;
    struct Input {NativeSpellItBody binding;NativeSpellItBodyState local,canonical;};
    std::vector<Input> inputs;inputs.reserve(bindings.size());
    for(const auto &body:bindings){
        if(!body.dynamics)continue;
        if(inputs.size()>=SYNC_MAX_PHYSICS_CHOICES/2)return failure();
        Input input{};input.binding=body;
        if(!live(s)||!native_spellit_body_read(&s.source,&body,&input.local))return failure();
        input.canonical=input.local;
        for(unsigned part=0;part<2;++part){
            SyncPhysicsChoice choice{};choice.kind=part?SYNC_PHYSICS_SPELLIT_BODY_MOTION:SYNC_PHYSICS_SPELLIT_BODY_BASIS;choice.site=0x840660;
            auto &values=choice.spellit_body;values.clock=s.clock;std::memcpy(values.key,body.key,sizeof values.key);
            values.body_class=body.body_class;values.piece_ordinal=body.piece_ordinal;
            std::memcpy(values.values,reinterpret_cast<const unsigned char *>(&input.local)+part*48,48);
            if(!physics_choice_valid(&choice))return failure();
            auto expected=choice;
            if(!live(s)||physics_world_input(&choice,&s.token)!=1||!live(s))return failure();
            std::memcpy(expected.spellit_body.values,values.values,48);
            if(std::memcmp(&choice,&expected,sizeof choice)||!physics_choice_valid(&choice))return failure();
            std::memcpy(reinterpret_cast<unsigned char *>(&input.canonical)+part*48,values.values,48);
        }
        inputs.push_back(input);
    }
    if(!live(s)||!native_spellit_source_revalidate(&s.source))return failure();
    for(const auto &input:inputs){
        NativeSpellItBodyState current{};
        if(!live(s)||!native_spellit_body_read(&s.source,&input.binding,&current)||std::memcmp(&current,&input.local,sizeof current))return failure();
    }
    for(const auto &input:inputs){
        if(!live(s))return false;
        const bool corrected=std::memcmp(&input.local,&input.canonical,sizeof input.local)!=0;
        // Native body normalization must use the game's precision, not the SEH helper's.
        MachineState helper;helper.capture();s.machine.restore();
        const int applied=native_spellit_body_apply(&s.source,&input.binding,&input.canonical,body_guard,&s);
        helper.restore();if(!applied)return failure();
        if(!live(s))return false;
        ++clonewars_spellit_body_debug[0];
        if(!corrected){++clonewars_spellit_body_debug[1];continue;}
        ++clonewars_spellit_body_debug[2];
        if(!clonewars_spellit_body_correction[0]){
            const uint32_t values[]={s.token.epoch,s.token.sequence,s.clock,input.binding.piece_ordinal,input.binding.body_class,
                input.binding.key[0],input.binding.key[1],s.source.key.gizmo_ordinal};
            std::memcpy(const_cast<uint32_t *>(clonewars_spellit_body_correction),values,sizeof values);
        }
    }
    return live(s);
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
        if(!body_inputs(s))return nullptr;
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
uint32_t query(void *target,NativeQuery original,unsigned kind,uint32_t site=0) {
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
        if(site)input.site=site;
        if (resolve_input(*scope,input,&piece)) result=input.world.value;
    }
    machine.restore();return result;
}
uint32_t __attribute__((fastcall)) entity_hook(void *record,void *) {
    return query(record,native_entity,SYNC_PHYSICS_SPELLIT_ENTITY);
}
void selection_input(void *gizmo,uint32_t site) {
    HopScope *scope=current;
    if(scope && scope->bound) {
        SyncPhysicsChoice input{};input.kind=SYNC_PHYSICS_SPELLIT_SELECTION;
        input.site=site;
        auto &selection=input.spellit_selection;
        if(scope->gizmo!=gizmo || !live(*scope) ||
           !native_spellit_selection_snapshot(&scope->source,&selection.candidate_count,selection.eligibility)) {
            reject(*scope,13,input.kind);return;
        }
        selection.clock=scope->clock;selection.engine_seed=*reinterpret_cast<uint32_t *>(0xea178c);
        std::memcpy(selection.source_name,scope->source.key.name,sizeof selection.source_name);
        selection.gizmo_class=scope->source.key.gizmo_class;selection.gizmo_ordinal=scope->source.key.gizmo_ordinal;
        selection.piece_count=scope->source.piece_count;const auto before=input;
        if(physics_world_input(&input,&scope->token)!=1) {reject(*scope,14,input.kind);return;}
        uint32_t candidates,eligibility[4];
        if(!live(*scope) || !native_spellit_selection_snapshot(&scope->source,&candidates,eligibility) ||
           candidates!=before.spellit_selection.candidate_count ||
           std::memcmp(eligibility,before.spellit_selection.eligibility,sizeof eligibility) ||
           !physics_choice_same_source(&before,&input) ||
           *reinterpret_cast<uint32_t *>(0xea178c)!=before.spellit_selection.engine_seed) {
            reject(*scope,15,input.kind);return;
        }
        *reinterpret_cast<uint32_t *>(0xea178c)=selection.engine_seed;
        ++clonewars_spellit_hop_debug[1];
        if(selection.engine_seed!=before.spellit_selection.engine_seed)++clonewars_spellit_hop_debug[2];
    }
}
void *__attribute__((fastcall)) selection_hook(void *gizmo,void *) {
    MachineState machine;machine.capture();
    selection_input(gizmo,reinterpret_cast<uintptr_t>(__builtin_return_address(0))-5);
    using Selection=void *(__attribute__((thiscall)) *)(void *);
    machine.restore();void *result=reinterpret_cast<Selection>(0x7da280)(gizmo);machine.capture();
    machine.restore();return result;
}
uint32_t __attribute__((fastcall)) enabled_hook(void *receiver,void *table) {
    NativeQuery original;std::memcpy(&original,static_cast<unsigned char *>(table)+0x1c,4);
    const auto site=static_cast<uint32_t>(reinterpret_cast<uintptr_t>(__builtin_return_address(0)));
    if(current && current->bound && (site==0x812d8c || site==0x812e02))
        ++clonewars_spellit_completion_debug[site==0x812d8c?2:3];
    return query(receiver,original,SYNC_PHYSICS_SPELLIT_ENABLED,site);
}
extern "C" uint32_t __cdecl native_spellit_receiver_flags(void *receiver,uint32_t site) {
    const DWORD error=GetLastError();
    const uint32_t local=static_cast<unsigned char *>(receiver)[0x183]&4;
    uint32_t result=local;HopScope *scope=current;
    if(scope && scope->bound) {
        NativeSpellItPiece piece{};void *selected=nullptr;
        if(live(*scope) && native_spellit_source_revalidate(&scope->source))
            std::memcpy(&selected,static_cast<unsigned char *>(scope->gizmo)+0x21c,4);
        if(!selected || !native_spellit_piece_resolve(&scope->source,selected,&piece) || piece.receiver!=receiver)
            reject(*scope,21,SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS);
        else {
            auto input=choice(*scope,SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS,local,&piece);input.site=site;
            ++clonewars_spellit_completion_debug[site==0x812d7a?0:1];
            if(resolve_input(*scope,input,&piece)) {
                result=input.world.value;
                if(result!=local)++clonewars_spellit_completion_debug[4];
            }
        }
    }
    SetLastError(error);return result;
}
extern "C" __attribute__((naked)) void native_spellit_timeout_flags_bridge(void) {
    __asm__ volatile(SPELLIT_RECEIVER_FLAGS_ASM(0x812d7a,spellit_timeout_flags_resume));
}
extern "C" __attribute__((naked)) void native_spellit_finish_flags_bridge(void) {
    __asm__ volatile(SPELLIT_RECEIVER_FLAGS_ASM(0x812df0,spellit_finish_flags_resume));
}
}

int spellit_input_install(void) {
    if (installed) return 1;
    char trace[8];trace_native=GetEnvironmentVariableA("CLONEWARS_SPELLIT_SOURCE_TRACE",trace,sizeof trace)>0;
    struct Patch {uintptr_t address;unsigned char expected[7];void *target;DWORD protection;unsigned size;};
    Patch patches[]={
        {0x861019,{0xe8,0x42,0xf6,0xfd,0xff},reinterpret_cast<void *>(hop_hook),0,5},
        {0x8407cf,{0xe8,0x6c,0xa8,0xf6,0xff},reinterpret_cast<void *>(entity_hook),0,5},
        {0x840856,{0x8b,0x42,0x1c,0xff,0xd0},reinterpret_cast<void *>(enabled_hook),0,5},
        {0x812d87,{0x8b,0x42,0x1c,0xff,0xd0},reinterpret_cast<void *>(enabled_hook),0,5},
        {0x812dfd,{0x8b,0x42,0x1c,0xff,0xd0},reinterpret_cast<void *>(enabled_hook),0,5},
        {0x812d7a,{0xf6,0x81,0x83,0x01,0,0,4},reinterpret_cast<void *>(native_spellit_timeout_flags_bridge),0,7},
        {0x812df0,{0xf6,0x81,0x83,0x01,0,0,4},reinterpret_cast<void *>(native_spellit_finish_flags_bridge),0,7},
        {0x8406b2,{0x8b,0x8b,0x1c,0x02,0,0},reinterpret_cast<void *>(native_spellit_pose_bridge),0,6},
        {0x8406a7,{0xe8,0xd4,0x9b,0xf9,0xff},reinterpret_cast<void *>(selection_hook),0,5},
        {0x840790,{0xe8,0xeb,0x9a,0xf9,0xff},reinterpret_cast<void *>(selection_hook),0,5},
        {0x840b93,{0xe8,0xe8,0x96,0xf9,0xff},reinterpret_cast<void *>(selection_hook),0,5}
    };
    for (const auto &patch:patches) if (std::memcmp(reinterpret_cast<void *>(patch.address),patch.expected,patch.size)) return 0;
    unsigned acquired=0;DWORD ignored;
    constexpr unsigned patch_count=sizeof patches/sizeof *patches;
    for (;acquired<patch_count;++acquired) if (!VirtualProtect(reinterpret_cast<void *>(patches[acquired].address),patches[acquired].size,
        PAGE_EXECUTE_READWRITE,&patches[acquired].protection)) break;
    if (acquired!=patch_count) {
        while (acquired) {--acquired;auto &p=patches[acquired];VirtualProtect(reinterpret_cast<void *>(p.address),p.size,p.protection,&ignored);}
        return 0;
    }
    for (const auto &p:patches) {
        auto *code=reinterpret_cast<unsigned char *>(p.address);
        const int32_t relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(p.target)-p.address-5);
        code[0]=(p.address==0x8406b2 || p.address==0x812d7a || p.address==0x812df0)?0xe9:0xe8;std::memcpy(code+1,&relative,4);
        if(p.size>5)std::memset(code+5,0x90,p.size-5);
        FlushInstructionCache(GetCurrentProcess(),code,p.size);
    }
    for (const auto &p:patches) VirtualProtect(reinterpret_cast<void *>(p.address),p.size,p.protection,&ignored);
    installed=true;return 1;
}
