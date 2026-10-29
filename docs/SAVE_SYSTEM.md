# Save system
- 3 slots at `user://save_N.json`. Each file: `{save_version, saved_unix, game:{...}}`.
- Write path: write `.tmp`, re-read and validate it, rotate the old file to `.bak`, rename `.tmp` to `.json`.
- Load: validates types; if the main file is missing/corrupt it tries `.bak`; otherwise reports "damaged" and the game stays on the title screen.
- Values are clamped on load (unknown skills/equipment dropped, counts clamped).
- `save_version` is migrated by `Save.migrate`.
- Autosave on shrines, boss defeat, chests/altars, quit to title.
- Settings are stored separately in `user://settings.json`.
