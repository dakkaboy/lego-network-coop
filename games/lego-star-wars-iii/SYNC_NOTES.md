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

## AI and section input follow-up

The next audit traced the Defenders jump mismatch upstream of avoidance `70C1E0`: the native move goal at `710E70` came from the actor-backed RTS competitor, whose `541180` inputs already differed. Supplying both RNG inputs, twelve timers and delta leaves native strategic goal selection and movement in charge. The uninstrumented follow-up stayed synchronized beyond 30,000 steps with movement, jump and fall inputs. All 1,332 paired native/strategic goal samples matched, including 119 for the previously failing NPC. This is partial mission coverage; other `-21` cases remain possible.

The AI attack source now supplies the native `899ED0` task's timer and RNG input before its update, and the visibility operand consumed at `89A093`. Original cooldown draws still execute once; the model's local visibility flag is unchanged.

A full Ambush follow-up exposed an earlier world-admission return before `8888CD`. Native `888750` can return through `7E4800(0xF)` after its preflight predicates. The converged destinations `888889` and `888897` now journal one logical decision. A peer follows the host decision, executes either the original transition or `57D420` once, and resumes its native continuation. Root phase fields and asynchronous loading indicators are not copied.

That candidate completed Ambush A and the native transition to B. Eight B1 and 68 B2 damage keys matched without duplicates. Neither peer needed an early-return correction in that run; asymmetric decisions are covered by production bridge and journal fixtures.

The first B frame exposed an input-device lifetime error. Native section loading retained the controller while replacing its actor allocation. The mod had retired its actor assignment and rejected its retained synthetic device despite a known native NULL origin. Original device provenance is now keyed by LAN session independently of actor lifetime. Unknown origins, cross-slot devices and origins from another session remain rejected. The current native controller and actor allocation still determine the input consumer. No hardware device is guessed from a player number.

Another native A to B/B check is running. Fourteen repository tests pass, covering wire validation, native bridges, journal lifecycle and device provenance. A private fixture exercised 6,000 cases through the exact production input-assignment functions, with allocation, Tag and LAN context stubs.

Wire64/protocol63 adds the native Force candidate visibility operand at7F8177. The existing actor-gate journal now carries the caster allocation, query mode and native clock with each candidate allocation. It changes only which original branch consumes the visibility input; model42 and native hint/action state are not written. All16CTests pass, including4500 native bridge comparisons and malformed context/wire regressions. The full offscreen paired Ambush route is running; previous -21/-16 cases remain open until exercised successfully.

Wire64 paired runtime applied148928 Force candidate operands with28145 visibility corrections andzero Force failures through8600 A steps. The route stopped at a different actor-gate ordering mismatch, so full Ambush and global -21 elimination remain unverified. Three B1 HP-loss keys matched with no duplicates; no B2 combat was reached.
Wire65/protocol64 adds a separate Attack base-input source at899ED0 before921140. It supplies the two native RNG states, elapsed/cooldown timers and delta under actor/task/callback-class/clock identity. The original late899F37 source remains in place after the callback, preserving its scope lifetime and post-callback context. The entry replay contains only the overwritten native FLD/MOV; no extra base or actor update is invoked.4500 native entry-bridge comparisons and wire-bound regressions pass. If no brain exists before the base callback, this source does not bind that path; callbacks that create a brain still need source coverage. Paired full-game verification is running.

Wire66/protocol65 covers the positions read by the native Force distance calculation at `7F8310`. Candidate visibility alone did not guarantee the same selection: one paired run consumed all mode-one visibility entries, but the client selected B1 while the host continued to mode two. Both SpellIt queries returned NULL in that case.

The new source binds both native `F28` point arguments to the caster/candidate allocations, query mode and clock. It substitutes scratch argument arrays for one original `574EC0` call. It does not write actor positions, targets, hints or actions. Native eligibility, range, facing and final selection remain active. The frame and gate capacities are unchanged; malformed references, nonfinite points, reserved fields and union tails are rejected. All 18 repository tests pass, including 5,000 native bridge cases. A paired offscreen Ambush run is in progress; this is not yet a verified fix for every selection mismatch.

