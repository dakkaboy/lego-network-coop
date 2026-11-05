#define WIN32_LEAN_AND_MEAN
#include <windows.h>
extern "C" {
#include "lan.h"
}
#include "network_window.h"

#ifndef NETWORK_PROCESS_POLICY
#define NETWORK_PROCESS_POLICY ((volatile LONG *)0xe13978)
#endif

static HWND network_window;
static DWORD network_window_thread;
static LONG drag_active;
static POINT drag_offset;
static DWORD last_drag_move;
static LONG saved_process_policy;
static int process_policy_owned;
extern "C" {
__declspec(dllexport) volatile LONG clonewars_network_window_debug[8];
}

static int on_window_thread(void) {
    return network_window && network_window_thread==GetCurrentThreadId();
}

static int session_active(void) {
    int status=lan_status();
    return status==LAN_LISTENING || status==LAN_CONNECTING || status==LAN_CONNECTED;
}

static void end_drag(void) {
    if (!InterlockedExchange(&drag_active,0)) return;
    if (GetCapture()==network_window) ReleaseCapture();
}

static int move_drag_window(int final) {
    POINT cursor;DWORD tick=GetTickCount();
    if (!GetCursorPos(&cursor)) return 0;
    /* High-rate mouse events must not starve the normal game and network loop. */
    if (!final && tick-last_drag_move<16) return 1;
    last_drag_move=tick;
    if (!SetWindowPos(network_window,NULL,cursor.x-drag_offset.x,cursor.y-drag_offset.y,
                      0,0,SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE)) return 0;
    ++clonewars_network_window_debug[4];
    return 1;
}

void network_window_configure(HWND window) {
    DWORD thread=GetWindowThreadProcessId(window,NULL);
    if (!thread || thread!=GetCurrentThreadId()) return;
    network_window=window;
    network_window_thread=thread;
}

void network_window_update(void) {
    if (!on_window_thread()) return;
    if (session_active()) {
        LONG current=*NETWORK_PROCESS_POLICY;
        if (!process_policy_owned && (current==0 || current==1)) {
            saved_process_policy=current;
            process_policy_owned=1;
        }
        if (process_policy_owned) *NETWORK_PROCESS_POLICY=1;
    } else {
        end_drag();
        if (process_policy_owned && *NETWORK_PROCESS_POLICY==1)
            *NETWORK_PROCESS_POLICY=saved_process_policy;
        process_policy_owned=0;
    }
    clonewars_network_window_debug[0]=process_policy_owned;
    clonewars_network_window_debug[1]=process_policy_owned ? *NETWORK_PROCESS_POLICY : -1;
}

int network_window_input_blocked(void) {
    return InterlockedCompareExchange(&drag_active,0,0)!=0;
}

int network_window_message(HWND window, UINT message, WPARAM wp, LPARAM lp) {
    (void)lp;
    if (window!=network_window || !on_window_thread()) return 0;
    network_window_update();
    if (!session_active()) return 0;
    if (message==WM_SIZE && wp==SIZE_MINIMIZED) {
        /* Keep the last valid render dimensions; a minimized client must not reset its camera to a zero-size viewport. */
        ++clonewars_network_window_debug[2];
        return 1;
    }
    if (message==WM_CAPTURECHANGED || message==WM_CANCELMODE || message==WM_KILLFOCUS ||
        (message==WM_ACTIVATEAPP && !wp)) {
        end_drag();
        return 0;
    }
    if (message==WM_NCLBUTTONDOWN && wp==HTCAPTION && GetForegroundWindow()==window) {
        RECT bounds;POINT cursor;
        if (!GetWindowRect(window,&bounds) || !GetCursorPos(&cursor)) return 0;
        drag_offset.x=cursor.x-bounds.left;
        drag_offset.y=cursor.y-bounds.top;
        SetCapture(window);
        if (GetCapture()!=window) return 0;
        InterlockedExchange(&drag_active,1);
        last_drag_move=GetTickCount()-16;
        ++clonewars_network_window_debug[3];
        return 1;
    }
    if (!network_window_input_blocked()) return 0;
    if (message==WM_LBUTTONUP) {
        move_drag_window(1);
        end_drag();
        return 1;
    }
    if (message==WM_MOUSEMOVE) {
        if (!(wp&MK_LBUTTON) || !move_drag_window(0)) end_drag();
        return 1;
    }
    return 0;
}
