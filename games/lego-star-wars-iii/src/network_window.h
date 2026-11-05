#pragma once
#include <windows.h>

void network_window_configure(HWND window);
void network_window_update(void);
int network_window_message(HWND window, UINT message, WPARAM wp, LPARAM lp);
int network_window_input_blocked(void);
