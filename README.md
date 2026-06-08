# ☠ DeadSwitch

A dead man's switch for Android. Configure messages to specific people — if you don't abort in time, they all go out automatically via SMS.

---

## How It Works

1. **Initiate** the switch from the Dashboard
2. A **15-minute countdown** begins
3. If you **abort before time runs out**, nothing happens
4. If the timer expires, every configured message is sent via SMS automatically
5. You can re-initiate at any time after aborting or after a send

The intent is that you check in regularly and abort the switch. If something happens to you and you stop checking in, the messages go out on their own.

---

## Required: httpsms App

DeadSwitch does **not** send SMS directly from the app. It uses [httpsms.com](https://httpsms.com) as the SMS relay layer. This requires two things:

### 1. httpsms Android App
Install the **httpsms** app on the **same phone** running DeadSwitch (or any Android phone that stays online):

- [Download from Google Play](https://play.google.com/store/apps/details?id=com.httpsms)
- The app runs in the background and listens for send requests from the httpsms API
- Your phone's SIM card is used to physically send the SMS messages
- The phone must be online and the httpsms app must be running when the trigger fires

### 2. httpsms Account + API Key
- Create a free account at [httpsms.com](https://httpsms.com)
- Go to **Settings → API Key** and copy your key
- Register your phone number in the httpsms dashboard
- Enter both the API key and your phone number in the DeadSwitch **Settings** tab

> Phone numbers must be in E.164 format: `+12025551234`. DeadSwitch auto-formats US numbers on save.

---

## Features

### Individual Messages
Configure a personal message for each recipient. When the switch triggers, every person gets their own tailored message sent directly to their phone number.

- Add recipients manually or pick from your phone's contacts
- Each recipient has their own unique message
- Edit or delete at any time

### Groups
Send one shared message to multiple people at once.

- Create named groups (e.g. "Family", "Work", "Emergency Contacts")
- Add recipients by picking from your phone's contacts or entering manually
- Each group has its own message text
- Multiple groups can be configured — all trigger simultaneously

### Web Portal
A built-in local web server lets you manage everything from a browser on the same Wi-Fi network — no need to interact with the phone directly.

**To enable:**
1. Go to **Settings → Web Portal** and toggle it on
2. The URL appears (e.g. `http://192.168.1.x:8080`)
3. Open that URL in any browser on the same network
4. Enter your PIN to unlock
5. Manage Individual Messages, Groups, and API settings from the browser

The portal provides the same full CRUD interface as the app — add, edit, and delete messages and groups from a desktop or laptop.

### PIN Protection
The app is protected by a numeric PIN set on first launch. The same PIN is required to access the web portal.

---

## Setup Guide

### First Launch
1. Install the APK
2. Set a PIN when prompted — **save this, there is no recovery**
3. Go to **Settings** and enter your httpsms API key and phone number
4. Tap **Send Test Message** to verify SMS delivery is working
5. Add your recipients under **Individual Messages** and/or **Groups**
6. Return to **Dashboard** and initiate the switch to test the flow

### Building from Source

**Prerequisites:**
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (Dart 3.12+)
- Android SDK (API 36 / Android 16 target)
- Java 17+

```bash
git clone https://github.com/SirBiggin/Deadswitch.git
cd Deadswitch
flutter pub get
flutter build apk --release
```

The release APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

> `android/local.properties` is not included in the repo (machine-specific). Flutter generates it automatically when you run `flutter build` with a valid Android SDK installed.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Local database | SQLite via `sqflite` |
| SMS delivery | httpsms.com REST API via `http` |
| Background scheduling | WorkManager via `workmanager` |
| Web portal server | `shelf` + `shelf_router` |
| Contact picker | `flutter_contacts` |
| Permissions | `permission_handler` |
| Settings storage | `shared_preferences` |

### Database Schema
- **contacts** — individual message recipients (name, phone, message)
- **message_groups** — group definitions (name, shared message)
- **group_recipients** — recipients per group (independent of contacts table)
- **pending_triggers** — scheduled send jobs with status tracking
- **trigger_log** — history of all trigger events

### Background Execution
WorkManager is used to schedule the 15-minute delayed send. The task runs even if the app is backgrounded. On Android 16+, WorkManager's auto-initialization ContentProvider is disabled in `AndroidManifest.xml` and initialized manually in code to prevent crash-on-launch.

---

## Permissions

| Permission | Reason |
|---|---|
| `INTERNET` | httpsms API calls |
| `READ_CONTACTS` | Contact picker for adding recipients |
| `ACCESS_NETWORK_STATE` | Web portal: display local IP address |
| `RECEIVE_BOOT_COMPLETED` | Re-schedule pending triggers after reboot |
| `WAKE_LOCK` | Keep CPU awake during background send |
| `SCHEDULE_EXACT_ALARM` | Precise 15-minute trigger timing |
| `POST_NOTIFICATIONS` | WorkManager task notifications |
| `FOREGROUND_SERVICE` | Background task execution |

---

## Architecture Notes

- **No cloud dependency** beyond httpsms — all data stays on-device in SQLite
- **Web portal** binds to `0.0.0.0:8080` — accessible from any device on the same LAN
- **PIN auth** is used for both the app lock screen and the web portal Bearer token
- **Phone number normalization** is applied at all entry points — 10-digit US numbers are automatically formatted to E.164 (`+1XXXXXXXXXX`)
- Group recipients are stored independently from individual contacts, so the same person can appear in both without duplication constraints

---

## License

MIT
