## Quickstart (Dual-Screen Love2D on Android)

This SDK is a **two-fork setup**:

- **Engine fork** (`engine/`): provides the `love.dualscreen` native module.
- **Android wrapper fork** (`android/`): provides the Java `Presentation` + JNI bridge and builds the APK.

### Prerequisites

- **Android Studio** (recent stable)
- **Android NDK** installed via Android Studio SDK Manager
- A device which exposes a **secondary Android display** (e.g. Ayn Thor)

### 1) Clone + bootstrap

From the SDK repo root:

- Windows:

```powershell
.\scripts\bootstrap.ps1 -EngineRepoUrl "<YOUR_LOVE2D_FORK_URL>" -AndroidRepoUrl "<YOUR_LOVE_ANDROID_FORK_URL>"
```

- macOS/Linux:

```bash
./scripts/bootstrap.sh --engine "<YOUR_LOVE2D_FORK_URL>" --android "<YOUR_LOVE_ANDROID_FORK_URL>"
```

This will create:

- `engine/` (Love2D fork)
- `android/` (love-android fork)

### 1b) Sync engine into love-android (no junctions/symlinks)

If your `love-android` fork tracks the engine as a git submodule under `android/app/src/main/cpp/love`, run this to repoint it to your engine fork:

- Windows:

```powershell
.\scripts\sync-engine.ps1 -EngineRepoUrl "<YOUR_LOVE2D_FORK_URL>"
```

- macOS/Linux:

```bash
./scripts/sync-engine.sh android "<YOUR_LOVE2D_FORK_URL>"
```

### 2) Put a game in assets

Copy the template game into the embed assets folder:

- Source: `template/game/`
- Destination: `android/app/src/embed/assets/`

Minimum expected files:

- `main.lua`
- `conf.lua`
- `dualscreen.lua`

### 3) Build & run from Android Studio

1. Open the `android/` folder in Android Studio
2. Select build variant `embedNoRecordDebug` (or whichever your fork uses for embedded assets)
3. Run on device

### 4) Verifying the bottom screen

In the demo template, the bottom screen shows:

- a grid + player dot
- touch indicators (touching the bottom screen draws circles)

On desktop, you’ll see a **simulated dual-screen preview** in a single window.

