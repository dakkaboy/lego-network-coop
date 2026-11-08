typedef struct ScriptShootFrameBinding {
    CadenceFrameLease lease;
    void *actor;
    uint32_t generation;
} ScriptShootFrameBinding;
_Static_assert(sizeof(ScriptShootFrameBinding)<=sizeof(NativeScriptShootDispatchBinding),"script dispatch binding storage");

int cadence_script_shoot_dispatch_active(void) {
    const DWORD error=GetLastError();CadenceFrameLease op;
    const int result=cadence_frame_lease_get(&op) && op_live(&op) && active;
    SetLastError(error);return result;
}

static void script_shoot_dispatch_failed(const CadenceFrameLease *op,const NativeScriptShootDispatchSource *source,uint32_t reason) {
    if (!op_live(op) || !active || journal.failed) return;
    void *actor=source ? source->actor : NULL;
    if (!clonewars_script_shoot_failure[0]) {
        uint32_t values[16]={journal.frame->epoch,journal.frame->sequence,reason,*(uint32_t*)0xfb4b6c,
            (uint32_t)(uintptr_t)actor,source ? (uint32_t)(uintptr_t)source->state : 0,
            source ? (uint32_t)(uintptr_t)source->model : 0,source ? (uint32_t)source->native_stack : 0};
        if (source && valid((void*)source->native_stack,8*sizeof(uint32_t))) memcpy(values+8,(void*)source->native_stack,8*sizeof(uint32_t));
        memcpy((void*)clonewars_script_shoot_failure,values,sizeof(values));
    }
    journal.failed=18;++clonewars_script_shoot_debug[3];failed(op,actor,NULL,18);
}

int cadence_script_shoot_dispatch_begin(const NativeScriptShootDispatchSource *source,uint32_t local_byte,uint32_t *canonical,NativeScriptShootDispatchBinding *opaque) {
    const DWORD error=GetLastError();
    CadenceFrameLease op;
    int status=0;
    if (!cadence_frame_lease_get(&op) || !op_live(&op) || !active) goto done;
    status=-1;
    if (journal.failed) goto done;
    if (!source || !canonical || !opaque || !valid(source,sizeof(*source)) ||
        !native_script_shoot_dispatch_source_revalidate(source) || !op_live(&op)) goto invalid;
    entities_update();
    if (!op_live(&op)) goto done;
    const uint32_t generation=entities_observed_generation(source->actor);
    if (!generation) goto invalid;
    SyncScriptShootState input;
    memcpy(&input,&source->input,sizeof(input));
    const uint32_t visible=local_byte!=0;
    const uint32_t result=(uint32_t)apply_actor_gate(source->actor,SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY,0,0,(int)visible,&input,clonewars_script_shoot_debug);
    if (!op_live(&op) || !active || journal.failed) goto done;
    if (entities_observed_generation(source->actor)!=generation || !native_script_shoot_dispatch_source_revalidate(source) || !op_live(&op)) goto invalid;
    if (!journal.host && visible!=result && !clonewars_script_shoot_correction[0]) {
        uint32_t slot=UINT32_MAX,observed=0;entities_observed_identity(source->actor,&slot,&observed);
        const uint32_t values[]={journal.frame->epoch,journal.frame->sequence,slot,generation,visible,result,input.clock,input.state_flags,input.argument_count,input.caller_rva,input.initialize,0};
        memcpy((void*)clonewars_script_shoot_correction,values,sizeof(values));
    }
    const ScriptShootFrameBinding captured={op,source->actor,generation};
    memset(opaque,0,sizeof(*opaque));memcpy(opaque,&captured,sizeof(captured));
    *canonical=result;status=1;
    goto done;
invalid:
    script_shoot_dispatch_failed(&op,source && valid(source,sizeof(*source)) ? source : NULL,2);
done:
    SetLastError(error);return status;
}

int cadence_script_shoot_dispatch_validate(const NativeScriptShootDispatchSource *source,const NativeScriptShootDispatchBinding *opaque) {
    const DWORD error=GetLastError();int result=0;
    ScriptShootFrameBinding captured;
    if (!opaque || !valid(opaque,sizeof(*opaque))) goto done;
    memcpy(&captured,opaque,sizeof(captured));
    if (!op_live(&captured.lease) || !active || journal.failed) goto done;
    result=-1;
    if (source && valid(source,sizeof(*source)) && source->actor==captured.actor &&
        entities_observed_generation(source->actor)==captured.generation && op_live(&captured.lease)) result=1;
done:
    SetLastError(error);return result;
}

void cadence_script_shoot_dispatch_invalid(const NativeScriptShootDispatchSource *source,const NativeScriptShootDispatchBinding *opaque,uint32_t reason) {
    const DWORD error=GetLastError();CadenceFrameLease op;
    if (opaque) {
        ScriptShootFrameBinding captured;
        if (!valid(opaque,sizeof(*opaque))) goto done;
        memcpy(&captured,opaque,sizeof(captured));op=captured.lease;
    } else if (!cadence_frame_lease_get(&op)) goto done;
    script_shoot_dispatch_failed(&op,source && valid(source,sizeof(*source)) ? source : NULL,reason);
done:
    SetLastError(error);
}

__attribute__((used,noinline)) uint32_t cadence_script_shoot_visibility(void *actor,void *state,void *model,uintptr_t native_frame,uint32_t local_byte) {
    return native_script_shoot_dispatch_consume(actor,state,model,native_frame,local_byte);
}
