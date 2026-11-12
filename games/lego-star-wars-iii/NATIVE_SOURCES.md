# Native simulation sources

| Source | Native consumer | Current handling |
| --- | --- | --- |
| Game random state, `E637B4` | Inlined native random draws | Host state at frame admission and native shot/Tag contexts |
| Engine random state, `EA178C` | `573100`, `573160` | Host state at frame admission and native shot/Tag contexts |
| Physical effect random state, `E5F498` | `71AB90`, `71AC10` | Input seed per matching physical source; original native call executes once |
| Character breakup visibility | `9689A0` branch at `968A94`, then `9059D0` | Host's native visibility decision, keyed by actor allocation in the coherent actor gate journal |
| Death handler breakup argument | `968D60` comparison at `968F14` | Host's native fourth-argument truth value before the original comparison and dependent native continuations |
| Falling death visibility | `9C3230` comparison at `9C49B3` | Host's native model visibility operand before the original falling-animation delay and death decision |
| Physical part launch direction | `905F33` call to `966AF0`, native draws in `78E450` | Game RNG input seed keyed by native part resource, model and breakup recipe; original generator runs once and retains its native advances |
| Registered module spawn delays | Native module registry and `483A90` | Initial delays and native choices keyed by registered producer |
| RTS spawn timers | `50AFC0`, `55E2C0` | Initial team timers and native random cooldown choices |
| Character collision body | Native model/body links, `A294C0`, `A08380`, `A083E0` | Native body move/velocity plus the independent solver height cache |
| Registered vehicle body | `FBDB3C` registry, `9736C0`, component/driver/body links | Full transform through native `A29570` / `A15380`, including solver center and quaternion |
| Force target acquisition | `7F80E0`, candidate operand `7F8177` | Host candidate visibility input, bound to candidate/caster allocations, query mode and native clock; original selection runs once and local render visibility remains local. 8600 paired A steps exercised148928 inputs/28145 corrections without a Force-source failure; full mission verification remains open. |
| Force target distance | `7F8310` call to `574EC0` | Caster and candidate render positions sampled at the native consumer, bound to their allocations, query mode and clock. The native function receives scratch arguments and computes the distance/vector once; actor positions and target/action state remain untouched. Runtime verification is pending. |
| SpellIt interaction query | `7DA941`, heading reads `7DA948` / `7DA967`, height `7DAA7C`, distance call `7DAAEB` | Native caster position, model heading and initial distance limit, keyed by actor allocation, clock, caller and the current world's registered SpellIt group. Query-local operands and scratch arguments preserve native target selection and local actor/model data. Runtime verification is pending. |
| AI Attack base callback | `899ED0` before `921140` | Both native RNG inputs, elapsed/cooldown and delta before the original base callback; late AIM input still binds the post-callback task. Pre-callback brain creation remains uncovered. |
| AI attack task | `899ED0`, source `899F37`, visibility operand `89A093` | Native task timer, engine RNG and visibility decision, keyed by actor/target allocations, native clock and task recipe |
| AI primary opponent | `9DCE70`, sweep completion at `9DDA14` / `9DD0F4`, candidate read at `9DDC19` | Both peers publish on the host's native sweep boundary. An unfinished sweep carries its native cursor. The stock publisher still validates each candidate and updates the cache from the native target, distance and flag. |
| RTS actor planning | `541180` | Both RNG inputs, twelve native planning timers and delta; owner verified through competitor/actor backlinks |
| World admission | `888750` destinations `888889` / `888897` and comparison `8888CD` | Matching host early-exit decision and cinematic operand before original native continuations |
| Mission/section entry mode | `FC16B0`, `8BD740`, `9097E0` | Native host entry intent and original loader path |

The preload indicator timer (`FB4A0C`) and background I/O state stay local. Both machines keep processing native loading while network gameplay waits for readiness.

## Remaining source work

- Physical emitter producers `742800` and `743580` choose emission position, launch velocity, model and lifetime before the already covered spin functions. Their private random inputs and emission timing still need a paired physical emission case.
- Particle scheduling and generation also use `E5F4DC`. Identify any consumers that feed collision or gameplay before extending the coherent journal to them.
- `678AB0` advances seeds embedded in native nodes at offset `1C`. Their owner identity and effect on simulation remain unverified.
- `740B10` also calls the CRT generator. Trace its consumers before treating that draw as shared simulation input.
- RTS competitors without an actor owner do not yet have a cross-peer binding. Their native planning state remains local.
- Full Ambush B completion and the earlier extra unowned projectile birth through `44E460` remain unverified with the new AI input sources.

