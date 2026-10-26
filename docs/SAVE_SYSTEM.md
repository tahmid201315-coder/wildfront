# Save system

- File: `user://save.json`, with `user://save.bak` as the previous good copy and `user://save.tmp` used while writing.
- Atomic write: the new save is written to the temp file and read back and validated; only then is the old save moved to the backup and the temp file renamed into place. If the rename fails the backup is restored. A crash mid-write leaves either the old or the new save.
- Corruption: on load, a save that fails to parse or fails validation is skipped and the backup is tried. If both fail the menu shows a clear message and offers a new game; the bad file is not deleted silently.
- Versioning: every save carries `save_version`. A save from a newer version than the game is refused rather than misread; older versions go through a `migrate` step (version 1 is current, so no migrations exist yet).
- Autosave: every 90 seconds, when the app is paused, and on Save and Quit. Saving is skipped while defeated or loading.
- Reset: "New Game" over an existing save asks for confirmation.
- Stored: player stats, level, skills, inventory and equipment, quests, logs, found sites, regions, fog of war, defeated bosses, opened containers, flags, structures with their state, depleted resources with respawn timers, enemy den state, death cache, respawn point, waypoint, time of day.
- Settings live separately in `user://settings.json`.
