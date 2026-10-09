# Changelog

## 1.0.4

- Allow the clothesline and capture animations to join other applications, full-screen Spaces and Stage Manager.
- Remove the original full-screen suppression and its private window-server API helper.
- Retain automatic retraction, the reveal shortcut and nonactivating click-through behavior.
- Include the upstream license inside the built application.
- Universal build and signature checks passed; real full-screen display across macOS versions remains to be verified.

## 1.0.3

- Set the native capture toolbar destination and save location together so recordings save directly to the inbox.
- Back up and restore destination settings, including sessions upgraded from earlier versions.
- Verify save-setting round trips with isolated test preferences.

## 1.0.2

- Collect completed, recognizable desktop system recordings into the internal inbox when capture handling is enabled.
- Move rather than duplicate files, avoid overwriting collisions, and retain originals on failure.

## 1.0.1

- Recognize the Simplified Chinese system recording filename prefix `录屏`.
- Add manual video import and use CaptureLine as the executable name.

## 1.0.0

- Derive CaptureLine from Alejandro Buján's Tendedero with a new application name and icon.
- Support MOV, MP4 and M4V, playable-file readiness checks, retry cancellation and duplicate prevention.
- Add asynchronous video covers, placeholders, file copying and external playback.
- Preserve screenshot markup, animations, dragging, capacity limits and path-based restoration.
- Update English, Spanish and Simplified Chinese interface translations.