Local pointers, actor pool order and coordinates are not cross-peer source identities. New bindings need the game's authored or registered owner and the native consumer context.

## Native SpellIt node identity

The query's candidate transform is read at `7DAA69`, before the height, range and facing filters. A paired passive capture after silver breakup had 36,621 matching callbacks and 6,167 differing matrices over the common interval. The actor-side query source does not cover these candidate translations.

Wire70/protocol69 supplies only the translation in the query's temporary matrix. Its authored key uses the native LEDResource registry at `F9DD10`: entry `4C` owns the scene, `34` holds its filename, and `40` its logical name (`45CF20` is a pure name getter). The container at `54` links to its area at `C`, with the reciprocal area `22E4` link checked. The native area name, source filename and logical name qualify the resource. The receiver's POI must belong to its native `6F8 -> 68/6C` count/table with stride `E0` and point back through `D4`. The authored ordinal/name, receiver/component class, caster allocation, clock and query order qualify each input. A child scene may use its documented `734` root only when they share the same native runtime table.

No native transform callback is repeated, and the hook writes no receiver, rigid body, target, action or filter result. Ambiguous or changed bindings fail the frame. The build and 20 tests pass; the two-instance Ambush check is pending. Free rigid-body integration and thrown-weapon trajectory sources remain open.

## Native emitter identity

`6740A0` dispatches a native effect node through `744CB0` and `743580`. The node carries its template, count, transform and scale. `71BC40` can allocate a scaled copy in the native template table at `FAFCFC` (192 entries, stride `1BC`). Such a copy retains its root template at `190` and scale at `18C`; its generated name includes a local allocation index. That suffix and the table index must not be used as cross-peer identity. The authored root name and native owner are the useful sources.

`FAFCF8` is the emitter clock. Its wrap function `71ACA0` subtracts 800 from the clock and the active native stream/template timestamps together. It is not a general clock setter. No emitter-clock or upstream RNG projection has been added without a paired physical emission case.
# Character rest history

The input at `9C43D1` also carries the native Character `WORD+C8` rest counter.
`A15C60` uses it with the previous support and contact list to decide whether
to skip the contact solver after six qualifying quiet updates.
The counter is read from the qualified model `+38` body and applied before the
original velocity setter. Body class, clock, allocation and backlink are
rechecked after resolving the frame. The constructor leaves this word
uninitialized until the native no-support path resets it, so the wire accepts
the complete 16-bit range rather than assuming every pre-update value is 0вЂ“6.
The solver, support selection, grounded state and actions still execute locally.
This covers the observed 0/6 rest-history difference, but does not establish
that the separate dynamic-collider and thrown-weapon differences are fixed.

# Destructible object recovery

`GizmoBlowUpManager::virtual+44` (`85C870`) calls `859240` and writes its return
value to the object's `BYTE+EC`. This render callback advances the recovery
timer at `F0+4` using `FB4B74`. Repeating a render therefore advances gameplay
even when no new world step ran. A private fixture with the native routine
confirmed that different render counts can change the tick at which the same
damage sequence destroys an object.

The network adapter observes the real `virtual+40` update (`87C930`) and its
delta. After the corresponding `887AC0` world step completes, it runs the
original recovery routine once, using the original eligibility conditions.
Render callbacks retain the native visual calculation with zero elapsed time
and recovery disabled. Offline calls retain their original arguments.

The source is the game's world/container backlink, provider registry slot and
manager list. The adapter revalidates the cohort, manager, object membership,
model, recipe and recovery provider before writing the native return value.
It stores no cross-level object pointers and adds no mission-specific table.

# SpellIt idle-piece inputs

The idle update `840660` chooses a piece through `7DA280`, using the native
engine RNG at `EA178C`. Its hop predicate consumes `7AB040` and the model
receiver's `virtual+1C`. `7AB040` first requires receiver `183 & 4`; this can
differ between separate views while both receivers report enabled.

The adapter supplies the host's native RNG state before the original update,
then retains the original stream advances. It supplies the two native query
values at their original consumers. The update, piece choice, timer reset,
linear and angular velocity setters still run through the game's functions.
Local rendering retains its own receiver flags.

The root key uses the native world name, object name, class and manager ordinal.
The piece key adds its resource filename/logical name/source area, POI name
and ordinal, receiver class and native piece ordinal. A cloned model can be
traced through its native `+48` source model to the authored resource record.
The local witness checks the `B4` entity list, `A8` piece list, `FC` owner and
the native adapter pairs at `owner+84`. Resolve and revalidation read fresh
metadata within the current frame lease.


## Projectile renderer retirement

