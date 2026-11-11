#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include "native_spellit_source.h"

namespace {
using Byte=unsigned char;
struct LastError {
    DWORD value=GetLastError();
    ~LastError(){SetLastError(value);}
};
bool readable(const void *pointer,size_t size) {
    const auto address=reinterpret_cast<uintptr_t>(pointer);
    if (!pointer || !size || address+size<address) return false;
    MEMORY_BASIC_INFORMATION memory;
    return VirtualQuery(pointer,&memory,sizeof(memory)) && memory.State==MEM_COMMIT &&
        !(memory.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
        address+size<=reinterpret_cast<uintptr_t>(memory.BaseAddress)+memory.RegionSize;
}
template<class T> T get(const void *pointer,size_t offset=0) {
    T value;std::memcpy(&value,static_cast<const Byte *>(pointer)+offset,sizeof(value));return value;
}
Byte *pointer(const void *base,size_t offset=0){return get<Byte *>(base,offset);}
uintptr_t image(){return reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr));}
Byte *native(uint32_t address){return reinterpret_cast<Byte *>(image()+address-0x400000u);}
bool image_class(const void *object,uint32_t &rva) {
    if (!readable(object,4)) return false;
    const auto address=get<uintptr_t>(object),base=image();
    MEMORY_BASIC_INFORMATION memory;
    if (address<=base || !VirtualQuery(reinterpret_cast<void *>(address),&memory,sizeof(memory)) ||
        memory.State!=MEM_COMMIT || reinterpret_cast<uintptr_t>(memory.AllocationBase)!=base ||
        (memory.Protect&(PAGE_GUARD|PAGE_NOACCESS))) return false;
    rva=static_cast<uint32_t>(address-base);return true;
}
struct Hash {
    uint32_t word[4]={2166136261u,0x9e3779b9u,0x85ebca6bu,0xc2b2ae35u};
    void bytes(const void *value,size_t length) {
        const auto *data=static_cast<const Byte *>(value);
        for (size_t n=0;n<length;++n) for (unsigned i=0;i<4;++i) word[i]=(word[i]^data[n])*(16777619u+2*i);
    }
    void number(uint32_t value){bytes(&value,sizeof(value));}
};
bool text(const Byte *value,unsigned cap,unsigned &length) {
    length=0;
    if (!value) return false;
    while (length<cap) {
        MEMORY_BASIC_INFORMATION memory;
        if (!VirtualQuery(value+length,&memory,sizeof(memory)) || memory.State!=MEM_COMMIT ||
            (memory.Protect&(PAGE_GUARD|PAGE_NOACCESS))) return false;
        const auto end=reinterpret_cast<uintptr_t>(memory.BaseAddress)+memory.RegionSize;
        size_t available=end-reinterpret_cast<uintptr_t>(value+length);
        if (available>cap-length) available=cap-length;
        if (!available) return false;
        for (size_t i=0;i<available;++i) {
            const Byte c=value[length];
            if (!c) return length!=0;
            if (c<32 || c>126) return false;
            ++length;
        }
    }
    return false;
}
bool hash_text(Hash &hash,const Byte *value,unsigned cap=1024) {
    unsigned length;
    if (!text(value,cap,length)) return false;
    hash.number(length);hash.bytes(value,length);return true;
}
bool counted_name(Hash &hash,const Byte *name) {
    if (!name) {hash.number(0);return true;}
    if (!readable(name,1)) return false;
    const unsigned stored=*name;
    if (stored<2 || !readable(name,stored)) return false;
    const unsigned length=stored-2;
    if (name[length+1]) return false;
    for (unsigned i=0;i<length;++i) if (name[i+1]<32 || name[i+1]>126) return false;
    hash.number(length+1);hash.bytes(name+1,length);return true;
}
bool source_snapshot(void *object,NativeSpellItSource &s) {
    s={};auto *g=static_cast<Byte *>(object);
    if (!readable(g,0x230) || !image_class(g,s.key.gizmo_class) || s.key.gizmo_class!=0x8480ac) return false;
    s.gizmo=g;
    if (!readable(native(0xfb4a20),4) || !readable(native(0xe90220),4) || !readable(native(0xe90184),4)) return false;
    s.world=pointer(native(0xfb4a20));s.provider=pointer(native(0xe90220));s.manager_registry=pointer(native(0xe90184));
    if (!readable(s.world,0x22e8) || !readable(s.provider,0x3c) || !readable(s.manager_registry,0x2c)) return false;
    s.container=pointer(s.world,0x22e4);s.handle=pointer(s.world,0x400);
    if (!readable(s.container,0x10) || pointer(s.container,0xc)!=s.world || !readable(s.handle,4)) return false;
    s.manager_index=get<uint32_t>(s.provider,0x38);s.manager_count=get<uint32_t>(s.manager_registry,0x28);
    s.table=pointer(s.handle);
    if (!s.manager_count || s.manager_count>4096 || s.manager_index>=s.manager_count || !readable(s.table,s.manager_count*4)) return false;
    s.manager=pointer(s.table,s.manager_index*4);
    if (!readable(s.manager,0x28) || !image_class(s.manager,s.manager_class)) return false;
    auto *current=pointer(s.manager,0x24);unsigned seen=0,ordinal=0;
    while (current && ordinal<65536) {
        if (!readable(current,0x28)) return false;
        if (current==g) {if (++seen!=1) return false;s.key.gizmo_ordinal=ordinal;}
        current=pointer(current,0x24);if (++ordinal>=65536 && current) return false;
    }
    if (seen!=1) return false;
    const auto *vtable=get<const Byte *>(g);
    if (!readable(vtable,0x140) || get<uintptr_t>(vtable,0xf4)!=reinterpret_cast<uintptr_t>(native(0x823340)) ||
        get<uintptr_t>(vtable,0x13c)!=reinterpret_cast<uintptr_t>(native(0x823350))) return false;
    s.scene=pointer(g,0xb4);s.piece_head=pointer(g,0xa8);s.piece_tail=pointer(g,0xac);s.piece_count=get<uint32_t>(g,0xb0);
    s.adapter=pointer(g,0x84);s.adapter_count=get<uint32_t>(g,0x88);s.counted_name=pointer(g,0xc);
    if (!readable(s.scene,0x30) || s.piece_count>65536 || s.adapter_count!=s.piece_count ||
        (s.adapter_count && !readable(s.adapter,s.adapter_count*8))) return false;
    Hash hash;
    if (!hash_text(hash,static_cast<Byte *>(s.world)+0x81) || !hash_text(hash,g+0x30,32) || !counted_name(hash,static_cast<Byte *>(s.counted_name))) return false;
    hash.number(s.manager_class);hash.number(s.key.gizmo_class);hash.number(s.key.gizmo_ordinal);
    std::memcpy(s.key.name,hash.word,sizeof(hash.word));return true;
}
bool resource_key(Byte *resource,NativeSpellItPiece &p,const NativeSpellItSource &source) {
    if (!native_resource_identity_resolve(source.world,resource,&p.resource_identity)) return false;
    const auto &identity=p.resource_identity;
    if (identity.runtime!=p.authored.runtime || identity.array!=p.authored.array) return false;
    p.resource=identity.actual_resource;p.root_resource=identity.root_resource;p.runtime=identity.runtime;
    p.registry=identity.registry;p.entry=identity.entry;p.container=identity.container;p.source_world=identity.source_world;
    p.filename=identity.filename;p.logical_name=identity.name;
    std::memcpy(p.key.resource,identity.key,sizeof(identity.key));return true;
}
bool piece_snapshot(const NativeSpellItSource &s,void *value,NativeSpellItPiece &p) {
    p={};auto *wanted=static_cast<Byte *>(value),*current=static_cast<Byte *>(s.piece_head),*previous=static_cast<Byte *>(nullptr);
    unsigned index=0,matches=0;
    while (current && index<s.piece_count) {
        if (!readable(current,0x120) || pointer(current)!=previous || pointer(current,0xfc)!=s.gizmo) return false;
        if (current==wanted) {++matches;p.key.piece_ordinal=index;p.previous=previous;p.next=pointer(current,4);}
        previous=current;current=pointer(current,4);++index;
    }
    if (current || index!=s.piece_count || previous!=s.piece_tail || matches!=1) return false;
    p.piece=wanted;p.source_entity=pointer(wanted,0xf0);p.model=pointer(wanted,0x100);p.live_record=pointer(wanted,8);
    if (!readable(p.model,0x5c) || !readable(p.source_entity,0x1c) || pointer(p.source_entity,8)!=p.model) return false;
    auto *entity=pointer(s.scene,0x2c);unsigned found=0,n=0;
    while (entity && n++<65536) {if (!readable(entity,0x1c)) return false;if (entity==p.source_entity) ++found;entity=pointer(entity,4);}
    if (entity || found!=1 || !s.adapter || p.key.piece_ordinal>=s.adapter_count) return false;
    const auto *pair=static_cast<Byte *>(s.adapter)+p.key.piece_ordinal*8;
    if (pointer(pair)!=p.live_record || pointer(pair,4)!=p.model || !readable(p.live_record,0x18) || pointer(p.live_record,8)!=p.model) return false;
    if (!native_authored_poi_resolve(p.model,&p.authored)) return false;
    p.receiver=p.authored.receiver;p.key.receiver_class=p.authored.chain[0].receiver_class;
    p.poi=p.authored.poi;p.array=p.authored.array;p.key.poi_count=p.authored.poi_count;p.key.poi_ordinal=p.authored.poi_ordinal;
    p.authored_receiver_class=p.authored.receiver_class;p.chain_count=p.authored.chain_count;p.poi_name=pointer(p.poi,0xb4);
    for (unsigned i=0;i<p.chain_count;++i) {
        p.models[i]=p.authored.chain[i].model;p.receivers[i]=p.authored.chain[i].receiver;
        p.chain_resources[i]=p.authored.chain[i].resource;p.chain_pois[i]=p.authored.chain[i].poi;
    }
    Hash name;
    if (!hash_text(name,static_cast<Byte *>(p.poi_name)) || !resource_key(static_cast<Byte *>(p.authored.resource),p,s)) return false;
    std::memcpy(p.key.poi_name,name.word,sizeof(name.word));return true;
}
}

