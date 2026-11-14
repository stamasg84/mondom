# Tasks

How to use: start a Sonnet session (`claude --model sonnet`) and say "Do task T28 from docs/tasks.md". Read `docs/architecture.md` first.
**Agent** tasks: stay in scope, run the listed checks, finish with a short summary of what changed and what the human should verify. Don't commit; the human commits after testing.
**You** tasks: done by the human (new to Flutter) on Windows + a Pixel 6a. Flutter SDK and Android Studio are installed, `flutter doctor` is OK, developer mode is on.
Mark tasks done by changing `[ ]` to `[x]`. When a phase is finished, move it to `docs/done.md`.

---

## Phase 8: Final adjustments before the Play Store release

Goal: polish what testers will see first, give the project a public face (About, README, license, privacy policy), and produce a signed release build. No new features beyond these.

### [ ] T39 (Agent): ElevenLabs picker section and setup screen wording
Problems found in T38: the "Beállítások" entry is drawn like a voice row (with a play button area), and as the section's last row it's hard to find under a long voice list. The setup screen's Hungarian reads like a translation.
- Voice picker, ElevenLabs section (`_elevenLabsSection` in `voice_picker.dart`):
  - The section header gets a trailing gear `IconButton` (tooltip "ElevenLabs beállításai", ≥48 dp) that opens the setup screen. It's in the header, so it's visible as soon as the section is reached, however many voices follow. Remove the "Beállítások" row.
  - No key: no voice-style row. Instead, under the header, one full-width `OutlinedButton.icon` "ElevenLabs beállítása" (no play button). The gear is hidden in this state (the button does the same).
  - Keep the "Nincs internet" / failure note directly under the header.
  - Subtitle: "Saját ElevenLabs-fiókkal, internettel" (en: "With your own ElevenLabs account, needs internet").
- Setup screen (`elevenlabs_screen.dart`): rewrite the Hungarian strings (keep the keys where the meaning stays; the English ones follow the same meaning). Drafts, the human may adjust them before the task runs:
  - Intro (final wording, decided 2026-11-14; keep it this short, everything else goes to the GitHub manual, see T42): "Az ElevenLabs egy külső, a Mondomtól független felhőszolgáltatás. Használatához saját ElevenLabs API-kulcs és internetkapcsolat kell. A felolvasandó szövegeket a Mondom elküldi az ElevenLabs szervereire, ezekre az ElevenLabs adatkezelési feltételei vonatkoznak." (en: "ElevenLabs is an external cloud service, independent of Mondom. It needs your own ElevenLabs API key and an internet connection. Mondom sends the texts to be spoken to ElevenLabs' servers; ElevenLabs' privacy terms apply to them.") Don't explain fallback, caching or generated recordings on this screen.
  - Below the intro, a link "Részletek a súgóban" (en: "More in the manual") to the README's ElevenLabs section (`https://github.com/stamasg84/mondom#elevenlabs`, Hungarian UI → `README.hu.md`'s section; match the anchors T42 creates). Open through the T41 `openUrl` channel if T41 is done, otherwise selectable text.
  - Key hint (replaces `elevenLabsPermissions`), shown as the API key field's `helperText` (allow wrapping, `helperMaxLines` ≥ 3): "Szükséges jogosultságok: Text to Speech, Voices (olvasás). Nem kötelező: User (olvasás), a kreditek kijelzéséhez." (en: "Required permissions: Text to Speech, Voices (read). Optional: User (read), to show your credits.") Keep the permission names in English, they match the ElevenLabs key screen. Agent: check the permission names and access levels against current ElevenLabs docs and adjust only if they differ.
  - `elevenLabsKeySaved`: "A kulcs működik, elmentve."
  - `elevenLabsErrPermission`: "A kulcsnak nincs meg minden szükséges jogosultsága. Nézd meg a jogosultságait az ElevenLabs honlapján." (en: "The key is missing a required permission. Check its permissions on the ElevenLabs website.") Generic on purpose: the save check only calls `listVoices()`, but `missingPermission` can come from any endpoint, so don't name a specific permission.
  - `elevenLabsErrOffline`: "Nincs internet, így nem lehet ellenőrizni a kulcsot."
  - `elevenLabsFallbackChoice`: "Tartalék hang, ha nincs internet:"
  - `elevenLabsExpressive`: title "Kifejezőbb hang", subtitle "Lassabban indul, és kétszer annyi kreditbe kerül."
  - `elevenLabsDeleteKeyQuestion`: "Törlöd a kulcsot? A listákba mentett ElevenLabs-felvételek megmaradnak, a többi kimondott mondat legközelebb a tartalék hangon szól." ("gyorsítótár" is jargon. Generated recordings from T45 are kept; only the cache is cleared.)
  - **No ElevenLabs promotion in the app** (decided 2026-11-14): no Impact Program mention or link, no prices, plans, free offers or eligibility rules, no "sign up" wording. ElevenLabs is a neutral opt-in for people who already have an account; programs and plans can change or end at any time on ElevenLabs' side. Also no prices, plans or eligibility rules in the README (the only allowed hint is the one in T42's ElevenLabs section). Describe only what Mondom does.
  - Use "ElevenLabs-hang", "ElevenLabs-fiók" consistently (hyphenated) in every ElevenLabs string, including the fallback dialog ones.
