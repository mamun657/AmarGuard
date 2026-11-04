# AmarGuard — CareSignal AI + SilentSpeak AI (Meta Global AI Developer Hackathon 2026)

AmarGuard is a bilingual (Bengali / English) family safety app for Android. The repository contains the
existing AmarGuard product (Firebase Auth, Firestore family connections, GPS sharing, member rename and
member removal) plus **CareSignal AI** and **SilentSpeak AI**, built during the Meta Global AI Developer
Hackathon 2026.

## CareSignal AI in one sentence

Speak a short Bengali or English request, review the Meta-generated summary and the verified device data
that will be shared, pick one approved family member, and confirm. The request is saved for the selected
recipient's in-app inbox, where they can acknowledge it.

---

## Repository layout

```
amarguard/
├─ lib/
│  ├─ features/family_safety/        # existing Family Safety module + CareSignal AI screens
│  │  ├─ controllers/caresignal_controller.dart
│  │  ├─ services/caresignal_api.dart
│  │  ├─ services/caresignal_recorder.dart
│  │  └─ screens/caresignal_*.dart
│  ├─ features/silent_speak/         # Speak for Me + Listen & Understand
│  ├─ l10n/app_en.arb, app_bn.arb    # bilingual strings for every new screen
│  └─ …
├─ backend/                          # isolated FastAPI service for Meta Model API
│  ├─ app/
│  │  ├─ main.py, routes.py, config.py, auth.py
│  │  ├─ meta_client.py, voice_service.py, agent_service.py
│  │  ├─ family_tools.py, incident_service.py, models.py
│  │  └─ audio_utils.py, firebase_gateway.py, errors.py
│  ├─ tests/
│  ├─ requirements.txt
│  └─ .env.example
├─ firestore.rules                   # includes the helpRequests collection rules
├─ tool/firestore_rules_test.js      # Firestore Emulator rules test suite
└─ test/                             # Flutter unit / widget tests
```

---

## Features

### Pre-existing AmarGuard work

- Firebase Authentication (email sign-in)
- Firestore-backed family invitations and approved viewers
- GPS / location sharing with freshness and battery status
- Family member rename and member removal
- English and Bengali localisation

### CareSignal AI (created during the hackathon)

- **Need Help** entry point inside the existing Family Safety module
- Push-to-talk recording with explicit microphone permission and an explicit
  "allow Meta AI to process this recording" consent step **before** recording starts
- Mono 16-bit PCM WAV at 16 kHz or 24 kHz; anything else is converted server-side
- Meta **Muse Voice Transcribe 1.0** (`POST /asr/transcribe`, `PUSH_TO_TALK`) for Bengali, English and
  Bengali-English code-switching
- Editable transcript review — the original transcript is stored separately from the AI interpretation
- **Meta Muse Spark 1.3 tool-calling agent** with seven allowlisted, permission-checked tools
- Structured assistance report (request type, detected language, both transcripts, summary, last known
  location + accuracy + timestamp + freshness, last reported battery, approved recipients, safe actions,
  `consent_required`)
- Confirm-and-send screen that shows exactly what will be shared before anything is sent
- Firestore `helpRequests` collection with server timestamps, idempotent creation and recipient-only
  acknowledgement
- Family Help Inbox + response details with call, map and acknowledge actions
- Full English / Bengali localisation of every new screen, button, error and status label

### SilentSpeak AI

- Two independent modes: offline pictogram-to-message communication, and push-to-talk
  transcription with Meta Muse Voice Transcribe.
- Mode preference is optional and stored only in local SharedPreferences. No medical
  diagnosis or accessibility preference is saved to Firestore.
- The original Listen & Understand transcript stays on the device. Family Help requires
  a separate user-edited message, a server-verified approved recipient, and final confirmation.
