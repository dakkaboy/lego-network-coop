# LAN session

The host owns player one. The first compatible client claims player two. A client sends its build ID and a nonce. The host echoes the nonce and supplies a session ID if the protocol version and build match. A retry from the same endpoint with the same nonce receives the same response. A client accepts replies only from the endpoint it contacted.

The host announces a new scene generation when loading begins and when the game publishes the room. A zero room key marks loading. The room key should identify the native room and mode. A fresh publication can reuse the same room key and still advances the generation. Each announcement clears the previous input.

The client confirms the latest generation after it observes the matching local scene publication. Until confirmation it sends no input. The transport should resend the current scene announcement after joining and during a transition, because UDP can drop or reorder it.

Each input is a complete snapshot of held buttons and signed stick axes. The host accepts it from the joined endpoint and session when the packet matches the current generation. Sequence numbers start at one and increase for the lifetime of a session. Duplicate and older packets leave the current snapshot intact. Start a new session before sequence or generation exhaustion.

## Protocol version 2

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

Message types are hello (1), welcome (2), incompatible (3), input (4), and scene (5). Hello, welcome and incompatible carry a nonzero build ID and nonce. Welcome, input and scene carry a nonzero session ID. Input and scene carry a nonzero generation. Only scene carries the room key. Only input carries a sequence, buttons and axes. Unused fields are zero. An incompatible reply includes the host's build ID and protocol version.

The game integration still needs to bind scene announcements and confirmations to native lifecycle events, provide the executable build ID and fresh session IDs, and own connection timeouts and input delivery.
