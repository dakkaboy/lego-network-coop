#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <windowsx.h>
#include <shellapi.h>
#include <d3d9.h>
#include <stdio.h>
#include <wchar.h>
#include <string.h>
#include "overlay.h"
extern "C" {
#include "../net/lan.h"
#include "../engine/game_state.h"
#include "../sync/game_sync.h"
#include "../engine/loading.h"
}

namespace {

struct FontDescA;
struct FontDescW;
struct Sprite;

// ABI of the font returned by the game's D3DXCreateFontW.
struct Font : IUnknown {
    virtual HRESULT STDMETHODCALLTYPE GetDevice(IDirect3DDevice9 **) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetDescA(FontDescA *) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetDescW(FontDescW *) = 0;
    virtual BOOL STDMETHODCALLTYPE GetTextMetricsA(TEXTMETRICA *) = 0;
    virtual BOOL STDMETHODCALLTYPE GetTextMetricsW(TEXTMETRICW *) = 0;
    virtual HDC STDMETHODCALLTYPE GetDC() = 0;
    virtual HRESULT STDMETHODCALLTYPE GetGlyphData(UINT, IDirect3DTexture9 **, RECT *, POINT *) = 0;
    virtual HRESULT STDMETHODCALLTYPE PreloadCharacters(UINT, UINT) = 0;
    virtual HRESULT STDMETHODCALLTYPE PreloadGlyphs(UINT, UINT) = 0;
    virtual HRESULT STDMETHODCALLTYPE PreloadTextA(const char *, INT) = 0;
    virtual HRESULT STDMETHODCALLTYPE PreloadTextW(const wchar_t *, INT) = 0;
    virtual INT STDMETHODCALLTYPE DrawTextA(Sprite *, const char *, INT, RECT *, DWORD, D3DCOLOR) = 0;
    virtual INT STDMETHODCALLTYPE DrawTextW(Sprite *, const wchar_t *, INT, RECT *, DWORD, D3DCOLOR) = 0;
    virtual HRESULT STDMETHODCALLTYPE OnLostDevice() = 0;
    virtual HRESULT STDMETHODCALLTYPE OnResetDevice() = 0;
};

}

static LONG opened;
static int address_focus;
static char address[64] = "127.0.0.1";
static float scale = 1.0f;
static Font *font, *title_font;
static int keyboard_focus = 1;
static unsigned char previous_keyboard_block;
enum {
    PROJECT_CONTROL = 7,
    CONTROL_COUNT,
    PROJECT_X = 230,
    PROJECT_Y = 576,
    PROJECT_WIDTH = 260,
    BUTTON_HEIGHT = 48,
};
void coop_set_window(HWND window) { (void)window; }

struct Vertex { float x, y, z, rhw; DWORD color; };

static void rectangle(IDirect3DDevice9 *device, float x, float y, float width, float height, DWORD color) {
    float left = x * scale - 0.5f, top = y * scale - 0.5f;
    float right = (x + width) * scale - 0.5f, bottom = (y + height) * scale - 0.5f;
    struct Vertex vertices[] = {{left,top,0,1,color},{right,top,0,1,color},
                                {left,bottom,0,1,color},{right,bottom,0,1,color}};
    device->SetTexture(0, NULL);
    device->SetPixelShader(NULL);
    device->SetVertexShader(NULL);
    device->SetFVF(D3DFVF_XYZRHW | D3DFVF_DIFFUSE);
    device->SetRenderState(D3DRS_ZENABLE, FALSE);
    device->SetRenderState(D3DRS_CULLMODE, D3DCULL_NONE);
    device->SetRenderState(D3DRS_ALPHABLENDENABLE, TRUE);
    device->SetRenderState(D3DRS_SRCBLEND, D3DBLEND_SRCALPHA);
    device->SetRenderState(D3DRS_DESTBLEND, D3DBLEND_INVSRCALPHA);
    device->SetTextureStageState(0, D3DTSS_COLOROP, D3DTOP_SELECTARG1);
    device->SetTextureStageState(0, D3DTSS_COLORARG1, D3DTA_DIFFUSE);
    device->SetTextureStageState(0, D3DTSS_ALPHAOP, D3DTOP_SELECTARG1);
    device->SetTextureStageState(0, D3DTSS_ALPHAARG1, D3DTA_DIFFUSE);
    device->DrawPrimitiveUP(D3DPT_TRIANGLESTRIP, 2, vertices, sizeof(vertices[0]));
}

static void text(const wchar_t *label, int x, int y, int width, DWORD color, int title) {
    RECT bounds = {(int)(x*scale),(int)(y*scale),(int)((x+width)*scale),(int)((y+60)*scale)};
    (title ? title_font : font)->DrawTextW(nullptr, label, -1, &bounds,
                       DT_LEFT | DT_NOCLIP, color);
}

