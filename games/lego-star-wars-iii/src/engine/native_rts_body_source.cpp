#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "native_rts_body_source.h"
namespace {
using Byte=unsigned char;
bool readable(const void *p,size_t n){
 auto a=reinterpret_cast<uintptr_t>(p);if(!p||n>UINTPTR_MAX-a)return false;const auto end=a+n;
 while(a<end){MEMORY_BASIC_INFORMATION m;if(!VirtualQuery(reinterpret_cast<void *>(a),&m,sizeof m)||m.State!=MEM_COMMIT||(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)))return false;const auto base=reinterpret_cast<uintptr_t>(m.BaseAddress);if(m.RegionSize>UINTPTR_MAX-base||base+m.RegionSize<=a)return false;a=base+m.RegionSize;}
 return true;
}
template<class T>T get(const void *p,unsigned o=0){T v;std::memcpy(&v,static_cast<const Byte *>(p)+o,sizeof v);return v;}
struct Hash {uint32_t v[4]={2166136261u,0x9e3779b9u,0x85ebca6bu,0xc2b2ae35u};void bytes(const void *p,unsigned n){for(unsigned j=0;j<n;++j)for(unsigned i=0;i<4;++i)v[i]=(v[i]^static_cast<const Byte *>(p)[j])*(16777619u+2*i);}bool text(const void *p,unsigned n){for(unsigned i=0;i<n;++i){if(!readable(static_cast<const Byte *>(p)+i,1))return false;if(!static_cast<const Byte *>(p)[i]){if(!i)return false;bytes(p,i);return true;}}return false;}};
}
int native_rts_body_source(void *object,uint32_t request,NativeRtsBodySource &out){
 NativeRtsBodySource s{};s.object=object;if(!readable(object,0x290))return -1;
 s.pad=get<void *>(object,0x24);s.team=get<void *>(object,0x28);s.world=*reinterpret_cast<void **>(0xfb4a20);
 if(!readable(s.pad,0x118)||get<void *>(s.pad,0x114)!=object||!readable(s.team,0x10d4)||get<uint32_t>(s.team)!=0xaef0fc||!readable(s.world,0x221c))return -1;
 auto *resource=get<void *>(s.team,0x10d0);auto *descriptor=get<void *>(s.team,0x1c);
 if(!readable(resource,0x10)||get<void *>(resource,0xc)!=s.world||!readable(descriptor,0x34))return -1;
 if(!native_gizmo_source_resolve(get<void *>(s.pad,0x28),s.pad,s.pad_source)||s.pad_source.world!=s.world)return -1;
 s.ordinal=s.pad_source.ordinal;
 s.model=get<void *>(object,0x28c);if(!s.model){out=s;return 0;}
 if(!readable(s.model,0x5c))return -1;
 if(!(get<uint16_t>(s.model,0x5a)&0x200)){out=s;return 0;}
 s.receiver=get<void *>(s.model,0x3c);if(!readable(s.receiver,0x1a4))return -1;
 s.body=get<void *>(s.receiver,0x1a0);if(!s.body||s.body==reinterpret_cast<void *>(UINTPTR_MAX)){out=s;return 0;}
 if(!readable(s.body,0xa0)||get<void *>(s.body,0x28)!=s.receiver)return -1;
 s.dynamics=get<void *>(s.body,0x98);if(!s.dynamics){out=s;return 0;}
 if(!readable(s.dynamics,0x50))return -1;
 const auto type=get<uintptr_t>(s.body);if(type<0x400000||type>=0xd00000)return -1;s.body_class=type-0x400000;
 Hash hash;const uint32_t context[]={get<uint32_t>(object),get<uint32_t>(object,0x288),get<uint32_t>(descriptor,0x30),s.ordinal,request};hash.bytes(context,sizeof context);hash.bytes(s.pad_source.key,sizeof s.pad_source.key);
 if(!hash.text(static_cast<Byte *>(s.world)+0x81,512)||!hash.text(static_cast<Byte *>(s.pad)+0x30,32)||!hash.text(get<void *>(s.body,0x1c),128))return -1;
 std::memcpy(s.key,hash.v,sizeof s.key);out=s;return 1;
}

int native_rts_object_source(void *object,NativeRtsObjectSource &out){
 NativeRtsObjectSource s{};s.object=object;if(!readable(object,0x2c))return 0;
 s.pad=get<void *>(object,0x24);s.team=get<void *>(object,0x28);s.world=*reinterpret_cast<void **>(0xfb4a20);s.object_class=get<uint32_t>(object);
 if(!readable(s.pad,0x280)||!readable(s.team,0x10d4)||get<uint32_t>(s.team)!=0xaef0fc||!readable(s.world,0x82))return 0;
 auto *resource=get<void *>(s.team,0x10d0);auto *descriptor=get<void *>(s.team,0x1c);
 if(!readable(resource,0x10)||get<void *>(resource,0xc)!=s.world||!readable(descriptor,0x34))return 0;
 if(!native_gizmo_source_resolve(get<void *>(s.pad,0x28),s.pad,s.pad_source)||s.pad_source.world!=s.world)return 0;
 s.ordinal=s.pad_source.ordinal;
 Hash hash;const uint32_t context[]={s.object_class,get<uint32_t>(descriptor,0x30),s.ordinal};hash.bytes(context,sizeof context);hash.bytes(s.pad_source.key,sizeof s.pad_source.key);
 if(!hash.text(static_cast<Byte *>(s.world)+0x81,512)||!hash.text(static_cast<Byte *>(s.pad)+0x30,32))return 0;
 std::memcpy(s.key,hash.v,sizeof s.key);out=s;return 1;
}
