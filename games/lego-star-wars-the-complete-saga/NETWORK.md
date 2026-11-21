# LAN session

The host owns player one. The first compatible client claims player two. A client sends its build ID and a nonce. The host echoes the nonce and supplies a session ID if the protocol version and build match. A retry from the same endpoint with the same nonce receives the same response. A client accepts replies only from the endpoint it contacted.

The host announces a new scene generation when loading begins and when the game publishes the room. A zero room key marks loading. The room key should identify the native room and mode. A fresh publication can reuse the same room key and still advances the generation. Each announcement clears the previous input.

The client confirms the latest generation after it observes the matching local scene publication. Until confirmation it sends no input. The transport should resend the current scene announcement after joining and during a transition, because UDP can drop or reorder it.

Each input is a complete snapshot of held buttons and signed stick axes. The host accepts it from the joined endpoint and session when the packet matches the current generation. Sequence numbers start at one and increase for the lifetime of a session. Duplicate and older packets leave the current snapshot intact. Start a new session before sequence or generation exhaustion.

## Protocol version 9

Each datagram is 40 bytes. Multi-byte integers use network byte order.

| Offset | Field | Size |
| ---: | --- | ---: |
| 0 | Magic `LSCS` | 4 |
| 4 | Protocol version | 1 |
| 5 | Message type | 1 |
| 6 | Held buttons | 2 |
| 8 | Build ID or scene generation | 8 |
| 16 | Client nonce or room key | 8 |
| 24 | Session ID | 8 |
| 32 | Input sequence | 4 |
| 36 | X axis | 2 |
| 38 | Y axis | 2 |

Message types are hello (1), welcome (2), incompatible (3), client input (4), scene (5), host input (6), player state (7), Story (8), campaign progress (9), and per-player pose (10 and 11). Hello, welcome and incompatible carry a nonzero build ID and nonce. Welcome, both input messages and scene carry a nonzero session ID. Both input messages and scene carry a nonzero generation. Scene carries the room key. Story carries the host selection sequence and two native catalogue indices at offsets 16 and 20. Campaign progress carries two 72-bit sets for unlocked and completed Story chapters. Input carries a sequence, buttons and axes. Player state carries a sequence, two health bytes at offsets 6 and 7, and two unsigned 32-bit player scores at offsets 16 and 20, and two unsigned 16-bit death counters at offsets 36 and 38. Pose messages carry the host position and heading of one player. The client applies gameplay snapshots from the host for its confirmed generation. Both players need the same protocol version. Unused fields are zero. An incompatible reply includes the host's build ID and protocol version.

## Start on a LAN

After building, place the Saga `d3d9.dll` from `build/Release` beside `LEGOStarWarsSaga.exe` in a disposable game copy on each computer. Run `tools/Start-SagaLan.ps1` on both. Select the game folder and enter the host's LAN IPv4 address on both computers. On the host choose **Создать игру** and on the client choose **Подключиться**. The host listens on UDP port 34244 at the specified address.

Start both copies in the cantina. Choose Story on the host. The client loads the selected chapter automatically. After both players join the mission, each copy follows its own character when the game uses its normal follow camera. The host reads its normal player-one controls. Once both games confirm the room, player one uses WASD, J for Force, H to attack, U to jump and K to switch characters on the host. Player two uses the left stick or D-pad, Y for Force, X to attack, A to jump, Right Bumper to switch characters and Start to join on the client. These controls are sent to both copies. Both sides clear remote movement on a scene change or after 250 ms without a fresh input packet. In episode missions, the host supplies stud counts, health and death events while both native player slots are active. The client uses the game damage path for host-authorized damage. This build still uses Saga's native rendering and each copy loads its own scenes.

## In-game loopback test

Set `COMPLETE_SAGA_LOCAL_INPUT` to `host` in the first disposable copy and to `client` in the second. Set `COMPLETE_SAGA_ISOLATE_TEST_EVENTS=1` for both on the same PC. Use the default keyboard controls on the host. The client reads XInput controller 0. Start the first copy, reach the cantina, then start the second and reach the same scene through the native menu.

The test listens on IPv4 loopback port 34244. The host maps Start to F2 and the left stick or D-pad to the native direction keys for player two. It neutralizes those inputs on a scene change or after 250 ms without new input. The client sends input once both copies have published the same room. It requires a fresh local publication before accepting a new generation, even when the native room path is unchanged.

The room key comes from the normalized native asset path. The host sends Story selections separately from gameplay input so they can arrive during a room transition. The client receives unlocked and completed Story chapter flags from the host in the cantina. Free Play selection and broader world state still need synchronization.
