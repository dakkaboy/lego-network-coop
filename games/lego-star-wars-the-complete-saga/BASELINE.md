# Local co-op baseline

The Steam executable fingerprint is in the [build audit](README.md). Use a disposable copy and a separate save/config directory. The observed PC route starts at the native input prompt and reaches the cantina from **New Game**.

## First route

| Action | Observed result |
| --- | --- |
| Enter at the input prompt | Main menu appears with keyboard controls. |
| Select **New Game** | The cantina loads. Qui-Gon has the blue HUD. The green HUD asks for player two. |
| Press F2 in the cantina | Obi-Wan joins. Both players have their own health displays and share a camera. |
| Hold D, then release | Qui-Gon moves. |
| Hold Right, then release | Obi-Wan responds independently. |
| Press Esc | The native pause menu opens. |

The test used a copy of the Steam game with a disposable LocalAppData directory and injected keyboard states at the native DirectInput boundary. The diagnostic window stayed at `(-30000, -30000)`. Direct3D rendered to a windowed back buffer, which supplied the local frames. Opening the copy without Steam application context produced `5:0000065434`. The same copy reached the game with app ID 32440 and the running Steam client. An inactive Windows desktop gave a graphics initialization error. A window outside the screen on the active desktop rendered successfully.

Two simultaneous instances, controller join and drop-out, and the first chapter still need a baseline pass.

## Observed calls

These RVAs are call return addresses from the running Steam executable.

| Call | RVA | Observed in |
| --- | --- | --- |
| DirectInput keyboard device creation | `0x2da115` | Startup |
| DirectInput keyboard `GetDeviceState` | `0x2d5a13` | Menu, cantina and pause |
| Direct3D `Present` | `0x2e4016` | Startup |
| Direct3D `Present` | `0x2e41c2` | Menu, cantina and pause |

The keyboard poll writes a 256-byte scan-code buffer and alternates between two buffers. This is a keyboard input boundary. The gameplay tick and lifecycle boundaries still need runtime verification.