`BoltsManager::virtual+2C` (`85B630`) can retire a tracked projectile through
`85BA1F -> 846460`. Its unseen-flight timer depends on eligible render calls.
In the retained R9 case, the client ran this removal one native clock before
the host and then received an authoritative state for the retired object.

The adapter now defers this caller's request and executes the original native
removal once at the beginning of the next shared DISPATCH. The request carries
the projectile birth ID and native flags/effects/caller. Local instance,
resource, manager and session/epoch/release provenance are checked again before
execution. Native AL0 remains a real veto; tracking changes only on native AL1.
Ordinary collision/expiry callers retain their original timing. Local rendering
still runs, including its view decisions; no projectile is recreated to hide
a missing source.

Wire74/protocol73 uses layout46. Twenty repository tests and 10,799 private
actual-module checks pass. The fixture mocks native removal and allocation;
it does not establish gameplay success. The separate direct-B missing birth
(id74, reason4) remains open.


## Registered weapon-module RNG

The paired second-tank run identified a native `ModTankShoot` burst fork before
the missing projectile. Both peers entered `4DA6D0` with burst1 and identical
timers/delta at native clock8965. Their `EA178C` seeds differed. At8966 the
native burst length was4 versus3 and the cooldowns differed. The private
fixture executes the original `4DA6D0`, `573100` and `573160` and reproduces
those exact outputs. Supplying the same entry seed makes the native outputs
and subsequent RNG advances agree.

The adapter replaces the class's update slot (`AE6B3C+28`) and calls the
original update once. It journals only the engine seed. The source key uses
the native192-entry module registry at `E906B0`, ID/generation/type/class,
clock and authored burst/interval/weapon recipe. Fresh reciprocal bindings,
current world, descriptor/channel references and duplicate identities are
checked around the journal operation. No burst counter, cooldown, target,
message value or Gizmo flag is overwritten.

The channel's cached `+F8` reference is a Gizmo; `+FC` is a LEGOMessage.
They are not render models or animation controllers. `49DBC0` selects among
native party members using muzzle geometry and `actor+F28`; its used-actor
mask adjusts scoring rather than excluding a player. No extra admission or
geometry override was added without a measured mismatch at that consumer.

## Native AI target publication

The qualified `CharacterBrain` class is `C324C4`. Its `+E8` wrapper stores
primary and secondary brain references at `+4` and `+C`. Native actor pass
`9DCE70` publishes them from the game's perception candidates; `9DE890` also
clears references during actor-state handling. Target actors are resolved
through the brain's `+1A0` binding and `+1A4` owner-type tag, checked against
`FA3AA4`. The tag is assigned by a startup initializer and stamped at actor
birth; it is not a frame or network epoch.

`AverageAttack::update` (`89A370`) first calls the current child through
`921140`. Its `8999F0` selection then uses the previous `+B8` target and current
child state. Only afterward does `899AB0` refresh the target. Matching targets
in a stopped actor pool therefore does not prove matching task admission on
earlier ticks. The Wire75 failure requires paired source tracing before an
adapter can be justified; no final task, target or action projection was added.

## Loading-to-simulation boundary

Unbound native spans used a local engine delta before SyncFrame publication
began. In the retained Wire75 R6 run, the first recorded `743BB0(float)`
received 0.1 on the host and about 0.090734 on the client. Later paired deltas
and relative effect ages matched. `FAFCF8` is a float cache clock, not a seed;
its absolute offset does not establish a lifetime error. That observer filtered
by the exported gameplay level and did not cover the earlier inner-D update.

The outer packet already contains engine `+E0C` at `76152C..761538`.
Updating only `FB4B74` inside World cannot change that packet's later
DynoManager event12 input. The bootstrap adapter therefore supplies the host
clock, both native seeds, World delta, packet delta and engine mode before
the original outer span. A direct-B Wire76 run confirms matching first effect
inputs and completed the first tank on both peers through sequence5704.

Wire77 adds serial receipts and a host seal to this handoff. Receipts record
actual completed World calls and the native end phase; a span with no World
call is not mistaken for completed initialization. The native D phase also
calls World and cannot wait for load status2, which is published only at E.
Bindings use the live World's level definition and catalog entry. Same-level
reloads reset the source, receipts and seal through the new epoch.

The Wire77 natural run completed both corals, gold and silver targets and the
B2 wave, then reproduced a sealed-D stall at the native ending cutscene. D is
also a normal cutscene phase after initialization; keeping it behind bootstrap
readiness is incorrect. Wire78 routes a sealed D through the existing SyncFrame
path and keeps its ready publication valid for that same catalog-bound World.

