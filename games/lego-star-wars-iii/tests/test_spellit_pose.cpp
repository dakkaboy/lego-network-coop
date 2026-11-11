#undef NDEBUG
#include <cassert>
#include <cstdio>
#include "../src/sync/spellit_input_sync.cpp"

__attribute__((used)) static unsigned char native_image[0x1200000];
static unsigned char gizmo_memory[0x230],piece_memory[0x120],other_piece[0x120];
static bool alive=true,proof=true;
static unsigned mode,calls,faults;
static unsigned original_calls;
static float authoritative[3]={340.76535f,44.27975f,47.423156f};
extern "C" int coherent_frame_valid(const CoherentFrameToken *t,uint32_t) {return alive && t && t->sequence==44;}
extern "C" int coherent_frame_get(CoherentFrameToken *t,uint32_t) {*t={};t->sequence=44;return alive;}
extern "C" void game_sync_native_fault(int value){assert(value==15);++faults;}
extern "C" void *constructor_lexical_seh(void *raw,ConstructorLexicalInvoke f,ConstructorLexicalAbort){return f(raw);}
extern "C" int native_spellit_source_resolve(void *g,NativeSpellItSource *s) {
    *s={};s->gizmo=g;s->key={{1,2,3,4},0x8480ac,3};return g==gizmo_memory;
}
extern "C" int native_spellit_source_revalidate(const NativeSpellItSource *){return proof;}
extern "C" int native_spellit_piece_resolve(const NativeSpellItSource *,void *p,NativeSpellItPiece *out) {
    if(p!=piece_memory)return 0;
    *out={};out->piece=p;out->key={{5,6,7,8},{9,10,11,12},265,672,0x820f64,8};return 1;
}
extern "C" int native_spellit_piece_revalidate(const NativeSpellItSource *,const NativeSpellItPiece *){return proof;}
extern "C" int physics_world_input(SyncPhysicsChoice *p,const CoherentFrameToken *) {
    ++calls;assert(physics_choice_valid(p));
    if(p->kind==SYNC_PHYSICS_SPELLIT_STEP) {
        p->spellit_step.engine_seed=12345;p->spellit_step.game_seed=23456;
        p->spellit_step.delta=.016f;p->spellit_step.timer=-.004f;return 1;
    }
    assert(p->kind==SYNC_PHYSICS_SPELLIT_POSE);
    std::memcpy(p->spellit_pose.position,authoritative,sizeof authoritative);p->spellit_pose.last_time=.25f;
    if(mode==1)++p->spellit_pose.piece_ordinal;
    if(mode==2)alive=false;
    if(mode==3)proof=false;
    if(mode==4){void *other=other_piece;std::memcpy(gizmo_memory+0x21c,&other,4);}
    if(mode==5)p->spellit_pose.position[1]=NAN;
    SetLastError(999);return 1;
}
static void __attribute__((thiscall)) original_hop_fixture(void *gizmo,uint32_t delta_bits) {
    ++original_calls;float delta,timer;std::memcpy(&delta,&delta_bits,4);
    std::memcpy(&timer,static_cast<unsigned char *>(gizmo)+0x218,4);
    assert(delta==.016f && timer==-.004f && *reinterpret_cast<uint32_t *>(0xea178c)==12345 &&
           *reinterpret_cast<uint16_t *>(0xe637b4)==23456);
    timer-=delta;std::memcpy(static_cast<unsigned char *>(gizmo)+0x218,&timer,4);
    native_spellit_pose_input(gizmo);assert(!std::memcmp(piece_memory+0xd0,authoritative,sizeof authoritative));
    *reinterpret_cast<uint32_t *>(0xea178c)=54321;*reinterpret_cast<uint16_t *>(0xe637b4)=34567;SetLastError(4321);
}
__attribute__((naked)) static uint32_t invoke_bridge(void *) {
    __asm__ volatile("pushl %ebx\n\tmovl 8(%esp),%ebx\n\tmovl $0xcafebabe,%eax\n\tmovl $0x87654321,%edx\n\t"
        "cmpl %eax,%eax\n\tstc\n\tcall _native_spellit_pose_bridge\n\tpushfl\n\t"
        "cmpl $0xcafebabe,%eax\n\tjne 1f\n\tcmpl 0x21c(%ebx),%ecx\n\tjne 1f\n\t"
        "cmpl $0x87654321,%edx\n\tjne 1f\n\tpopl %eax\n\tpopl %ebx\n\tret\n\t"
        "1: addl $4,%esp\n\tpopl %ebx\n\tmovl $-1,%eax\n\tret");
}
int main() {
    assert(reinterpret_cast<uintptr_t>(native_image)<0xfb0000 && reinterpret_cast<uintptr_t>(native_image)+sizeof native_image>0xfc0000);
    *reinterpret_cast<uint32_t *>(0xfb4b6c)=100;
    HopScope scope{};scope.gizmo=gizmo_memory;scope.bound=true;scope.clock=100;scope.token.sequence=44;
    assert(native_spellit_source_resolve(gizmo_memory,&scope.source));current=&scope;
    for(mode=0;mode<=5;++mode) {
        alive=proof=true;void *selected=piece_memory;std::memcpy(gizmo_memory+0x21c,&selected,4);
        const float local_time=-.25f;std::memcpy(piece_memory+0xf4,&local_time,4);
        float local[3]={1,2,3};std::memcpy(piece_memory+0xd0,local,sizeof local);
        const auto before_faults=faults;SetLastError(123);native_spellit_pose_input(gizmo_memory);
        assert(GetLastError()==123);float stamp;std::memcpy(&stamp,piece_memory+0xf4,4);assert(stamp==(mode?local_time:.25f));
        assert(!std::memcmp(piece_memory+0xd0,mode?local:authoritative,sizeof local));
        assert(faults==before_faults+(mode!=0));
    }
    alive=proof=true;mode=0;current=nullptr;const auto before_calls=calls;
    native_spellit_pose_input(gizmo_memory);assert(calls==before_calls);
    void *selected=piece_memory;std::memcpy(gizmo_memory+0x21c,&selected,4);
    DWORD old;assert(VirtualProtect(reinterpret_cast<void *>(0x8406b8),1,PAGE_EXECUTE_READWRITE,&old));
    *reinterpret_cast<unsigned char *>(0x8406b8)=0xc3;
    assert(FlushInstructionCache(GetCurrentProcess(),reinterpret_cast<void *>(0x8406b8),1));
    for(unsigned bound=0;bound<2;++bound) {
        current=bound?&scope:nullptr;const auto calls_before=calls;
        double retained;uint16_t cw_before,cw_after;uint32_t mx_before,mx_after;SetLastError(456);
        __asm__ volatile("fnstcw %0\n\tstmxcsr %1\n\tfld1":"=m"(cw_before),"=m"(mx_before));
        const uint32_t flags=invoke_bridge(gizmo_memory);
        __asm__ volatile("fstpl %0\n\tfnstcw %1\n\tstmxcsr %2":"=m"(retained),"=m"(cw_after),"=m"(mx_after));
        assert(flags!=UINT32_MAX && (flags&0x41)==0x41 && retained==1 && cw_before==cw_after && mx_before==mx_after && GetLastError()==456);
        assert(calls==calls_before+bound);
    }
    assert(VirtualProtect(reinterpret_cast<void *>(0x840660),5,PAGE_EXECUTE_READWRITE,&old));
    auto *code=reinterpret_cast<unsigned char *>(0x840660);code[0]=0xe9;
    const int32_t relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(original_hop_fixture)-0x840665);
    std::memcpy(code+1,&relative,4);assert(FlushInstructionCache(GetCurrentProcess(),code,5));
    const float local_timer=1;std::memcpy(gizmo_memory+0x218,&local_timer,4);
    current=nullptr;mode=0;alive=proof=true;const auto old_calls=calls;
    hop_hook(gizmo_memory,nullptr,.049f);
    assert(original_calls==1 && calls==old_calls+2 && current==nullptr && GetLastError()==4321);
    assert(*reinterpret_cast<uint32_t *>(0xea178c)==54321 && *reinterpret_cast<uint16_t *>(0xe637b4)==34567);
    puts("Native SpellIt pose transaction, stale identities, retired cohort and bridge machine state passed.");
}