- Tests: update `voice_picker_test.dart` / `elevenlabs_screen_test.dart` (gear opens the setup screen; the no-key button opens it; no row with key `elevenlabs-settings`).
- **Checks:** `flutter analyze`, `flutter test`.

### [ ] T40 (Agent): Speech speed
Some voices talk faster than others (e.g. `nst` vs `imre`), so the speed is **stored per voice** (`shared_preferences` key `speechSpeed:<voiceId>`, default 1.0), and switching voices brings back that voice's speed.
- Beállítások, section Beszéd: "Beszéd sebessége" slider with "Lassabb" / "Gyorsabb" end labels (no numbers), 0.7–1.3 in 0.05 steps, with the selected voice's name under the title ("Imre hangjára"). Releasing the slider says the language's `sampleText` at the new speed. A "Visszaállítás" text button when ≠ 1.0. Hidden when no voice is selected.
- Per source (`VoiceEngine` gets a `speed` it applies on each `synthesizeToWav`, so changing it needs no model reload):
  - **Piper**: pass it as `generate(..., speed: speed)` (sherpa-onnx divides the length scale by it; the configured `lengthScale` 1.2 stays the baseline for 1.0).
  - **System TTS**: `flutter_tts.setSpeechRate` before `synthesizeToFile`. flutter_tts on Android maps 0.5 to Android's normal rate 1.0, so pass `speed / 2`. Verify it affects `synthesizeToFile`.
  - **ElevenLabs**: `voice_settings.speed` in the request body (API range 0.7–1.2: clamp). Check the API docs for whether `eleven_v3` accepts it; if not, omit it there. **Add the speed to the cache key** (old entries simply miss, no migration).
  - The ElevenLabs fallback engine uses the fallback voice's own speed.
  - Recordings and built-in sounds: unchanged (no time-stretching).
- Architecture doc: a short "Speech speed" note with the above.
- Tests: per-voice persistence; Piper and system engines receive the speed; the ElevenLabs body has the clamped speed and different speeds give different cache keys; slider hidden without a voice.
- **Checks:** `flutter analyze`, `flutter test`.

### [ ] T41 (Agent): About screen, LICENSE file, opening links
- Add the GPL-3.0 text as `LICENSE` in the repo root (the official text from gnu.org, unmodified).
- `MainActivity.kt`: an `openUrl` method on an existing small channel (`Intent.ACTION_VIEW`; no `url_launcher` dependency). Catch `ActivityNotFoundException` and return false; the UI then shows the URL as selectable text.
- New `lib/ui/about_screen.dart`, drawer row "Névjegy", last. Contents, top to bottom:
  - App name, version (`package_info_plus`), one line: "Ingyenes, reklám nélküli, nyílt forráskódú beszédsegítő. Nincs fiók, minden adat a telefonon marad."
  - "A projekt a GitHubon" → `https://github.com/stamasg84/mondom`. "Adatkezelés" → the privacy policy from T43 (`https://github.com/stamasg84/mondom/blob/main/PRIVACY.md`).
  - **Hangok**: every catalog voice with its license from the catalog; `alma` gets the CC BY 4.0 credit line with the dataset author as given on the Piper model card (copy it from the model card, link to it). Then "Android alapértelmezett: a telefon saját hangja".
  - **Felhasznált szoftverek**: sherpa-onnx (Apache-2.0), Piper (MIT), espeak-ng (GPL-3.0), Flutter (BSD-3-Clause), `record` and `flutter_secure_storage` (BSD-3-Clause), plus "Összes licenc" → Flutter's `showLicensePage` (which already lists every Dart package). Register the licenses that aren't Dart packages (espeak-ng, Piper, the voice licenses) with `LicenseRegistry.addLicense` in `main.dart` so they appear there too.
  - **Tárhely**: "Saját felvételek" (`<appSupport>/recordings/`) and "Letöltött hangok" (`<appSupport>/voices/`, incl. espeak-ng-data), in MB, computed in an isolate when the screen opens ("…" until done).
  - One small line: "Az ElevenLabs az ElevenLabs védjegye; a Mondom nem kapcsolódik hozzá." (en: "ElevenLabs is a trademark of ElevenLabs. Mondom is not affiliated with ElevenLabs.") See `docs/architecture.md` "ElevenLabs voice" → Legal.