The inner `889F92..889FB7` Tick loop can reach D without another outer entry.
Wire78 therefore also fences the proper Tick entry for `root+1B44` before its
first D World. A fresh owner/nonce/release boundary permits lifecycle/profile
publication there. The source is applied once for the remaining span, including
later event12; subsequent inner Ticks are not reseeded. This suffix fence does
not cover the earlier cutscene-clock advance at `889ED7`.

`E901F4` is CloneWarsCutscenes; its `+84` is an active blocking descriptor,
not an asynchronous loading counter. `+88` holds the instance. Native start,
scene progression and finished-instance cleanup own this lifetime. The optional
`7B8AC0` clock uses a track-backed playback time or capped native delta. No
descriptor, timer, phase, ground flag, task or fragment pose is forced. Full
deterministic loading and the complete A-to-B route still need verification.

Wire78's first loading test rejected an intermediate native World before the
requested mission. Wire79 qualifies both entry points against the actual level
request; no level number is exempted. Its clean paired loading run captured
source serial1 at native clock0/rootD on both peers, one original World call,
end phaseE, and seal1 with no bootstrap fault. The host held at clock1 while
the client finished loading. Native damage then matched9/9 for B1 and54/54 for
B2 without duplicate keys. EndBlow1's native cutscene entered B and reached D
inside that unbound span; the late fence waited on a sealed session and stalled
both peers at sequence16938. The exported B phase was stale while the actual
native phase was D. Last-present captures from this stall are not fresh frames.

Wire80 includes native cutscene queue/advance phases A/B in an established
World's normal SyncFrame path. An inner B-to-D Tick now stays inside that opened
cohort. Before the first source, A/B retain native loading behavior; after a
bootstrap source they may use the ordered stream. Seal remains E-only. An
unexpected sealed unbound D is rejected rather than waiting indefinitely.
The paired Wire80 route completed that native cutscene, EndBlow2 and the exit
opening on both peers. The subsequent A-to-B transition rejected the old World
while the native pending request already named the next World. Wire81 uses one
eligibility predicate at both outer and late entry. Wire82 also requires the
pending request to be cleared: a same-level pending request can still refer to
the old World before its reload. This follows the native request writer and
loader clear, without a mission exception.

Wire81's next full-A attempt stopped earlier, during B2 combat: physics finish
reported eight missing choices at sequence4708 and cadence finish found an
unconsumed Character tail. Reaction, model and projectile first failures were
zero. Frozen actor flags do not establish why those calls were absent. The
native `9B6C20` effect batch does not own the Character pass; `96D5B0` calls
`9C3230`. Proper-entry observations must distinguish pass omission, per-actor
admission and an earlier cancellation before changing this path.

Wire83 additionally carries the actual native effects seed `E5F498` in the
bootstrap input. Its native `5730C0/573140` consumers determine particle axes,
rotation and emission scheduling. The seed is applied before the qualified
native suffix; original consumers advance it normally. It is not restored at
the end of that suffix. This closes an omitted input, but is not evidence that
the separate Wire81 Character-tail failure is fixed. First-fault and first-reject
records preserve their order and caller for the paired verification.

Wire83's full-A run matched B1 damage9/9 and B2 damage14/14 without duplicate
keys, but failed at the ending cinematic. The first error was model finish
(`-21`), sequence10439, with no earlier core rejection. The paired proper-entry
World tails agree on admission for189 shared clocks. At clock10438, both have
phaseD, engine mode0 and identical delta bits1015775603; the host has retired
the blocking descriptor/instance and executes17 Character entries, while the
client retains both and executes no Character pass. This establishes a native
cutscene retirement fork. It does not yet identify a track-clock or provider
initialization cause. Canonical delta alone is insufficient evidence of equal
cinematic progression. The next same-build run observes the provider and scene
operands without changing either side's native output.

That same-build run identifies the first source fork at clock5945. Both native
providers start at0, both scenes at frame1, and both use identical delta. The
NuVoiceXAudio `61B980` query supplies0.01 on the host and0.0200226754 on the
client. Scene advance first differs at5948 and its frame at5949. This is an
audio-device playback input, not an unequal simulation delta. The later chained
scene retains the original provider and stores its current time as the new
segment offset. Forcing a descriptor, frame or finished bit would leave this
source unresolved.

Wire84 intercepts only the native `7B8B08 -> 6C11D0` clock query. The original
getter still runs once on each peer. Three ordered Tick input records carry a
two-word authored identity and the host's float32 query value, including the
native unavailable sentinel. Identity combines the current descriptor and the
provider's original descriptor: native directory/name, level and parse ordinal,
with bounded registry membership and the current World's level definition.
The local track must belong to the native three-slot TrackManager. Chained
providers are supported without replacing either descriptor. The unmodified
`7B8AC0`, `84A230`, scene integration and retirement consume that input.

