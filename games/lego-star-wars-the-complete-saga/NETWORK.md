# LAN session

The host owns player one. The first compatible client claims player two. A client sends its build ID and a nonce. The host echoes the nonce and supplies a session ID if the protocol version and build match. A retry from the same endpoint with the same nonce receives the same response. A client accepts replies only from the endpoint it contacted.

The host accepts input only from the joined endpoint and session. Each input is a complete snapshot of held buttons and signed stick axes. Sequence numbers start at one and increase for the lifetime of a session. Duplicate or older packets leave the current snapshot intact. Start a new session before the sequence is exhausted.

## Protocol version 1

Each datagram is 40 bytes. Multi-byte integers use network byte order.

| Offset | Field | Size |
| ---: | --- | ---: |
| 0 | Magic `LSCS` | 4 |
| 4 | Protocol version | 1 |
| 5 | Message type | 1 |
| 6 | Held buttons | 2 |
| 8 | Build ID | 8 |
| 16 | Client nonce | 8 |
| 24 | Session ID | 8 |
| 32 | Input sequence | 4 |
| 36 | X axis | 2 |
| 38 | Y axis | 2 |

Message types are hello (1), welcome (2), incompatible (3), and input (4). Hello, welcome and incompatible carry a nonzero build ID and nonce. Only welcome and input carry a nonzero session ID. Only input carries a sequence, buttons and axes. Unused fields are zero. An incompatible reply includes the host's build ID and protocol version.

The game integration still needs to provide the executable build ID, generate fresh nonce and session IDs, and own connection timeouts and input delivery.
