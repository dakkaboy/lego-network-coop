# Complete Saga mission checklist

The Steam archives identify 36 main chapters across six episodes. The first and last gameplay rooms below follow the order in the area's catalogue. The count excludes scenes flagged as intro, midtro, cutscene, outro, status or test, and startup and load-game scenes. Each of the 135 main gameplay rooms resolves to a PC scene in its episode's archive.

## Status

Every route below starts at **Identified**. Record **Reachable** when the game opens the route from its native selector, **Local pass** when the baseline route completes in local co-op, and **Network pass** when both peers complete it and agree on the resulting scene and progression. Track Story and Free Play separately.

For each main chapter, test entry from the cantina, room changes, chapter completion, changing to another chapter, and returning to the cantina. Check restart from an active room and after returning to the hub. Use the same lifecycle for every route. Gameplay phase and transition type can select parameters. Chapter and room IDs are for selection, traces and test data.

## Main chapters

| Episode.chapter | Area | First gameplay room | Last gameplay room | Gameplay rooms |
| --- | --- | --- | --- | ---: |
| 1.1 | `negotiations` | `negotiations_a` | `negotiations_c` | 3 |
| 1.2 | `gungan` | `gungan_a` | `gungan_e` | 4 |
| 1.3 | `palacerescue` | `rescue_a` | `rescue_e` | 4 |
| 1.4 | `podsprint` | `podsprint_a` | `podsprint_a` | 1 |
| 1.5 | `retakepalace` | `retake_a` | `retake_g` | 6 |
| 1.6 | `maul` | `maul_a` | `maul_f` | 5 |
| 2.1 | `pursuit` | `pursuit_a` | `pursuit_e` | 5 |
| 2.2 | `kamino` | `kamino_a` | `kamino_f` | 5 |
| 2.3 | `factory` | `factory_a` | `factory_g` | 6 |
| 2.4 | `jedi` | `jedi_b` | `jedi_b` | 1 |
| 2.5 | `gunship` | `gunship_a` | `gunship_b` | 2 |
| 2.6 | `dooku` | `dooku_b` | `dooku_c` | 2 |
| 3.1 | `dogfight` | `dogfight_a` | `dogfight_a` | 1 |
| 3.2 | `cruiser` | `cruiser_a` | `cruiser_g` | 7 |
| 3.3 | `grievous` | `grievous_a` | `grievous_a` | 1 |
| 3.4 | `kashyyyk` | `kashyyyk_a` | `kashyyyk_d` | 4 |
| 3.5 | `temple` | `temple_a` | `temple_c` | 3 |
| 3.6 | `vader` | `vader_a` | `vader_c` | 3 |
| 4.1 | `blockaderunner` | `blockaderunner_a` | `blockaderunner_d` | 4 |
| 4.2 | `tatooine` | `tatooine_a` | `tatooine_e` | 5 |
| 4.3 | `moseisley` | `moseisley_a` | `moseisley_e` | 5 |
| 4.4 | `deathstarrescue` | `deathstarrescue_a` | `deathstarrescue_e` | 5 |
| 4.5 | `deathstarescape` | `deathstarescape_a` | `deathstarescape_d` | 4 |
| 4.6 | `deathstarbattle` | `deathstarbattle_a` | `deathstarbattle_d` | 4 |
| 5.1 | `hothbattle` | `hothbattle_a` | `hothbattle_e` | 5 |
| 5.2 | `hothescape` | `hothescape_a` | `hothescape_d` | 4 |
| 5.3 | `asteroidchase` | `asteroidchase_d` | `asteroidchase_c` | 4 |
| 5.4 | `dagobah` | `dagobah_a` | `dagobah_e` | 5 |
| 5.5 | `cloudcitytrap` | `cloudcitytrap_a` | `cloudcitytrap_c` | 3 |
| 5.6 | `cloudcityescape` | `cloudcityescape_a` | `cloudcityescape_c` | 3 |
| 6.1 | `jabbaspalace` | `jabbaspalace_a` | `jabbaspalace_e` | 4 |
| 6.2 | `sarlaccpit` | `sarlaccpit_a` | `sarlaccpit_c` | 3 |
| 6.3 | `speederchase` | `speederchase_a` | `speederchase_a` | 1 |
| 6.4 | `endorbattle` | `endorbattle_a` | `endorbattle_d` | 4 |
| 6.5 | `emperorfight` | `emperorfight_a` | `emperorfight_b` | 2 |
| 6.6 | `deathstar2battle` | `deathstar2battle_a` | `deathstar2battle_g` | 7 |

