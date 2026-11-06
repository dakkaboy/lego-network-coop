# LEGO Star Wars: The Complete Saga

The current build is a development proxy for the game's Direct3D 9 imports. LAN play is pending. [Track development on GitHub](https://github.com/dakkaboy/lego-network-coop/milestone/2).

## Build

Run from the repository root in PowerShell on Windows.

```powershell
./games/lego-star-wars-the-complete-saga/build.ps1 -Test
```

The script builds a 32-bit `d3d9.dll` in the game's repository `build` directory. The smoke test loads the proxy, calls all three exports and checks that the resulting Direct3D object can enumerate an adapter. It runs independently of the game.

The proxy has no game hooks. It resolves the three observed exports from the system Direct3D library on first use, outside DLL initialization. Use a disposable copy of the game to test the proxy. An existing `d3d9.dll` in that copy may belong to another mod.

On the Steam build below, Windows mapped the proxy from a staged game directory. The loader probe stopped before the main menu. The standalone smoke test passed with one Direct3D adapter.

## Steam build audit

| Property | Observed value |
| --- | --- |
| Steam app ID | 32440 |
| Executable | `LEGOStarWarsSaga.exe` |
| SHA-256 | `085688e73561c61f4619fcf1f3006c56425ca365e80ea5fc0175bab334cec671` |
| Format | PE32, x86 |
| Preferred image base | `0x00400000` |
| Entry RVA | `0x026382ed`, in `.bind` |
| Direct3D imports | `Direct3DCreate9`, `D3DPERF_BeginEvent`, `D3DPERF_EndEvent` from `d3d9.dll` |
| Input import | `DirectInput8Create` from `DINPUT8.dll` |
| Other game dependencies | `d3dx9_35.dll`, `binkw32.dll`, `DSOUND.dll`, `WINMM.dll` |

Reproduce the binary checks with the Steam game directory as your working directory.

```powershell
Get-FileHash -Algorithm SHA256 ./LEGOStarWarsSaga.exe
llvm-objdump --private-headers --section-headers ./LEGOStarWarsSaga.exe
```

`GAME.DAT` and the six episode archives share an index. In all seven files the first two little-endian 32-bit fields give its offset and the number of bytes from that offset to EOF. The index version is `-3`. See the [mission checklist](MISSIONS.md) for the chapters and bonus routes found in those archives. The executable also contains references to `SavedGames` and `pcconfig.txt` for testing save isolation.

## Mission lifecycle

Use one loading path for all six episodes in Story and Free Play. Entering from the cantina, changing chapters and returning to the hub should use the same lifecycle for both peers. If a native mode needs different parameters, select them by transition type or gameplay phase. Keep chapter identifiers in level selection and test data.

Game-specific addresses, hooks and packet layouts belong here. Use `common/` for code that can run independently of either game's executable and state.