Two follow-ups destroyed the first gold target on both peers. The first applied 16,682 geometry inputs with 749 corrections before a constructor-time projectile failure. The second stopped at another mode-one/mode-two selection mismatch despite consuming all geometry inputs. Geometry alone does not close the selection issue.

Wire68/protocol67 adds native caster inputs to `7DA8E0`, the SpellIt interaction query that runs before Force selection. An earlier paired trace showed the client skipping Force acquisition while the host entered it; the client had already filled its secondary hint with a SpellIt target. The examined animation-batch inputs, physical transforms, velocities and cached actor-facing inputs agreed.

The source captures actor position, the model heading actually consumed by the query, and its initial nearest-distance limit. The client supplies them through query-local operands and one scratch position argument to the original `574F60` calculation. It does not copy target/hint/action outputs or write actor/model transforms. Manager identity comes from the game's current world registry and the registered SpellIt provider slot; the actor allocation, native clock, manager class and original caller must match. Query-frame scopes preserve nested inputs, reject expired leases and stop on bounded-store exhaustion.

All 19 repository tests pass, including 30,000 ASM bridge cases. A private fixture using the extracted production prepare/gate/scope functions passed 2012 cases with native-global storage relocated into the fixture and actor/cohort bindings stubbed. It covers wrong owners/classes/callers/clocks, cancellation, allocation reuse, nested frames and scope capacity. The ordinary release DLL is undergoing a paired offscreen Ambush run. Full mission and projectile-constructor verification remain open.

The first Wire68 release run destroyed gold on both sides but stopped at MODEL -21 before completing the left objective. At native clock3495, one B1 began action0 on the host while the client still had actionFFFF; both matched through3494. The SpellIt source applied5517 queries with0 corrections and0 failures in this run, so this run does not demonstrate a corrected SpellIt boundary. The native Force geometry source applied9093 queries with291 corrections and0 failures. Frames, actor pools, input records and native-source exports were retained locally. The verified Wire52 installation was restored after cleanup; Wire68 is not a released or installed fix.

Wire69/protocol68 captures the native Character velocity input at `9C43D1 -> A08380`, before collision integration. The paired source trace showed slightly different XZ velocities at this setter and a later native support/ground difference. The source binds actor allocation, current model/proxy ownership, body class and clock, then supplies a scratch vector to one original native setter call. It preserves the caller vector, actor state, native return registers and ordinary collision/action decisions.

All20 tests pass, including5000 actual bridge cases;3008 private cases using the actual helper/gate bodies passed with only the native clock storage relocated. A separate ABI/lifetime review found no concrete defect. Native support-collider transforms also differed in the failing trace, so this change is not claimed to close the collision source. An ordinary paired Ambush run is underway; no release or permanent installation yet.

Wire70/protocol69 adds the native candidate translation consumed by SpellIt at `7DAA69`. Authored resource/area/POI provenance and native call context qualify the scratch matrix input. The first paired run destroyed gold on both peers at clock2949 but stopped at cadence -15 at sequence2978. Decoding the authoritative frame retained by the client proves that it consumed Yoda's query10 at gate13, then missed the first node12 at gate14. The earlier interpretation that the whole query had been omitted was incorrect. Host node records108/client applications0 include the host's two-step lead at failure. The remaining admission difference is inside the native Gizmo filters or node iteration; frozen ground flags from different clocks do not establish its cause.

Review found and fixed resource-cache ambiguity: a second resource with the same portable name could bypass the cache check. The reviewed build reads source metadata afresh and revalidates the native resource witness, classes, table and allocation after consuming a source record. Twenty tests,36,000 bridge cases,3012 private actual-source cases and16 mutation cases pass. A new passive comparison follows free rigid bodies through native force and integration phases. No hit, contact, ground or action result is copied to bypass a mismatch. The stable Wire52 installation was restored after the failed first run; the reviewed run remains unpublished.

