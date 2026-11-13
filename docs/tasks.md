# Tasks

How to use: start a Sonnet session (`claude --model sonnet`) and say "Do task T28 from docs/tasks.md". Read `docs/architecture.md` first.
**Agent** tasks: stay in scope, run the listed checks, finish with a short summary of what changed and what the human should verify. Don't commit; the human commits after testing.
**You** tasks: done by the human (new to Flutter) on Windows + a Pixel 6a. Flutter SDK and Android Studio are installed, `flutter doctor` is OK, developer mode is on.
Mark tasks done by changing `[ ]` to `[x]`. When a phase is finished, move it to `docs/done.md`.

---

## Phase 7: ElevenLabs voice (optional, user's own account)

Goal: a user with an ElevenLabs account (e.g. their own voice clone from the Impact Program) can use it in Mondom, with automatic fallback to an offline voice. Design and API facts: `docs/architecture.md` "ElevenLabs voice" (read it first). Never put a real API key in code, tests, docs or logs; tests use `package:http/testing.dart`'s `MockClient`.

### [x] T35 (Agent): API client and key store (no UI)
- Add `flutter_secure_storage` (approved 2026-11-13, BSD-3-Clause, which is GPL-3.0 compatible; credit it in About). Exclude its data from Android auto-backup (`android:fullBackupContent` / `android:dataExtractionRules` excluding the secure-storage shared-prefs file; check the package README for the file name). Add it to the approved list in `docs/architecture.md`.
- `lib/voices/elevenlabs_key_store.dart`: `abstract class ElevenLabsKeyStore { Future<String?> read(); Future<void> write(String); Future<void> clear(); }` with a secure-storage implementation and an in-memory fake for tests.
- `lib/voices/elevenlabs_client.dart`, taking an `http.Client` and the key:
  - `listVoices()` → `List<ElevenLabsVoice>` (`id`, `name` = the part of the API name before " - ", so "Brian - Deep, Resonant..." shows as "Brian"). All voices, no filtering and no labels; own voices (any `category` other than `premade`) first, then the rest, each group by name.
  - `synthesize(text, voiceId, modelId, languageCode)` → WAV bytes: PCM 22050 Hz from the endpoint wrapped in a WAV header (reuse the WAV writing helpers in `loudness.dart` if they fit). Timeout `elevenLabsTimeout` (4 s) on the whole request.
  - `subscription()` → `(used, limit, resetsAt)` from `GET /v1/user/subscription` (`character_count`, `character_limit`, `next_character_count_reset_unix`), or null on `missing_permissions`.
  - One `ElevenLabsException` with a `reason` enum: `offline` (socket/DNS/timeout), `badKey` (401 other than missing permissions), `missingPermission`, `quota` (402, or `status` `quota_exceeded`), `unsupportedLanguage` (400 `unsupported_language`), `voiceNotAllowed` (e.g. `paid_plan_required` for a library voice), `server` (5xx, anything else). `toString` never includes the key.
- Tests with `MockClient`: voice parsing and ordering; synthesis sends `xi-api-key`, a UTF-8 JSON body with `language_code`, `output_format=pcm_22050`, and returns a valid WAV with the right sample count; each error maps to its reason (use the real response bodies quoted in the architecture doc); timeout → `offline`; the key never appears in any exception text.
- **Checks:** `flutter analyze`, `flutter test`.