- ARB (hu + en). Tests: the drawer row opens the screen; voice credits come from the catalog; sizes render after computing; the link calls the channel.
- **Checks:** `flutter analyze`, `flutter test`.

### [ ] T42 (Agent): README in English and Hungarian
`README.md` (English, what GitHub shows) and `README.hu.md` (Hungarian), each linking the other in its first line. Same content in both:
- One paragraph: what Mondom is and who it's for (from `CLAUDE.md`: literate adults who lost their speech; ALS, stroke, laryngectomy, MS; Hungarian-first).
- Goals / why: free, no ads, no accounts, offline after setup; natural voices without setting up a TTS engine; everything in one install. Plain tone, no superlatives, no competitor names.
- Features: sentence lists, free text with tap-again-to-repeat, history, prepared conversations, message banking + backup, alarm rows, voices (offline Piper voices, the system voice, optionally your own ElevenLabs account). For ElevenLabs, state the generate feature factually: a whole list can be saved as recordings in your ElevenLabs voice, and they keep working offline even after the key is removed. Nothing about ElevenLabs plans, prices or eligibility (see T39).
- Short manual (5–8 steps): first launch and voice choice, speaking a row, typing, ☰ → Listák (editing), preparing a conversation, recording your own voice, making a backup, alarms. Placeholders for 3 screenshots (`docs/screenshots/*.png`, the human adds them).
- An "ElevenLabs" manual section with a stable anchor (the T39 setup screen links to it, since that screen only has a 3-sentence intro): creating the API key and its permissions, picking a voice, the fallback voice when offline, already-spoken sentences working offline (cache), the "Kifejezőbb hang" option, generating a list's recordings (T45), what deleting the key keeps. Same rule: no ElevenLabs plans, prices or eligibility. The one exception is a single neutral sentence with no link and no program name, e.g. "ElevenLabs has at times offered free voice cloning to people with ALS and other speech-affecting conditions; search their website for current options." (Hungarian equivalent in `README.hu.md`.)
- Install: Google Play (link placeholder), APKs from GitHub Releases. Building from source: `flutter build apk --split-per-abi`.
- Privacy (2 sentences + link to `PRIVACY.md`), license (GPL-3.0; voice licenses per voice in `voices/catalog.json`), feedback (GitHub issues).
- Write the Hungarian version natively, not sentence-by-sentence from the English; the human proofreads it.
- **Checks:** links point at files in the repo (or are marked placeholders).

### [ ] T43 (Agent): Privacy policy and release build setup
- `PRIVACY.md` (Hungarian first, English below, plain language): no accounts, no analytics, no ads, the developer collects nothing. The microphone is used only to record sentences the user chooses; recordings, lists and history stay on the phone; backups go only where the user saves them. Network: the voice catalog and voice downloads (GitHub), and only if the user sets it up, the text to be spoken goes to ElevenLabs with the user's own key, under ElevenLabs' privacy policy (link). The key is stored encrypted on the phone. Contact: GitHub issues.
- `docs/release.md`: the Play data-safety answers matching the above (shared: the text spoken, with ElevenLabs, only when the user opts in; nothing collected by the developer; encrypted in transit), and the release steps from T44.
- Release signing: `android/app/build.gradle.kts` reads `android/key.properties` (storeFile, storePassword, keyAlias, keyPassword) when it exists and signs `release` with it; otherwise it falls back to debug signing as now. Add `key.properties` and `*.jks` to `.gitignore`. Document in `docs/release.md` how to create the upload keystore (`keytool -genkey ...`), and that it must be backed up outside the PC (with Play App Signing a lost upload key can be reset, but it takes days).
- Release build check: `flutter build appbundle` and `flutter build apk --split-per-abi` succeed; if R8 strips something sherpa-onnx or another plugin needs, add keep rules in `proguard-rules.pro`. Note the per-ABI APK sizes in `docs/release.md`, and update `docs/TODO.md` "APK size" with the decision: keep `armeabi-v7a`, since cheap old phones are exactly the target.
- **Checks:** both builds succeed; `flutter analyze`; `git status` shows no keystore or `key.properties`.

