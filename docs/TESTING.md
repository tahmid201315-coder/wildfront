# Testing

All results below came from real runs in a headless Godot 4.3-stable on Linux (software rendering where a screenshot was needed). **Nothing here was run on an Android device.** Treat "tests pass" as "the logic and connections work", not "the game feels good".

## Commands

```
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd        # logic and data validation
godot --headless --path . res://tests/build_check.tscn             # base building
godot --headless --path . res://tests/combat_check.tscn            # enemies and combat
godot --headless --path . res://tests/boss_check.tscn              # three bosses, phases, defeat
godot --headless --path . res://tests/playthrough.tscn             # new game to final quest
```

## Latest local results

| Suite | Result |
|---|---|
| Logic and data (`run_tests.gd`) | 69 passed, 0 failed |
| Building | 7 passed, 0 failed |
| Combat | 18 passed, 0 failed |
| Bosses | 18 passed, 0 failed |
| Scripted playthrough | 43 passed, 0 failed |

The logic suite prints one expected JSON parse error: it deliberately feeds a corrupt save to check recovery.

## What the playthrough does and does not prove

It builds the real world and walks the real quest chain: gathers by hand, crafts, places a campfire, shelter and workbench through the build manager, opens the outpost and mine lockers, restarts the generator, defeats all three bosses, opens both gates, activates the pylons (including a wrong-order reset) and completes quests m01 to m12.

Shortcuts it takes: it teleports the player, grants some crafting materials (marked in the script), and damages bosses with scripted hits instead of fighting them. So it shows the chain is completable and connected; it does not show that the bosses are fair or fun.

## Not verified

- Anything on a physical Android device: touch feel, thumb reach, safe-area insets, vibration.
- Frame rate. The 30 FPS baseline is a design target. Draw-call and particle budgets were kept small but never measured on a phone.
- Audio output (the CI and sandbox have no sound device; sounds are generated and play without error).
- Boss difficulty and economy balance (resource rates, hunger and temperature pacing).
- Save/load across a long session on a device.

## Visual checks

Screenshots were taken under software rendering for the menu, HUD, inventory, crafting, journal, skills, map, defeat screen, rain, structures and several sites. Terrain banding on steep slopes and some dark enemy colours are known cosmetic issues.

## CI

The workflow runs import, the logic suite, the scene tests and the playthrough, then exports the APK. Check the Actions tab for the real status of the latest run; this file does not claim a CI result.
