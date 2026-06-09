# DeadSwitch

A dead man's switch for Android. Set a countdown timer — if you don't abort it in time, the app automatically sends pre-configured SMS/MMS messages to your chosen contacts.

Built with Flutter. Tested on Samsung Galaxy S24 Ultra (One UI 6).

---

## What it does

1. Press **Initiate Dead Switch** on the dashboard
2. A countdown timer starts (configurable delay, default 15 minutes)
3. If you **Abort** before time runs out, nothing happens
4. If the timer expires, every configured message is sent to its recipients via SMS or group MMS

The countdown shows as a heads-up notification immediately when triggered — visible on both the lock screen and notification shade. A foreground service and WorkManager backup keep the timer alive even if the phone sleeps.

---

## Features

- **Configurable trigger delay** — set any delay (minimum 1 minute) in Settings
- **Lock screen countdown notification** — appears immediately on trigger with a live countdown timer and skull icon
- **Multiple messages** — configure as many messages as you want, each with its own recipients
- **Group MMS** — messages with multiple recipients are sent as a group MMS thread; falls back to individual SMS if MMS fails
- **Contact picker** — select recipients from your contacts or type numbers manually
- **PIN lock** — app requires a PIN to open; re-locks when backgrounded
- **Test Send** — send all messages immediately without starting the timer (to verify the pipeline works)
- **SMS test** — send a single test message to any number from Settings
- **Web portal** — configure messages from a browser on the same Wi-Fi network
- **Skull and crossbones app icon** ☠

---

## Setup

### Permissions required

| Permission | Purpose |
|---|---|
| SMS | Send messages when triggered |
| Notifications | Show countdown timer |
| Contacts | Pick recipients from your contact list |
| Battery optimization exempt | Stay running when the screen is off |

SMS is a restricted permission on Android. On first launch the app walks you through: App Info → ⋮ menu → "Allow restricted settings" → Permissions → SMS → Allow.

### Install

Download `app-release.apk` from the [latest release](../../releases/latest) and sideload it.

---

## Architecture

| Component | Role |
|---|---|
| Flutter/Dart | UI and business logic |
| `flutter_local_notifications` | Countdown notification (channel `deadswitch_countdown_v6`, IMPORTANCE_HIGH) |
| `flutter_foreground_task` | Foreground service to keep the process alive during countdown |
| WorkManager | Backup scheduler if the process is killed before the timer fires |
| SQLite (`sqflite`) | Stores pending triggers, messages, recipients, and trigger log |
| `shared_preferences` | Persists settings (PIN hash, delay minutes, web portal toggle) |
| Native Kotlin (`MainActivity`) | Creates notification channels; SMS and group MMS via `SmsManager` |
| `shelf` HTTP server | Optional LAN web portal for configuring messages from a browser |

### Notification on Samsung One UI

Samsung One UI forces all notification channels to `mLockscreenVisibility=-1000` (VISIBILITY_NO_OVERRIDE) regardless of what apps set — this affects every app on the device including system apps. Samsung uses the **notification-level** `visibility` field instead. The countdown notification posts with `visibility=PUBLIC`, which Samsung honours for lock screen display.

The channel uses the device's default notification sound, which is what causes Samsung One UI to show the heads-up pop-up banner immediately when the trigger fires. `onlyAlertOnce: true` prevents the sound from repeating on subsequent timer updates.

At each launch, `MainActivity.createNotificationChannels()` checks whether the channel was previously created with sound suppressed (older installs) and deletes + recreates it if so.

---

## Building from source

```bash
git clone https://github.com/SirBiggin/Deadswitch.git
cd Deadswitch
flutter pub get
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

Requires Flutter 3.x and Android SDK with build tools.

---

## Version history

| Version | Notes |
|---|---|
| 1.2.48 | Fix WorkManager init (was broken inside runZonedGuarded); fix logger concurrent write interleaving |
| 1.2.47 | Add debug log file (100 MB rotating, readable via ADB) |
| 1.2.46 | Remove Test Send Now button from dashboard |
| 1.2.45 | Fix heads-up notification on Samsung One UI — channel now uses default sound to trigger banner; dynamic trigger delay wired through TriggerService |
| 1.2.44 | Notification posted immediately on trigger press (before foreground service starts) |
| 1.2.40 | Configurable trigger delay in Settings |
| 1.2.38 | Skull and crossbones app icon; larger skull + white text in notification |
| 1.2.35 | Remove "Tap to abort" from notification body |
| 1.2.24 | Lock screen countdown notification; PIN re-auth on app resume |
| 1.2.20 | Instant UI response on initiate and abort |
