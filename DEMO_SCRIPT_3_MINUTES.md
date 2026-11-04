# CareSignal AI — 3-Minute Demo Script

English narration, real Bengali voice request on the phone, English subtitles, real Meta-powered
workflow, real Firestore delivery, real acknowledgement.

## Setup before filming

```bash
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

```bash
flutter run --dart-define=CARESIGNAL_API_BASE_URL=http://<PC-LAN-IP>:8000
```

- Phone A = family owner / requester (signed in, approved viewer for Phone B already set up)
- Phone B = approved family viewer / recipient
- Both phones on the same network, backend reachable from both
- Screen recording on both phones, one shared camera angle

---

## 0:00 – 0:20 — The problem

> "AmarGuard already keeps families connected through live location sharing. CareSignal AI adds
> something new: an elderly family member can *speak* a request in their own language, and the family is
> contacted only after the sender reviews and confirms exactly what will be shared."

**On screen:** AmarGuard dashboard → Family Safety.

## 0:20 – 0:45 — The entry point

> "Inside Family Safety there is a new CareSignal AI card with a single large Need Help button. No
> separate app, no new account, no extra permission."

**On screen:** CareSignal AI Home, *Need Help* button in coral, privacy note.

## 0:45 – 1:05 — Consent before the microphone opens

> "Tapping Need Help does not start recording immediately. AmarGuard first explains that the recording
> will be processed by Meta Voice Transcribe, and asks for explicit permission. If the user declines,
> nothing is recorded and nothing is uploaded."

**On screen:** the consent dialog, English subtitle: *"Allow Meta AI to process this recording?"*

## 1:05 – 1:35 — The real Bengali voice request

> "Now the phone records a short push-to-talk clip in mono 16-bit PCM at 16 kHz, with a live timer and
> Stop and Cancel controls. Here is a real Bengali request."

**On screen:** the recording screen with the timer running.

**Spoken (Bengali, subtitle in English):** আমি পথ হারিয়ে ফেলেছি, আমার ছেলেকে জানাও।
*"I am lost. Please inform my son."*

Tap **Stop**.

## 1:35 – 1:55 — Meta Muse Voice Transcribe 1.0

> "The clip goes to the FastAPI backend over an authenticated connection. The backend normalises the
> audio and calls the Meta transcription endpoint with `muse-voice-transcribe-1.0` in `PUSH_TO_TALK`
> mode, with a Bengali language bias."

**On screen:** *Transcribing your voice* state.

> "The transcript arrives in Bengali. The user can fix a misheard word before anything else happens,
> and the original transcript is preserved separately from the correction."

**On screen:** the transcript review screen with the Bengali text in the editable field.

## 1:55 – 2:20 — Meta Muse Spark 1.3 as a tool-calling agent

> "Now Muse Spark 1.3 interprets the request. This is a real agent loop, not a keyword matcher: the
> model asks the backend for the approved family contacts, the last authorized location and the last
> reported battery. The backend enforces ownership and revocation on every tool call — the model can
> never read a collection path or widen its own permissions."

**On screen:** the AI Processing screen with the step list, then the AI Help Summary.

> "The report shows the request type, the detected language, both transcripts, the assistance summary,
> the last known location with accuracy and freshness, the last reported battery, the approved
> recipients and suggested safe actions. Nothing is invented: if a value is unavailable it is marked
> unavailable, and an old location is always labelled last known, never live."

## 2:20 – 2:40 — Confirm and send

> "Nothing has been sent yet. The owner reviews the transcript, the summary and the data that will be
> shared, picks one approved family member, and confirms. Cancelling sends nothing."

**On screen:** recipient picker, then the confirmation dialog, then **Send now**.

## 2:40 – 2:55 — Real Firestore delivery to Phone B

> "The request is written to Firestore with a server timestamp and an idempotent request id, so a
> double tap cannot create two alerts. Firestore rules only allow the sender and the intended
> recipient to read it."

**On screen (Phone B):** the Family Help Inbox with the request, the original message, the AI summary,
the last known location, the battery and the creation time.

## 2:55 – 3:00 — Real acknowledgement

> "The recipient acknowledges, and Phone A sees the status change to acknowledged in the same session."

**On screen (Phone B):** tapping **Acknowledge Help**.
**On screen (Phone A):** the sent request showing *Acknowledged*.

**Closing line:** "Voice in, verified data, human confirmation, real family delivery — built with the
Meta Model API."

---

## Manual two-phone validation — UNVERIFIED in this environment

Two physical devices were not available, so this scenario is not verified. Run it before the demo:

1. Sign Phone A in as the family owner; complete the invitation flow so Phone B becomes an approved
   viewer of Phone A's device.
2. On Phone A, enable location sharing and let one sync complete.
3. On Phone B, open the app and confirm the family member appears with live status.
4. On Phone A, open **Family Safety → CareSignal AI → Need Help**, grant the consent, record
   "আমি পথ হারিয়ে ফেলেছি, আমার ছেলেকে জানাও।", stop, and review the transcript.
5. Continue to the summary, confirm the location shown is Phone A's own last known location, select the
   approved family member and send.
6. On Phone B, open the Family Help Inbox, verify the message, summary, location and battery come from
   Phone A's device, call the family member, and acknowledge.
7. On Phone A, confirm the acknowledgement appears.
8. Repeat the flow after restarting both apps to confirm persistence.

Record the outcome in the README's Verification status section before presenting.
Do not claim push-notification delivery unless it has been confirmed on a device.
