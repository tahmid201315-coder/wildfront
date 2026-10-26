# Project Wildlands

A third-person 3D open-world survival adventure for Android (desktop optional), built with Godot 4.3 (GDScript, Compatibility renderer, landscape).
Every model, texture, UI icon, music track and sound effect is generated procedurally in code at runtime. There are no third-party assets.

**Status: feature-complete first version, not yet tested on a physical device.** See [docs/TESTING.md](docs/TESTING.md) for exactly what has and has not been verified, and [docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md) for what is missing (for example, the optional rover is not built).

## The game

You crash-land on an island controlled by a dormant Consortium machine. Gather, craft, build a base, survive the climate, and follow 12 main quests across five regions to the Core Architect.

- Regions: Greenhaven Coast (start), Whispering Forest, Ironfall Highlands, Ashen Expanse (needs heat protection), Forgotten Core (story-unlocked).
- Survival: health, stamina, hunger, temperature (cold nights, heat in the Ashen Expanse, rain chill).
- Gathering with tool tiers, inventory with equipment, recipe crafting with stations and unlocks.
- Base building: grid snapping, placement preview and validation, doors, storage, turrets, dismantling with refund, saved structures.
- Real-time combat with light/heavy attacks, dodge, ranged weapons; 4 enemy types and 3 multi-phase bosses.
- XP, levels and a 3-branch skill tree (Survival, Combat, Engineering).
- Map with fog of war, discovered sites, waypoint and compass; day/night cycle; rain; ash fall; wildlife.
- Loot containers with one-time state, research logs, side quests, death cache, ending.

## Controls

Touch: left stick moves, drag the right side to look, buttons for attack, jump, dodge, interact, sprint and crouch. Top-right icons open Pause, Map, Pack, Craft and Journal. Left-handed layout and button size are in Settings.

Desktop: the mouse emulates touch (click-drag on the right side to look, click the on-screen buttons). Keyboard: WASD move, Space jump, F attack, R heavy attack, E interact, C dodge, Shift sprint. Desktop play has had less testing than the touch layout design.

## Build

See [docs/BUILD.md](docs/BUILD.md). The GitHub Actions workflow `.github/workflows/android-build.yml` runs on push, pull request and manual dispatch: it imports the project, runs the tests, exports a debug APK and uploads it as an artifact. No secrets are committed; a throwaway debug keystore is generated at build time.

## Docs

| File | Contents |
|---|---|
| [docs/FEATURES.md](docs/FEATURES.md) | Feature checklist with status |
| [docs/TESTING.md](docs/TESTING.md) | Test commands and honest results |
| [docs/BUILD.md](docs/BUILD.md) | Building and installing the APK |
| [docs/SAVE_SYSTEM.md](docs/SAVE_SYSTEM.md) | Save format, atomic writes, corruption handling |
| [docs/ASSETS.md](docs/ASSETS.md) | Asset and licence statement |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common problems |
| [docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md) | Missing features and risks |
