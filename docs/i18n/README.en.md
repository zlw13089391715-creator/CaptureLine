# CaptureLine

[简体中文](../../README.md) · English · [Español](README.es.md)

CaptureLine organizes macOS screenshots and screen recordings on a clothesline at the top of the screen, ready to copy, drag or open.

Derived from [Tendedero](https://github.com/alejandrobujan/tendedero), created by **Alejandro Buján**. The clothesline concept and original implementation come from Tendedero. This version is independently maintained and is not affiliated with or endorsed by its author. See [CREDITS.md](../../CREDITS.md) and [LICENSE](../../LICENSE).

## Features

- System screenshots and MOV, MP4 and M4V recordings.
- Asynchronous video covers. Click to copy the file; double-click or hold to open the default player.
- Screenshot copying and system Markup, dragging, animations and restart restoration.
- “Handle screenshots and recordings” saves new system captures directly to the inbox, bypassing the Desktop. Previous settings return on normal exit or disabling the option.
- Reveal the line over apps, desktop Spaces, full-screen apps and Stage Manager at the top edge or with **Control+Option+T**. Move away to retract it.
- Local operation, with no account, analytics or media uploads.

## Install and use

Requires macOS 14 or later. Builds support Apple silicon and Intel.

This repository contains source. If [Releases](https://github.com/zlw13089391715-creator/CaptureLine/releases) has an application ZIP, download it; otherwise build below. Local packages are ad hoc signed and have not been notarized by Apple. If macOS blocks opening, allow it in System Settings → Privacy & Security.

Move CaptureLine.app to Applications, quit Tendedero or any older CaptureLine instance, and launch. Enable capture handling and use standard screenshot shortcuts or Command+Shift+5 to record. Recordings hang after saving finishes and the video track is readable. Close and reopen an already-open capture toolbar after changing the save setting.

The inbox is `~/Library/Application Support/CaptureLine/Screenshots`, including videos. The line references the file without duplicating it. The cross moves inbox items to the Trash; taking down external items keeps their files. Use “Show in Finder” or “Save to Desktop” in the context menu. Ordinary Desktop videos are ignored; use “Add recording…” to import existing videos.

## Build and checks

Install Xcode or Command Line Tools with Swift:

```sh
git clone https://github.com/zlw13089391715-creator/CaptureLine.git
cd CaptureLine
bash scripts/build-app.sh
open build/CaptureLine.app
swift scripts/check-strings.swift
bash scripts/check-recordings.sh
```

The script can fall back to an installed macOS 26 SDK; `SDKROOT` can select a compatible SDK. Full Xcode may be needed when Command Line Tools lacks SwiftUI macro plugins. Signing uses an available Developer ID or ad hoc fallback. The script does not notarize releases.

SwiftPM's internal module and source paths retain `Tendedero`; the app uses a separate name, executable, icon and bundle identifier.

Media integration checks, translation checks and universal builds passed. Actual system recording and direct inbox saving were verified. Version 1.0.5 fixes full-screen visibility. The user verified Desktop and full-screen revealing on the test Mac; other apps, Stage Manager and macOS versions still need verification. The deployment target does not mean every supported OS has been tested.

See [CHANGELOG.md](../../CHANGELOG.md). Code retains the upstream MIT license and copyright. Tendedero's name and icon are excluded from its license; CaptureLine uses its own name and icon and does not redistribute upstream promotional artwork.
