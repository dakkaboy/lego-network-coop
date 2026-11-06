# LEGO Star Wars III: The Clone Wars

[Русский](README.ru.md)

Network co-op for two Windows PCs. One player hosts, the other joins by IP, and each player has their own camera and the original HUD.

0.0.2 fixes broken geometry on the client and reduces simulation overhead. Ambush was tested through destruction of the gold coral with two game instances on one PC.

- [Download 0.0.2](https://github.com/dakkaboy/lego-network-coop/releases/tag/v0.0.2)
- [Nexus Mods](https://www.nexusmods.com/legostarwars3theclonewars/mods/28)

## Build

On Windows, put Python 3, Zig and Clang on PATH. Run this from the game project directory:

```powershell
./build-camera.ps1 -WithHitEntryObserver
```

The x86 build writes `d3d9.dll` and `clonewars-camera.dll` to `build/`. The proxy loads the mod; the mod owns the camera, game hooks and network session. The wire protocol is 29. Both players need the same build.

## Run

Close the game and copy both DLLs next to `LEGOCloneWars.exe`. Back up any existing `d3d9.dll` before replacing it. Open F12, select Host on one PC, then enter the host IP and select Connect on the other. Close the menu and start a mission on the host. The mod uses TCP port 32510.

## Source layout

- `src/net/` handles TCP, queues and the wire format.
- `src/sync/` orders simulation steps and applies input and state.
- `src/engine/` contains the proxy, game addresses, hook bridges and exception handlers.
- `src/render/` handles cameras, the stock HUD, frame capture and window behavior.
- `src/debug/` contains observers and runtime diagnostics.

Some synchronization and rendering modules still contain native hooks. Their addresses and memory layouts target the Windows executable for this game. C++ modules use C++23 and expose C linkage to existing C callers.
