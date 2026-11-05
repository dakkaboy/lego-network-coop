# LEGO Star Wars III: The Clone Wars

Network co-op for two Windows PCs. One player hosts, the other joins by IP, and each player has their own camera and the original HUD.

0.0.1 is an alpha. Ambush and Geonosian Arena were tested in short sessions with two game instances on one PC. Full missions and connections between separate PCs remain untested.

- [Download 0.0.1](https://www.nexusmods.com/legostarwars3theclonewars/mods/28)
- [Steam guide (English)](https://steamcommunity.com/sharedfiles/filedetails/?id=3834270478)
- [Руководство Steam (русский)](https://steamcommunity.com/sharedfiles/filedetails/?id=3834269735)

## Build

On Windows, put Python 3, Zig and Clang on PATH. Run this from the game project directory:

```powershell
./build-camera.ps1 -WithHitEntryObserver
```

The x86 build writes `d3d9.dll` and `clonewars-camera.dll` to `build/`. The proxy loads the mod; the mod owns the camera, game hooks and network session. The wire protocol is 29. Both players need the same build.

## Run

Close the game and copy both DLLs next to `LEGOCloneWars.exe`. Back up any existing `d3d9.dll` before replacing it. Open F12, select Host on one PC, then enter the host IP and select Connect on the other. Close the menu and start a mission on the host. The mod uses TCP port 32510.

## Source layout

- `src/proxy.c` loads the mod through Direct3D 9.
- `src/camera.c` handles views, HUD routing and the in-game menu.
- `src/network_window.cpp` owns Win32 window behavior during a session.
- `src/input_buffer.cpp` buffers input edges across simulation waits.
- `src/lan.c` and `src/sync_wire.c` handle transport and packet layout.
- `src/game_sync.c` and `src/coherent_core_body.inc` coordinate simulation steps and game state.

Hooks and memory layouts target the Windows executable for this game.

C++ modules use C++23 and expose C linkage to existing C callers. Keep executable addresses and native hooks inside this game directory.
