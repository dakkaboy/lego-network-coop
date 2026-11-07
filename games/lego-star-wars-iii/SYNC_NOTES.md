# Synchronization notes

## Physical debris

The native spin functions at `71AB90` and `71AC10` use a separate random stream at `E5F498`. Physical effects now carry the host's input seed, native consumer, part name fingerprints and recipe. The client supplies that seed around the original native call, then restores its local visual stream. Each original function runs once. These choices belong to the existing geometry frame lifetime.

The native death handler `968D60` calls actor breakup `9689A0`, which can skip physical part creation when model flags `42` and `43` are both clear. Those flags depend on the local view. The branch at `968A94` consumes the host's native decision before continuing the original function. Falling deaths can also pass local visibility as the death handler's fourth argument and skip the call entirely. That argument's truth value is projected at its native comparison `968F14`, so the same original continuation also handles dependent death behavior. The actor gate journal retains allocation identity and order; no actor death or part constructor is replayed. Model visibility itself stays local.

Falling death has an earlier visibility input at `9C49B3`. A locally invisible model can bypass the native falling-animation delay, so matching only calls already inside the death handler is too late. This comparison now consumes the host's visibility operand before the original delay/height checks. The local model flags, action, timer and death function remain native. Wire 56 carries all three visibility decisions with distinct actor gate kinds.

Part launch direction is generated earlier than the private spin functions. `9059D0` calls native `966AF0`, which draws twice from `E637B4` through `78E450` and rotates a unit vector. In paired Defenders captures, the same native part, clock and breakup descriptor reached this generator with different seeds. Its input seed now belongs to the physical journal, keyed by the native part resource name, model and descriptor recipe. The bridge tail-calls the original generator once; it keeps the game's RNG advances. It does not substitute a generated velocity or alter the local visual RNG stream.

## Registered physical bodies

An AI-controlled vehicle can own a physical body independently of the character's model/body proxy. The native `FBDB3C` registry resolves its component through `9736C0`; the component's actor backlink, driver at `294` and body at driver offset `260` establish ownership. Wire 57/layout 43 carries this body's full transform separately from `SyncActorBody`.

Client correction uses native `A29570`, which copies the matrix and calls `A15380` to rebuild the solver center and quaternion, then refreshes the broadphase when attached. `A294A0` only copies the wrapper matrix and leaves the independent solver pose unchanged. A local fixture executing the original functions confirms that distinction and verifies that native linear and angular velocities survive the transform operation. Correction checks actor allocation and component/driver/body/dynamics ownership after the native call. It does not duplicate a simulation step or transport local pointers.

The body's velocities, forces, contact history and AI state still require paired source coverage; transporting the transform does not establish full deterministic physics.

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

## Breakup and body follow-up

The next candidate completed Ambush A and its native transition to B again with separate cameras. Nine B1 and 49 B2 damage records matched without duplicates. The client applied 336 native breakup launch seeds, including ten corrections, and 336 private spin seeds without journal faults. Reviewed frames retain the original HUD, visible characters and the host's green Yoda blade.

A subsequent B run destroyed both first-tank side guns and completed Yoda's native finisher on both peers; the mission counter reached one on both sides. It remained synchronized beyond 16,700 steps. This is partial B coverage, not completion of Ambush. Nine repository tests and a local fixture executing the original solver transform and integration functions pass.

The long Defenders test still exposed an NPC jump decision mismatch before model input. That case and the native AI attack cooldown source remain open; these changes do not claim to eliminate every `-21` failure.