Wire71/protocol70 adds the Character rest-history input. Twenty repository tests and3026 private actual-helper/native-consumer cases pass, including the real PE implementations of A08380, A15B50 and A15C60. The observed0/6 counter case changes from native AL0/1 to0/0 with counters1/1 while support and contact lists remain untouched. The paired run destroyed gold on both peers at20087, but stopped at20130 inside the SpellIt query: query10 at gate16 was consumed, node12 at17 was missing. This is not a complete gameplay fix and remains uninstalled and unpublished.

The native source of an earlier six-lane rigid velocity change is840660, the SpellIt idle piece hop. It sets linearY=1, scales XZ by1.25 and adds1 to each angular lane through8B5CD0/8B5E00. That writer did not run before the first-node admission failure in Wire71R2. Its timer218, selected piece21C, piece listA8 and573100 engine RNG inputs remain a separate source to align.

Wire72/protocol71 separates native destructible recovery from repeated rendering.
The original recovery function runs after each observed native world update;
rendering keeps its visual callback without advancing the gameplay timer.
No hit result, destruction flag, event16 dispatch or actor action is replayed.
Twenty repository tests pass. Private fixtures prove render-count dependence
in the native routine and exercise the actual adapter's cancellation, source
binding and calling convention. Paired gameplay verification remains required;
this candidate is not a release or a permanent installation.

Wire72R1 ran native object recovery with zero binding failures despite different
render counts on the two peers. Gold completed, but the client later stopped
at cadence -15. The first idle-piece RNG difference preceded piece selection.
At a later common tick, both peers selected the same motionless piece and
reported receiver enabled, while only the host had receiver183 bit4 set.

Wire73/protocol72 carries native world inputs in the physics journal. Layout45
adds typed source and piece keys with strict seed/query validation. Native
object recovery remains in the simulation path. Twenty repository tests pass,
including codec roundtrips and rejection of malformed world inputs. Source
binding and native calling-convention fixtures accompany the paired test.
Full Ambush and campaign verification remain open.


Reviewed Wire73R2 completed Ambush A through the native A-to-B transition in
two hidden instances without Frida. B1 damage records matched 8/8 and B2 81/81,
with no duplicate keys. Ambush B stopped at sequence1141: the host entered
Attack's AimBase input for NPC12 while the client proceeded to character
motion. This is not a complete Ambush pass. Stable Wire52 was restored.

Wire74/protocol73 adds queued native renderer-retirement requests. Layout46
appends a bounded request array; the former reserved header word stores its
count, preserving existing array offsets. Requests drain once before native
world dispatch and remain part of the existing cancellation and source
provenance checks. A direct-B gameplay run is in progress; no permanent
installation or publication has been made.


Wire74 completed the first Ambush B tank on both peers. Four renderer requests
ran once on each side without provenance failures. The second-tank approach
later stopped at a missing projectile. Paired native module records identify
an engine-RNG difference before the original burst/cooldown computation.

Wire75/protocol74 journals that registered module's entry seed in the existing
physics-source array; layout46 and the frame capacity are unchanged. The
original native update derives its own counters, timers, targeting and shots.
The private actual-source fixture passes7193 checks and reproduces the exact
measured fork using native code. Twenty repository tests pass. Clean paired
Ambush B gameplay remains incomplete; the failed Wire74 build was not published
or installed permanently.

Wire75 completed the first tank in a clean direct-B run with zero module-source
failures and 913 client seed corrections. A subsequent clean, natural A-to-B run
completed A with B1 damage 9/9 and B2 57/57, with no duplicate keys. The original
host green blade, HUD and separate views were reviewed in paired captures.
B stopped at sequence807: the client attempted NPC12 AimBase while the host's
next source was NPC4 character motion. Module RNG, physics, model and SpellIt
reported no first fault. Native AI target publication and task selection remain
under investigation. The candidate is not ready to publish; stable Wire52 was
restored after both tests.

