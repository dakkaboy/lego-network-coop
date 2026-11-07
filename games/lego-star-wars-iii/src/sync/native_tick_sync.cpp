#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include "native_tick_sync.h"
extern "C" {
#include "game_sync.h"
#include "world_vars.h"
#include "../engine/native_tick_gate_thunk.h"
}

namespace {
SyncFrame *frame;
CoherentFrameToken token;
uint32_t cursor;
bool active,host,failed;
bool same(const CoherentFrameToken &a,const CoherentFrameToken &b) {
    return a.owner==b.owner && a.owner_nonce==b.owner_nonce && a.cohort_nonce==b.cohort_nonce &&
        a.thread==b.thread && a.release==b.release && a.epoch==b.epoch && a.sequence==b.sequence && a.frame==b.frame;
}
bool live(uint32_t phases) {
    return active && frame && token.frame==frame && world_vars_cohort_valid(&token,phases);
}
}
extern "C" {
__declspec(dllexport) volatile uint32_t clonewars_native_tick_debug[4];
__declspec(dllexport) volatile uint32_t clonewars_native_tick_failure[8];
__declspec(dllexport) volatile uint32_t clonewars_native_tick_correction[6];
}
namespace {
void fail(unsigned reason,uint32_t site=0,uint32_t clock=0,const SyncTickGate *expected=nullptr) {
    if (!live(COHERENT_ALL_PHASES)) return;
    failed=true;
    if (!clonewars_native_tick_failure[0]) {
        const uint32_t values[]={frame->epoch,frame->sequence,cursor,reason,site,expected?expected->site:0,clock,expected?expected->clock:0};
        std::memcpy(const_cast<uint32_t *>(clonewars_native_tick_failure),values,sizeof(values));
    }
    ++clonewars_native_tick_debug[3];game_sync_native_fault(22);
}
}
extern "C" uint32_t __cdecl native_tick_gate(uint32_t site) {
    const DWORD error=GetLastError();
    const uint32_t local=*reinterpret_cast<uint8_t *>(0xfbc161);
    uint32_t result=local;
    if (live(COHERENT_PHASE_BIT(COHERENT_DISPATCH)) && !failed) {
        const uint32_t clock=*reinterpret_cast<uint32_t *>(0xfb4b6c);
        if (host) {
            if (frame->tick_gate_count>=SYNC_MAX_TICK_GATES) fail(1,site,clock);
            else {frame->tick_gates[frame->tick_gate_count++]={site,clock,local};++clonewars_native_tick_debug[0];}
        } else {
            const auto *expected=cursor<frame->tick_gate_count?frame->tick_gates+cursor:nullptr;
            if (!expected || !native_tick_gate_valid(expected) || expected->site!=site || expected->clock!=clock) fail(2,site,clock,expected);
            else {
                ++cursor;++clonewars_native_tick_debug[1];result=expected->value;
                if (result!=local) {
                    ++clonewars_native_tick_debug[2];
                    if (!clonewars_native_tick_correction[0]) {
                        const uint32_t values[]={frame->epoch,frame->sequence,site,clock,local,result};
                        std::memcpy(const_cast<uint32_t *>(clonewars_native_tick_correction),values,sizeof(values));
                    }
                }
            }
        }
    }
    SetLastError(error);return result;
}

extern "C" {
__attribute__((used)) static volatile uintptr_t first_resume=0x8888d4,second_resume=0x8889f1;
// The saved x87 stack is restored before the original FSTP between CMP and JNE.
__attribute__((naked)) void native_tick_first(void) {__asm__ volatile(NATIVE_TICK_GATE_ASM(0x8888cd,first_resume));}
__attribute__((naked)) void native_tick_second(void) {__asm__ volatile(NATIVE_TICK_GATE_ASM(0x8889ea,second_resume));}
}
int native_tick_begin(SyncFrame *next,int authority,const CoherentFrameToken *original) {
    if (!next || !original || original->frame!=next || !world_vars_cohort_valid(original,COHERENT_PHASE_BIT(COHERENT_PREPARE))) return 0;
    if (token.epoch!=original->epoch) {
        std::memset(const_cast<uint32_t *>(clonewars_native_tick_failure),0,sizeof(clonewars_native_tick_failure));
        std::memset(const_cast<uint32_t *>(clonewars_native_tick_correction),0,sizeof(clonewars_native_tick_correction));
    }
    frame=next;token=*original;cursor=0;host=authority!=0;failed=false;active=true;
    if (host) frame->tick_gate_count=frame->tick_gate_reserved=0;
    return live(COHERENT_PHASE_BIT(COHERENT_PREPARE));
}
int native_tick_finish(void) {
    if (!live(COHERENT_PHASE_BIT(COHERENT_DISPATCH))) return 0;
    if (!host && cursor!=frame->tick_gate_count && !failed) fail(3);
    const bool result=!failed;active=false;return result;
}
void native_tick_cancel(const CoherentFrameToken *original) {
    if (original && same(token,*original)) {active=false;frame=nullptr;}
}
int native_tick_install(void) {
    const uintptr_t sites[]={0x8888cd,0x8889ea};
    void *hooks[]={reinterpret_cast<void *>(native_tick_first),reinterpret_cast<void *>(native_tick_second)};
    const unsigned char bytes[]={0x80,0x3d,0x61,0xc1,0xfb,0,0};
    for (const auto site:sites) if (std::memcmp(reinterpret_cast<void *>(site),bytes,sizeof(bytes))) return 0;
    for (unsigned i=0;i<2;++i) {
        auto *p=reinterpret_cast<unsigned char *>(sites[i]);DWORD old;
        if (!VirtualProtect(p,7,PAGE_EXECUTE_READWRITE,&old)) return 0;
        const auto relative=static_cast<int32_t>(reinterpret_cast<uintptr_t>(hooks[i])-sites[i]-5);
        p[0]=0xe9;std::memcpy(p+1,&relative,4);p[5]=p[6]=0x90;
        const bool flushed=FlushInstructionCache(GetCurrentProcess(),p,7)!=0;DWORD ignored;
        if (!VirtualProtect(p,7,old,&ignored) || !flushed) return 0;
    }
    return 1;
}