## Endings and bonuses

Each episode lists an ending and two bonus routes after its six main chapters.

| Episode | Ending area | Character bonus | Vehicle bonus |
| --- | --- | --- | --- |
| I | `e1ending` | `e1characterbonus` | `e1vehiclebonus` |
| II | `e2ending` | `e2characterbonus` | `e2vehiclebonus` |
| III | `e3ending` | `e3characterbonus` | `e3vehiclebonus` |
| IV | `e4ending` | `e4characterbonus` | `e4vehiclebonus` |
| V | `e5ending` | `e5characterbonus` | `e5vehiclebonus` |
| VI | `e6ending` | `e6characterbonus` | `e6vehiclebonus` |

The area catalogue also contains the following routes outside the six episode lists.

| Area | First gameplay or hub scene | Archive | Check |
| --- | --- | --- | --- |
| `map` | `map` | `GAME.DAT` | Cantina on new game, load and return |
| `podrace` | `podrace_b` | `EPISODE_I.DAT` | Alternate vehicle route, flagged `no_freeplay` |
| `bonus_gunship` | `bonus_gunship_a` | `GAME.DAT` | Alternate vehicle route, flagged `no_freeplay` |
| `anewhope` | `anewhope_a` | `EPISODE_III.DAT` | Extra chapter |
| `bonus` | `new_town` | `GAME.DAT` | Super bonus |
| `bonus2` | `lego_city` | `GAME.DAT` | Super bonus |
| `anakinsflight` | `anakinsflight_a` | `GAME.DAT` | Extra vehicle chapter |
| `senate` | `senate_a` | `GAME.DAT` | Bonus |
| `utapau` | `utapau_a` | `GAME.DAT` | Bonus |
| `hoth` | `hoth_a` | `GAME.DAT` | Bonus |
| `nb_kamino` | `nb_kamino_a` | `GAME.DAT` | Bonus |
| `nb_kashyyyk` | `nb_kashyyyk_a` | `GAME.DAT` | Bonus |
| `nb_dagobah` | `nb_dagobah_a` | `GAME.DAT` | Bonus |
| `losttemple` | `losttemple_a` | Unresolved | Catalogue entry with no matching PC scene in these archives. Check reachability. |

The bounty catalogue defines 20 routes that reuse existing rooms. Test them from their own selector and verify the mission result separately from ordinary room completion. The remaining area entries are marked `test_area`.

## Reproducing the archive check

The `saga_catalogue` tool reads the four catalogue files directly from the installed `GAME.DAT`. It resolves chapter and room references and retains the flags declared in the archive, including bonus and Free Play restrictions. It also lists unresolved room references. The Steam archive contains a dangling room ID in the JimTest area.

```powershell
$catalogue = './games/lego-star-wars-the-complete-saga/build/Release/saga_catalogue.exe'
& $catalogue 'C:/path/to/Saga/GAME.DAT'
& $catalogue 'C:/path/to/Saga/GAME.DAT' --list
& $catalogue 'C:/path/to/Saga/GAME.DAT' --pid 1234
```

Replace `1234` with the game process ID. The live check verifies the Steam scene-reader signature, reads the scene record and resolves its asset path against the archive. During loading it can report that the scene is unavailable. The path identifies the room. A restart of the same room and the active mode still need lifecycle observations.

Configure with `-DSAGA_TEST_GAME_ARCHIVE=<path>` to include catalogue lookups in CTest.

Read `LEVELS\EPISODES.TXT`, `LEVELS\AREAS.TXT`, `LEVELS\LEVELS.TXT` and `LEVELS\MISSIONS.TXT` from `GAME.DAT`. Join episode area IDs to area records, then area scene IDs to level records, case-insensitively. Use the level's directory and ID to check the matching `_PC.GSC` path in the archive indices. Two Episode II non-gameplay records have an unterminated quoted ID. Both IDs are visible before the line break.

The audit used [tt-oldera-tools at a8a21be](https://github.com/stryderjoe/tt-oldera-tools/tree/a8a21beb2f8944da23242e2f1a63fec42a55a7af) to read the installed archives. It resolved 12,174 file paths in `GAME.DAT` and 285 across the six episode archives, with no unnamed entries. All four catalogue files are stored without compression. The episode archives mark their file payloads as LZ2K-compressed. Keep extracted files in a local test directory.
