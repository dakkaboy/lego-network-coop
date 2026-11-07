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
| World admission | `888750` comparison at `8888CD` | Matching host operand and original world update |
| Mission/section entry mode | `FC16B0`, `8BD740`, `9097E0` | Native host entry intent and original loader path |

The preload indicator timer (`FB4A0C`) and background I/O state stay local. Both machines keep processing native loading while network gameplay waits for readiness.

## Remaining source work

- Physical emitter producers `742800` and `743580` choose emission position, launch velocity, model and lifetime before the already covered spin functions. Their private random inputs and emission timing still need a paired physical emission case.
- Particle scheduling and generation also use `E5F4DC`. Identify any consumers that feed collision or gameplay before extending the coherent journal to them.
- `678AB0` advances seeds embedded in native nodes at offset `1C`. Their owner identity and effect on simulation remain unverified.
- `740B10` also calls the CRT generator. Trace its consumers before treating that draw as shared simulation input.
- AI task `899ED0` gates attack input on local model visibility at `89A093`, then draws from `EA178C` through `573100` twice to set its cooldown at task offset `1C`. Paired Ambush traces show different seeds at these consumers. Its earlier timer and branch inputs still need source projection.
- A long Defenders run still reproduced a mismatched native jump (`8C2A90`), leaving NPC action `0` on one peer and `FFFF` on the other before the model-input guard. The upstream jump decision remains unresolved.

Local pointers, actor pool order and coordinates are not cross-peer source identities. New bindings need the game's authored or registered owner and the native consumer context.

## Native emitter identity

`6740A0` dispatches a native effect node through `744CB0` and `743580`. The node carries its template, count, transform and scale. `71BC40` can allocate a scaled copy in the native template table at `FAFCFC` (192 entries, stride `1BC`). Such a copy retains its root template at `190` and scale at `18C`; its generated name includes a local allocation index. That suffix and the table index must not be used as cross-peer identity. The authored root name and native owner are the useful sources.

`FAFCF8` is the emitter clock. Its wrap function `71ACA0` subtracts 800 from the clock and the active native stream/template timestamps together. It is not a general clock setter. No emitter-clock or upstream RNG projection has been added without a paired physical emission case.
