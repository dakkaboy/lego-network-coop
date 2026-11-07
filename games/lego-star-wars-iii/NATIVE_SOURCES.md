# Native simulation sources

| Source | Native consumer | Current handling |
| --- | --- | --- |
| Game random state, `E637B4` | Inlined native random draws | Host state at frame admission and native shot/Tag contexts |
| Engine random state, `EA178C` | `573100`, `573160` | Host state at frame admission and native shot/Tag contexts |
| Physical effect random state, `E5F498` | `71AB90`, `71AC10` | Input seed per matching physical source; original native call executes once |
| Registered module spawn delays | Native module registry and `483A90` | Initial delays and native choices keyed by registered producer |
| RTS spawn timers | `50AFC0`, `55E2C0` | Initial team timers and native random cooldown choices |
| Character collision body | Native model/body links, `A294C0`, `A08380`, `A083E0` | Native body move/velocity plus the independent solver height cache |
| World admission | `888750` comparison at `8888CD` | Matching host operand and original world update |
| Mission/section entry mode | `FC16B0`, `8BD740`, `9097E0` | Native host entry intent and original loader path |

The preload indicator timer (`FB4A0C`) and background I/O state stay local. Both machines keep processing native loading while network gameplay waits for readiness.

## Remaining source work

- Physical emitter producers `742800` and `743580` choose emission position, launch velocity, model and lifetime before the already covered spin functions. Their private random inputs and emission timing still need a paired physical emission case.
- Particle scheduling and generation also use `E5F4DC`. Identify any consumers that feed collision or gameplay before extending the coherent journal to them.
- `678AB0` advances seeds embedded in native nodes at offset `1C`. Their owner identity and effect on simulation remain unverified.
- `740B10` also calls the CRT generator. Trace its consumers before treating that draw as shared simulation input.

Local pointers, actor pool order and coordinates are not cross-peer source identities. New bindings need the game's authored or registered owner and the native consumer context.
