#pragma once
#include <cstddef>
#include <cstdint>
namespace clonewars::engine {
struct NativeEffectBodyBinding {
    const unsigned char *node,*receiver,*body,*resource;
    uint32_t epoch,sequence,event,release;
};
template<class Validate>
int resolve_effect_body(NativeEffectBodyBinding *bindings,size_t count,const void *body,uint32_t epoch,uint32_t release,
                        Validate validate,uint32_t source[2],uint32_t &revoked) {
    revoked=0;const NativeEffectBodyBinding *found=nullptr;
    for (size_t i=0;i<count;++i) {
        auto &binding=bindings[i];
        if (binding.epoch!=epoch || binding.release!=release || binding.body!=body) continue;
        // A retired native pool entry can precede a new owner of the same heap address.
        if (!validate(i,binding)) {binding={};++revoked;continue;}
        if (found) return -1;
        found=&binding;
    }
    if (!found) return 0;
    source[0]=found->sequence;source[1]=found->event;return 1;
}
}
