#ifdef USER_MAPPING_SESSION_FIXTURE
void user_mapping_test_before_negative(void);
#endif
#include "user_mapping_internal.h"
__declspec(noinline) void __cdecl user_mapping_bridge_c(UserMappingBridge *s){int returned=0;__try{user_mapping_bridge_begin(s);user_mapping_bridge_inner(s);returned=1;}__finally{__try{user_mapping_bridge_end(s,!returned);}__finally{user_mapping_bridge_unlock(s);}}}
__declspec(noinline) int user_mapping_owned_request(const UserMappingRequest *request,UserMappingKey *out){MappingMarker marker={0};int sent=0,returned=0;__try{user_mapping_request_begin(&marker,request,out);if(marker.admitted){sent=1;user_mapping_setter_entry(request->user,request->requested);}returned=1;}__finally{user_mapping_request_end(&marker,!returned);}return sent;}

#include "user_mapping_session.h"
__declspec(noinline) int user_mapping_session_owned_request(uint32_t session,const UserMappingRequest *request,UserMappingKey*out){MappingSessionAcquire scope={0};int result=0,returned=0;__try{if(user_mapping_session_acquire_begin(&scope,session,request)){scope.sent=1;result=user_mapping_owned_request(request,&scope.key);}returned=1;}__finally{user_mapping_session_acquire_end(&scope,!returned);if(returned&&out)*out=scope.key;}return result;}
__declspec(noinline) int user_mapping_session_drain(const void *boundary,uint32_t bytes,uint32_t observed){MappingSessionDrain scope={0};int result=UM_DRAIN_IDLE,returned=0;__try{result=user_mapping_session_drain_begin(&scope,boundary,bytes,observed);if(scope.consumed){
#ifdef USER_MAPPING_SESSION_FIXTURE
 user_mapping_test_before_negative();
#endif
 user_mapping_setter_entry(1,scope.negative);scope.returned=1;result=user_mapping_session_drain_complete(&scope);}returned=1;}__finally{user_mapping_session_drain_end(&scope,!returned);}return result;}
