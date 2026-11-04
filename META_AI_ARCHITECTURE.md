# CareSignal AI — Meta AI Architecture

## 1. Component map

```
┌────────────────────────── Android app (Flutter) ──────────────────────────┐
│  Family Safety → CareSignal AI                                              │
│    • Need Help → consent → record → transcript review → summary → confirm   │
│    • Family Help Inbox → response details → acknowledge                     │
│    • CareSignalApi (Bearer Firebase ID token, never the Meta key)          │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                │ HTTPS / dev HTTP on the LAN
┌───────────────────────────────▼─────────────────────────────────────────────┐
│  FastAPI backend (backend/app)                                              │
│  routes.py  ── auth.py (Firebase ID token verification)                     │
│      ├── audio_utils.py  → mono 16-bit WAV, 16 kHz / 24 kHz                 │
│      ├── voice_service.py → meta_client.transcribe()                        │
│      ├── agent_service.py → meta_client.chat() + tool loop                  │
│      │        └── family_tools.py → permission-checked Firestore reads      │
│      └── incident_service.py → helpRequests read / create / acknowledge     │
│                                    │                                        │
└────────────────────────────────────┼────────────────────────────────────────┘
                                     │
              ┌──────────────────────▼───────────────────────┐
              │ Meta Model API (https://api.meta.ai/v1)        │
              │  • muse-spark-1.3  (chat completions + tools)  │
              │  • muse-voice-transcribe-1.0 (asr/transcribe)   │
              └───────────────────────────────────────────────┘
```

## 2. Models and endpoints

| Purpose | Model / endpoint |
|---|---|
| Chat + tool calling | `muse-spark-1.3` via the OpenAI-compatible Python SDK (`/chat/completions`) |
| Speech-to-text | `muse-voice-transcribe-1.0` via `POST /asr/transcribe`, `mode: PUSH_TO_TALK` |

`MODEL_API_KEY` is read from the backend environment only. It is never present in Dart sources,
Flutter assets, git history, documentation, logs or HTTP responses.

## 3. Multi-step agent workflow

1. The reviewed transcript plus the selected app language go to the backend `/agent/process`.
2. The backend builds a `ToolContext` from the **verified Firebase ID token** (uid, email, display name)
   and the caller's own device id.
3. Muse Spark 1.3 is called with the seven tool definitions and `tool_choice: auto`.
4. Every requested tool call is dispatched through `FamilyTools.execute()`, which:
   - rejects any name that is not on the allowlist,
   - resolves the Firestore path itself from `context.uid` and `context.device_id`,
   - verifies `ownerUid` / `deviceId` ownership before reading,
   - filters approved viewers by `active == true`,
   - withholds location coordinates when sharing is stopped, paused-by-policy or revoked.
5. Tool results are appended to the conversation as `tool` messages and the model is called again.
   The loop is bounded to `MAX_AGENT_ROUNDS = 5`.
6. The final model output is a JSON object, but the authoritative report fields are rebuilt from the
   **tool payloads**, not from the model's free text. The model can only choose the wording of the
   summary and the suggested safe actions.
7. The structured summary is validated with Pydantic (`AssistanceSummary`) and returned to the app.

## 4. Voice pipeline

| Stage | Behaviour |
|---|---|
| Capture | `record` package, mono, PCM 16-bit, 16 kHz |
| Permission | Android `RECORD_AUDIO` requested by the plugin; denial surfaces a localised message |
| Consent | Explicit in-app dialog **before** recording starts; the backend also rejects `consent_to_process=false` |
| Upload | Multipart POST to `/voice/transcribe` with the Firebase ID token |
| Normalisation | Server-side: mono 16-bit WAV at 16 kHz or 24 kHz; other rates/channels are resampled with the standard library, and oversized or too-long clips are rejected |
| Meta call | `languageBias` = `["Bengali"]`, `["English"]` or `["Bengali", "English"]` |
| Result | Transcript returned to the app for review; the audio is not persisted by the backend |

## 5. Authorization model

- **Transport**: every private route depends on `require_user`, which verifies the Firebase ID token
  (`check_revoked=True`). Missing or invalid tokens return 401.
- **HTTPS**: authenticated endpoints reject non-HTTPS requests when the host is not a local development
  address; production deployments must set `REQUIRE_HTTPS=true` and terminate TLS upstream.
- **Tools**: the backend, not the model, decides what a user may read. A tool call can never name a
  collection path.
- **Help requests**: creation requires an active approved viewer for the sender's own device; reading is
  restricted to the sender and the intended recipient; acknowledgement is recipient-only.
- **Firestore rules**: the `helpRequests` block in `firestore.rules` mirrors the backend checks, so a
  compromised client still cannot read another account's request.

## 6. Error handling

| Condition | Backend response | Flutter behaviour |
|---|---|---|
| Missing `MODEL_API_KEY` | 503 `missing_api_key` | Localised "service not configured" state |
| 401 from Meta | 502 `unauthorized` | Safe message, no credential text |
| 403 from Meta | 502 `forbidden` | Safe message |
| 429 from Meta | 429 `rate_limited` | Safe message, no automatic retry loop |
| 400 from Meta | 400 `invalid_request` | Safe message |
| Network timeout | 504 `timeout` | Safe message |
| 5xx from Meta | 502 `server_error` | Safe message |
| Oversized audio | 413 `payload_too_large` | Safe message |
| Bad WAV | 400 `unsupported_audio` | Safe message |

The Flutter client never retries automatically, so a failing Meta credential cannot generate a stream of
billable calls.

## 7. Data minimisation

Only the fields required for an assistance request are stored: the transcripts, the generated summary and
a verified snapshot of the values the user actually approved (location, accuracy, timestamp, freshness,
battery, request type, language, safe actions). Raw audio is not retained. The Meta key, full Firestore
snapshots and unrelated account data never leave the backend.
