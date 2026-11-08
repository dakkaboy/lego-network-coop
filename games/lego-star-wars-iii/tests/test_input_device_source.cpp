#undef NDEBUG
#include <cassert>
#include <cstdio>
#include "../src/engine/input_device_source.h"
int main(){
 unsigned char shadow[2][0x200],physical[0x200];void *out=physical;
 NativeInputDeviceSource origin={nullptr,7};
 assert(!native_input_device_source(shadow[1],shadow[1],shadow[0],origin,7,&out)&&out==nullptr);
 origin.device=physical;assert(!native_input_device_source(shadow[1],shadow[1],shadow[0],origin,7,&out)&&out==physical);
 out=shadow[0];assert(native_input_device_source(shadow[1],shadow[1],shadow[0],origin,8,&out)==5&&out==shadow[0]);
 assert(native_input_device_source(shadow[1],shadow[1],shadow[0],origin,0,&out)==5);
 assert(native_input_device_source(shadow[1],shadow[1],shadow[0],origin,UINT32_MAX,&out)==5);
 assert(native_input_device_source(shadow[0],shadow[1],shadow[0],origin,7,&out)==4);
 origin={};assert(native_input_device_source(shadow[1],shadow[1],shadow[0],origin,7,&out)==5);
 assert(!native_input_device_source(nullptr,shadow[1],shadow[0],origin,7,&out)&&out==nullptr);
 assert(!native_input_device_source(physical,shadow[1],shadow[0],origin,7,&out)&&out==physical);
 puts("Native device provenance retains known NULL/physical origins across actor retirement and rejects unknown, cross-slot and stale-session shadows.");
}
