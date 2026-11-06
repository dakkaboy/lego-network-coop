#pragma once
void game_poll(void);
void game_native_tick(void);
void game_request_level(int level);
void game_request_reload(int level);
int game_current_level(void);
int game_actor_count(void);
int game_load_status(void);
int game_target_level(void);
int game_network_profile_ready(void);

void game_cancel_level_request(void);
int game_network_target_level(void);
int game_network_level_valid(int level);
int game_network_level_authorized(int level);

int game_native_profile_ready(void);
