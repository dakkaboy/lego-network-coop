#undef NDEBUG
#include <cassert>
#include <cstring>
#include "../src/sync/rts_generator_input_sync.cpp"
__attribute__((used)) static unsigned char image[0x1200000];
static unsigned char object[0x2a8],team[0x10d4],descriptor[0x34],resource[0x10],world[4],engine[0xe10];
static bool alive=true;static unsigned mode,calls,original_calls,faults;
static void put(void *p,unsigned off,uint32_t value){std::memcpy(static_cast<unsigned char *>(p)+off,&value,4);}
static uint32_t get(const void *p,unsigned off){uint32_t v;std::memcpy(&v,static_cast<const unsigned char *>(p)+off,4);return v;}
extern "C" int coherent_frame_get(CoherentFrameToken *t,uint32_t){*t={};t->sequence=44;return alive;}
extern "C" int coherent_frame_valid(const CoherentFrameToken *t,uint32_t){return alive && t->sequence==44;}
extern "C" void game_sync_native_fault(int reason){assert(reason==15);++faults;}
extern "C" void *constructor_lexical_seh(void *p,ConstructorLexicalInvoke f,ConstructorLexicalAbort){return f(p);}
extern "C" int physics_world_input(SyncPhysicsChoice *c,const CoherentFrameToken *){
 ++calls;assert(physics_choice_valid(c));
 auto &v=c->rts_generator;v.delta=.017f;v.elapsed=.25f;v.countdown=-.1f;v.phase_time=2;v.previous_state=4;v.rng_game=123;v.rng_engine=456;v.rng_effects=789;v.timer_delta=.023f;
 if(mode==1)++v.index;if(mode==2)alive=false;if(mode==3)put(resource,0xc,0);
 if(mode==4)v.delta=NAN;if(mode==5)++v.state;
 SetLastError(999);return mode==6?-1:1;
}
static void __attribute__((thiscall)) original(void *p,uint32_t delta){
 ++original_calls;assert(p==object);float f;std::memcpy(&f,&delta,4);assert(f==.017f);
 assert(get(object,0x264)==4 && get(object,0x268)==4);
 float values[3];std::memcpy(values,object+0x26c,12);assert(values[0]==.25f && values[1]==-.1f && values[2]==2);
 assert(*reinterpret_cast<uint32_t *>(0xe637b4)==123 && *reinterpret_cast<uint32_t *>(0xea178c)==456 && *reinterpret_cast<uint32_t *>(0xe5f498)==789);
 float timer_delta;std::memcpy(&timer_delta,engine+0xe0c,4);assert(timer_delta==.023f);
 assert(GetLastError()==123);SetLastError(321);
}
int main(){
 assert(reinterpret_cast<uintptr_t>(image)<0xfb0000 && reinterpret_cast<uintptr_t>(image)+sizeof image>0xfc0000);
 *reinterpret_cast<uint32_t *>(0xfb4b6c)=100;*reinterpret_cast<void **>(0xfb4a20)=world;*reinterpret_cast<void **>(0xfb0afc)=engine;
 put(object,0,0xaed18c);put(object,0x28,reinterpret_cast<uintptr_t>(team));put(object,0x250,1);put(object,0x254,1);
 put(team,0,0xaef0fc);put(team,0x1c,reinterpret_cast<uintptr_t>(descriptor));put(team,0x10d0,reinterpret_cast<uintptr_t>(resource));put(descriptor,0x30,0);
 for(mode=0;mode<7;++mode){
  alive=true;put(resource,0xc,reinterpret_cast<uintptr_t>(world));put(object,0x264,4);put(object,0x268,3);std::memset(object+0x26c,0,12);const float local_delta=.1f;std::memcpy(engine+0xe0c,&local_delta,4);
  const auto before=original_calls;SetLastError(123);rts_generator_input_update(object,0x3dcccccd,original);
  assert(original_calls==before+(mode==0));assert(GetLastError()==(mode?123u:321u));
  if(mode)assert(get(object,0x268)==3 && !get(object,0x26c) && !get(object,0x270));
 }
 alive=true;put(resource,0xc,reinterpret_cast<uintptr_t>(world));NativeRtsGeneratorSource source{};assert(native_rts_generator_source(object,&source));
 put(object,0x250,2);assert(!native_rts_generator_source_live(&source));put(object,0x250,1);
 put(object,0x254,2);assert(!native_rts_generator_source(object,&source));put(object,0x254,1);
 put(descriptor,0x30,SYNC_MAX_RTS_TEAMS);assert(!native_rts_generator_source(object,&source));put(descriptor,0x30,0);
 SyncPhysicsChoice c{};c.kind=SYNC_PHYSICS_RTS_GENERATOR;c.site=0x547d30;c.rts_generator.object_class=0xaed18c;
 c.rts_generator.state=c.rts_generator.previous_state=UINT32_MAX;assert(physics_choice_valid(&c));
 auto other=c;other.rts_generator.previous_state=0;other.rts_generator.delta=.1f;assert(physics_choice_same_source(&c,&other));
 other.rts_generator.state=0;assert(!physics_choice_same_source(&c,&other));
 other=c;other.rts_generator.reserved[4]=1;assert(!physics_choice_valid(&other));
}
