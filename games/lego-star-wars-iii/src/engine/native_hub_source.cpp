#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "native_hub_source.h"
extern "C" {
#include "game_state.h"
}
namespace {
bool readable(const void *p,size_t n) {
    MEMORY_BASIC_INFORMATION m;const auto a=reinterpret_cast<uintptr_t>(p);
    return p && a+n>=a && VirtualQuery(p,&m,sizeof m) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_NOACCESS|PAGE_GUARD)) && a+n<=reinterpret_cast<uintptr_t>(m.BaseAddress)+m.RegionSize;
}
template<class T>T get(const void *p,size_t o=0){T v;std::memcpy(&v,static_cast<const uint8_t *>(p)+o,sizeof v);return v;}
bool snapshot(void *owner,void *frame,NativeHubSource &out,uint32_t &reason) {
    reason=1;NativeHubSource s{};s.owner=owner;s.native_frame=frame;
    if(!readable(owner,0x214)||!readable(frame,0x18))return false;
    s.manager=get<void *>(frame,8);s.ordinal=get<uint32_t>(frame,0xc);
    reason=2;
    if(!readable(s.manager,0x6b8)||
        get<uintptr_t>(s.manager)!=0xae68bc || get<uint32_t>(frame,0x14))return false;
    s.world=get<void *>(reinterpret_cast<void *>(0xfb4a20));s.profile=get<void *>(reinterpret_cast<void *>(0xfbd8bc));
    reason=3;
    if(!readable(s.world,0x22e8)||!readable(s.profile,4)||get<uint32_t>(s.profile)!=0x500||
        !game_native_profile_storage_ready())return false;
    auto *container=get<uint8_t *>(s.world,0x22e4);
    if(!readable(container,0x10)||get<void *>(container,0xc)!=s.world)return false;
    s.definition=get<void *>(s.world,0x220);
    if(!readable(s.definition,0x1b0))return false;
    s.level=get<int16_t>(s.definition,0x94);
    const auto catalog=get<uintptr_t>(reinterpret_cast<void *>(0xfb8404));
    const auto count=get<uint32_t>(reinterpret_cast<void *>(0xfb8410));
    if(!catalog||!count||count>4096||s.level<0||static_cast<uint32_t>(s.level)>=count||
        catalog+static_cast<uintptr_t>(s.level)*0x1b0!=reinterpret_cast<uintptr_t>(s.definition)||
        (get<uint32_t>(s.definition,0x50)&0x40000000u))return false;
    reason=4;s.registry=get<void *>(reinterpret_cast<void *>(0xe906b0));
    if(!readable(s.registry,8+192*20))return false;
    s.registration=get<void *>(s.manager,0x68);
    const auto first=reinterpret_cast<uintptr_t>(s.registry)+8;
    const auto offset=reinterpret_cast<uintptr_t>(s.registration)-first;
    if(offset>=192*20||offset%20)return false;
    std::memcpy(s.registration_data,s.registration,20);
    s.manager_id=get<uint32_t>(s.registration);s.manager_generation=get<uint32_t>(s.registration,4);
    s.manager_type=get<uint32_t>(s.manager,4);
    if(!s.manager_id||!s.manager_type||get<void *>(s.registration,8)!=s.manager||
        get<uint32_t>(s.registration,12)!=4||(get<uint32_t>(s.registration,16)&0xff)||
        get<uint32_t>(s.manager,8)!=s.manager_id||get<uint32_t>(s.manager,0x6c)!=s.manager_generation)return false;
    for(unsigned i=0;i<192;++i){const auto *e=static_cast<uint8_t *>(s.registry)+8+i*20;
        if(get<uint32_t>(e)==s.manager_id&&get<uint32_t>(e,4)==s.manager_generation&&get<uint32_t>(e,12)==4&&
            !(get<uint32_t>(e,16)&0xff)&&get<void *>(e,8)&&get<void *>(e,8)!=s.manager)return false;
    }
    reason=5;s.owner_id=get<uint32_t>(owner,0xb8);
    if(!s.owner_id)return false;
    unsigned matches=0,ids=0,walked=0;auto *node=get<uint8_t *>(s.manager,0x98);
    for(;node&&walked<4096;++walked){
        if(!readable(node,0x214))return false;
        matches+=node==owner;ids+=get<uint32_t>(node,0xb8)==s.owner_id;node=get<uint8_t *>(node,0x9c);
    }
    if(node||matches!=1||ids!=1)return false;
    reason=6;const int native_count=get<int8_t>(owner,0x1b4);
    if(native_count<=0||s.ordinal>=static_cast<uint32_t>(native_count))return false;
    s.count=static_cast<uint32_t>(native_count);s.records=get<void *>(owner,0xcc);
    if(!readable(s.records,s.count*100))return false;
    s.record=static_cast<uint8_t *>(s.records)+s.ordinal*100;
    std::memcpy(s.record_data,s.record,100);s.serial=(static_cast<uint32_t>(s.level)<<7)|s.ordinal;
    out=s;reason=0;return true;
}
bool resolve(void *owner,void *frame,const uint32_t args[12],NativeHubSource &out,uint32_t &reason){
    NativeHubSource a{},b{};
    if(!args||!snapshot(owner,frame,a,reason))return false;
    reason=7;
    if(args[0]>0x257||!readable(reinterpret_cast<void *>(args[1]),12)||args[2]>UINT16_MAX||
        !readable(reinterpret_cast<void *>(args[3]),1)||args[4]||args[5]!=1||args[6]||args[7]||args[8]||args[9]||args[10]||args[11]!=UINT32_MAX)return false;
    if(!snapshot(owner,frame,b,reason))return false;
    reason=8;if(std::memcmp(&a,&b,sizeof a))return false;
    out=a;reason=0;return true;
}
}
int native_hub_source_resolve(void *owner,void *frame,const uint32_t args[12],NativeHubSource *out,uint32_t *reason){
    DWORD error=GetLastError();uint32_t code=1;int result=0;
    __try{if(out)result=resolve(owner,frame,args,*out,code);}__except(EXCEPTION_EXECUTE_HANDLER){code=9;result=0;}
    if(reason)*reason=code;SetLastError(error);return result;
}
int native_hub_source_revalidate(const NativeHubSource *source){
    DWORD error=GetLastError();uint32_t reason=0;int result=0;
    __try{NativeHubSource now{};if(source&&snapshot(source->owner,source->native_frame,now,reason))result=!std::memcmp(source,&now,sizeof now);}
    __except(EXCEPTION_EXECUTE_HANDLER){result=0;}
    SetLastError(error);return result;
}