Wire76 supplies the first native span's time and seeds through loading control
state. The first effects update now received identical delta and RNG values in
the paired direct-B run. Both first-tank counters reached1; a controlled stop at
sequence5704 retained sync2 and no source faults. This does not cover all of B.

Wire77/protocol76 adds ordered bootstrap receipts and a host seal before normal
SyncFrame traffic. It includes native phaseD and derives the World binding from
the level catalog. Twenty-one tests pass, including serial and receipt lifecycle
checks. The full A-to-B run is in progress. Native Tick-loop and admission
coverage remains under review. Neither candidate has been published or installed
permanently; completed tests restore the verified Wire52 DLL pair.

Wire77 reached the native ending cutscene after both corals, gold, silver and
the B2 wave. B1 damage matched8/8 and B2 damage89/89 without duplicate keys.
Both peers then stopped at sequence19954 in native phaseD: sealed bootstrap
readiness required E and prevented the scene from advancing. The retained
cutscene descriptor and instance were active on both peers.

Wire78/protocol77 keeps sealed D on the normal SyncFrame path. Its first-world
source can also be acquired at a qualified inner Tick boundary when the native
loop reaches D inside an already-running outer span. Source application remains
once per span; no native update is duplicated. Twenty-one tests and the full
DLL build pass. A natural A-to-B run is pending; no gameplay pass or publication
is claimed for Wire78 yet.

Wire79's qualified first-world handoff passed on both peers at native clock0,
with one World call and matching E completion/seal. The cave ending exposed an
additional B-to-D path inside an unbound outer span. Both peers stopped at16938;
native B1/B2 damage matched9/9 and54/54 without duplicates before that stop.

Wire80/protocol79 admits the established A/B cutscene phases through the normal
SyncFrame cohort. It retains ordered bootstrap handling before seal and fails
fast on an unexpected sealed unbound Tick. Twenty-one tests and the full build
pass. Its natural paired route is running; there is no full-mission pass yet.

Wire85 canonicalizes the native audio playback-time query used by cutscenes.
The original getter still runs once per peer; native scene integration and
retirement consume the host's qualified input. Two paired natural A-to-B routes
completed the previously failing ending cinematic. Rare extra death-breakup
and AI Attack updates remain separate unresolved sources.

Wire86 adds bilateral readiness before the first native World and subsequent
bootstrap steps, including fresh epochs on area changes. Readiness uses the
native loading phase and worker queue, without game pause or a fixed delay.
The host waited at clock0 while its client loaded; both then completed one
World call and matching seals. A-to-B loading and the first B tank also passed.
The controlled run ended at sequences19353/19352 with both peers synchronized.
The private second-tank route was incorrect: Thire's cinematic head item is
expected story behavior. The gold guns require fire from a B2 held by Yoda.
No inventory restoration change is needed.
Wire87 checks completed receipts before the next readiness wait and is being
verified separately. No full-mission pass or release is claimed for these builds.

Candidate88 completed native Ambush B through all three tanks, all five final
Droidekas and the Outro8-to-Status9 transition on both peers. At Status the
client could not acknowledge the profile because readiness required player0;
native Status deliberately creates no party. The resulting wait eventually
hit the300-second preload timeout. This is separate from projectile4 and the
previous rare extra animation/death updates.

Candidate89 separates bound-profile storage from actor availability and admits
native non-Titles scenes whose definition does not require a party and whose
eight party slots are null. Native loading jobs, epoch/World identity, profile
authority, receipts and shared bootstrap completion are still checked. Gameplay
guards retain their existing death/respawn behavior. Empty actor collection
rejects a malformed raw count rather than treating it as a legitimate zero.

