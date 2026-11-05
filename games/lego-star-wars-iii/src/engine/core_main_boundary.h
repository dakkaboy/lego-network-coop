#pragma once
#include "native_owner.h"
typedef struct CoreMainBoundary {NativeOwnerScope*owner;uint32_t owner_nonce,thread,release,boundary_serial;} CoreMainBoundary;
int game_sync_main_boundary_get(CoreMainBoundary*);
int game_sync_main_boundary_valid(const void*,uint32_t,void*);
int camera_install_qualified_main(void);