static void button(IDirect3DDevice9 *device, const wchar_t *label, int x, int y, int width, int checked) {
    DWORD color = checked ? 0xff315c84 : 0xff142c45;
    rectangle(device,x,y,width,BUTTON_HEIGHT,color);
    rectangle(device,x,y,width,2,checked ? 0xffffcf48 : 0xff4384b6);
    text(label,x+16,y+10,width-24,0xfff4f7ff,0);
}

static void activate(HWND window, int control) {
    if (control == 0) address_focus = 1;
    if (control == 1 || control == 2) {
        if (lan_status() == LAN_OFF || lan_status() == LAN_FAILED) lan_start(control == 1,address);
        else lan_stop();
    }
    if (control >= 3 && control <= 5) camera_select(control-4);
    if (control == 6) coop_toggle();
    if (control == PROJECT_CONTROL)
        ShellExecuteW(window,L"open",L"https://github.com/dakkaboy/lego-network-coop",NULL,NULL,SW_SHOWNORMAL);
}

static void draw_hud(const CoopHudPlayer hud[2]) {
    for (int i=0;i<2;++i) {
        const CoopHudPlayer *player=&hud[i];
        int x=i ? 1020 : 80;
        if (player->has_studs) {
            wchar_t count[32];
            swprintf(count,32,L"%llu",(unsigned long long)player->studs);
            text(count,x+1,31,180,0xff171008,0);
            text(count,x,30,180,0xffffcd39,0);
        }
        int hearts=player->max_health<16 ? player->max_health : 16;
        for (int j=0;j<hearts;++j) {
            int left=x+24*(j%8),top=51+24*(j/8);
            text(L"\u2665",left+1,top+1,24,0xff250c12,0);
            text(L"\u2665",left,top,24,j<player->health ? 0xffff4949 : 0xff78383f,0);
        }
    }
}

void coop_draw(IDirect3DDevice9 *device,const CoopHudPlayer hud[2]) {
    D3DVIEWPORT9 viewport;
    if (FAILED(device->GetViewport(&viewport)) || !viewport.Width || !viewport.Height) return;
    float wanted_scale = (float)viewport.Width / 1280.0f;
    if (font && (scale > wanted_scale + 0.01f || scale < wanted_scale - 0.01f)) {
        font->Release();
        title_font->Release();
        font = title_font = NULL;
    }
    scale = wanted_scale;
    if (!font) {
        typedef HRESULT (WINAPI *CreateFont)(IDirect3DDevice9 *,INT,UINT,UINT,UINT,BOOL,DWORD,DWORD,DWORD,DWORD,LPCWSTR,Font **);
        HMODULE library = GetModuleHandleW(L"d3dx9_41.dll");
        CreateFont create = library ? (CreateFont)GetProcAddress(library,"D3DXCreateFontW") : NULL;
        if (!create || FAILED(create(device,(int)(23*scale),0,FW_SEMIBOLD,1,FALSE,DEFAULT_CHARSET,
                                     OUT_DEFAULT_PRECIS,ANTIALIASED_QUALITY,DEFAULT_PITCH,L"Segoe UI",&font))) return;
        if (FAILED(create(device,(int)(38*scale),0,FW_BOLD,1,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,
                          ANTIALIASED_QUALITY,DEFAULT_PITCH,L"Segoe UI",&title_font))) {
            font->Release();
            font = NULL;
            return;
        }
    }
    draw_hud(hud);
    if (!opened) return;
    rectangle(device,0,0,1280,720,0xd90a121e);
    rectangle(device,190,75,900,565,0xf50e1d30);
    rectangle(device,190,75,900,3,0xffffcf48);
    text(L"LAN",230,103,700,0xffffcf48,1);
    text(L"Host IP",230,178,400,0xffb3c5dc,0);
    rectangle(device,230,214,820,48,address_focus || keyboard_focus == 0 ? 0xff274666 : 0xff162d46);
    wchar_t ip[64];
    MultiByteToWideChar(CP_UTF8,0,address,-1,ip,64);
    text(ip,246,224,780,0xffffffff,0);
    long state = lan_status();
    if (state == LAN_OFF || state == LAN_FAILED) {
        button(device,L"Host",230,286,392,keyboard_focus==1);
        button(device,L"Connect",658,286,392,keyboard_focus==2);
    } else button(device,L"Disconnect",230,286,820,keyboard_focus==1 || keyboard_focus==2);
    wchar_t status[128];
    const wchar_t *description = L"Not connected";
    if (state == LAN_LISTENING) description = L"Waiting for player";
    if (state == LAN_CONNECTING) description = L"Connecting...";
    if (state == LAN_CONNECTED) {
        description = L"Connected";
        if (!lan_is_host() && game_load_status() == 3) description = L"Preparing game";
        if (!lan_is_host() && game_load_status() == 1) description = L"Loading host level";
    }
    if (state == LAN_FAILED) {
        swprintf(status,128,L"Connection error: %ld",lan_error());
        description = status;
    }
    text(description,230,354,820,0xffb3c5dc,0);
    const wchar_t *sync_description=L"TCP 32510";
    wchar_t sync_text[128];
    if (state==LAN_CONNECTED) {
        if (game_sync_status()==-8) sync_description=L"Sync disabled";
        else if (game_sync_status()<0) {
            swprintf(sync_text,128,L"Sync error: %d. Reconnect.",game_sync_status());
            sync_description=sync_text;
        } else if (game_sync_status()==2) {
            swprintf(sync_text,128,L"Frame: %u",game_sync_sequence());
            sync_description=sync_text;
        } else sync_description=L"Waiting for level";
    }
    text(sync_description,230,391,820,0xffffcf48,0);
    button(device,L"Default view",230,452,260,camera_selected()==-1 || keyboard_focus==3);
    button(device,L"Player 1",510,452,260,camera_selected()==0 || keyboard_focus==4);
    button(device,L"Player 2",790,452,260,camera_selected()==1 || keyboard_focus==5);
    text(L"Tab / Arrows · Enter · Esc",230,530,540,0xffb3c5dc,0);
    button(device,L"Close",790,518,260,keyboard_focus==6);
    button(device,L"Project on GitHub",PROJECT_X,PROJECT_Y,PROJECT_WIDTH,keyboard_focus==PROJECT_CONTROL);
}

