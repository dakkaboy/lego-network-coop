# LEGO Star Wars III: The Clone Wars

[Русский](README.ru.md)

Network co-op for two Windows PCs. One player hosts, the other joins by IP, and each player has their own camera and the original HUD.

**Beta 1 — 0.1.1.** Fixes for combat, debris and troop synchronization, with lower synchronization overhead in large battles.

Some mission desyncs remain unresolved. Install the same version on both PCs.

- [Download 0.1.1 Beta 1](https://github.com/dakkaboy/lego-network-coop/releases/tag/v0.1.1)
- [Nexus Mods](https://www.nexusmods.com/legostarwars3theclonewars/mods/28)

![Network Co-op menu](images/network-coop.png)

## Build

Install Zig 0.17.1. With Zig on `PATH`, run this in the game project directory.

```powershell
./build-camera.ps1
```

The x86 build writes `d3d9.dll` and `clonewars-camera.dll` to `build/`. The proxy loads the mod, which owns the camera, game hooks and network session. Both players need the same build.

## Run

Close the game and copy both DLLs next to `LEGOCloneWars.exe`. Back up any existing `d3d9.dll` before replacing it. On the host, select **Co-op** in the main menu and load a save to start hosting. You can also press F10 or F12 and select **Create game**. On the guest, press F10 or F12, enter the host IP and select **Connect**. Close the menu and start a mission on the host. The mod uses TCP port 32510.

## Source layout

- `src/zig/` contains the mod's Zig code: networking, synchronization, cameras, UI and diagnostics.
- `build.zig` builds the 32-bit DLLs and tools.
- `src/engine/proxy.def` lists the proxy DLL's exported functions.

The mod targets the Windows edition of the game. Build both DLLs with `zig build dll`. Enable profiling with `-Dtracy=true`.