Twenty-two tests and the full DLL build pass. The paired direct Status check
completed one actual native World and sealed serial1 on each peer, followed
by over9000 shared steps. A subsequent private UI-input address error invalidates
only the later part of that run; it was closed and the verified DLL pair restored.
The clean Continue/next-scene and gameplay regression checks remain pending.


The subsequent native Continue route passed Status (9) -> StoryB (11) -> Hub (3) after
separating the initial profile snapshot from live progression and allowing
matching bootstrap receipts in native phases D/E. Hub population captures Tag
operands before native retirement and identifies new actors from their actual
Hub owner records. Authored POI ancestry and optional library World ownership
are resolved from native metadata. The paired Hub check now displays textured
rooms, visible actors, the original HUD and separate camera viewpoints, and
accepts ordinary movement/jump input without a synchronization fault.

Protocol 93 also uses these common source witnesses for physical SpellIt pieces.
The full DLL and 26 CTests pass; the optimized actual-source fixtures add 2027
engine and 2039 Hop checks. Full Ambush regression of this combined build is
still running. No all-mission or two-PC coverage is implied.


The combined protocol 93 build completed Ambush A and its native exit into B.
Observed B1 and B2 damage transitions matched 9/9 and 31/31 across peers, with no
duplicate keys in those intervals. Early B then exposed a native projectile
removal one step earlier on the client. A targeted source comparison narrowed
this to the BlowUp manager and then to a birth-time scene-collision policy bit.

Protocol 94 synchronizes the native scripted Shoot visibility input before
forced aim and firing policy are produced. The bridge preserves the separate
rendering state and the native Offscreen fallback. Engine/bridge fixtures pass
114101 checks, including 18000 ABI/FX cases; the actual cadence adapter passes
4073 checks. The full DLL and 26 CTests pass. Clean paired runtime validation is
in progress; no successful full-mission result or release is claimed yet.


Protocol 95 publication (0.0.6 alpha): the user requested release of the current build before the remaining synchronization work. The latest combined build passes 27 CTests and the native ABI fixtures. A paired session completed natural Ambush A to B, three tanks and one blue Droideka without a sync fault through native B clock39050; full B ending was not completed. A separate run still produced a client-only action114 expiration hit and extra death breakup at A clock1556. Early B script selection can also diverge. Those issues remain open; publication does not imply full-mission or two-PC coverage.

2026-11-11: native combat inputs and clocks (protocol 125)

The client could discard an actor binding before its final native weapon command,
or miss an actor created inside the current tick. Bindings now retain pending
command references and resolve new actors from the game's producer, serial and
character identity. Native queued weapon bytes are shared at their original
consumer; Fire and character updates are not called again.

Module pool generations are local allocation witnesses. Peer identity uses a
unique live authored module ID; local generation checks still reject reuse.
GizmoTurret inputs use the native world/manager registry and authored gizmo
membership, with the actual game RNG streams and native countdown.

SpellIt consumes the native call delta, countdown, RNG state, selected piece
working position and last-attempt timestamp. Resource and POI identity binds the
piece; coordinates are values, never lookup keys. Native elapsed time is also
shared during preload and before every coherent world dispatch. Original native
functions perform their calculations and side effects once.

29 CTests pass, including actual x86 bridges, x87/MXCSR/EFLAGS preservation,
transactional input rejection, allocation reuse and native time replay. Exact
DLL161 completed the short CWHub -> DuelOfTheDroids_A -> CWHub -> HiddenEnemy_A
entry/action route in two offscreen instances. Run ledger: hub-native-time161.
Screens confirm native HUD, distinct views, visible players and textured geometry.
This covers mission entry and short actions, not complete missions or two PCs.
Space vehicle assignment and extended RTS/campaign regression remain unqualified.

## Native piece selection inputs (wire 126)

