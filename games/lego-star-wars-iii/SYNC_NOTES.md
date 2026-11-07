# Synchronization notes

## Physical debris

The native spin functions at `71AB90` and `71AC10` use a separate random stream at `E5F498`. Physical effects now carry the host's input seed, native consumer, part name fingerprints and recipe. The client supplies that seed around the original native call, then restores its local visual stream. Each original function runs once. These choices belong to the existing geometry frame lifetime.

## Section transitions

The native fresh-mission flag at `FC16B0` changes how the loader carries the selected party into the next section. Calling `8BD740` for a normal section exit sets that flag and can load a different party order on the client.

The host now publishes its native entry mode with the destination epoch. An established client uses the stock section queue at `9097E0` for a section exit. Initial joins, explicit reloads and fresh mission entries retain the mission entry path. Native party saving and selection remain in `9B8B50` and `9BE0E0`; the mod does not replace the roster.

## Verification, 7 November 2026

Two offscreen instances completed the Ambush A cave route: both coral objectives, gold and silver destruction, the initial B2 wave, EndBlow1, the native cinematic and Force-held B2 destruction of EndBlow2. Both then entered Ambush B with the same selected party and continued beyond 180 network steps. A host saber attack and client jump worked after the transition.

Nine B1 and 42 B2 damage records matched between peers without duplicates at the retained combat checkpoints. All 2,360 paired projectile constructor casts matched in the checked inputs and results. Reviewed frames retain the original HUD, separate views and the host's green Yoda blade, with no grey geometry in those frames.

Six repository tests pass, including transition publication and protocol rejection. Local fixtures also checked native hook register, floating-point and lifetime behavior against the installed executable.

Ambush B was not completed in this run. Earlier intermittent model, item-range and projectile failures did not recur; their absence here does not establish a fix for every case. Internet latency and two-PC play were not tested.
