#pragma once
#ifdef __cplusplus
extern "C" {
#endif
enum NativeSceneInputCapability {
    GAME_SCENE_NOT_READY = 0,
    GAME_SCENE_PARTY_INPUT = 1,
    GAME_SCENE_NO_PARTY_INPUT = 2
};
void game_poll(void);
void game_native_tick(void);
void * __attribute__((thiscall)) game_native_scene_entry(void *manager,int level,int selector);
int game_transition_waiting(void);
int game_native_join_party_player(int slot,void *actor,void *controller);
void game_request_level(int level);
void game_request_reload(int level);
int game_can_return_to_hub(void);
int game_request_return_to_hub(void);
int game_current_level(void);
int game_actor_count(void);
int game_load_status(void);
int game_target_level(void);
int game_network_profile_ready(void);

void game_cancel_level_request(void);
int game_network_target_level(void);
int game_network_level_valid(int level);
int game_network_world_valid(int level,const void *world);
int game_network_world_targeted(int level);
int game_native_loader_idle(void);
int game_network_level_authorized(int level);

int game_native_profile_ready(void);
int game_native_profile_storage_ready(void);
int game_native_scene_input_capability(int expected_level,const void *expected_world);
#ifdef __cplusplus
}
#endif