### [ ] T45 (Agent): Generate a list's recordings with ElevenLabs
Included before the release without waiting for user requests (decided 2026-11-14). Design: `docs/architecture.md` "ElevenLabs voice" → "Generating a list's recordings", and "Message banking" → "Generated recordings". Do after T40 (speed).
- Schema v5: `sentences.recordingGenerated` bool, default false. Migration adds the column; regenerate `database.g.dart`. Copy/move keep it with `recordingPath`; recording an own take sets it false. Backup zip: include the flag; old zips import as false.
- `RecordingStore`: save a WAV from the ElevenLabs engine output as a normal recording file. Add a strict `ElevenLabsEngine.generate(text, voiceId)` (no fallback, no `urgent`, reads/writes the cache, returns an unboosted WAV or throws the failure reason).
- Entry points mirror message banking (T31/T32), visible only with a key, never in history. Voice choice: the account's voices, preselected the current ElevenLabs voice.
  - Row ⋮ sheet: "ElevenLabs-hangon mentés" next to "Saját hang felvétele" / "Új felvétel". Opens `recording_screen.dart` in a generate mode: synthesize → the existing Review state (listen, Mentés, "Újra" regenerates). As with "Új felvétel", the old recording (own or generated) is replaced only on Mentés.
  - List editor app bar: a cloud button next to the mic button for the bulk run (flow below). "Generált hangok törlése" in the overflow menu.
- Bulk flow: own-recording dialog (only if needed) → cost dialog (estimated credits, remaining credits if known, rows already cached count as free) → progress screen with Mégse → result line ("42 mondat kész" / "Megállt: elfogyott a kredit, 30/42 kész").
- `prepareRecording`: for generated rows only level normalization + peak limit.
- Text edit of a generated row: keep / delete / "Újragenerálás" (with a key).
- Strings (hu + en). Tests: replaces generated, keeps own on "Csak a többit", skips `soundKey` rows; cached rows make no request; a failure stops and keeps finished rows; never uses the fallback; the flag survives copy, move and backup round-trip; deleting the key leaves generated recordings playing.
- **Checks:** `flutter analyze`, `flutter test`.

### [ ] T44 (You): Release candidate test and store listing
1. Proofread T39's Hungarian on the phone, and `README.hu.md`. Take 3–4 screenshots for the README and the store listing.
2. Speed slider: Imre a bit faster, nst slower, the system voice, an ElevenLabs voice. Each keeps its own speed after switching back and forth.
3. About: links open, storage numbers plausible, Alma credit present.
3a. T45: generate a short list with an ElevenLabs voice (check the cost dialog against the credit line), record one row yourself first and try "Csak a többit". Then delete the key and switch to Imre: the generated rows still speak in the ElevenLabs voice, offline too (airplane mode), and survive a backup/restore.
4. Create the upload keystore (`docs/release.md`) and back it up. Build the release APK, uninstall the debug app, install the release one, and do a full smoke test (first-launch picker, download a voice, rows, typing, recording, alarm, backup/restore, ElevenLabs). Release builds can break things debug builds don't.
5. If possible: install on the cheapest Android phone available, time tap → sound with Imre (the measurement `CLAUDE.md` asks for), and try "Más nyelvek" (`docs/TODO.md`).
6. App icon: still Flutter's default? Decide on one.
7. Play Console: listing texts (hu + en, from the README), screenshots, content rating, target audience, data safety (from `docs/release.md`), privacy policy URL; upload the app bundle to internal testing first.
Done → commit, tag `v1.0.0`.

---

## Later (rough)
**Before the Play Store release:**
- **Crash course for the human (You + Opus, interactive, do it late so the code is near its release state).** Goal: not to become a Flutter dev, but to have basic confidence in how the app solves its problem, where to check what it asks for, and how to take responsibility for it doing no harm without knowing every line. Walk through this repo's real code, and let the human's questions set the depth:
  - Flutter basics (widgets, state, how a screen gets drawn), and how Flutter handles cross-platform (one Dart UI, native code only behind platform channels and plugins).
  - What each folder in the repo is for.
  - Android app basics (manifest, activity, app storage, APK vs app bundle).
  - What permissions the app requires, why, and where to check them (source manifest and the merged one in the built APK, since plugins can add their own).
  - Dart basics, only as needed to read the code being discussed.
  - The "does no harm" checklist: where network calls and file writes happen, what plugins can do, what could fail in an urgent moment (a silent tap, a lost recording), and how to check these again before each release.

**After, or if testing asks for it:**
- Carry unsaid sentences of a conversation over to a new one.
- Offer new default lists/sentences added in later app versions to existing users (seed version).
- Choose a row's built-in sound in the editor.
- Play a recording when free text exactly matches a recorded sentence.
