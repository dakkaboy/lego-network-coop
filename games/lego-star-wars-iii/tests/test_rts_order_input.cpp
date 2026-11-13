#undef NDEBUG
#include <cassert>
#include <cstring>
#include "../src/sync/rts_order_input_sync.cpp"
__attribute__((used)) static unsigned char image[0x1200000];
static unsigned char order[0x330],building[0x604],team[0x1a34],descriptor[0x34];
static bool alive=true;static unsigned mode,calls,original_calls,faults;
static void put(void *p,unsigned offset,uint32_t v){std::memcpy(static_cast<unsigned char *>(p)+offset,&v,4);}
static uint32_t get(const void *p,unsigned offset){uint32_t v;std::memcpy(&v,static_cast<const unsigned char *>(p)+offset,4);return v;}
extern "C" int coherent_frame_get(CoherentFrameToken *t,uint32_t){*t={};t->sequence=44;return alive;}
extern "C" int coherent_frame_valid(const CoherentFrameToken *t,uint32_t){return alive && t->sequence==44;}
extern "C" void game_sync_native_fault(int reason){assert(reason==15);++faults;}
extern "C" void *constructor_lexical_seh(void *p,ConstructorLexicalInvoke f,ConstructorLexicalAbort){return f(p);}
extern "C" int physics_world_input(SyncPhysicsChoice *c,const CoherentFrameToken *){
    ++calls;assert(physics_choice_valid(c));
    if(c->site==0x55e2c0){c->rts_order.state=5;c->rts_order.previous_state=4;c->rts_order.elapsed=.5f;c->rts_order.progress=.1f;}
    else c->rts_order.ready=2;
    if(mode==1)++c->rts_order.building_id;
    if(mode==2)alive=false;
    if(mode==3)put(building,0x114,0);
    if(mode==4)c->rts_order.elapsed=NAN;
    SetLastError(999);return mode==5?-1:1;
}
static void __attribute__((thiscall)) original(void *p,uint32_t delta){
    ++original_calls;assert(p==order && delta==0x3dcccccd && get(order,0x2e8)==5 && get(order,0x2ec)==4);
    assert(GetLastError()==123);
    SetLastError(321);assert(native_rts_order_ready(order,0xa0)==0xa2 && GetLastError()==321);
}
int main(){
    assert(reinterpret_cast<uintptr_t>(image)<0xfb0000 && reinterpret_cast<uintptr_t>(image)+sizeof image>0xfc0000);
    *reinterpret_cast<uint32_t *>(0xfb4b6c)=100;
    put(order,0,0xaec000);put(order,0x24,reinterpret_cast<uintptr_t>(building));put(order,0x28,reinterpret_cast<uintptr_t>(team));
    put(team,0,0xaef0fc);put(team,0x1c,reinterpret_cast<uintptr_t>(descriptor));put(descriptor,0x30,0);put(building,0x600,0);
    for(mode=0;mode<6;++mode){
        alive=true;put(building,0x114,reinterpret_cast<uintptr_t>(order));put(order,0x2e8,2);put(order,0x2ec,1);put(order,0x2f0,0);put(order,0x2d4,0);
        NativeRtsOrderSource check{};assert(native_rts_order_source(order,&check));
        const auto before=original_calls;SetLastError(123);rts_order_input_update(order,0x3dcccccd,original);
        assert(original_calls==before+(mode==0));
        if(mode)assert(get(order,0x2e8)==2 && get(order,0x2ec)==1 && get(order,0x2f0)==0 && get(order,0x2d4)==0);
        assert(GetLastError()==(mode?123u:321u));
    }
    alive=true;put(building,0x114,reinterpret_cast<uintptr_t>(order));NativeRtsOrderSource s{};assert(native_rts_order_source(order,&s));
    put(building,0x600,1);assert(!native_rts_order_source_live(&s));put(building,0x600,0);
    put(descriptor,0x30,SYNC_MAX_RTS_TEAMS);assert(!native_rts_order_source(order,&s));put(descriptor,0x30,0);
    assert(native_rts_order_source(order,&s));put(order,0,0xaec004);assert(!native_rts_order_source_live(&s));
}