void coop_toggle(void) {
    opened = !opened;
    address_focus = 0;
    keyboard_focus = 1;
    unsigned char *input_flags = (unsigned char *)0xf91eb4;
    if (opened) {
        previous_keyboard_block = *input_flags & 2;
        *input_flags |= 2;
    } else *input_flags = (*input_flags & ~2) | previous_keyboard_block;
}
void coop_release_fonts(void) {
    if (font) font->Release();
    if (title_font) title_font->Release();
    font = title_font = NULL;
}
void coop_fonts_lost(void) {
    if (font) font->OnLostDevice();
    if (title_font) title_font->OnLostDevice();
}
void coop_fonts_reset(void) {
    if (font) font->OnResetDevice();
    if (title_font) title_font->OnResetDevice();
}

int coop_input(HWND window, UINT message, WPARAM wp, LPARAM lp) {
    if (!opened) return 0;
    if (message == WM_KEYDOWN && wp == VK_ESCAPE) { coop_toggle(); return 1; }
    if (message == WM_KEYDOWN && (wp == VK_TAB || wp == VK_UP || wp == VK_DOWN ||
                                 wp == VK_LEFT || wp == VK_RIGHT)) {
        int backward = wp == VK_UP || wp == VK_LEFT || (wp == VK_TAB && (GetKeyState(VK_SHIFT)&0x8000));
        keyboard_focus = (keyboard_focus + (backward ? CONTROL_COUNT-1 : 1)) % CONTROL_COUNT;
        address_focus = keyboard_focus == 0;
        return 1;
    }
    if (message == WM_KEYDOWN && wp == VK_RETURN) {
        if (keyboard_focus != PROJECT_CONTROL || !(lp & (1L << 30)))
            activate(window,address_focus ? 2 : keyboard_focus < 0 ? 1 : keyboard_focus);
        return 1;
    }
    if (message == WM_LBUTTONUP) {
        int x = GET_X_LPARAM(lp), y = GET_Y_LPARAM(lp);
        if (x >= PROJECT_X*scale && x < (PROJECT_X+PROJECT_WIDTH)*scale &&
            y >= PROJECT_Y*scale && y < (PROJECT_Y+BUTTON_HEIGHT)*scale) {
            keyboard_focus = PROJECT_CONTROL;
            address_focus = 0;
            activate(window,PROJECT_CONTROL);
        }
    }
    if (message == WM_CHAR && address_focus) {
        size_t length = strlen(address);
        if (wp == 8 && length) address[length-1] = 0;
        if (((wp >= '0' && wp <= '9') || wp == '.') && length < sizeof(address)-1) {
            address[length] = (char)wp;
            address[length+1] = 0;
        }
    }
    return (message >= WM_KEYFIRST && message <= WM_KEYLAST) ||
           (message >= WM_MOUSEFIRST && message <= WM_MOUSELAST);
}