SpellIt can choose a new piece at three sites inside its native update: 8406A7,
840790 and 840B93. The last two run after other native effects. Sharing the engine
seed only at update entry did not cover those consumers. Each site now supplies
the actual EA178C seed immediately before the original 7DA280 selector. Native
gizmo identity, piece count and an eligibility fingerprint of the game's linked
list must match. Eligibility follows the selector's own state != 3 predicate.
No piece pointer, piece state, NPC action or actor flag is projected by this fix.
The native selector runs once and retains its own RNG advance.

29 CTests pass, including wire round trips, stale source/cohort rejection without
seed writes, all three actual call-site wrappers, original-once behavior and live
x87 state. Exact DLL163 completed CWHub actions with both players through
947/946, then ShadowOfMalevolence_A in the same session through 652/660 with
both-role firing. Source-data level selection used the native loader; this does
not certify a mission-map UI route or full mission completion. Frames show ships,
textured geometry, stock HUD and different views. Ledger: hub-selection163.

The game selected roaming NPC195 on both peers, matching the earlier -21 case.
Neither -21 nor -16 recurred. Hardware write observation found no bit400 change
in Hub; the first changes on both sides were normal native destruction at unload
clock982. This was regression evidence, not proof that every -21 source was closed.
Later captures established that model reason9 also covers other context fields:
it cannot by itself identify a changed actor flag.

## Native physical piece inputs (wire 127)

The extended Hub route reproduced -21 with the same 0x400 bit on both peers.
NPC188 started action0 at native clock769 on both. The host returned to FFFF at
785 and the client at786 through the same native 8C5A4A call. Their action timer
was bit-identical; the ground-contact predicate differed. Hardware observations
at A381E0/A15FD0/A15D20 then found matching character physics inputs and numeric
modes, but different transforms of nearby physical build pieces. The game named
those bodies BridgeBuild_09 and BridgeBuild_010. Those names are evidence only;
production code contains no level or piece-name filter.

Before each original SpellIt update, physical pieces are now bound through the
native linked list, resource/POI identity and live model -> receiver -> body ->
dynamics links. Two typed inputs carry the native basis, position, linear
velocity and angular velocity. Both peers feed the authoritative inputs through
A29570, 8B5CD0 and 8B5E00 before the original update. The same native normalization
and motion-cache updates must run on both even if their input bytes already match.
Body/name replacement or a retired
frame cancels further writes. Native calls receive the caller's original numeric
environment, with helper state and LastError preserved separately. The original
update still runs once; NPC action, grounded and 0x400 flags are not projected.

Bindings are cached only within the same release, epoch and native source graph;
current links and body names are revalidated on use. Network keys contain native
source, resource, POI and body identity. Coordinates are payload values. Frame
layout 50 and its 3882064-byte capacity remain unchanged.

30 CTests pass, including native setter ABI, native/helper x87 precision,
mid-call lease retirement, rebound bodies, rejected batch writes and both wire
records. Candidate166 passed the two-instance offscreen hub-physical166 run: Hub attacks/jumps through sequence 945, then native catalog loading of ShadowOfMalevolence_A in the same session and firing by both players through sequence 639/645. Both terminal states remained sync=2, reject=0, with no recorded native fault. A hardware-breakpoint sample at the original SpellIt update entry compared 240 physical body states with bit-identical matrices and velocities. Later character-contact samples still contain small floating-point differences; this is not a claim of deterministic simulation everywhere. Saved flight frames show separate views, original HUD and textured geometry. This qualifies the tested short route, not full mission completion or separate-PC play.

Extended two-instance check (2026-11-12, hub-flight166-extended): both players
moved and attacked in CWHub, then loaded ShadowOfMalevolence_A in the same
session. Four cycles of steering and firing by each player, followed by neutral
simulation, reached flight sequence 2241/2252; terminal states were sync=2 and
reject=0 at 2267/2272. All 22 sampled native mission variables matched. No
sampled mission-variable progress occurred, so this is combat/steering coverage,
not objective or mission-completion coverage. Final frames show separate views,
original HUD, ships and textured geometry. The owned offscreen pair was closed
and installed candidate166's hash was verified afterward.

