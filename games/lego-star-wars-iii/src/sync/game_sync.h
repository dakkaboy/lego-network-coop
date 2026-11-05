#pragma once
#include <stdint.h>
int game_sync_install(void);
int game_sync_status(void);
unsigned game_sync_sequence(void);
void game_sync_inspect(void);
int game_sync_poll_epoch(int target,int transitioning);
uint32_t game_sync_epoch(void);
int game_sync_epoch_level(void);

void game_sync_native_fault(int code);
