# Testing

Install Godot 4.3 (standard build), then from the project folder:

```
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/playthrough.gd
```
Each prints `==== ... N passed, 0 failed ====` and exits non-zero on failure. The headless renderer prints harmless
`mesh_get_surface_count ... m is null` errors; they are noise from the dummy renderer.

## What is covered
- `run_tests.gd`: data consistency, inventory rules, crafting rules, XP, creatures, quests (rewards once), save/load, backup recovery, corrupt/future saves, audio generation, world scene loads, gathering, placement validation.
- `playthrough.gd`: menus and back-button state, real multi-touch events through the touch layer, every HUD button connected, quest chain, taming, companion follow, crafting, shelter building, doors, chests, farming, rest-station production, all companion abilities, Rustmaw telegraphs/phases/defeat, shrine, defeat and recovery, survival rules, save and reload of everything, settings effects.

## What is NOT covered (needs a real phone)
Rendering and visuals, shadows/performance and frame rate, touch feel and button sizes, audio by ear, thermal/battery, notch/cutout layout, Android lifecycle (app switching, call interruption), APK installation.
## Manual device checklist
1. Install APK; launch; menu appears in landscape.
2. New Game; joystick and camera drag work together; pinch zooms.
3. Gather, tame the Mossbun, craft, build a shelter; open every menu.
4. Press Home and return; press Back repeatedly; rotate/notch layout looks right.
5. Pause > Save, force-stop the app, reopen, Continue.
6. Check frame rate in Settings (30/60) and quality presets.