int native_spellit_source_resolve(void *gizmo,NativeSpellItSource *out) {
    LastError preserve;if (!out) return 0;
    NativeSpellItSource first{},second{};
    if (!source_snapshot(gizmo,first) || !source_snapshot(gizmo,second) || std::memcmp(&first,&second,sizeof(first))) return 0;
    *out=first;return 1;
}
int native_spellit_source_revalidate(const NativeSpellItSource *source) {
    LastError preserve;if (!source) return 0;NativeSpellItSource current{};
    return native_spellit_source_resolve(source->gizmo,&current) && !std::memcmp(source,&current,sizeof(current));
}
int native_spellit_piece_resolve(const NativeSpellItSource *source,void *piece,NativeSpellItPiece *out) {
    LastError preserve;if (!source || !out || !native_spellit_source_revalidate(source)) return 0;
    NativeSpellItPiece first{},second{};
    if (!piece_snapshot(*source,piece,first) || !piece_snapshot(*source,piece,second) ||
        std::memcmp(&first,&second,sizeof(first)) || !native_spellit_source_revalidate(source)) return 0;
    *out=first;return 1;
}
int native_spellit_piece_revalidate(const NativeSpellItSource *source,const NativeSpellItPiece *piece) {
    LastError preserve;if (!source || !piece) return 0;NativeSpellItPiece current{};
    return native_spellit_piece_resolve(source,piece->piece,&current) && !std::memcmp(piece,&current,sizeof(current));
}
int native_spellit_selection_snapshot(const NativeSpellItSource *source,uint32_t *count,uint32_t eligibility[4]) {
    LastError preserve;
    if(!source || !count || !eligibility || !native_spellit_source_revalidate(source))return 0;
    auto *node=static_cast<Byte *>(source->piece_head);Byte *previous=nullptr;
    Hash hash;uint32_t index=0,candidates=0;
    while(node && index<source->piece_count) {
        if(!readable(node,0x114) || pointer(node)!=previous || pointer(node,0xfc)!=source->gizmo)return 0;
        const bool eligible=get<uint32_t>(node,0x110)!=3;
        hash.number(index);hash.number(eligible);candidates+=eligible;
        previous=node;node=pointer(node,4);++index;
    }
    if(node || index!=source->piece_count || previous!=source->piece_tail ||
       !native_spellit_source_revalidate(source))return 0;
    *count=candidates;std::memcpy(eligibility,hash.word,sizeof hash.word);return 1;
}
