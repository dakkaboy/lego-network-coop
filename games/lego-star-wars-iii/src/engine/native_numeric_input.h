#pragma once
#include <stdint.h>
#include <string.h>
typedef struct NativeNumericInput {uint32_t cw,mxcsr;} NativeNumericInput;
typedef struct NativeNumericScope {NativeNumericInput local;uint32_t active;} NativeNumericScope;
static inline int native_numeric_valid(NativeNumericInput value){
 return !(value.cw&~UINT32_C(0x1f3f)) && (value.cw&0x300)!=0x100 && !(value.mxcsr&~UINT32_C(0xffc0));
}
static inline NativeNumericInput native_numeric_read(const void *fx){
 uint16_t cw;uint32_t mxcsr;memcpy(&cw,fx,2);memcpy(&mxcsr,(const unsigned char*)fx+24,4);
 NativeNumericInput value={cw&0x1f3fu,mxcsr&0xffc0u};return value;
}
static inline int native_numeric_apply(void *fx,NativeNumericInput value){
 if(!fx||!native_numeric_valid(value))return 0;
 uint16_t cw;uint32_t mxcsr;memcpy(&cw,fx,2);memcpy(&mxcsr,(unsigned char*)fx+24,4);
 cw=(uint16_t)((cw&~0x1f3fu)|value.cw);mxcsr=(mxcsr&~0xffc0u)|value.mxcsr;
 memcpy(fx,&cw,2);memcpy((unsigned char*)fx+24,&mxcsr,4);return 1;
}
static inline void native_numeric_borrow(NativeNumericScope *scope,NativeNumericInput local,const void *fx){
 NativeNumericInput effective=native_numeric_read(fx);scope->local=local;
 scope->active=effective.cw!=local.cw||effective.mxcsr!=local.mxcsr;
}
static inline void native_numeric_restore(NativeNumericScope *scope,void *fx){
 if(scope->active){native_numeric_apply(fx,scope->local);scope->active=0;}
}
