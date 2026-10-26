# Build and install

## From GitHub Actions (no local setup)

1. Open the repository's **Actions** tab, choose **Android Build**, and open a successful run (or press **Run workflow**).
2. Download the `Project-Wildlands-apk` artifact and unzip it.
3. Copy `Project-Wildlands.apk` to the phone and install it (allow "install unknown apps" for your file manager if asked).

The APK is a debug build signed with a throwaway keystore created during the run. It is meant for testing, not the Play Store.

## Locally

Requirements: Godot 4.3-stable with Android export templates, JDK 17, Android SDK (build-tools 34, platform 34), and the editor's Android SDK path configured.

```
godot --headless --path . --import
godot --headless --path . --export-debug "Android" build/Project-Wildlands.apk
```

Package name: `com.wildlands.survival`. Architecture: arm64-v8a. Permissions: vibration only.

Run on desktop: open the project in Godot 4.3 and press Play.
