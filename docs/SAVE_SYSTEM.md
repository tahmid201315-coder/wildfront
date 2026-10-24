# Save system

Files in Godot's `user://` directory (private app storage on Android):

- `save.json` - current save. `save.bak` - previous good save. `save.tmp` - temporary during a write.
- `settings.json` - settings, stored separately so a bad save never loses them.

## Write procedure (atomic)
1. Serialize game, inventory, quests and world to JSON and write `save.tmp`.
2. Read `save.tmp` back and validate it. If invalid, delete it and keep the old save.
3. Move current `save.json` to `save.bak`.
4. Rename `save.tmp` to `save.json`.

## Load procedure
1. Parse and validate `save.json`. On success, use it.
2. If it is corrupt, try `save.bak` and tell the player a backup was restored.
3. If both fail, show a clear message; the player may start a New Game. Nothing crashes.
4. Saves from a **newer** save version than the game understands are refused rather than guessed at.

## Versioning
`save_version` (currently 1) is stored in each save. `Save.migrate()` is the place for future upgrades; no migrations exist yet.

## When it saves
Pause menu Save, quest completion, building placement, and automatically when the app is paused, the back button leaves the game, or the app closes. Offline progress (crops, production) is caught up on load, clamped to 30 minutes.
## New Game
Asks for confirmation, then deletes the save.
