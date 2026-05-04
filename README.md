# DS Love Android SDK (Dual-Screen)

![LoveDS Logo](assets/logo.png)

This folder is intended to become the **developer entrypoint repo** for building dual-screen Android games (Ayn Thor and similar devices) using:

- a modified **Love2D engine** fork (C++), which provides `love.dualscreen`
- a modified **love-android** fork (Gradle/Java), which provides the secondary-display `Presentation` + JNI bridge
- a Lua convenience library (`dualscreen.lua`) used by game code

## Status

This is the **meta-repo** / superproject. It pins the engine + Android wrapper forks as submodules and adds docs + scripts + a template game.

## Quickstart

See:

- `docs/QUICKSTART.md`
- `docs/GAME_GUIDE.md`

## Forks

This SDK expects two forks to be pinned (typically via git submodules):

- `engine/` → your Love2D fork (contains `src/modules/dualscreen/`)
- `android/` → your love-android fork (contains DualScreenManager / SecondaryPresentation)

Bootstrap scripts will set this up once you provide the repo URLs:

- `scripts/bootstrap.ps1`
- `scripts/bootstrap.sh`

