#include "model_producer_bridge.h"
__declspec(noinline) void __cdecl model_producer_c(ModelProducerBridge *s){
 int returned=0;
 __try {model_producer_enter(s);model_producer_inner(s);returned=1;}
 __finally {model_producer_leave(s,!returned);}
}
