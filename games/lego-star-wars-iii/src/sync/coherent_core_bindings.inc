/* Install readiness is supplied only by the reviewed qualified-main cohort installer. */
static uint32_t core_module_install_mask;
static TagFrameBinding core_tag_binding;
static ProjectileFrameLease core_projectile_binding;
static GeometryFrameLease core_geometry_binding;
static CadenceFrameLease core_cadence_binding;
static ModelInputFrameLease core_model_binding;
static ReactionFrameLease core_reaction_binding;
static int core_token_same(const CoherentFrameToken*a,const CoherentFrameToken*b){return a&&b&&a->owner==b->owner&&a->owner_nonce==b->owner_nonce&&a->cohort_nonce==b->cohort_nonce&&a->thread==b->thread&&a->release==b->release&&a->epoch==b->epoch&&a->sequence==b->sequence&&a->frame==b->frame;}
static int core_tag_bind(const CoherentFrameToken*t){return tags_bind_cohort(t)&&tags_frame_binding_get(&core_tag_binding)&&core_token_same(t,&core_tag_binding.token);}
static int core_tag_valid(const CoherentFrameToken*t,uint32_t phases){return core_token_same(t,&core_tag_binding.token)&&tags_cohort_valid(t,phases);}
static void core_tag_abort(const CoherentFrameToken*t){if(core_token_same(t,&core_tag_binding.token))tags_abort_frame(&core_tag_binding);}
static int core_projectile_bind(const CoherentFrameToken*t){return projectiles_bind_cohort(t)&&projectiles_frame_lease_get(&core_projectile_binding)&&core_token_same(t,&core_projectile_binding.cohort);}
static int core_projectile_valid(const CoherentFrameToken*t,uint32_t phases){return core_token_same(t,&core_projectile_binding.cohort)&&coherent_frame_valid(t,phases)&&!projectiles_frame_cancelled(&core_projectile_binding);}
static void core_projectile_abort(const CoherentFrameToken*t){if(core_token_same(t,&core_projectile_binding.cohort))projectiles_abort_frame(&core_projectile_binding);}
static int core_geometry_bind(const CoherentFrameToken*t){return geometry_bind_cohort(t)&&geometry_frame_lease_get(&core_geometry_binding)&&core_token_same(t,&core_geometry_binding.cohort);}
static int core_geometry_valid(const CoherentFrameToken*t,uint32_t phases){return core_token_same(t,&core_geometry_binding.cohort)&&coherent_frame_valid(t,phases)&&!geometry_frame_cancelled(&core_geometry_binding);}
static void core_geometry_abort(const CoherentFrameToken*t){if(core_token_same(t,&core_geometry_binding.cohort))geometry_abort_frame(&core_geometry_binding);}
static int core_cadence_bind(const CoherentFrameToken*t){return cadence_bind_cohort(t)&&cadence_frame_lease_get(&core_cadence_binding)&&core_token_same(t,&core_cadence_binding.cohort);}
static int core_cadence_valid(const CoherentFrameToken*t,uint32_t phases){return core_token_same(t,&core_cadence_binding.cohort)&&coherent_frame_valid(t,phases)&&!cadence_frame_cancelled(&core_cadence_binding);}
static void core_cadence_abort(const CoherentFrameToken*t){if(core_token_same(t,&core_cadence_binding.cohort))cadence_abort_frame(&core_cadence_binding);}
static int core_model_bind(const CoherentFrameToken*t){return model_input_bind_cohort(t)&&model_input_frame_lease_get(&core_model_binding)&&core_token_same(t,&core_model_binding.cohort);}
static int core_model_valid(const CoherentFrameToken*t,uint32_t phases){return core_token_same(t,&core_model_binding.cohort)&&coherent_frame_valid(t,phases)&&!model_input_frame_cancelled(&core_model_binding);}
static void core_model_abort(const CoherentFrameToken*t){if(core_token_same(t,&core_model_binding.cohort))model_input_abort_frame(&core_model_binding);}
static int core_reaction_bind(const CoherentFrameToken*t){return reaction_bind_cohort(t)&&reaction_frame_lease_get(&core_reaction_binding)&&core_token_same(t,&core_reaction_binding.cohort);}
static int core_reaction_valid(const CoherentFrameToken*t,uint32_t phases){return core_token_same(t,&core_reaction_binding.cohort)&&coherent_frame_valid(t,phases)&&!reaction_frame_cancelled(&core_reaction_binding);}
static void core_reaction_abort(const CoherentFrameToken*t){if(core_token_same(t,&core_reaction_binding.cohort))reaction_abort_frame(&core_reaction_binding);}
static int core_npc_bind(const CoherentFrameToken*t){return npc_input_bind_cohort(&npc_inputs,t);}
static int core_npc_valid(const CoherentFrameToken*t,uint32_t phases){return npc_input_cohort_valid(&npc_inputs,t,phases);}
static void core_npc_abort(const CoherentFrameToken*t){npc_input_abort_cohort(&npc_inputs,t);}
static int core_world_bind(const CoherentFrameToken*t){return world_vars_bind_cohort(t);}
static int core_world_valid(const CoherentFrameToken*t,uint32_t phases){return world_vars_cohort_valid(t,phases);}
static void core_world_abort(const CoherentFrameToken*t){world_vars_abort_cohort(t);}
static int core_tag_ready(void){return (core_module_install_mask&(1u<<0))!=0;}
static int core_projectile_ready(void){return (core_module_install_mask&(1u<<1))!=0;}
static int core_geometry_ready(void){return (core_module_install_mask&(1u<<2))!=0;}
static int core_cadence_ready(void){return (core_module_install_mask&(1u<<3))!=0;}
static int core_model_ready(void){return (core_module_install_mask&(1u<<4))!=0;}
static int core_npc_ready(void){return (core_module_install_mask&(1u<<5))!=0;}
static int core_reaction_ready(void){return (core_module_install_mask&(1u<<6))!=0;}
static int core_world_ready(void){return (core_module_install_mask&(1u<<7))!=0;}
static const CoreCohortBinding core_actual_bindings[CORE_COHORT_COUNT]={
 {1,core_tag_ready,core_tag_bind,core_tag_valid,core_tag_abort},
 {1,core_projectile_ready,core_projectile_bind,core_projectile_valid,core_projectile_abort},
 {1,core_geometry_ready,core_geometry_bind,core_geometry_valid,core_geometry_abort},
 {1,core_cadence_ready,core_cadence_bind,core_cadence_valid,core_cadence_abort},
 {1,core_model_ready,core_model_bind,core_model_valid,core_model_abort},
 {1,core_npc_ready,core_npc_bind,core_npc_valid,core_npc_abort},
 {1,core_reaction_ready,core_reaction_bind,core_reaction_valid,core_reaction_abort},
 {1,core_world_ready,core_world_bind,core_world_valid,core_world_abort},
};