### [x] T36 (Agent): Engine with fallback, cache and status
- `VoiceKind.elevenlabs`; `Voice.elevenLabs(lang, voiceId, name)` with id `elevenlabs:<lang>:<voiceId>`. The selected voice (in `shared_preferences`, as now) keeps the name so the picker can show it offline. Settings in `shared_preferences`: `elevenLabsFallbackVoiceId`, `elevenLabsExpressive` (false = `eleven_flash_v2_5`, true = `eleven_v3`).
- `VoiceEngine.synthesizeToWav(text, {bool urgent = false})`; Piper and system engines ignore `urgent`.
- `lib/voices/elevenlabs_engine.dart`: `ElevenLabsEngine(voice, client, fallback, cache)`. `load()` loads only the fallback. `synthesizeToWav`: cache hit → copy to a new temp WAV (boosted when Hangosítás is on, as in Piper); else if `urgent` → fallback; else request → write the cache entry, then the temp copy; on `ElevenLabsException` → fallback, and set `lastFallback` (the reason, or null after a successful ElevenLabs utterance or cache hit). `isLoaded` = fallback loaded.
- `lib/voices/elevenlabs_cache.dart`: as in the architecture doc (key, 100 MB cap, oldest-used eviction, `clear()`). Eviction runs after a write, in the background.
- `main.dart` engine factory: build the fallback from `elevenLabsFallbackVoiceId` (if missing or not installed: the system voice of the voice's language). No key stored → the engine always falls back with reason `badKey`.
- `Speaker`: pass `urgent: alarm` for TTS rows; expose `lastFallback` (notify listeners when it changes).
- Speaking screen app bar: a `cloud_off` icon slot shown while `lastFallback != null` (keep the app-bar layout fixed). Tap → a dialog with the reason text and the fallback voice's name. ARB (hu + en).
- Tests: success writes the cache and plays; second call is a cache hit with no request; each failure reason falls back and is exposed; `urgent` never calls the client; the returned path is never the cache file; eviction keeps the newest files under the cap; alarm rows pass `urgent`; the icon shows and hides.
- **Checks:** `flutter analyze`, `flutter test`.

### [x] T37 (Agent): Setup screen and voice picker section
- Voice picker: for languages in `elevenLabsLanguages` only (constant in `elevenlabs_client.dart`, see the architecture doc), below the language's voices, an "ElevenLabs" section header with a short subtitle "Internet és saját ElevenLabs-fiók kell". No key → one row "Beállítás" opening the setup screen. Key stored → the account's voices, by name only (fetched when the picker opens; offline → just the currently selected ElevenLabs voice, plus a "Nincs internet" note), each with "Próba" and select, like Piper rows, and a "Beállítások" row to the setup screen. Selecting one makes the picker's language the speech language (same as the system voice row).
- "Próba" synthesizes the catalog's `sampleText` for the picker language with that voice, through the cache (so it costs credits only once).
- New `lib/ui/elevenlabs_screen.dart`:
  - Plain explanation: optional; needs internet and an ElevenLabs account; the text you say is sent to ElevenLabs and appears in your ElevenLabs history; the free plan has a monthly credit limit; without internet another voice speaks instead. Which permissions the key needs (Text to Speech, Voices; User optional for the credit display).
  - Key field (obscured, paste-friendly) + "Ellenőrzés": calls `listVoices()`; stores the key only if that succeeds; otherwise shows the reason (bad key / missing permission / no internet).
  - With a key: credit line when available ("Felhasznált kredit: 1 234 / 10 000, újraindul: <date>"); "Ha nincs internet, ez a hang beszél:" picking among installed Piper voices and the system voice of the speech language; the "Kifejezőbb hang (lassabb, kétszer annyi kredit)" switch; "Kulcs törlése" (confirm dialog; clears the key and the cache; if an ElevenLabs voice is selected, switch to the fallback voice).
- ARB (hu + en). Tests with the fake key store and `MockClient`: bad key isn't stored; good key stores and lists voices; the offline picker shows the selected voice; delete key switches to the fallback and clears the cache.
- **Checks:** `flutter analyze`, `flutter test`.

### [ ] T38 (You): Try ElevenLabs on the phone
Create a new API key for the phone (Text to Speech + Voices, optionally User read), don't reuse one that was pasted into a chat.
1. ☰ → Hang és nyelv → ElevenLabs → Beállítás: try a wrong key first (clear error), then the real one. Credits shown (if User read is on)?
2. Listen to "Próba" for 2–3 voices, pick one. Speak list rows and typed text: how long until sound starts (compare with Imre)? Try the "Kifejezőbb hang" switch.
3. Tap a row twice and re-tap a row said earlier: the second is instant (cache).
4. Airplane mode: a row said before still uses the ElevenLabs voice (cache); a new sentence comes in the fallback voice within ~4 s, and the cloud icon explains why. Turn the network back on: the icon disappears after the next ElevenLabs utterance.
5. An alarm row with typed text (no sound): plays immediately even on slow/no network.
6. A recorded row still plays your recording.
7. Kulcs törlése: back to the fallback voice.
Note the delay numbers. If 4 s feels too long before the fallback, say so. Done → commit.

---

**After Phase 7, if users ask for it:** "Lista hangjának letöltése" in the list editor (fetch every row of a list into the cache ahead of time, showing the credit cost first), so the user's own ElevenLabs voice works offline for whole lists.

---

## Later (rough)
**Before the Play Store release:**
- About screen, its own drawer row, last (GPL-3.0 app; per-voice licenses from the catalog, Alma is CC BY 4.0 and needs credit; Apache-2.0 sherpa-onnx; BSD-3-Clause `record`). Also shows disk usage: "Saját felvételek" (`<appSupport>/recordings/`) and "Letöltött hangok" (`<appSupport>/voices/`, including the shared espeak-ng-data), in MB, computed in the background when the screen opens.
- Per-ABI builds / app bundle (`docs/TODO.md`).
- Privacy policy and Play data-safety form (mic is used, nothing leaves the phone).
- Measure speed on the cheapest Android phone available (never done; `CLAUDE.md`), and the "Más nyelvek" check (`docs/TODO.md`).
- **Crash course for the human (You + Opus, interactive, do it late so the code is near its release state).** Goal: not to become a Flutter dev, but to have basic confidence in how the app solves its problem, where to check what it asks for, and how to take responsibility for it doing no harm without knowing every line. Walk through this repo's real code, and let the human's questions set the depth:
  - Flutter basics (widgets, state, how a screen gets drawn), and how Flutter handles cross-platform (one Dart UI, native code only behind platform channels and plugins).
  - What each folder in the repo is for.
  - Android app basics (manifest, activity, app storage, APK vs app bundle).
  - What permissions the app requires, why, and where to check them (source manifest and the merged one in the built APK, since plugins can add their own).
  - Dart basics, only as needed to read the code being discussed.
  - The "does no harm" checklist: where network calls and file writes happen, what plugins can do, what could fail in an urgent moment (a silent tap, a lost recording), and how to check these again before each release.

**After, or if testing asks for it:**
- Speech speed setting (lengthScale): a slider in the Beállítások screen, section Beszéd.
- Carry unsaid sentences of a conversation over to a new one.
- Offer new default lists/sentences added in later app versions to existing users (seed version).
- Choose a row's built-in sound in the editor.
- Play a recording when free text exactly matches a recorded sentence.
