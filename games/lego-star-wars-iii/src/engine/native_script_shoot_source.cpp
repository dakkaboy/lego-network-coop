#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "native_script_shoot_source.h"

namespace {
struct Region {uintptr_t first,last,allocation;DWORD state,protection;};
struct ReadContext {
    Region regions[32]{};unsigned count=0,next=0;
    bool region(uintptr_t address,Region &out) {
        for(unsigned i=0;i<count;++i)if(address>=regions[i].first && address<regions[i].last){out=regions[i];return true;}
        MEMORY_BASIC_INFORMATION m;
        if(!VirtualQuery(reinterpret_cast<void *>(address),&m,sizeof m))return false;
        const uintptr_t first=reinterpret_cast<uintptr_t>(m.BaseAddress),last=first+m.RegionSize;
        if(last<=first || address<first || address>=last)return false;
        out={first,last,reinterpret_cast<uintptr_t>(m.AllocationBase),m.State,m.Protect};
        if(count<32)regions[count++]=out;else{regions[next]=out;next=(next+1)%32;}
        return true;
    }
    bool readable(const void *p,size_t bytes) {
        uintptr_t first=reinterpret_cast<uintptr_t>(p);const uintptr_t last=first+bytes;
        if(!p || !bytes || last<first)return false;
        while(first<last){Region r;if(!region(first,r)||r.state!=MEM_COMMIT||(r.protection&(PAGE_NOACCESS|PAGE_GUARD)))return false;first=r.last<last?r.last:last;}
        return true;
    }
    bool image(uintptr_t address,uint32_t &rva,bool executable=false) {
        const uintptr_t base=reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr));Region r;
        if(address<=base || address-base>UINT32_MAX || !region(address,r) || r.allocation!=base ||
           r.state!=MEM_COMMIT || (r.protection&(PAGE_NOACCESS|PAGE_GUARD)))return false;
        if(executable && !(r.protection&(PAGE_EXECUTE|PAGE_EXECUTE_READ|PAGE_EXECUTE_READWRITE|PAGE_EXECUTE_WRITECOPY)))return false;
        rva=static_cast<uint32_t>(address-base);return true;
    }
    bool image_class(void *object,uint32_t &rva) {
        if(!readable(object,4))return false;uintptr_t table;std::memcpy(&table,object,4);return image(table,rva);
    }
};
template<class T>T get(const void *p,size_t offset=0){T value;std::memcpy(&value,static_cast<const unsigned char *>(p)+offset,sizeof value);return value;}
void hash_byte(uint32_t hash[4],uint8_t value) {
    static const uint32_t primes[4]={16777619u,2246822519u,3266489917u,668265263u};
    for(unsigned i=0;i<4;++i)hash[i]=(hash[i]^value)*primes[i];
}
void hash_word(uint32_t hash[4],uint32_t value){for(unsigned i=0;i<4;++i)hash_byte(hash,static_cast<uint8_t>(value>>(i*8)));}
bool argument_hash(ReadContext &read,void *arguments,uint32_t count,uint32_t hash[4]) {
    const uint32_t initial[4]={2166136261u,0x9e3779b9u,0x85ebca6bu,0xc2b2ae35u};std::memcpy(hash,initial,sizeof initial);
    hash_word(hash,count);
    if(!count)return true;
    if(!read.readable(arguments,count*sizeof(void *)))return false;
    for(uint32_t i=0;i<count;++i) {
        auto *text=get<unsigned char *>(arguments,i*sizeof(void *));uint32_t length=0;
        for(;length<NATIVE_SCRIPT_SHOOT_MAX_STRING;++length) {
            if(!read.readable(text+length,1))return false;
            if(!text[length])break;
        }
        if(length==NATIVE_SCRIPT_SHOOT_MAX_STRING)return false;
        hash_word(hash,length);
        for(uint32_t j=0;j<length;++j)hash_byte(hash,text[j]);
    }
    return true;
}
bool snapshot(void *actor,void *state,void *model,uintptr_t frame,NativeScriptShootSource &out) {
    ReadContext read;NativeScriptShootSource s{};
    if(!read.readable(reinterpret_cast<void *>(0xfb4a20),4) || !read.readable(reinterpret_cast<void *>(0xfb2f60),4) ||
       !read.readable(reinterpret_cast<void *>(0xfb2e3c),4) || !read.readable(reinterpret_cast<void *>(0xfb4b6c),4) ||
       !read.readable(reinterpret_cast<void *>(frame),sizeof s.frame_words))return false;
    s.world=get<void *>(reinterpret_cast<void *>(0xfb4a20));
    if(!read.readable(s.world,0x224))return false;
    s.definition=get<void *>(s.world,0x220);if(!read.readable(s.definition,0x96))return false;
    s.actor_pool=get<uintptr_t>(reinterpret_cast<void *>(0xfb2f60));s.actor_count=get<uint32_t>(reinterpret_cast<void *>(0xfb2e3c));
    const uintptr_t value=reinterpret_cast<uintptr_t>(actor);
    if(!s.actor_pool || !s.actor_count || s.actor_count>4096 || value<s.actor_pool || (value-s.actor_pool)%0x1440)return false;
    s.actor_ordinal=static_cast<uint32_t>((value-s.actor_pool)/0x1440);
    if(s.actor_ordinal>=s.actor_count || !read.readable(actor,0x1440) || !read.readable(model,0x44) || !read.readable(state,0xa8))return false;
    s.actor=actor;s.model=model;s.state=state;s.native_frame=frame;
    std::memcpy(s.frame_words,reinterpret_cast<void *>(frame),sizeof s.frame_words);
    s.wrapper=reinterpret_cast<void *>(s.frame_words[4]);s.arguments=reinterpret_cast<void *>(s.frame_words[5]);s.command=reinterpret_cast<void *>(s.frame_words[2]);
    if(reinterpret_cast<void *>(s.frame_words[3])!=state || !read.readable(s.wrapper,8) || get<void *>(s.wrapper,4)!=actor || get<void *>(actor,8)!=model)return false;
    s.brain=get<void *>(model,0x34);
    if(!read.readable(s.brain,0x19c) || !read.image_class(model,s.input.model_class) || !read.image_class(s.brain,s.input.brain_class) ||
       !read.image_class(state,s.input.state_class) || !read.image(s.frame_words[1],s.input.caller_rva,true))return false;
    s.brain_admission_raw=get<uint32_t>(s.brain,0x198);if(!s.brain_admission_raw)return false;
    s.input.brain_admission=1;
    s.input.clock=get<uint32_t>(reinterpret_cast<void *>(0xfb4b6c));s.input.state_flags=get<uint16_t>(state,0xa6);
    s.input.argument_count=s.frame_words[6];s.input.initialize=s.frame_words[7]!=0;
    if(s.input.argument_count>NATIVE_SCRIPT_SHOOT_MAX_ARGUMENTS || !argument_hash(read,s.arguments,s.input.argument_count,s.input.argument_hash))return false;
    out=s;return true;
}
bool dispatch_snapshot(void *descriptor,uintptr_t stack,NativeScriptShootDispatchSource &out,bool callback) {
    ReadContext read;NativeScriptShootDispatchSource s{};
    if(!read.readable(reinterpret_cast<void *>(stack),sizeof s.stack_words) || !read.readable(descriptor,0x14))return false;
    std::memcpy(s.stack_words,reinterpret_cast<void *>(stack),sizeof s.stack_words);
    s.descriptor=descriptor;s.native_stack=stack;
    s.command=reinterpret_cast<void *>(s.stack_words[1]);s.state=reinterpret_cast<void *>(s.stack_words[2]);
    s.wrapper=reinterpret_cast<void *>(s.stack_words[3]);s.arguments=reinterpret_cast<void *>(s.stack_words[4]);
    if(!read.readable(s.state,0xa8) || get<void *>(s.state,4) || get<void *>(s.state,0x14)!=descriptor ||
       get<void *>(descriptor,8)!=s.arguments || get<uint32_t>(descriptor,0xc)!=s.stack_words[5] ||
       !read.readable(s.wrapper,8))return false;
    s.handler=get<void *>(descriptor,0x10);
    if(!read.readable(s.handler,8) || get<uintptr_t>(s.handler,4)!=0x963520)return false;
    s.actor=get<void *>(s.wrapper,4);
    if(!read.readable(reinterpret_cast<void *>(0xfb4a20),4) || !read.readable(reinterpret_cast<void *>(0xfb2f60),4) ||
       !read.readable(reinterpret_cast<void *>(0xfb2e3c),4) || !read.readable(reinterpret_cast<void *>(0xfb4b6c),4))return false;
    s.world=get<void *>(reinterpret_cast<void *>(0xfb4a20));if(!read.readable(s.world,0x224))return false;
    s.definition=get<void *>(s.world,0x220);if(!read.readable(s.definition,0x96))return false;
    s.actor_pool=get<uintptr_t>(reinterpret_cast<void *>(0xfb2f60));s.actor_count=get<uint32_t>(reinterpret_cast<void *>(0xfb2e3c));
    const uintptr_t value=reinterpret_cast<uintptr_t>(s.actor);
    if(!s.actor_pool || !s.actor_count || s.actor_count>4096 || value<s.actor_pool || (value-s.actor_pool)%0x1440)return false;
    s.actor_ordinal=static_cast<uint32_t>((value-s.actor_pool)/0x1440);
    if(s.actor_ordinal>=s.actor_count || !read.readable(s.actor,0x1440))return false;
    s.model=get<void *>(s.actor,8);if(!read.readable(s.model,0x44))return false;
    s.brain=get<void *>(s.model,0x34);
    if(!read.readable(s.brain,0x19c) || !read.image_class(s.model,s.input.model_class) ||
       !read.image_class(s.brain,s.input.brain_class) || !read.image_class(s.state,s.input.state_class) ||
       !read.image(s.stack_words[0],s.input.caller_rva,true))return false;
    s.brain_admission_raw=get<uint32_t>(s.brain,0x198);if(!s.brain_admission_raw)return false;
    s.input.brain_admission=1;s.input.clock=get<uint32_t>(reinterpret_cast<void *>(0xfb4b6c));
    s.state_flags_raw=get<uint16_t>(s.state,0xa6);
    s.input.initialize=s.stack_words[6]!=0;
    s.input.state_flags=s.input.initialize?0:s.state_flags_raw;
    s.input.argument_count=s.stack_words[5];
    if(s.input.argument_count>NATIVE_SCRIPT_SHOOT_MAX_ARGUMENTS ||
       !argument_hash(read,s.arguments,s.input.argument_count,s.input.argument_hash))return false;
    if(callback){s.state_flags_raw=out.state_flags_raw;s.input.state_flags=out.input.state_flags;}
    out=s;return true;
}
}
extern "C" int native_script_shoot_source_resolve(void *actor,void *state,void *model,uintptr_t frame,NativeScriptShootSource *out) {
    const DWORD error=GetLastError();int result=0;
    __try {NativeScriptShootSource source{};if(out && snapshot(actor,state,model,frame,source)){*out=source;result=1;}}
    __except(EXCEPTION_EXECUTE_HANDLER){result=0;}
    SetLastError(error);return result;
}
extern "C" int native_script_shoot_source_revalidate(const NativeScriptShootSource *source) {
    const DWORD error=GetLastError();int result=0;
    __try {NativeScriptShootSource fresh{};if(source && snapshot(source->actor,source->state,source->model,source->native_frame,fresh) && !std::memcmp(&fresh,source,sizeof fresh))result=1;}
    __except(EXCEPTION_EXECUTE_HANDLER){result=0;}
    SetLastError(error);return result;
}
extern "C" int native_script_shoot_dispatch_source_resolve(void *descriptor,uintptr_t stack,NativeScriptShootDispatchSource *out) {
    const DWORD error=GetLastError();int result=0;
    __try {NativeScriptShootDispatchSource source{};if(out && dispatch_snapshot(descriptor,stack,source,false)){*out=source;result=1;}}
    __except(EXCEPTION_EXECUTE_HANDLER){result=0;}
    SetLastError(error);return result;
}
extern "C" int native_script_shoot_dispatch_initial_admission(uintptr_t stack) {
    const DWORD error=GetLastError();int result=-1;
    __try {
        ReadContext read;
        if(read.readable(reinterpret_cast<void *>(stack),4*sizeof(uint32_t))) {
            void *state=get<void *>(reinterpret_cast<void *>(stack),8);
            void *wrapper=get<void *>(reinterpret_cast<void *>(stack),12);
            if(!wrapper)result=0;
            else if(read.readable(wrapper,8)) {
                void *actor=get<void *>(wrapper,4);
                if(!actor || !state)result=0;
                else if(read.readable(actor,12)) {
                    void *model=get<void *>(actor,8);
                    if(!model)result=0;
                    else if(read.readable(model,0x38)) {
                        void *brain=get<void *>(model,0x34);
                        if(!brain)result=0;
                        else if(read.readable(brain,0x19c))result=get<uint32_t>(brain,0x198)?1:0;
                    }
                }
            }
        }
    } __except(EXCEPTION_EXECUTE_HANDLER){result=-1;}
    SetLastError(error);return result;
}
extern "C" int native_script_shoot_dispatch_source_revalidate(const NativeScriptShootDispatchSource *source) {
    const DWORD error=GetLastError();int result=0;
    __try {NativeScriptShootDispatchSource fresh{};if(source && dispatch_snapshot(source->descriptor,source->native_stack,fresh,false) &&
        !std::memcmp(&fresh,source,sizeof fresh))result=1;}
    __except(EXCEPTION_EXECUTE_HANDLER){result=0;}
    SetLastError(error);return result;
}
extern "C" int native_script_shoot_dispatch_frame_matches(const NativeScriptShootDispatchSource *source,
    void *actor,void *state,void *model,uintptr_t frame) {
    const DWORD error=GetLastError();int result=0;
    __try {
        ReadContext read;uint32_t words[9];NativeScriptShootDispatchSource fresh{};
        if(source && source->actor==actor && source->state==state && source->model==model &&
           read.readable(reinterpret_cast<void *>(frame),sizeof words)) {
            std::memcpy(words,reinterpret_cast<void *>(frame),sizeof words);
            fresh.state_flags_raw=source->state_flags_raw;fresh.input.state_flags=source->input.state_flags;
            if(words[1]==0x6f407f && !std::memcmp(words+2,source->stack_words+1,7*sizeof(uint32_t)) &&
               dispatch_snapshot(source->descriptor,source->native_stack,fresh,true) && !std::memcmp(&fresh,source,sizeof fresh))result=1;
        }
    } __except(EXCEPTION_EXECUTE_HANDLER){result=0;}
    SetLastError(error);return result;
}
