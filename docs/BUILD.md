# Build
Requires Godot 4.3-stable.
- Run tests locally: `godot --headless --path . res://tests/test_core.tscn` (see `tests/suite.txt` for all suites).
- Android: `.github/workflows/android-build.yml` installs Godot + export templates, imports, runs every suite in
  `tests/suite.txt` (fails on `, 0 failed` missing or `SCRIPT ERROR`), creates a throwaway debug keystore at run time
  (nothing secret is committed) and exports `build/Project-Starfall.apk` (arm64-v8a, debug). Run it from the Actions tab
  or push to a branch.
- Package: `com.starfall.shatteredsky`.
