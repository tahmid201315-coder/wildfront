# WILDFRONT: Creature Survival

An original, offline, single-player 3D open-world creature-survival game for Android, made with **Godot 4.3** and **GDScript**.
Explore the meadows of Aetherwild, befriend Wildlings, craft, build a base, farm, and face the Rustmaw.

> **Honest status (read this first)**
> - The game logic is covered by automated headless tests (61 unit checks, 142 scripted-playthrough checks). They pass in a Linux sandbox.
> - **No APK has been built yet.** The GitHub Actions workflow is written but **has not been run**. Until it runs and passes on GitHub, nothing here proves the export works.
> - **Nothing has been tested on a phone.** Touch feel, performance, visuals, audio quality and battery use are unverified on real hardware.
> - See [Known limitations](#known-limitations).

## Get the APK (no computer needed beyond a browser)

1. Put this project in a GitHub repository (upload the folder contents, keep the `.github` folder).
2. Open the repository's **Actions** tab → **Android Debug APK** → **Run workflow** (it also runs on every push to `main`).
3. Wait for the run to finish (roughly 10 minutes the first time).
4. If it is green, open the run and download the artifact named `wildfront-creature-survival-debug-apk-<number>`. Unzip it to get `Wildfront-Creature-Survival.apk`.
5. On your phone, allow "Install unknown apps" for your browser or file manager, then open the APK.
   It is a **debug** build signed with a throwaway key generated during the build. Each build has a different key, so uninstall the old version before installing a new one (this also removes the save).
6. If the run is red, download the `build-logs-<number>` artifact and see [Troubleshooting](docs/TROUBLESHOOTING.md).

Package: `com.wildfront.creaturesurvival` · arm64-v8a only · landscape · needs no network permission.

## How to play

| Control | Action |
|---|---|
| Left side drag | Floating joystick (move) |
| Right side drag | Look around |
| Two fingers on the right | Pinch to zoom the camera |
| Big button | Interact (gather, talk, offer food, open) |
| Strike / Ability / Jump | Attack, companion ability, jump (hold to glide) |
| Build | Open base-building menu |
| Pack / Map / Journal / Pause | Top-right buttons |
| Android back button | Closes the top menu, or opens Pause |

Desktop testing keys: WASD, Shift (run), Space, E (interact), F (strike), Q (ability), B (build), M (map), J (journal), Esc.

First hour: follow the quest tracker. Gather wood, berries, stone and fiber, find the fluffy Mossbun east of camp, offer it food until it trusts you, craft a workbench, and build a shelter (foundation + three walls + roof).

## Features that exist in this build

- Third-person controller with jump buffer, coyote time, glide, stamina/sprint, multi-touch controls.
- Procedural terrain, water, day/night, two regions (Verdant Meadow, Ember Highlands), 6 landmarks, fog-of-war map.
- Survival: health, stamina, hunger, temperature comfort (shelter, campfires, region heat/cold). Hunger never kills; defeat never deletes your items.
- 8 tameable Wildlings with trust/taming, each with a real companion ability and a work output, plus the Rustmaw boss with telegraphed attacks and two phases.
- Gathering, 30-slot inventory, 17 recipes (workbench/campfire stations), base building with snapping and placement validation, shelter detection, chests, doors, farming plots, rest stations where Wildlings produce items.
- 17 data-driven quests, XP/levels, journal (Wildlings, Bestiary, Quests, Lore).
- Versioned, atomic saves with backup recovery. Working settings (volume, FPS, quality, render scale, UI scale, camera sensitivity, vibration).
- All art, models and audio are generated in code. No third-party assets.

## Known limitations

Be aware before you judge the build:

- **Not device-tested.** Expect to find bugs, balance problems and performance issues on real phones.
- Visuals were never viewed on a screen in the development sandbox (it has no GPU/display); only logic was tested headless.
- Models are simple primitive-built shapes, not hand-made art. The world is a single 240 m x 240 m island-style map, not a huge open world.
- Audio is synthesized and basic; its quality is unreviewed by ear.
- Quest objectives that count events (gather, craft, place, harvest) only count while that quest is active. Discover, region, landmark, befriend and shelter objectives are counted retroactively.
- No iOS build, no multiplayer, no cloud save, no in-app purchases, no ads (by design).
- Only a **debug** APK is produced. Release signing and Play Store packaging are not set up.
- Not implemented: more than one boss, weather, creature breeding, mounts, wall/ceiling decoration, localization.

## Project layout

```
project.godot, export_presets.cfg, icon.svg
scenes/        boot, main menu, world scenes
scripts/       core (data, game state), inventory, crafting, quests, saving, audio,
               player, creatures, world, building, ui
tests/         run_tests.gd (unit), playthrough.gd (scripted playthrough)
docs/          ASSETS, SAVE_SYSTEM, TESTING, TROUBLESHOOTING
.github/workflows/android-build.yml
```

## Running the tests locally

See [docs/TESTING.md](docs/TESTING.md).

## Docs

[Assets & licensing](docs/ASSETS.md) · [Save system](docs/SAVE_SYSTEM.md) · [Testing](docs/TESTING.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)

WILDFRONT is an original work. It is not affiliated with, and uses no assets or branding from, any other game.
