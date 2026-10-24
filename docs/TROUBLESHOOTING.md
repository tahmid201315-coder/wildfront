# Troubleshooting

**Workflow is red** - download the `build-logs-<n>` artifact; each step writes a log. The failing step name in Actions says where.
- *Checksum mismatch*: re-run; if persistent, the Godot release URL or version changed.
- *sdkmanager not found / Android SDK not found*: the runner image changed; adjust the "Install Android SDK packages" step.
- *Godot export errors / configuration errors*: usually missing SDK path, templates or keystore env vars (see the export log).
- *Unit tests / playthrough failed*: the log names the failed check.
- *GDScript errors during import*: see `import.log`.

**APK will not install** - allow installs from unknown sources; uninstall any older build signed with a different debug key; the device must be arm64 (nearly all phones since 2017) and Android 5+ (API 21+; untested).

**Game closes at start** - capture `adb logcat | grep -i godot` and open an issue with it.

**Stuck/slow** - Settings: lower Quality, set render scale 0.75, FPS 30.

**Corrupt save message** - the game tries `save.bak` automatically; otherwise start a New Game.
