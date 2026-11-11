#undef NDEBUG
#include <cassert>
#include <cmath>
#include <cstdio>
#include "../src/engine/native_spellit_source.cpp"

__attribute__((used)) static unsigned char native_image[0x1200000];
static unsigned char piece_memory[0x120],model_memory[0x60],receiver_memory[0x1a4],body_memory[0xa0],dynamics_memory[0x50];
static uint32_t body_vtable[8];
static char body_name[]="NativeBody",other_name[]="ReplacedBody";
static bool alive=true;
static unsigned matrix_calls,linear_calls,angular_calls,mutation;
extern "C" int native_authored_poi_resolve(void *,NativeAuthoredPoi *){return 0;}
extern "C" int native_authored_poi_revalidate(const NativeAuthoredPoi *){return 0;}
extern "C" int native_resource_identity_resolve(void *,void *,NativeResourceIdentity *){return 0;}
extern "C" int native_resource_identity_revalidate(const NativeResourceIdentity *){return 0;}
static int lease(void *){return alive;}
static void native_environment(){uint16_t control;__asm__ volatile("fnstcw %0":"=m"(control));assert(control==0x7f);}
static void clobber(){SetLastError(777);__asm__ volatile("fninit\n\tfldz\n\tpcmpeqd %%xmm0,%%xmm0":::"xmm0","memory");}
static void __attribute__((thiscall)) set_matrix(void *body,const float *matrix){
    native_environment();assert(body==body_memory);++matrix_calls;std::memcpy(body_memory+0x40,matrix,64);
    if(mutation==1)alive=false;
    if(mutation==2){void *replacement=nullptr;std::memcpy(body_memory+0x98,&replacement,4);}
    clobber();
}
static void __attribute__((thiscall)) set_linear(void *model,const float *values){native_environment();assert(model==model_memory);++linear_calls;std::memcpy(dynamics_memory+0x20,values,16);clobber();}
static void __attribute__((thiscall)) set_angular(void *model,const float *values){native_environment();assert(model==model_memory);++angular_calls;std::memcpy(dynamics_memory+0x30,values,16);clobber();}
static void install(uintptr_t address,void *function){
    auto *site=reinterpret_cast<unsigned char *>(address);DWORD old;
    assert(VirtualProtect(site,5,PAGE_EXECUTE_READWRITE,&old));site[0]=0xe9;
    const auto relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(function)-address-5);std::memcpy(site+1,&relative,4);
    assert(FlushInstructionCache(GetCurrentProcess(),site,5));
}
static void store(void *base,size_t offset,void *value){std::memcpy(static_cast<unsigned char *>(base)+offset,&value,4);}
int main(){
    assert(reinterpret_cast<uintptr_t>(native_image)<0xa29570&&reinterpret_cast<uintptr_t>(native_image)+sizeof native_image>0xa29575);
    install(0xa29570,reinterpret_cast<void *>(set_matrix));install(0x8b5cd0,reinterpret_cast<void *>(set_linear));install(0x8b5e00,reinterpret_cast<void *>(set_angular));
    NativeSpellItSource source{};source.gizmo=&source;
    NativeSpellItBody binding{};binding.piece=piece_memory;binding.model=model_memory;binding.receiver=receiver_memory;
    binding.body=body_memory;binding.dynamics=dynamics_memory;binding.name=body_name;
    store(piece_memory,0xfc,source.gizmo);store(piece_memory,0x100,model_memory);store(model_memory,0x3c,receiver_memory);
    const uint16_t physical=0x200;std::memcpy(model_memory+0x5a,&physical,2);
    store(receiver_memory,0x1a0,body_memory);store(body_memory,0,body_vtable);store(body_memory,0x98,dynamics_memory);store(body_memory,0x1c,body_name);
    assert(image_class(body_memory,binding.body_class));Hash name;assert(hash_text(name,reinterpret_cast<Byte *>(body_name),128));std::memcpy(binding.name_key,name.word,16);
    NativeSpellItBodyState canonical{};canonical.basis[0]=canonical.basis[5]=canonical.basis[10]=1;canonical.position[0]=7;canonical.position[3]=1;
    canonical.linear[1]=2;canonical.angular[2]=3;
    for(mutation=0;mutation<=2;++mutation){
        alive=true;store(body_memory,0x98,dynamics_memory);std::memset(body_memory+0x40,0,64);std::memset(dynamics_memory+0x20,0,32);
        matrix_calls=linear_calls=angular_calls=0;
        double retained;uint16_t before,after;uint32_t mx_before,mx_after;SetLastError(321);
        const uint16_t native_control=0x7f;
        __asm__ volatile("fninit\n\tfldcw %2\n\tfnstcw %0\n\tstmxcsr %1\n\tfld1":"=m"(before),"=m"(mx_before):"m"(native_control));
        const int result=native_spellit_body_apply(&source,&binding,&canonical,lease,nullptr);
        __asm__ volatile("fstpl %0\n\tfnstcw %1\n\tstmxcsr %2":"=m"(retained),"=m"(after),"=m"(mx_after));
        assert(result==(mutation==0)&&matrix_calls==1&&linear_calls==(mutation==0)&&angular_calls==(mutation==0));
        assert(retained==1&&before==after&&mx_before==mx_after&&GetLastError()==321);
    }
    alive=false;matrix_calls=linear_calls=angular_calls=0;assert(!native_spellit_body_apply(&source,&binding,&canonical,lease,nullptr));assert(!matrix_calls&&!linear_calls&&!angular_calls);
    alive=true;mutation=0;store(body_memory,0x98,dynamics_memory);canonical.linear[0]=NAN;
    assert(!native_spellit_body_apply(&source,&binding,&canonical,lease,nullptr));assert(!matrix_calls&&!linear_calls&&!angular_calls);
    canonical.linear[0]=0;store(body_memory,0x1c,other_name);assert(!native_spellit_body_matches(&source,&binding));
    assert(!native_spellit_body_apply(&source,&binding,&canonical,lease,nullptr));assert(!matrix_calls&&!linear_calls&&!angular_calls);
    puts("Native physical piece setters, retired leases, rebound bodies and machine state passed.");
}
