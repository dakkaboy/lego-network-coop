#undef NDEBUG
#include <cassert>
#include <cstdio>
#include "../src/sync/spellit_input_sync.cpp"

__attribute__((used)) static unsigned char native_image[0x1200000];
static unsigned char gizmo_memory[0x230],piece_memory[0x120],other_piece[0x120];
static bool alive=true,proof=true;
static unsigned mode,calls,faults;
static unsigned original_calls;
static unsigned selection_calls;
static uint32_t expected_selection_seed;
static bool bodies_enabled,body_proof=true;
static unsigned body_mode,body_applies;
static NativeSpellItBodyState local_body{},canonical_body{};
static float authoritative[3]={340.76535f,44.27975f,47.423156f};
extern "C" int coherent_frame_valid(const CoherentFrameToken *t,uint32_t) {return alive && t && t->sequence==44;}
extern "C" int coherent_frame_get(CoherentFrameToken *t,uint32_t) {*t={};t->sequence=44;return alive;}
extern "C" void game_sync_native_fault(int value){assert(value==15);++faults;}
extern "C" void *constructor_lexical_seh(void *raw,ConstructorLexicalInvoke f,ConstructorLexicalAbort){return f(raw);}
extern "C" int native_spellit_source_resolve(void *g,NativeSpellItSource *s) {
    *s={};s->gizmo=g;s->key={{1,2,3,4},0x8480ac,3};
    if(bodies_enabled){s->piece_count=1;s->piece_head=s->piece_tail=piece_memory;}
    return g==gizmo_memory;
}
extern "C" int native_spellit_source_revalidate(const NativeSpellItSource *){return proof;}
extern "C" int native_spellit_piece_resolve(const NativeSpellItSource *,void *p,NativeSpellItPiece *out) {
    if(p!=piece_memory)return 0;
    *out={};out->piece=p;out->key={{5,6,7,8},{9,10,11,12},265,672,0x820f64,8};return 1;
}
extern "C" int native_spellit_piece_revalidate(const NativeSpellItSource *,const NativeSpellItPiece *){return proof;}
extern "C" int native_spellit_body_resolve(const NativeSpellItSource *,void *piece,NativeSpellItBody *body){
    *body={};body->piece=piece;body->dynamics=&local_body;body->body_class=0x869eac;body->key[0]=123;
    return body_proof?1:-1;
}
extern "C" int native_spellit_body_matches(const NativeSpellItSource *,const NativeSpellItBody *){return body_proof;}
extern "C" int native_spellit_body_read(const NativeSpellItSource *,const NativeSpellItBody *,NativeSpellItBodyState *state){*state=local_body;return body_proof;}
extern "C" int native_spellit_body_apply(const NativeSpellItSource *,const NativeSpellItBody *,const NativeSpellItBodyState *state,int(*live)(void *),void *context){
    uint16_t control;__asm__ volatile("fnstcw %0":"=m"(control));assert(control==0x7f);
    assert(body_proof&&live(context));++body_applies;local_body=*state;return 1;
}
extern "C" int native_spellit_selection_snapshot(const NativeSpellItSource *,uint32_t *count,uint32_t hash[4]) {
    *count=0;for(unsigned i=0;i<4;++i)hash[i]=i+1;return proof;
}
extern "C" int physics_world_input(SyncPhysicsChoice *p,const CoherentFrameToken *) {
    ++calls;assert(physics_choice_valid(p));
    if(p->kind==SYNC_PHYSICS_SPELLIT_BODY_BASIS||p->kind==SYNC_PHYSICS_SPELLIT_BODY_MOTION){
        const unsigned part=p->kind==SYNC_PHYSICS_SPELLIT_BODY_MOTION;
        std::memcpy(p->spellit_body.values,reinterpret_cast<const unsigned char *>(&canonical_body)+part*48,48);
        if(body_mode==1)++p->spellit_body.key[0];
        if(body_mode==2)alive=false;
        if(body_mode==3)body_proof=false;
        if(body_mode==4)local_body.position[1]+=1;
        if(body_mode==5)p->spellit_body.values[0]=NAN;
        if(body_mode==6&&part)return -1;
        return 1;
    }
    if(p->kind==SYNC_PHYSICS_SPELLIT_STEP) {
        p->spellit_step.engine_seed=12345;p->spellit_step.game_seed=23456;
        p->spellit_step.delta=.016f;p->spellit_step.timer=-.004f;return 1;
    }
    if(p->kind==SYNC_PHYSICS_SPELLIT_SELECTION) {
        p->spellit_selection.engine_seed=98765;
        if(mode==1)++p->spellit_selection.eligibility[0];
        if(mode==2)alive=false;
        if(mode==3)proof=false;
        return mode==4?-1:1;
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
static void *__attribute__((thiscall)) original_selection_fixture(void *gizmo) {
    assert(gizmo==gizmo_memory && *reinterpret_cast<uint32_t *>(0xea178c)==expected_selection_seed);
    ++selection_calls;++*reinterpret_cast<uint32_t *>(0xea178c);SetLastError(789);return piece_memory;
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
    bodies_enabled=true;assert(native_spellit_source_resolve(gizmo_memory,&scope.source));
    uint16_t helper_control;const uint16_t native_control=0x7f;
    __asm__ volatile("fnstcw %0\n\tfldcw %1":"=m"(helper_control):"m"(native_control));scope.machine.capture();
    __asm__ volatile("fldcw %0"::"m"(helper_control));
    for(body_mode=0;body_mode<=6;++body_mode){
        body_cache.clear();alive=proof=body_proof=true;local_body={};canonical_body={};
        canonical_body.basis[0]=canonical_body.basis[5]=canonical_body.basis[10]=1;
        canonical_body.position[0]=340.25f;canonical_body.position[3]=1;canonical_body.linear[1]=.5f;canonical_body.angular[2]=.75f;
        const auto before=body_applies;const bool applied=body_inputs(scope);
        assert(applied==(body_mode==0));assert(body_applies==before+(body_mode==0));
        if(!body_mode){
            assert(!std::memcmp(&local_body,&canonical_body,sizeof local_body));
            const auto normalized=body_applies;assert(body_inputs(scope));assert(body_applies==normalized+1);
        }
        else assert(local_body.position[0]==0);
        uint16_t restored;__asm__ volatile("fnstcw %0":"=m"(restored));assert(restored==helper_control);
    }
    bodies_enabled=false;body_mode=0;body_proof=alive=proof=true;assert(native_spellit_source_resolve(gizmo_memory,&scope.source));
    for(mode=0;mode<=4;++mode) {
        alive=proof=true;*reinterpret_cast<uint32_t *>(0xea178c)=111;
        const auto before_faults=faults;selection_input(gizmo_memory,0x840790);
        assert(*reinterpret_cast<uint32_t *>(0xea178c)==(mode?111:98765));
        assert(faults==before_faults+(mode!=0));
    }
    alive=proof=true;
    DWORD selection_old;assert(VirtualProtect(reinterpret_cast<void *>(0x7da280),5,PAGE_EXECUTE_READWRITE,&selection_old));
    auto *selection_code=reinterpret_cast<unsigned char *>(0x7da280);selection_code[0]=0xe9;
    int32_t selection_relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(original_selection_fixture)-0x7da285);
    std::memcpy(selection_code+1,&selection_relative,4);
    const uintptr_t selection_sites[]={0x8406a7,0x840790,0x840b93};
    for(uintptr_t selection_site:selection_sites) {
    auto *callsite=reinterpret_cast<unsigned char *>(selection_site);
    assert(VirtualProtect(callsite,6,PAGE_EXECUTE_READWRITE,&selection_old));callsite[0]=0xe8;
    selection_relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(selection_hook)-selection_site-5);
    std::memcpy(callsite+1,&selection_relative,4);callsite[5]=0xc3;
    assert(FlushInstructionCache(GetCurrentProcess(),nullptr,0));
    for(unsigned bound=0;bound<2;++bound)for(mode=0;mode<=1;++mode) {
        current=bound?&scope:nullptr;alive=proof=true;*reinterpret_cast<uint32_t *>(0xea178c)=222;
        expected_selection_seed=bound&&!mode?98765:222;const auto before=selection_calls;
        void *result;double retained;__asm__ volatile("fld1");
        result=reinterpret_cast<void *(__attribute__((thiscall)) *)(void *)>(callsite)(gizmo_memory);
        __asm__ volatile("fstpl %0":"=m"(retained));
        assert(retained==1 && result==piece_memory && selection_calls==before+1 && GetLastError()==789);
        assert(*reinterpret_cast<uint32_t *>(0xea178c)==expected_selection_seed+1);
    }
    }
    current=&scope;
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
