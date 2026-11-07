#pragma once
#ifdef __cplusplus
extern "C" {
#endif
typedef struct NativeRigidBodyBinding {
    void *component,*driver,*body,*dynamics;
} NativeRigidBodyBinding;
int native_actor_rigid_body(const void *actor,NativeRigidBodyBinding *out);
int native_actor_rigid_body_same(const void *actor,const NativeRigidBodyBinding *binding);
void native_rigid_body_transform(void *body,const float *transform);
#ifdef __cplusplus
}
#endif
