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
| Enter Episode I and walk through the door marked 1 | The Negotiations mode selector opens. |
| Select **Story** with U and dismiss the crawl with Enter | The opening Negotiations cutscene renders. |
| Wait for the opening cutscene, then press F2 | The first gameplay room opens and Obi-Wan joins with his own health and studs displays. |
| Move Qui-Gon and Obi-Wan to the first Force door. Hold J with Qui-Gon. | The door breaks into pieces and reveals the corridor and battle droids. Both HUDs remain active as Qui-Gon crosses the threshold. |

The test used a copy of the Steam game with a disposable LocalAppData directory and injected keyboard states at the native DirectInput boundary. The diagnostic window stayed at `(-30000, -30000)`. Direct3D rendered to a windowed back buffer, which supplied the local frames. Opening the copy without Steam application context produced `5:0000065434`. The same copy reached the game with app ID 32440 and the running Steam client. An inactive Windows desktop gave a graphics initialization error. A window outside the screen on the active desktop rendered successfully.

With two simultaneous processes in separate game directories and profiles, both created Direct3D devices and the second process opened all seven archives. Its back buffer stayed black in a startup loop with a null scene pointer while the first process rendered the cantina. Delivering focus messages to the second game's offscreen window left it in that loop. Physical controller join, drop-out and chapter completion still need a baseline pass.

A follow-up reversed the order of the copies and started both during the opening sequence. Both rendered the legal screen and reached a non-null scene pointer. The second still produced a black back buffer after leaving the startup loop, with input and presentation on the title path. The black frame can therefore persist after startup has advanced.

## Observed calls

These RVAs are call return addresses from the running Steam executable.

| Call | RVA | Observed in |
| --- | --- | --- |
| DirectInput keyboard device creation | `0x2da115` | Startup |
| DirectInput keyboard `GetDeviceState` | `0x2d5a13` | Menu, cantina and pause |
| Direct3D `Present` | `0x2e4016` | Startup |
| Direct3D `Present` | `0x2e41c2` | Menu, cantina and pause |

The keyboard poll writes a 256-byte scan-code buffer and alternates between two buffers. The same poll serves both keyboard slots, so it needs input ownership rules before it can carry remote control.

## Frame and controller probes

In a paused cantina sample, `Present` advanced by 94 frames. The paths at `0x93370`, `0x93405`, `0x93416` and `0x2579f0` each also advanced by 94 calls. Those counts follow frame cadence through pause. Use a probe inside the gated gameplay update to identify simulation steps.

The scene routine at `0x927f0` is a narrower probe. It ran 352 times during 351 presents in an active Episode I lobby sample, zero times during 244 presents while paused, and 195 times during 195 presents after resuming. The caller loads the scene pointer into ESI at `0x93565` and invokes the routine at `0x9356b`. Verify its side effects and timing under different render rates before using it as a simulation boundary.

The pointer at RVA `0x402c54` held the same value from the cantina through the chapter selector and crawl. It changed by the first playable Negotiations room. It also read as null in the stalled second process. This is a candidate for observing active room state. Reset and hub return still need measurements.

The XInput capability call returns to `0x2da23d` during startup and enumerates indices 0–3. The native device poll beginning at `0x2d74e0` calls `XInputGetState` at `0x2d7584` when its mapped device is in indices 0–3 with type 6. The resolved runtime import slots for capabilities, state and vibration are `0x3512a4`, `0x3512a8` and `0x3512ac`. These came from the loaded game and were matched to system exports.

In the diagnostic run, synthetic capabilities made index 0 present while its type field remained zero. The test selected type 6 for that empty record after the game initialized. A through `XInputGetState` added Obi-Wan as player two. The native mapped device state contained signed X values of 21,999 and −21,999 for XInput values of ±22,000. A positive Y value of 28,000 mapped to −27,999. Release cleared the sampled analog state. A simulated disconnect returned an unavailable device and an empty state, and the pause HUD identified Obi-Wan. Character movement through that mapped state, menu navigation and clean drop-out need separate verification.
