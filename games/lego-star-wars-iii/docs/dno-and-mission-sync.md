# DNO collision data and mission synchronization

Verified against 259 DNO files from the Windows game. Numbers in this document use zero-based indexing.

| Record | Field | Finding |
| --- | --- | --- |
| Group 6 | u16 at +0x10 | Local name index. 0xFFFF is absent. Some other indices exceed the local name table. |
| Group 6 | u16 at +0x14, byte at +0x1B | Geometry index and kind. Kind 4 selects group 10. Kind 5 selects group 11. |
| Group 10 | Vertex and face lists | Convex hull. The vertex-to-face lists agree with the faces. A separate vertex list differs from edge adjacency in 156 hulls. |
| Group 10 | Face vectors | First three components are unit normals, verified against all 31,073 faces. Fourth word and the role of the 4×4 matrix are unresolved. |
| Group 11 | Polygon words 0–3 | Vertex indices. Triangles often repeat the last index. |
| Group 11 | Polygon word 4 | Six two-bit slots in the four indices above. Bits 0–1, 2–3, 4–5 select min X, Y, Z. Bits 6–7, 8–9, 10–11 select max X, Y, Z. Bits 12–15 are zero in the corpus. |
| Group 11 | Leaf bounds and mixed tree records | Leaf bounds enclose a contiguous polygon range. Node kinds 0–2 split by axis, and kind 3 selects a leaf. Verified in 966 meshes with 71,121 leaves. |
| Group 11 | Per-polygon byte | Index into the mesh's property table. Every entry is used. |
| Group 11 | Property entry | On disk: byte, category byte, big-endian u16, byte. Both outer bytes are zero in all 1,209 entries. Bits 0–5, 10, 11 and 15 occur in the u16. Their behavior remains unresolved. |
| Group 11 | Property category 1 | Associated with named KillTerrain meshes, including all five Null_Kill meshes in Blue Shadow Virus B_TECH. Appears on 2,097 polygons in the corpus. Gameplay behavior still needs a runtime check. |

The six extremum selectors matched exactly on all 495,337 polygons. Of 115 geometry references without a local name, 37 have a byte-identical named mesh elsewhere and 26 have only one candidate name. Resource reuse can produce these matches.

| Blue Shadow Virus B_TECH object slot | Group 11 mesh | Evidence |
| --- | --- | --- |
| 80 | 6 | Name and transform indices are 0xFFFF. |
| 81 | 7 | Name and transform indices are 0xFFFF. Reflecting mesh 6 across X and offsetting Z matches all 12 vertices and 10 polygon incidences within 0.000001. |
| 82 | 8 | Latt_FallKIll_nshack. Category 0, property word 0x0003. |

Neither mirrored mesh matched any of 926 named group 11 meshes by vertex count, polygon arity and pairwise distances. A search of six GSC files for the original float32 coordinate triples in both byte orders also returned no matches.

## Network synchronization

Both peers load the installed collision geometry. For matching game data, leave the vertices, polygon bounds and tree local. For a moving or toggled collider, synchronize the object transform, activation or collision state at the native simulation boundary if the peers disagree.

| Event | Existing handling or evidence | Next check |
| --- | --- | --- |
| Scripted attack | The script dispatch journal already reconciles the shooting visibility decision against the host. | Keep the narrow hook. Exercise the existing script-dispatch regression when it changes. |
| Mission object activation | B_TECH flow box 288 (Remove_Fall_Kill) is a child of FLYIN_1 and calls SetVisibility on Latt_FallKIll_nshack. The two native command records point to 0x948ED0 and 0xA02620. The first resolves a scene object by name and calls 0x5A3C80. That helper sets or clears mask 0x202 in the object word at +0xB8 and can also toggle a per-object byte. The second handler uses a separate actor path. Collision effects still need runtime confirmation. | Trace the executing handler and target on both peers. Compare collision state and execution tick. If they diverge, reconcile the specific native operation using the epoch, sequence and stable object identity. |
| Mission completion | D_TECH calls CompleteLevel with door LEVEL_END. The game transition already uses host-authorized epochs in sync_epoch.zig. | Check that the native completion branch runs and that both peers load the destination. Preserve native progress and rewards. |

Native addresses above are specific to the game executable analyzed for this mod.