- SilentSpeak requests use the authenticated `/family/contacts` and `/help-request`
  endpoints, Firestore request history, and the in-app inbox and acknowledgement flow.
  Their server-side `include_location=false` option prevents attaching a location or
  battery snapshot. The FCM code path exists, but device delivery has not been verified;
  see [Verification status](#verification-status).
- Temporary recording files are deleted after transcription; no continuous/background
  microphone use is implemented. Read Aloud remains disabled because platform TTS has
  not been verified for this build.

---

## Meta Model API configuration

The Meta credential is read **only** by the backend from `MODEL_API_KEY`. It is never placed in Dart
files, Flutter assets, git history, this README, logs or HTTP responses.

```bash
cd backend
python -m venv .venv
.\.venv\Scripts\pip.exe install -r requirements.txt
copy .env.example .env
```

Edit `backend/.env` and set:

| Variable | Purpose |
|---|---|
| `MODEL_API_KEY` | Meta Model API credential (required) |
| `META_BASE_URL` | Defaults to `https://api.meta.ai/v1` |
| `META_CHAT_MODEL` | Defaults to `muse-spark-1.3` |
| `META_TRANSCRIBE_MODEL` | Defaults to `muse-voice-transcribe-1.0` |
| `FIREBASE_PROJECT_ID` | Firebase project used for ID-token verification and Firestore |
| `FIREBASE_CREDENTIALS_PATH` | Service account JSON path (local development) |
| `ALLOWED_ORIGINS` | Comma-separated origins, `*` for local development only |
| `MAX_AUDIO_UPLOAD_BYTES` | Upload ceiling, default 10 MB |
| `MAX_AUDIO_DURATION_SECONDS` | Recording length ceiling, default 120 s |
| `REQUIRE_HTTPS` | Set `true` for any internet-exposed deployment |

### Verify the real Meta connection

```bash
cd backend
.\.venv\Scripts\python.exe tests\check_meta_connectivity.py
```

The script prints `RESULT: SUCCESS` with the actual model identity and usage metadata, or
`RESULT: BLOCKED` with the exact blocker when `MODEL_API_KEY` is missing.

The backend also requires Firestore credentials for family recipients, authorized
location, battery status, and help-request writes. `FIREBASE_PROJECT_ID` alone is
not sufficient. For local development:

1. In Firebase Console, open **Project settings → Service accounts** and generate a
   Firebase Admin service-account key for the same project as `FIREBASE_PROJECT_ID`.
2. Store the downloaded JSON outside this repository and restrict access to it.
   Never commit it, paste it into chat, or include it in a build artifact.
3. Set `FIREBASE_CREDENTIALS_PATH` in `backend/.env` to its absolute path, for example:

   ```dotenv
   FIREBASE_CREDENTIALS_PATH=C:/Users/you/secure/firebase-admin.json
   ```

4. Restart Uvicorn and check `/health` reports
   `"firestore_credentials_configured": true`.

Alternatively, configure Google Application Default Credentials for the backend
process. If neither source is configured, Firestore-dependent agent processing and
help-request operations return an explicit setup error; voice transcription can still
work independently.

The same Firebase Admin credentials are used for FCM sends. Ensure the Android app
is registered in this Firebase project with its matching `google-services.json`,
Cloud Messaging is enabled, and the backend service account is permitted to send
FCM messages (`cloudmessaging.messages.create`). FCM tokens are registered through
authenticated backend endpoints and stored in the Admin-only `fcmTokens` collection;
the Flutter client cannot read or write that collection directly.

### Configure Firebase before building

The generated Firebase client files are intentionally not committed. A fresh clone
needs both `lib/firebase_options.dart` (imported by the app) and
`android/app/google-services.json` (required by the Android Google Services Gradle
plugin) before it can build. The files contain Firebase project identifiers and client
API keys, not Firebase Admin credentials; keep them out of Git in this project.

Install the Flutter SDK version required by `pubspec.yaml` (Dart 3.13.1 or later),
Node.js/npm, and the Firebase CLI. For Android builds, also install the Android SDK
and JDK required by Flutter (`flutter doctor` reports missing toolchain components).
Then, in PowerShell from the repository root:

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
firebase projects:list
flutterfire configure --project=guard-ab0d3 --platforms=android,web,windows,macos
```

Use the Firebase project configured for the app (`guard-ab0d3`), or substitute a
Firebase project you administer and configure its services and rules for that project.
The Android Firebase app must use the application ID
`com.binarypulse.amarguard`. The FlutterFire CLI generates
`lib/firebase_options.dart` and configures the selected platforms. If
`android/app/google-services.json` was not generated, download it from Firebase
Console → **Project settings** → **General** → the Android app
(`com.binarypulse.amarguard`) → **Download google-services.json**, then save it at
`android/app/google-services.json`.

Confirm both files exist, then build:

```powershell
flutter pub get
flutter gen-l10n
flutter build apk --debug
```

To run Firebase-backed features, also enable the Firebase products used by the app
(including Email/Password Authentication and Cloud Firestore) in that project and
deploy the Firestore rules and indexes. CareSignal's Meta AI, server-verified family
operations, and push-send path additionally require the separately configured backend;
its Meta API key and Firebase Admin service-account credentials are not needed to
compile the Flutter app and must never be committed. Keep both generated Firebase
client files and `android/local.properties` local; `.gitignore` excludes them.

Deploy the help-request query indexes with
`firebase deploy --only firestore:indexes --project guard-ab0d3`. No new Firestore
security-rule deployment is needed for the CareSignal token workflow; the existing
help-request rules remain restrictive and are exercised by the rules test suite.

---

## Running the backend

```bash
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8001
```

When starting from the repository root, use:

```bash
.\backend\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port 8001
```

- Android emulator → `http://10.0.2.2:8001` (the default)
- Physical phone on the same Wi‑Fi → `--dart-define=CARESIGNAL_API_BASE_URL=http://<PC-LAN-IP>:8001`
- Physical phone over USB → run `adb reverse tcp:8001 tcp:8001`, then use
  `--dart-define=CARESIGNAL_API_BASE_URL=http://127.0.0.1:8001`

For local development, the app uses a platform-aware default: Android emulator
uses `http://10.0.2.2:8001`, while desktop builds default to
`http://127.0.0.1:8001`. A physical phone cannot use the emulator's `10.0.2.2`
address: configure its reachable PC LAN address or use the USB reverse tunnel
above. Replace the host with the reachable development host; use a stable HTTPS
URL for production rather than committing a LAN address.

For production, deploy the backend at a stable HTTPS URL and configure that URL
with `CARESIGNAL_API_BASE_URL`; the local network examples above are for development
only. On Android 13 and later, allow notifications when prompted. CareSignal uses
the `care_signal_requests` notification channel. The push contains only a request
ID and a generic preview; location and message details are fetched after the
authenticated recipient opens the request.

### Manual CareSignal device check (not yet verified)

The following is a verification procedure, not a report of completed testing. In
particular, end-to-end FCM notification delivery to a device has not been verified.

1. Install a build configured for the same Firebase project on both phones. Sign in
   as different users and approve the connection from the sender to the recipient.
2. Open AmarGuard on the recipient phone, allow notifications, and keep it signed
   in so its current FCM token is registered with the backend.
3. On the sender phone, create a CareSignal request that says “father” / “বাবা”.
   Confirm the recipient's saved name and relationship on the review screen before
   sending. If the transcript says “son” while the AI suggests “father”, the app
   must require manual recipient selection rather than silently choosing either.
4. In development backend logs, verify recipient validation and the matching
   `request_id`, sender UID, and recipient UID. Do not copy or log FCM tokens or
   precise location. In Firestore Admin Console, verify the corresponding
   `helpRequests/{requestId}` has the intended `recipientUid` and saved content.
5. On the recipient phone, open **Incoming CareSignal Requests** and verify the
   request appears with its sender, text, and timestamp. Acknowledge it and verify
   the sender sees the acknowledged state.
6. Put the recipient app in the background, send another request, and observe
   whether an Android notification appears. Tap it and verify it opens that
   specific request. `notification_status=submitted` means FCM accepted a send;
   it does not prove that the device displayed or the recipient read it.
7. Repeat with notifications disabled or the recipient offline. After reconnecting,
   open the inbox and verify the saved request is still available.

---

## Verification status

During this push preparation, the backend suite passed: 97 tests passed with one warning.
The focused Flutter tests could not start because Windows plugin builds require symlink
support, and Developer Mode is not enabled. The Firebase Emulator rules suite and
device-level tests were not run.

The CareSignal and SilentSpeak code includes FCM token registration and a backend send
path, but actual notification receipt, display, and tap-through on a device remain
unverified. An FCM status of `submitted` means the FCM service accepted the send
request; it does not prove device delivery. Firestore-backed requests and the in-app
inbox are separate from push delivery.

---

## Running the app

```bash
flutter pub get
flutter gen-l10n
flutter run --dart-define=CARESIGNAL_API_BASE_URL=http://10.0.2.2:8001
```

---

## Tests

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --debug

cd backend
.\.venv\Scripts\python.exe -m pytest

cd ..
firebase emulators:exec --only firestore --project guard-ab0d3 "node tool/firestore_rules_test.js"
```

## Security posture

- Firebase ID token verification on every private endpoint
- Server-side ownership, approved-viewer and revocation checks — the model never authorises itself
- Tool allowlist with validated arguments and bounded agent rounds
- Explicit consent before voice processing; explicit confirmation before sharing
- Bounded audio uploads, request validation and redacted logs
- `helpRequests` readable only by the sender and the intended recipient; only the recipient may
  acknowledge; privileged fields are immutable
- No continuous microphone capture, no covert tracking, no automatic emergency contact, no medical or
  risk-score claims

Further reading: `META_AI_ARCHITECTURE.md`, `DEMO_SCRIPT_3_MINUTES.md`.