Actual x86 wrapper tests verify one original getter call, host/client replay,
chained ownership, invalid registry/World rejection, LastError and floating-point
control preservation. Wire tests cover the complete ordered record, malformed
time, partial records and mismatched clocks. All21 tests pass; gameplay
verification of this source fix is still in progress. Wire85 also verifies the
exact native selection: the provider owner's component table atA0, kind4 handle
at table20, must equal track4. This is the read-only equivalent of the native
`6C0F00` getter followed by TrackManager lookup. Any finite negative queried
time retains the native delta fallback; no special negative value is required.

Wire85's paired natural route completed the cinematic, EndBlow2, exit opening
and A-to-B loading. The client replayed3205 native audio inputs,3064 differing
from its device clock, with no Tick-input failure. The first correction was
the measured0.0200226754-to0.01 source difference. B later failed on an extra
Attack update, so this is a cinematic/transition result, not a full mission pass.

At the end of a chained scene, the native TrackManager can release its track
before the scene releases the clock provider. Wire96 samples at `7B8B02`,
after the stock lookup. A present track still invokes the original getter
once. An absent track supplies the unavailable value from `AD76DC`, and
the client can replay the host sample while the authored provider still
matches. The original provider consumes the value and owns scene retirement.

## Bilateral native loading barrier

The native C phase commits the loaded World through `89C3F0`. Phase9 finishes
setup; A/B handle the cutscene queue and native component/track loading. The
`844800` B handler enters D only after those checks. This gives a pre-World
boundary that does not require the first World, E, controllers or a gameplay
ready flag. The native general worker has a queued count atEB0D18 and a current
job pointer atEB0D20; it sets the current pointer before decrementing the queue.
Two idle snapshots separated by a memory barrier check this specific queue.
They do not certify every streaming API globally.

Wire86 publishes `(epoch, level, phase, completed bootstrap serial)` only from
the qualified World/profile boundary with that queue idle. The host may publish
sourceN only when both peers confirm completion/readiness ofN-1. The client
also checks its current readiness before receivingN. Existing receipts still
describe actual completed native World calls; E sealing requires matching
readiness too. Queue state is checked again before source publication/application.
Epoch, level, invalid World/request and connection changes invalidate the
readiness. No game pause flag or fixed loading delay is used.

The paired initial-load trace records78 samples with the host held at clock0
before source1 while the client was still loading. Both then complete source1
at clock0 with one native World call and seal1. Wire86 also completed the native
A-to-B transition with a fresh epoch and matching bootstrap receipts. Both peers
destroyed the first B tank and remained in sync through sequences19353/19352.
The run stopped under control because the private route incorrectly tried to
use Thire on the second tank's gold guns. His cinematic `Droid_Head_Thire_item`
is expected story behavior; Yoda must use a Force-held B2's fire at this point.
No inventory restoration patch is needed. This is not a full-mission pass.
The original HUD and separate views are retained
in the paired final screenshots. Wire87 checks the previous receipt before waiting for the
next readiness, so mismatched native end phases reject rather than forming a
cyclic wait. Unit cases cover stale/partial readiness,5000 serial steps, pending
worker snapshots and receipt phase/count mismatches.

