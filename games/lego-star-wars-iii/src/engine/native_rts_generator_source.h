#pragma once
#include <stdint.h>
struct NativeRtsGeneratorSource {
 void *object,*team,*descriptor,*resource,*world,*engine;
 uint32_t team_slot,index,side,object_class;
};
int native_rts_generator_source(void *,NativeRtsGeneratorSource *);
int native_rts_generator_source_live(const NativeRtsGeneratorSource *);
