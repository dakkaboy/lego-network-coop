# Synchronization notes

## Physical debris

The native spin functions at `71AB90` and `71AC10` use a separate random stream at `E5F498`. Physical effects now carry the host's input seed, native consumer, part name fingerprints and recipe. The client supplies that seed around the original native call, then restores its local visual stream. Each original function runs once. These choices belong to the existing geometry frame lifetime.

## Section transitions

The native fresh-mission flag at `FC16B0` changes how the loader carries the selected party into the next section. Calling `8BD740` for a normal section exit sets that flag and can load a different party order on the client.

The host now publishes its native entry mode with the destination epoch. An established client uses the stock section queue at `9097E0` for a section exit. Initial joins, explicit reloads and fresh mission entries retain the mission entry path. Native party saving and selection remain in `9B8B50` and `9BE0E0`; the mod does not replace the roster.

## World updates and loading

The native cinematic comparison at `8888CD` admits the world update. Its input is journaled so both peers execute the same simulation step.

The later comparison at `8889EA` only advances `FB4A0C`, the timer used by the optional native loading indicator at `89A8E0`. Its outer guard uses the asynchronous preload key at `FB4A10`. That comparison stays native and local: requiring identical indicator calls caused false sync failures when one background load finished first.

Mission loading still has a peer readiness barrier. The host admits network steps only for the matching level and epoch after the client reports ready. A stale ready message from the previous epoch cannot release it.

## Verification, 7 November 2026

Two offscreen instances completed the Ambush A cave route: both coral objectives, gold and silver destruction, the initial B2 wave, EndBlow1, the native cinematic and Force-held B2 destruction of EndBlow2. Both then entered Ambush B with the same selected party and continued beyond 180 network steps. A host saber attack and client jump worked after the transition.

Nine B1 and 42 B2 damage records matched between peers without duplicates at the retained combat checkpoints. All 2,360 paired projectile constructor casts matched in the checked inputs and results. Reviewed frames retain the original HUD, separate views and the host's green Yoda blade, with no grey geometry in those frames.

Six repository tests pass, including transition publication and protocol rejection. Local fixtures also checked native hook register, floating-point and lifetime behavior against the installed executable.

Ambush B was not completed in this run. Earlier intermittent model, item-range and projectile failures did not recur; their absence here does not establish a fix for every case. Internet latency and two-PC play were not tested.

The follow-up run checked direct Ambush B entry, Geonosian Arena and Defenders of the Peace for roughly 6,000 steps each, with normal attack, jump and movement inputs. All three stayed synchronized. The host waited at network step zero while the client finished loading. In Arena, 32 paired physical detail creations matched in the checked transforms, launch velocities and recipes; the client applied 32 native spin choices, including 31 seed corrections, without a physics journal failure. These checks cover entry and short play, not mission completion.
