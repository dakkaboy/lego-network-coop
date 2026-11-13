#undef NDEBUG
#include <cassert>
#include <cmath>
#include <cstdio>
#include "../src/sync/rts_body_input_sync.cpp"
__attribute__((used)) static unsigned char image[0x1200000];
static unsigned char obj[0x290],pad[0x280],team[0x10d4],world[0x22e8],resource[0x10],descriptor[0x34],model[0x60],receiver[0x1a4],body[0xa0],dynamics[0x50];
static unsigned char gizmo_manager[0x2c],gizmo_registry[0x2c],container[0x10],world_handle[4],manager_table[4];
static bool enabled=true,alive=true,create_model=false;static unsigned mode,inputs,originals,applies,faults;static float expected[24];static unsigned visibility_originals;
static void put(void *p,unsigned o,uintptr_t v){uint32_t w=v;std::memcpy(static_cast<unsigned char *>(p)+o,&w,4);}
extern "C" int coherent_frame_get(CoherentFrameToken *t,uint32_t){*t={};t->sequence=44;return enabled;}
extern "C" int coherent_frame_valid(const CoherentFrameToken *t,uint32_t){return alive&&t->sequence==44;}
extern "C" void game_sync_native_fault(int r){assert(r==15);++faults;}
extern "C" void *constructor_lexical_seh(void *p,ConstructorLexicalInvoke f,ConstructorLexicalAbort){return f(p);}
extern "C" int physics_world_input(SyncPhysicsChoice *c,const CoherentFrameToken *){
 assert(physics_choice_valid(c));++inputs;if(c->kind==SYNC_PHYSICS_RTS_VISIBILITY){c->world.value=1;if(mode==12)alive=false;if(mode==11)c->world.source_name[0]^=1;SetLastError(999);return 1;}const unsigned part=c->kind==SYNC_PHYSICS_RTS_BODY_MOTION;std::memcpy(c->spellit_body.values,expected+12*part,48);
 if(mode==1)c->spellit_body.key[0]^=1;if(mode==2)alive=false;if(mode==3)put(pad,0x114,0);if(mode==4)c->spellit_body.values[0]=NAN;
 SetLastError(999);return 1;
}
static void __attribute__((thiscall)) matrix(void *p,const float *v){assert(p==body&&!std::memcmp(v,expected,64));++applies;SetLastError(777);}
static void __attribute__((thiscall)) linear(void *p,const float *v){assert(p==model&&!std::memcmp(v,expected+16,16));++applies;}
static void __attribute__((thiscall)) angular(void *p,const float *v){assert(p==model&&!std::memcmp(v,expected+20,16));++applies;}
static void __attribute__((thiscall)) original(void *p,uint32_t state,uint32_t flag){assert(p==obj&&state==5&&flag==1);assert(GetLastError()==123);++originals;if(create_model)put(obj,0x28c,reinterpret_cast<uintptr_t>(model));SetLastError(321);}
static void __attribute__((thiscall)) visibility_original(void *p,uint32_t delta){assert(p==obj&&delta==1234&&GetLastError()==123);if(enabled)assert(pad[0x27d]==1);++visibility_originals;SetLastError(321);}
template<class T>void jump(uintptr_t a,T f){auto *p=reinterpret_cast<unsigned char *>(a);DWORD before;assert(VirtualProtect(p,5,PAGE_EXECUTE_READWRITE,&before));p[0]=0xe9;int32_t rel=reinterpret_cast<uintptr_t>(f)-a-5;std::memcpy(p+1,&rel,4);assert(FlushInstructionCache(GetCurrentProcess(),p,5));}
int main(){
 assert(reinterpret_cast<uintptr_t>(image)<0xa29570&&reinterpret_cast<uintptr_t>(image)+sizeof image>0xfb4b70);
 jump(0xa29570,matrix);jump(0x8b5cd0,linear);jump(0x8b5e00,angular);
 *reinterpret_cast<void **>(0xe90184)=gizmo_registry;put(gizmo_registry,0x28,1);put(world,0x400,reinterpret_cast<uintptr_t>(world_handle));put(world_handle,0,reinterpret_cast<uintptr_t>(manager_table));put(manager_table,0,reinterpret_cast<uintptr_t>(gizmo_manager));put(gizmo_manager,0,0xaea284);put(gizmo_manager,0x24,reinterpret_cast<uintptr_t>(pad));put(pad,0,0xaee174);put(pad,0x28,reinterpret_cast<uintptr_t>(gizmo_manager));put(world,0x22e4,reinterpret_cast<uintptr_t>(container));put(container,0xc,reinterpret_cast<uintptr_t>(world));
 *reinterpret_cast<void **>(0xfb4a20)=world;*reinterpret_cast<uint32_t *>(0xfb4b6c)=100;
 put(obj,0,0xaeea9c);put(obj,0x24,reinterpret_cast<uintptr_t>(pad));put(obj,0x28,reinterpret_cast<uintptr_t>(team));
 put(team,0,0xaef0fc);put(team,0x1c,reinterpret_cast<uintptr_t>(descriptor));put(team,0x34,reinterpret_cast<uintptr_t>(pad));put(team,0x10d0,reinterpret_cast<uintptr_t>(resource));put(resource,0xc,reinterpret_cast<uintptr_t>(world));
 std::memcpy(world+0x81,"NativeWorld",12);std::memcpy(pad+0x30,"NativePad",10);put(model,0x3c,reinterpret_cast<uintptr_t>(receiver));put(model,0x58,0x02000000);put(receiver,0x1a0,reinterpret_cast<uintptr_t>(body));put(body,0,0xc69eac);put(body,0x28,reinterpret_cast<uintptr_t>(receiver));put(body,0x98,reinterpret_cast<uintptr_t>(dynamics));put(body,0x1c,reinterpret_cast<uintptr_t>("NativeBody"));
 expected[0]=expected[5]=expected[10]=expected[15]=1;expected[12]=2;expected[16]=3;expected[20]=4;

 for(mode=0;mode<5;++mode){alive=true;put(pad,0x114,reinterpret_cast<uintptr_t>(obj));put(obj,0x28c,reinterpret_cast<uintptr_t>(model));const auto before=originals;const auto applied=applies;SetLastError(123);rts_body_input_update(obj,5,1,original);assert(originals==before+1);assert(applies==applied+(mode==0?3:0));assert(GetLastError()==321u);}
 alive=true;mode=0;put(pad,0x114,reinterpret_cast<uintptr_t>(obj));put(obj,0x28c,0);auto before=originals;auto prior=inputs;SetLastError(123);rts_body_input_update(obj,5,1,original);assert(originals==before+1&&inputs==prior);
 create_model=true;before=originals;prior=inputs;SetLastError(123);rts_body_input_update(obj,5,1,original);assert(originals==before+1&&inputs==prior+2);prior=inputs;create_model=false;
 enabled=false;put(obj,0x24,0);before=originals;SetLastError(123);rts_body_input_update(obj,5,1,original);assert(originals==before+1&&inputs==prior);assert(faults==3);
 enabled=true;put(obj,0x24,reinterpret_cast<uintptr_t>(pad));
 for(mode=10;mode<13;++mode){alive=true;pad[0x27d]=0;const auto n=visibility_originals;SetLastError(123);rts_visibility_input_update(obj,1234,visibility_original);assert(visibility_originals==n+(mode==10)&&GetLastError()==(mode==10?321u:123u));assert(pad[0x27d]==(mode==10));}
 enabled=false;auto n=visibility_originals;prior=inputs;SetLastError(123);rts_visibility_input_update(obj,1234,visibility_original);assert(visibility_originals==n+1&&inputs==prior&&pad[0x27d]==0);
 NativeRtsObjectSource object_source{};put(team,0x34,0);assert(native_rts_object_source(obj,object_source));put(gizmo_manager,0x24,0);assert(!native_rts_object_source(obj,object_source));put(gizmo_manager,0x24,reinterpret_cast<uintptr_t>(pad));
 SyncPhysicsChoice c{};c.kind=SYNC_PHYSICS_RTS_BODY_BASIS;c.site=0x544b10;c.spellit_body.key[0]=1;c.spellit_body.body_class=0x869eac;assert(physics_choice_valid(&c));auto b=c;b.spellit_body.values[0]=7;assert(physics_choice_same_source(&c,&b));b.spellit_body.piece_ordinal=1;assert(!physics_choice_same_source(&c,&b));b=c;b.site=0x840660;assert(!physics_choice_valid(&b));
}