A read-only actor rigid-body sampler exposed a host-only tooling mistake: host
entity metadata is published differently from client bindings. That sample has
no comparable host records and proves nothing about rigid-body equality. The
sampler was corrected to use the authoritative roster for the next check; the
client-only rigid-transform restoration remains an audit candidate, not a
reproduced failure. A diagnostic-only follow-up reports the first body key word
correctly for physics kinds 12/13; the installed gameplay DLL remains the exact
runtime-qualified candidate166.

Native flight objectives and reentry qualification (2026-11-12): candidate166
passed the offscreen two-instance hub-flight-objectives166 route. P2 used the
original ring states to move from the upper flight path to the lower one while
P1 stayed above. Native landing transferred P2 from the vehicle to character184;
LandingZoneA_Docked became1 on both peers. The lower generator lever completed
with state6 and flags0x2180 on both. Reboarding and pickup then used normal input:
t_pup2 loaded native torpedo ammo from0 to1 on each peer. Goal positions, radii,
capabilities and weapon state were read from the game's live registries and
resource definitions; no game state or ammunition was forced.

The same pair subsequently returned to CWHub and reentered
ShadowOfMalevolence_A. Session1 survived, with matching epochs2->3->4. Both
players accepted input after each load, final native variables matched, and the
flight reentry checkpoints reached sequence395/401 with sync=2 and reject=0.
Saved final frames show textured geometry, vehicles, separate cameras and the
original HUD. The owned pair closed after verification; installed candidate166
retained SHA256 4457E04A1282FFE8FC6630EC9A38E034D51A6B7A471F0182E3570E1EDD6C1405.

The first torpedo shot remains unqualified: ammo was0 again at shot preflight,
so the driver stopped before firing. Both peers agreed. Native code has several
legitimate ammo drop/reset paths, including some damage-threshold and transport
transitions; the writer responsible for this particular loss was not captured.
No torpedo hit, completed flight mission or campaign-wide readiness is claimed.
No gameplay source change was justified by this run. Several failed approach
attempts were harness issues (vehicle inertia, a released ring button, using a
visual lever offset, and treating human transfer as a missing vehicle); their
original traces were retained alongside the successful native-state evidence.

Renderer numeric-state boundaries (candidate167, 2026-11-12): added Present,
Reset and per-view capture work now preserves FX state and LastError. Incoming
state is restored before the original Present/Reset call; original outgoing
state survives post-Reset helpers and frame capture. The wrapper does not force
a CW constant or erase numeric effects produced by the original game call.

The source-extracted x86 ABI fixture passed four rounding modes, helper-induced
CW/MXCSR/LastError changes, distinct native incoming/outgoing modes, successful
and failed Reset, a foreign device, and three capture-helper return paths.
All30 CTests pass. The two offscreen hub-flight-render167 instances passed native
ring traversal, PadA human transfer, same-session Hub return and flight reentry.
Both landing model-failure records remained zero, and session1 survived reentry.
Final host/client frames were visually reviewed; the owned pair closed normally.
The exact qualified DLL SHA256 is
282B4F92FC9A87D7DFFCC3DB055A873C40373FB3C9C206169DD0498DA96A4E9E.

The preceding instrumented166 run failed model context validation only on x87
precision (33F versus3F) for the attached pilot; NPC flags and actions matched.
Its new watchpoint tool unnecessarily repinned the host1276 times, with zero
actual write exceptions. A clean166 control subsequently passed the same native
landing. The renderer boundaries were a concrete preservation gap, but the
specific writer behind that earlier precision divergence remains unproven.
This qualification does not establish that every rare -21 or campaign mission
is fixed. Native torpedo hit progression remains a separate pending check.
