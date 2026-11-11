#pragma once
#include <stdint.h>
#define GAME_SYNC_RESTART_REQUIRED (-256)
int game_sync_install(void);
int game_sync_status(void);
int game_sync_restart_required(void);
unsigned game_sync_sequence(void);
void game_sync_inspect(void);
int game_sync_poll_epoch(int target,int transitioning);
int game_sync_transition_waiting(int target,int transitioning);
uint32_t game_sync_epoch(void);
uint32_t game_sync_transition_entry(void);
int game_sync_epoch_level(void);
int game_sync_scene_ready(int level);
int game_sync_scene_initialized(int level);
uint32_t game_sync_preload_flow_input(void *flow,uint32_t request);
int game_sync_preload_level(void);
uint32_t game_sync_preload_track_input(const uint32_t witness[2],uint32_t time);

void game_sync_native_fault(int code);
