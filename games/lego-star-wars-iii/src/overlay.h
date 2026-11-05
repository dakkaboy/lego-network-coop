#pragma once
#define COBJMACROS
#include <d3d9.h>
#include <stdint.h>
typedef struct CoopHudPlayer {
    int health,max_health,has_studs;
    uint64_t studs;
} CoopHudPlayer;
void coop_draw(IDirect3DDevice9 *device,const CoopHudPlayer hud[2]);
void coop_set_window(HWND window);
void coop_fonts_lost(void);
void coop_fonts_reset(void);
void coop_release_fonts(void);
void coop_toggle(void);
int coop_input(HWND window, UINT message, WPARAM wp, LPARAM lp);
void camera_select(int player);
int camera_selected(void);
