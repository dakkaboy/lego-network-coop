#include "camera_order_bridge.h"
__declspec(dllimport) unsigned long __stdcall GetLastError(void);
__declspec(dllimport) void __stdcall SetLastError(unsigned long);
__declspec(noinline) void __cdecl camera_order_c(CameraOrderBridge *s){
 int returned=0;
 __try {camera_order_enter(s);camera_order_inner(s);returned=1;}
 __finally {unsigned long error=GetLastError();camera_order_leave(s,!returned);SetLastError(error);}
}