Wire87 repeated the initial barrier with81 host-wait samples, then completed
the two native cinematic retirements at matching clocks9537 and11518. Both
peers loaded B in epoch2, sealed one native World call, and destroyed the first
tank. A separate Wire87 route failed before its cinematic at sequence9835:
the client lacked active projectile1501 (Rys's rocket). Missing-active checks
precede unconsumed-birth checks, so this does not establish that the constructor
ran or returned NULL. Native Fire admission is being observed separately.

## Rigid fragment contact fork

Wire75 R6 first differed at the physical support transform before the Character
ground query. The ordered contacts and captured Character operands matched.
Thirty-five recorded emission inputs matched, but the first capture omitted
some constructor operands and dynamics; it cannot establish equal body state.

The later birth observer reads the allocated A0-byte dynamics block. Its `+90`
constructor (`A124B0`) ORs bits0/1 rather than clearing the DWORD. `A06930`
uses those two bits for angular and linear velocity clamps. Differing upper
bits alone are not a measured physics input. Reading48 DWORDs would extend
beyond this allocation and must not be used as a state comparison.

## Native scenes without a party

The completed Ambush B route reaches native Outro8 and Status9. Status has
definition flags `0x01000405` and eight null party slots. Native character
creation `9C5D10` depends on definition flag2, which Status does not set.
Requiring a player to acknowledge its profile therefore deadlocks both peers
before their first shared World update.

Bound-profile readiness validates magic500, writable profile storage,
the seven native aliases, counted catalog/save tables and the
callbacks used by `928F10`. Its separate scene resolver checks the current
World against the live catalog and excludes the native Titles definition.
A scene may omit actor input only when flag2 is clear and all eight party
slots are null. A zero actor count permits a null pool; a nonempty pool still
requires a valid complete span. Existing gameplay admission remains in place
for death, respawn, tagging and retained reserve actors.

Partyless World dispatch does not assign controller devices or carry pressed
actor inputs into the next scene. The original native World still runs once
at each actual call site. No synthetic World, Tick, actor-effects batch or
fixed loading delay is introduced. Bootstrap receipts and bilateral queue
readiness remain mandatory.

The first paired Status test completed its native first World once per peer,
sealed serial1 and ran over9000 shared steps with an empty actor pool. The
later private UI probe used an incorrect address; evidence after that probe
is excluded and the test processes were closed. A clean native Continue
and return-to-gameplay check is tracked separately.

Status input is independent of actor controllers. `8FF080` also runs through
the native level callback at definition+68; its current stage update `9FDBB0`
reads pressed from `read_u32(FB3090)+8+60*user`, masked by the live `E64154`.
`FB3090` is a pointer global, not an inline user-input array. The stage state
is at `read_u32(FBC860)+20`; it must not be confused with the context block
at `FBC6F0`. None of these output states are synchronized by overwriting them.

The native Continue path is Status9, `Ambush\\StoryB_Midtro1`11, then
`CWHub\\CWHub`3. In a repeat source trace both peers queued descriptor169,
`Story/StoryB_Ventress_Midtro1`, before their first D World. All188 selected
event keys and captured profile hashes matched. Both retired the scene at
clock195. Its scene progress first differed inside the third World despite
matching global delta. These bootstrap Worlds had no full input cohort: the
old initial seal waited for E, which this blocking scene could reach only
after completing its animation. Native audio/provider input was therefore
outside its normal synchronization boundary. This does not prove the cause
of a separate first-receipt D/E mismatch in the preceding run.

Candidate90 permits the first seal in D after a real World has completed and
the peer has acknowledged the same call count and end phase. A native level
request can finish loading at that D boundary only with a fresh
session/epoch/World initialization proof. The following outer span uses the
existing complete D input cohort, including qualified native audio time.
It does not wait for the blocking descriptor at `E901F4.manager+84` to vanish:
that field is a descriptor pointer, not a loading counter. Existing receipt
mismatches still reject. The paired Status-to-StoryB regression passed after
the immutable initial profile and matching D/E transport seal fixes.

## Initial profile and native character handoffs

The initial profile is an immutable transaction keyed by session, epoch and
level. The host captures it before native scene admission. The client applies
sequence zero once; live profile publication resumes after the shared seal.
This prevents a host's newly written cutscene-seen bit from making the client
skip the same initial scene. `795E20` and `7F1530` source traces established
that race. `FB3110` must remain bound to profile `+B57C`.

Native Continue has passed Status9, StoryB11's blocking cutscene and entry into
Hub3 with matching D receipts. A receipt still requires exactly the expected
World call count and the same completed phase on both peers. Queue readiness
does not replace these checks, and a cutscene descriptor is not a pending job.

Tag command operands are captured before `8AE680` retires or transfers an actor.
They carry character, creation site and native producer identity independently
of the frame's later actor list. Cold command binding and post-call metadata
refresh preserve allocation generations and one-to-one mappings. The original
native command performs the party and controller changes.

Saved-roster actors originate in `8AFB80` through its `9DE240` constructor calls
at `8AFC3A` and `8AFCBE`. `FB4F20` contains at most eight records, stride `2C`;
the count is at `FB4F18`. A constructor scope witnesses its allocator birth,
then waits for the original caller's record-to-actor backlink. Only the same
allocation generation, World, catalog definition, provider and unchanged native
record may receive the source key. Its serial combines the native catalog level
and record ordinal. Stale or ambiguous identities reject; same-level repeated
restore lifetime coverage remains unverified. The paired handoff regression is
tracked separately from the passing source and ABI fixtures.

The paired Hub failure did not use saved-roster restoration: its count was
zero and neither constructor bridge ran. Proper-entry traces on both peers
instead identify `4EEAF0`, called from `4F07F0`, with its constructor call at
`4EED96`. The containing module is native `cModHubCharacters` (`AE68BC`).
Its owner list, native owner identifier at `+B8`, record array at `+CC` and
record ordinal provide the construction context. The owner's record backlinks
are written after the in-function Tag call, so waiting for that later link
would make the operand identity unavailable when the command is captured.
The paired source check passes: both native births acquire the same owner
keys and the client replays both Tag commands. The following sections describe
the independent SpellIt node and camera issues exposed after that step.

## Authored points on native runtime clones

The failing Hub candidate has a valid POI inside its resource's authored array.
Its `POI+D4` points to the authored receiver rather than the runtime clone.
Sixteen captured candidates follow the native `model+48` source link, with
`model+5A & 1` and `receiver+18 == model`, to an ancestor whose array membership,
E0 stride and D4 backlink all match. Treating every live receiver as the
authored receiver rejects these legitimate candidates.

`native_authored_poi` resolves and revalidates this bounded chain without game
calls or writes. Direct authored membership remains mandatory at its end;
missing clone flags, broken backlinks, cycles and excessive depth reject.
The cadence caller retains the actual candidate model, receiver, component,
node, actor allocation and frame guards. Only its portable resource/POI identity
comes from the authored ancestor. The existing resource registry/hash checks
remain in place, and the full chain is checked again around the input gate.
The paired check accepted this ancestry and exposed a separate library-resource
identity assumption, described below.

The next paired check accepted the clone ancestry and reached resource
identity validation. Its source file is a registered prefab library with no
bound World. `CloneWarsLevelContainer` (`ADA098`) is created and registered
before any optional World association; native `89CC8D`/`89CC93` establish the
World/container backlinks separately. Requiring every resource container to
have a World rejects valid library resources.

Portable identity now includes the current World path, native container class,
World-presence tag, the source World path when bound, and the native filename
and logical resource name. A nonnull World still requires reciprocal ownership.
Duplicate detection compares this complete tuple; a second worldless entry
alone is not evidence of ambiguity. Library identity uses its own namespace
and never substitutes the current World for an absent source World.
The paired check then passed the prior Tag, cloned POI and library identity
failures. Rendering required the separate camera-family correction below.

`native_resource_identity` now owns this lookup. Its per-call memory-region
cache reduces repeated OS queries while rereading the metadata, strings and
duplicate entries for every resolution. It retains the same portable key;
fresh witnesses detect source changes around the input gate. It caches no
resource identity across calls or epochs.

## Native camera view families

Hub's camera manager has two `DynamicSplitScreenLevelView` instances and two
native `BackgroundLayerLevelView` instances. The former have B4-byte layouts;
the latter have AC-byte layouts and do not have the dynamic view's role or
parent fields at AC/B0. Their native ownership is `main+28 -> background`, with
both views' shared context at `+30` matching `manager+C`.

The old pair check rejected nonnull slots2/3 while the focus path still forced
split updates. Candidate98 admits the qualified family consistently across
focus, ordering, fullscreen clipping and presentation. `77FE40` processes type1
views; its temporary permutation only changes the two primary slots. Native
background slots remain untouched. Auxiliary changes invalidate presentation
and HUD preparation while allowing restoration of a still-owned primary
permutation. Unknown families retain the native fallback.

The paired Hub check now renders textured rooms and visible characters on
both peers, with the original HUD and separate camera viewpoints. Ordinary
directional and jump inputs also replicated successfully. This is a Hub
check; full-mission coverage is tracked separately.

## Shared source resolution for SpellIt pieces

The physical piece path now uses the same authored POI and resource witnesses
as the node query path. Native scene membership, piece-list topology, adapter
links, selection and allocation guards remain mandatory. The original query
still receives the live record and live receiver; the authored ancestor is
used only to identify the source.

The resource portion of the portable key now uses the common class and
World-presence namespace, including native library resources without a bound
World. This changes its encoding and requires protocol 93; layout 47 is
unchanged. Resource filename and logical name retain their bounded native
bytes. Source-key and POI-name encoding are unchanged.

The optimized source fixtures cover library-backed direct models and clones,
mutation rejection, original-call arguments and FX/LastError preservation.
The full Ambush gameplay regression remains pending.


## Scripted Shoot admission with separate cameras

The native Shoot callback at `963520` reads the actor model's visibility byte
at `963CA5` before setting forced aim and enabling scene-object collisions for
its shots. Its authored Offscreen option supplies a separate fallback. With
separate cameras, local visibility can differ even when the actor and task
inputs match.

The paired source trace contains a native birth with the same shot ID, actor
generation, weapon, flags and clock whose `9095D0` policy differs by bit800.
Later complete callback traces also show visibility-dependent native forced-aim
writes on opposite peers. The birth trace and the later producer trace are
distinct observations; the producer call for that original birth was not
captured directly.

`native_script_shoot_source` qualifies the live actor, model, brain, script
state, native call frame and argument strings. Protocol 94 carries the actor's
ordered visibility input with a 56-byte context containing image classes,
clock, native task flags, caller and an ordered hash of bounded native argument
bytes. Arguments are length-framed so different argument lists remain distinct.
Allocation generation and frame ownership remain in the outer actor gate;
fresh local witnesses are checked again after that gate.

The bridge changes the visibility comparison operand. The renderer retains its
local visibility byte, and the original callback applies its own Offscreen
fallback, targets, flags and firing behavior. The native function executes once.
The wire layout and frame size remain 47 and 3784464 bytes. The optimized engine,
bridge and actual cadence-adapter fixtures pass; paired gameplay validation of
the combined change is still pending.

## Shoot input scope before optional native branches

The protocol 94 hook records an input only when `963520` reaches its visibility
comparison. Native target lookup can return earlier. Recording at that optional
site therefore makes the journal depend on which local path reached the read.
The clean full-route regression stopped with an extra client Shoot entry before
the host's movement entry. The precise earlier branch in that run was not
captured; a later direct-B run completed three tanks without that failure.

Protocol 95 samples the visibility input at the qualified native dispatcher
`6F3FE0` before invoking Shoot. A lexical scope holds the input until the
original comparison consumes it. The original dispatcher executes once through
its guarded entry trampoline and still calls Shoot at `6F407D`; Shoot's own
native return address remains `6F407F`. No target or model visibility is written.

The scope checks the live descriptor, handler, actor, model, brain, argument
strings and all seven raw call arguments. Before initialization, the wire key
uses zero task flags; parsing those flags remains the native callback's job.
Consumption permits the callback's own task-flag changes while rechecking its
immutable source and allocation generation. The binding belongs to one cohort;
a stale binding cannot report a fault against a later frame. Normal return and
exception unwind both retire the scope.

Native null-model and inactive-brain admissions keep their original early
return. Outside a network cohort, the dispatcher and visibility comparison keep
their local behavior. This prevents the new scope from imposing gameplay-World
requirements on unrelated single-player or frontend execution.

The actual cadence adapter and ordered actor gate pass 4046 optimized fixture
cases, including context mismatch, opposite visibility, generation changes and
stale epoch/serial rejection. The actual engine wrapper and comparison bridge
pass 90333 checks under optimized C++23, including nested calls, exception
cleanup and the two different native early-return paths. The full protocol 95
gameplay regression remains incomplete. Version 0.0.6 publishes the current alpha at the user's request; this does not mark the outstanding source investigations complete.

## Outgoing native level step

The authored scene callback at `827040` can queue a new resource descriptor
through `826D40` on the outgoing level's final world step. During a Duel of the
Droids map launch, the next epoch reached the client before it replayed that
step. The next scene's native constructor then had no descriptor to consume.

The host keeps the outgoing epoch and ready state until the client acknowledges
the last queued frame for that epoch and level. The native pending request
selects the destination. Both peers resume loading once the host commits the
transition.

## Native gun-jam selection

The registered module at `4ACAC0` draws from the shared `EA178C` stream. At
native clock 228 in the paired repro, it reached the same timer expiry on both
peers with different seeds. It queued a request for different actors and set
different next timers. `PlayGunJamAnim` at `487F40` then activated action 92 on
different actors.

Wire 99 samples the seed at `4ACB53` with the native module registration,
authored clip and timer parameters, and the native candidate count. The peers
use the same seed at the original RNG call. The game selects and applies the
request and advances its own stream. A controlled repeat with the old client
seed reproduced the input difference and both peers chose the same actor,
timer and animation after the correction.

## Native flight torpedo state

The actor's secondary weapon state is at actor+6EC. Ammo is the byte at+0C;
reading a word also includes flags and gives a false count. The weapon
descriptor supplies the secondary resource ID and capacity. Native pickup
7CE4E0 increments ammo at7CE55F. Original secondary fire reaches7EC1B0 and
decrements at7EC291 after requesting the projectile. Paired runtime watches
observed the post-store PCs7CE562 and7EC294 at matching native clocks.

Lock targets come from the native gizmo provider and resource definition flag
8000. Native damage869FA0 updates the hit byte at86A086 and increments FB312C
at86A17C for these targets. The lower-target runtime check observed matching
destruction flags and counter0->1->2 on both peers after two original shots.

An actor address alone does not identify a surviving ship. In the same run,
native generation74 retired with two torpedoes; generation75 reused its actor
slot with a new model and secondary-state allocation and zero ammo. Preserve
the original allocation/lifetime semantics when investigating apparent ammo
loss; this evidence does not justify carrying ammunition across destruction.
