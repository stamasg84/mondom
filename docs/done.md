# Done tasks

Completed tasks, moved out of `docs/tasks.md` to keep it short. Kept for reference (results, gotchas found along the way).

---

## Prototype: speak typed text with imre

### [x] T1 (Agent): Scaffold the Flutter app
- Run `flutter create --platforms android --org io.github.stamasg84 --project-name mondom .` in the repo root. Don't touch `CLAUDE.md` or `docs/`.
- Replace the counter demo in `lib/main.dart` with a single screen: title "Mondom", centered text "Szia!". Update `test/widget_test.dart` to match.
- In `android/app/build.gradle(.kts)`: `minSdk = 24`. App label "Mondom" in `AndroidManifest.xml`.
- Append `assets/voices/` to `.gitignore`.
- **Checks:** `flutter analyze` (no issues), `flutter test` (passes). No APK build here: the human builds in T2 via `flutter run`.

### [x] T2 (You): Run the app on the Pixel
1. Phone: Settings → System → Developer options → turn on **USB debugging**.
2. Connect via USB. On the phone, accept "Allow USB debugging?" (tick "Always allow").
3. `flutter devices` should list the Pixel 6a.
4. In the repo root: `flutter run`. The first run takes a few minutes. You should see "Szia!" on the phone.
5. Try hot reload: change "Szia!" in `lib/main.dart`, save, press `r` in the terminal. The phone updates within about 1 s. Press `q` to quit.

If the phone isn't listed: try another cable or USB port; pull down the notification shade → USB → "File transfer"; Android Studio → SDK Manager → SDK Tools → install **Google USB Driver**. If it shows as "unauthorized": Developer options → Revoke USB debugging authorizations, then replug.
Done → commit: `git add -A && git commit -m "Scaffold Flutter app"`.

### [x] T3 (Agent): Speak a hardcoded sentence with imre
- `tool/fetch_voices.ps1`: download `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-hu_HU-imre-medium.tar.bz2` (check that the URL exists; if it doesn't, find the correct name in the `tts-models` release) and extract it into `assets/voices/` (Windows `tar -xf` handles .bz2). Make it idempotent: skip the download if the folder exists. Run it.
- `pubspec.yaml`: add `sherpa_onnx`, `path_provider`, `audioplayers`. Register the assets. Flutter asset dirs are **not recursive**, so every subfolder of `espeak-ng-data/` needs its own entry. Generate the list from the actual extracted tree.
- `lib/tts/voice_assets.dart`: copy the voice folder to app support storage (see architecture.md "Android gotcha"). The copy list comes from `AssetManifest` (`AssetManifest.loadFromAssetBundle`), filtered by prefix.
- `lib/tts/tts_engine.dart`: `initBindings()`, build `OfflineTts` with `vits: model/tokens/dataDir`, `numThreads: 2`. Expose `Future<void> load()` and `Future<String> synthesizeToWav(String text)`, which writes to the temp dir with sherpa-onnx's `writeWave`.
- UI: a "Beszélj" button that speaks "Szia! Kérek egy pohár vizet." It is disabled until the model is loaded, and the screen shows "Betöltés…" while loading. Use `debugPrint` to log load ms and synthesis ms.
- Mirror the official `flutter-examples/tts` example for API usage.
- **Phonemization gotcha (found in T4):** `sherpa_onnx` 2.x (2.0.0+) removed the built-in espeak-ng phonemizer; `dataDir` is ignored, so Piper fails with "phoneme_codepoints is empty, no lexicon, and no frontend available" (and then `IntegerDivisionByZeroException` in the RTF log). `pubspec.yaml` is therefore pinned to `sherpa_onnx: ^1.13.8`, the last 1.x. **TODO: move to the latest sherpa_onnx** by phonemizing ourselves (e.g. `piper_phonemize` / espeak-ng via our own plugin, passing `OfflineTtsGenerationConfig.phonemeCodepoints`), or with a lexicon. Check licensing (espeak-ng is GPL-3.0, fine for Mondom) and that Hungarian output matches the 1.x output.
- **Checks:** `flutter analyze`, then `flutter build apk --debug 2>&1 | tail -40` (native deps and asset config break here; read only the tail). Report the APK size (`build/app/outputs/flutter-apk/`).

### [x] T4 (You): Hear imre on the phone
1. Run `.\tool\fetch_voices.ps1` once, if `assets\voices\` is empty.
2. `flutter run --profile`. Profile mode gives realistic speed; debug mode is slower.
3. Wait for "Betöltés…" to disappear, then tap **Beszélj**.
4. Note: Did it speak? Is the pronunciation correct? Load time and synthesis time (from the terminal log lines).

If it crashes or stays silent: copy the terminal output from the first red/`E/` line onward and paste it into a Claude session along with "T4 failed".
Result (Pixel 6a): works after the sherpa_onnx 1.x pin; synthesis ~115 ms for the test sentence, load time decent.
Done → commit.

### [x] T5 (Agent): Text field, timings on screen, voice tuning
- Main screen: a large multi-line `TextField` (font ≥ 24), a large "Beszélj" button below it, and an "Ismétlés" button (replays the last WAV without re-synthesizing).
- Show the timings on screen in small text: model load ms; for the last utterance, synthesis ms, audio duration ms and RTF (= synthesis / duration).
- An expandable "Hangolás" section with sliders: `lengthScale` 0.7–1.5 (default 1.0), `noiseScale` 0.3–1.0 (default 0.667), `noiseScaleW` 0.3–1.0 (default 0.8). These values are fixed at model creation, so changing them reloads `OfflineTts` and shows the reload time.
- **Checks:** `flutter analyze`, `flutter test`. No APK build; the human runs it in T6.

### [x] T6 (You): Measure
In `flutter run --profile`, speak:
1. "Kérek vizet!"
2. A 2–3 sentence paragraph.
3. The same short phrase 3 times.

Write down the load ms and the RTF for each in `docs/measurements.md` (just paste the numbers). Try the sliders and note which settings sound least flat.
The Pixel 6a is mid-to-upper range, so cheap phones will be slower. Treat an RTF under 0.3 here as comfortable.
Done → commit. Then ask Opus to plan the next phase using these results.
Result: see `docs/measurements.md` (load ~800 ms, short phrase ~120–140 ms; lengthScale 1.2 sounds best, noise sliders inaudible).

---

## Phase 2: voices (system TTS + downloadable Piper voices)

Decision: no voices are bundled in the APK. On first launch the user picks a voice. The system TTS ("Android alapértelmezett") works offline right away; Piper voices are downloaded once. The downloadable voices are listed in a curated catalog JSON in this repo, pointing at sherpa-onnx's `tts-models` release. See `docs/architecture.md` "Voices".

### [x] T7 (Agent): Localization setup
- Add `flutter_localizations` (SDK) and `intl`; set `generate: true` in `pubspec.yaml`; add `l10n.yaml` with `arb-dir: lib/l10n`, `template-arb-file: app_hu.arb`, `output-localization-file: app_localizations.dart`.
- Move every user-visible string of the current screen into `lib/l10n/app_hu.arb` (with `@key` descriptions). Add `app_en.arb` with English translations so the fallback path is exercised.
- `MaterialApp`: `localizationsDelegates`, `supportedLocales`. Hungarian when the phone is Hungarian, English otherwise.
- **Checks:** `flutter analyze`, `flutter test` (update the widget test to pump with the delegates).

### [x] T8 (Agent): Voice abstraction + system TTS
- Add `flutter_tts` and `shared_preferences`.
- `lib/voices/voice.dart`: `Voice` (id, languageCode e.g. `hu`, gender `male|female|unknown`, label, `VoiceKind { system, piper }`).
- `lib/voices/voice_engine.dart`: abstract `VoiceEngine { Future<void> load(); Future<SynthResult> synthesizeToWav(String text); void dispose(); }`. All callers (UI, later tiles) use only this.
- `PiperEngine`: refactor of the current `TtsEngine`. Takes the voice **directory path** and model file name instead of hardcoding imre. For now the path still comes from the bundled-asset copy (`VoiceAssets`); T10 replaces that with downloads. Default `lengthScale` = **1.2** (from `measurements.md`).
- `SystemEngine`: `flutter_tts` with the voice's language. Synthesize to a WAV file (`synthesizeToFile`; check the current package API for writing to a full path and for awaiting completion) so playback and "Ismétlés" work the same way as with Piper.
- Temporary dropdown on the main screen: "Imre" / "Android alapértelmezett". Persist the choice with `shared_preferences` and load it at start.
- Remove the "Hangolás" section (the noise sliders made no audible difference). Keep the timing text.
- **Checks:** `flutter analyze`, `flutter test`. Report what `synthesizeToFile` needed on Android (permissions, path quirks).

### [x] T9 (You): Compare system voice and imre
1. `flutter run --profile`. Switch between the two voices and speak the same sentences.
2. Check that the system voice works with airplane mode on (Google's Hungarian voice may need a one-time download in Android Settings → System → Languages → Text-to-speech).
3. Note in `measurements.md`: system TTS synthesis time, and how imre at length 1.2 compares.
Done → commit.

### [x] T10 (Agent): Voice catalog + Piper downloads
- `voices/catalog.json` in the repo. The remote URL is a single constant in `catalog.dart` (`https://raw.githubusercontent.com/stamasg84/mondom/main/voices/catalog.json`). If the remote fetch fails (offline, URL broken), the app must silently use the bundled copy. Format:
  ```json
  { "schemaVersion": 1,
    "voices": [ { "id": "hu_HU-imre-medium", "language": "hu", "gender": "male", "label": "Imre",
                  "url": "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-hu_HU-imre-medium.tar.bz2",
                  "sizeBytes": 0, "sha256": "...", "modelFile": "hu_HU-imre-medium.onnx",
                  "sampleUrl": "https://raw.githubusercontent.com/stamasg84/mondom/main/voices/samples/hu_HU-imre-medium.wav",
                  "license": "MIT", "minAppVersion": "1.0.0" } ],
    "sampleText": { "hu": "Szia! Kérek egy pohár vizet. Segítenél felállni?",
                    "en": "Hi! Could I have a glass of water, please? Can you help me stand up?" } }
  ```
  Entries: `imre`, `berta`, and `anna` **only if** its license is verified (check the Piper model card on HuggingFace `rhasspy/piper-voices`, `hu/hu_HU/anna/`, and report what it says). Get `sizeBytes`/`sha256` by downloading each file (`Get-FileHash`). The app also uses `sampleText` for the system voice preview (spoken live).
- **Samples:** `tool/make_samples.ps1` generates `voices/samples/<voice-id>.wav` for every catalog voice, so previews sound exactly like the app:
  - Uses the Python `sherpa-onnx` package **pinned to the same 1.x version as the app** (2.x dropped espeak-ng), installed into a venv under `tool/.venv` (gitignored). The Python part goes in `tool/make_samples.py`; the `.ps1` only sets up the venv and calls it.
  - For each voice: download/extract its archive (cache under `tool/.cache/`, gitignored; verify sha256), synthesize the catalog's `sampleText` for the voice's language with `lengthScale` 1.2 (same as the app), write a mono 16-bit WAV.
  - Idempotent: skip voices whose sample exists unless `-Force`.
  - Run it and commit the WAVs (expect ~200 KB each; report the sizes). Verify each `sampleUrl` path matches a generated file. (The raw URLs only work once the repo is public; until then previews fail gracefully in the picker.)
- Copy the same file to `assets/catalog.json` as the bundled fallback (add a tiny `tool/sync_catalog.ps1` that does the copy, and note it in architecture.md).
- `lib/voices/catalog.dart`: fetch the remote catalog (short timeout), fall back to the bundled one. Ignore unknown `schemaVersion`s and entries whose `minAppVersion` is newer than the app.
- `lib/voices/voice_installer.dart`: download to a temp file with progress (stream, bytes received / `sizeBytes`), verify the sha256, extract the `.tar.bz2` **in a background isolate** (`archive` package), and move it into `<appSupport>/voices/<id>/` only when complete. Keep **one shared** `<appSupport>/voices/espeak-ng-data/` (extract it from the first voice, skip it for later ones). Support cancel; a failed or cancelled download leaves nothing behind. Provide `isInstalled(id)` and `delete(id)`.
- Add deps: `http`, `archive`, `crypto`, `package_info_plus`.
- Remove the bundled voice: the asset entries in `pubspec.yaml`, `VoiceAssets`, `tool/fetch_voices.ps1`. `PiperEngine` now loads from the installed directory.
- Add the `INTERNET` permission to the main `AndroidManifest.xml`.
- **Checks:** `flutter analyze`, `flutter test` (unit-test catalog parsing/filtering and sha mismatch handling with a fake file), `flutter build apk --debug 2>&1 | tail -40`; report the new APK size. Log download and extraction ms with `debugPrint`.

### [x] T11 (Agent): First-run voice picker
- Shown on first launch (no saved voice) and from a settings icon on the main screen.
- Lists catalog voices for the UI language first, then "Más nyelvek" (expandable), and always "Android alapértelmezett". Each row: label, gender, size ("63 MB"), ▶ sample (streams `sampleUrl`; if it fails, show a short "A minta nem érhető el" message; the system voice previews by speaking the catalog's `sampleText` for its language), and a state: *Letöltés* / progress bar + *Mégse* / *Kiválasztva*. Installed voices can be deleted.
- "Kihagyás" selects the system voice. If the catalog can't be fetched and there's no network, the system voice is still selectable and the screen says downloads need internet.
- Replaces T8's temporary dropdown. All strings via ARB (hu + en).
- **Checks:** `flutter analyze`, `flutter test` (widget test: the picker renders with a fake catalog; skip selects the system voice).

### [x] T12 (You): Test the first run
1. Uninstall the app from the phone, then `flutter run --profile`.
2. Airplane mode on: the picker appears, the system voice works, downloads say they need internet.
3. Network on: preview the samples, download imre (note download + extraction time from the log), select it, speak.
4. Start downloading berta and cancel halfway. Start again and turn off wifi midway. The app must stay usable and no broken voice may appear.
5. Close and reopen: the chosen voice is remembered.
6. Intermittent bug hunt (seen once with `flutter run`: after toggling airplane mode, Android Studio lost the device and the voice unpacking hung ("Telepítés") on every later try). Install a release build (`flutter build apk --release`, `flutter install`) with Android Studio closed. Toggle airplane mode on/off several times, then download a voice and let the screen sleep during the unpack. If it hangs, run `adb logcat -d > log.txt` over USB before restarting anything. "Mégse" must interrupt the unpack, and an unpack stuck for 5 min must end in an error, not spin forever.
Done → commit.

### [x] T13 (Agent): Background synthesis
- A long-lived background isolate owns the `PiperEngine` (FFI pointers can't cross isolates). The UI sends text and gets WAV paths back. Load the saved voice at app start, so loading doesn't freeze the UI either.
- Switching voices: dispose the old engine in the isolate and load the new one there. Requests that arrive while it's loading wait for the load.
- The UI stays responsive during synthesis (show a progress indicator on the speak button).
- No sentence splitting/streaming (decided 2026-11-02, see `docs/TODO.md`): the whole text is synthesized in one call.
- **Checks:** `flutter analyze`, `flutter test`.

---

## Phase 3: sentence lists

Goal: the real speaking screen. Everything speakable is a sentence list, stored in SQLite (drift), seeded with per-locale default lists. Read `docs/architecture.md` "Speaking", "Storage" and "Sentence lists" first. State management stays plain `setState` + drift `watch` streams (`StreamBuilder`); no state-management package.

### [x] T14 (Agent): Speaker service, single "Mondd" button
- New `lib/speech/speaker.dart`: `Speaker` owns the current `VoiceEngine` and the `AudioPlayer` (move that logic out of `main.dart`). API: `Future<void> speak(String text)`, `Future<void> setVoice(Voice v)`, `stop()`, plus `busy`/`lastResult` for the UI (a `ChangeNotifier` is fine).
- **Last-utterance reuse:** `Speaker` remembers the last `(voice id, text)` → WAV path. Key = text trimmed with inner whitespace collapsed. Same key → stop current playback and replay the WAV from the start, without synthesizing. Different key → synthesize, then delete the previous WAV file (temp WAVs currently pile up in the temp dir). Switching voice clears the key. Only the last one is remembered; this is not a cache.
- Main screen: remove "Ismétlés". Keep the text in the field after speaking; add a large ✕ (clear) button inside the field. Mondom with an unchanged text = replay.
- Keep the small timing text (show "replay" instead of synth ms when reused).
- Remove the now-unused ARB key(s) in both `app_hu.arb` and `app_en.arb`.
- **Checks:** `flutter analyze`, `flutter test` (unit-test `Speaker` with a fake `VoiceEngine` that counts calls and a fake player: same text twice = 1 synthesis; whitespace-only difference = 1; different text = 2 and the old WAV is deleted; voice switch = re-synthesis).

### [x] T15 (Agent): Storage (drift) + seed data
- Add `drift`, `drift_flutter`; dev: `drift_dev`, `build_runner`. Commit the generated `*.g.dart` files (so a plain `flutter run` works without codegen). Note the regen command (`dart run build_runner build --delete-conflicting-outputs`) in architecture.md.
- `lib/storage/database.dart` with the tables from architecture.md "Storage": `sentence_lists`, `sentences`. Schema version 1.
- `assets/seed/hu.json`, `assets/seed/en.json` (format in architecture.md). Contents:
  - `everyday` list ("Alap" / "Basics"), pinned: ~25 short, well-punctuated phrases covering needs (water, food, toilet, pain, position, cold/hot, glasses, phone, TV, light), feelings, answers (Igen. / Nem. / Nem tudom. / Köszönöm!), and the meta phrases ("Várj, gépelek.", "Ismételd meg, kérlek!", "Lassabban, kérlek!"). Include the ones from `CLAUDE.md`. Natural, adult register (tegeződés, which is how family talks); no childish phrasing.
  - `example-conversation` ("Példa beszélgetés" / "Example conversation"), kind `conversation`, not pinned: the 3 sentences from `CLAUDE.md`'s prepared-conversation example (English: equivalent everyday sentences), so users discover the feature.
  - Every list and sentence has a stable `seedKey` (e.g. `"everyday"`, `"water"`).
- `onCreate`: insert the seed for the UI language (fallback `en`), plus the single `history` list ("Előzmények" / "History", pinned, `seedKey: "history"`; its title is localized at display time via ARB, not stored).
- `lib/storage/lists_repository.dart`: the only API the UI uses. At least: `watchLists()`, `watchSentences(listId)` (ordered), `createList`, `renameList`, `deleteList` (not for history), `setPinned`, `reorderLists`, `addSentences(listId, texts, {at})`, `updateSentenceText`, `deleteSentence`, `moveSentence(id, toListId)`, `copySentence(id, toListId)`, `reorderSentences(listId, ids)`, `setSaid(id, bool)`, `resetSaid(listId)`, `addToHistory(text)`, `restoreDefaultSentences(listId)`, `restoreDefaultLists()`, `hasMissingDefaults(listId)`.
  - `addToHistory`: if the same text (same normalization as `Speaker`) is already in history, move it to the top instead of duplicating; cap at 30 via a single constant `historyCap` (drop the oldest, no exceptions; history rows are separate `sentences` rows, so this never affects permanent lists. A recording only survives if a sentence in a non-history list has it. No recording files exist yet, so don't delete any files here).
  - Restore rules: see architecture.md "Storage" (only re-adds missing seed items, never deletes or changes anything).
- Last used list id: `shared_preferences`.
- **Checks:** `flutter analyze`, `flutter test` (in-memory drift DB, `NativeDatabase.memory()`): seeding hu vs en; history dedupe + cap; restore re-adds a deleted seed sentence at its seed position, doesn't duplicate an edited one, leaves user-added sentences alone; restore lists re-creates a deleted seed list; deleting a list cascades its sentences. `flutter build apk --debug 2>&1 | tail -40` (native sqlite libs).

### [x] T16 (Agent): Speaking screen
- Replaces the current main screen layout, per architecture.md "Sentence lists" (diagram + interaction rules). Voice picker stays behind the settings icon.
- Chip row: pinned lists in their order, plus the current list as a temporary chip if it isn't pinned, plus **▾**. ▾ toggles a large grid of all lists covering the sentence area; picking one closes it and shows that list.
- Sentence rows: big (font ≥ 24, min height 72 dp, full-width tap target, text wraps, never truncated). Tap = `Speaker.speak(text)`. Visual feedback on the tapped row while it is synthesizing/playing. `said` rows greyed out but tappable (the `said` logic itself is T19).
- Every speak (row or free text) calls `addToHistory`.
- Bottom bar: the free-text field with ✕, and Mondom (from T14), always visible.
- Opens on the last used list (fallback: the `everyday` list).
- An edit icon in the app bar opens the editing screen (T18); until then, it can be a placeholder.
- Empty list: a short hint text ("Ez a lista üres. Szerkesztés: ✎").
- All strings via ARB (hu + en).
- **Checks:** `flutter analyze`, `flutter test` (widget test with an in-memory DB and a fake `Speaker`: tapping a row speaks its text and adds it to history; chips switch lists; ▾ grid shows all lists and picking one shows it).

### [x] T16a (Agent): First-run voice picker closes on selection
Problem: on first launch the picker (`firstRun: true`) hides the back arrow, so after choosing a voice the only way out is "Kihagyás", which also overrides the choice with the system voice (`_skip` in `lib/ui/voice_picker.dart` calls `_select(_systemVoice)`).
- First run: choosing a voice closes the picker and returns to the speaking screen. That covers both "Kiválaszt" on an installed/system voice and a finished download (`_download` already calls `_select` on success). Pop only after `onSelect` completes, and only if still `mounted`.
- Remove the "Kihagyás" button, `_skip`, and the `skip` ARB key (hu + en). The "Android alapértelmezett" row's own select button already does what Kihagyás was for.
- Leaving with the system back gesture without choosing stays allowed: the system voice is used, nothing is saved, and the picker shows again on the next launch (current `savedId == null` logic in `main.dart`, unchanged).
- During a download on first run, nothing closes; cancelling the download leaves the picker open.
- Opened from settings (`firstRun: false`): unchanged (stays open after selecting, back arrow to leave), since there the user may also download or delete voices.
- **Checks:** `flutter analyze`, `flutter test`. Replace the `skip selects the system voice` test in `test/voice_picker_test.dart` with: first run, select system voice → `onSelect` called once and the picker route is popped; first run, a download finishing → selected and popped; not first run, select → not popped.

### [x] T16b (Agent): Speaking from the history list doesn't reorder it
Problem: tapping a row in Előzmények calls `addToHistory`, which moves that row to the top, so the list jumps under the user's finger (and a second tap on the same spot hits a different sentence).
- Rule: **speaking a row while the history list is shown doesn't change history** (no move, no insert). In `_speak` in `lib/ui/speaking_screen.dart`, skip `addToHistory` when the call is a row tap and the current list is the history list. Free text and rows in every other list still call `addToHistory` as before (same text → moves to the top), since the user isn't looking at history then.
- Free text typed while the history list is shown still goes in at the top (that's a new utterance; a shift there is expected).
- Accepted trade-off: a phrase repeated only from history can eventually fall off at the 30 cap. That's fine; frequently used phrases belong in a real list ("Mentés listába", T18).
- Add the rule as one sentence to the "History:" paragraph in architecture.md.
- **Checks:** `flutter analyze`, `flutter test` (widget test: with history showing A, B, C (A newest), tapping C speaks C and the order stays A, B, C; tapping a row in Alap that matches C moves C to the top; free text while history is shown is added at the top).

### [x] T17 (You): Try the speaking screen
1. Uninstall the app (fresh DB), `flutter run --profile`.
2. Use the Alap list for a few minutes as if you couldn't speak: are rows big enough, is anything missing or unnatural in the default phrases? Note changes to make in `assets/seed/hu.json`.
3. Tap the same row twice quickly: second tap replays at once. Type text, Mondom twice: second is instant.
4. Switch between Alap / Előzmények / Példa beszélgetés: one tap, nothing jumps under your finger.
5. Close and reopen: same list is open.
Done → commit.

### [x] T17a (Agent): Seed in the speech language, seed language per list
Problem: `onCreate` seeds from the UI language before any voice is picked, so a user who picks a voice in another language ("Más nyelvek") gets default sentences the voice can't pronounce, and restore keeps bringing them back. Read architecture.md "Storage", especially "Speech language", first.
- **Schema v2:** `sentence_lists.seedLanguage` nullable text; the list's `seedKey` uniqueness becomes `(seedLanguage, seedKey)`. Migration v1→v2: `addColumn`, set `seedLanguage` = the old `app_meta.seedLanguage` value on every list with a `seedKey` except history, replace the meta row with `seeded = 1`. Rebuilding the table is needed if the old unique constraint on `seedKey` is a column constraint (drift's `TableMigration`). Regenerate `*.g.dart`.
- **Deferred seeding:** `AppDatabase` no longer takes a `language`; `onCreate` creates only the history list. New repository methods: `isSeeded()`, `seedLanguages()` (distinct non-null `seedLanguage` of lists), `addSeedLists(String language)` (appends that seed's lists after the existing ones, with `seedLanguage` set, falling back to `en` via `resolveSeed`; sets `seeded = 1`). Seeding becomes a normal operation instead of being done in `onCreate`.
- **main.dart:** in `_selectVoice`, if not seeded → `addSeedLists(v.language)`. If seeded and `v.language` isn't in `seedLanguages()`, a seed file exists for it, and it isn't in `declinedSeedLanguages` (`shared_preferences`) → dialog "Hozzáadjam a(z) <nyelv> alapértelmezett listákat?" with "Hozzáadás" / "Nem". Language name in the UI language (a small `languageName(code, uiLang)` helper with a map for the catalog languages is fine; unknown code → the code itself).
- **Voice picker:** rows under "Más nyelvek" show the voice's language in the subtitle (e.g. "Svéd · Férfi · 67 MB"), using the same helper; otherwise a Swedish voice there is indistinguishable from a Hungarian one. When the first-run picker route is popped without a choice and the DB still isn't seeded → `addSeedLists(uiLang)`.
- The speaking screen's "last used list, fallback `everyday`" must work when lists appear after the screen is built (fallback: the first `everyday` list by position, re-evaluated when the lists stream changes while no valid list is open).
- **Restore:** `restoreDefaultSentences(listId)` uses the list's own `seedLanguage`. `restoreDefaultLists(language)` takes the current speech language and only re-creates that language's missing seed lists; the editor (T18) passes `Voice.language`.
- Unit test: every language in `assets/catalog.json` has `assets/seed/<lang>.json`.
- **Checks:** `flutter analyze`, `flutter test` (fresh DB has only history; `addSeedLists('hu')` then `('en')` gives both sets with no key clash; unknown language falls back to `en`; migration v1→v2 keeps all rows and sets `seedLanguage`; restore sentences uses the list's language; restore lists only touches the given language; widget/unit test for the decision in `_selectVoice`: not seeded → seed; seeded + new language → asks; declined → doesn't ask again; same language → nothing). `flutter build apk --debug 2>&1 | tail -40`.

### [x] T17b (You): Seeding by voice language
1. Migration first: **don't uninstall** the build from T17. Note a few edits (a deleted and an added sentence), then `flutter run --profile` the new build over it: lists and sentences are unchanged, and "restore" still works on Alap.
2. Uninstall, set the phone language to English, `flutter run --profile`. In the first-run picker choose Imre (under other languages): the lists are Hungarian (Alap…), the UI is English.
3. Settings → voice → pick the English system voice: you're asked once whether to add the English default lists. Say no, switch to Imre and back to English: not asked again.
4. Uninstall again, Hungarian phone, leave the first-run picker with the back gesture: Hungarian lists exist, and the picker shows again next launch.
Done → commit.

### [x] T17c (Agent): Voice picker: language selector, system voice per language
Do after T17a (uses its `languageName` helper and the speech-language rules). Read architecture.md "Voices" (voice picker) first. Replaces the "Más nyelvek" `ExpansionTile` in `lib/ui/voice_picker.dart`.
- **Language selector** at the top, only if the catalog has more than one language: a full-width button ≥ 56 dp, "Nyelv: Magyar ▾". It opens a bottom sheet (or dialog) of large rows (≥ 56 dp), one per catalog language: "Svéd (Svenska)" (UI-language name + native name; add the native name to the helper), with a marker (✓ + "1 letöltve") on languages that have installed voices, so downloaded voices in other languages can still be found and deleted. UI language first, then the others alphabetically by their UI-language name.
- **Default:** opened from settings → the selected voice's language; first run → the UI language. Changing the selector only filters the list; nothing is saved and no seed question is asked until a voice is picked.
- **List for the chosen language:** the "Android alapértelmezett" row (`Voice.system(lang)`), then that language's catalog voices (rows as today). The `language` subtitle T17a added under "Más nyelvek" isn't needed anymore (the selector shows it); remove it if the rows are now always single-language.
- **System voice availability** (new method on `SystemEngine` or a small `SystemTtsInfo` service, so tests can fake it): returns `installed | missingData | unsupported` for a language. Use `flutter_tts` (`isLanguageAvailable`, and on Android `isLanguageInstalled`, which tells an offline voice from a network-only one; check the current package API). Row states:
  - `installed`: ▶ preview (speaks the catalog's `sampleText` for that language) and Kiválaszt.
  - `missingData`: no Kiválaszt; text "A hang nincs letöltve a telefonon." and a button "Letöltés az Android beállításaiban", which opens the engine's install-voice-data screen (`TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA`) or, if that fails, the TTS settings (`com.android.settings.TTS_SETTINGS`). Needs a tiny platform channel or `android_intent_plus` (ask before adding the package). Re-check when the app resumes (`AppLifecycleState.resumed`), so the row turns selectable after the user installed the voice.
  - `unsupported`: row hidden, except for the UI language, where it stays with "A telefon nem tud ezen a nyelven beszélni." so the picker never looks voiceless.
  - If the check itself throws: treat as `installed` (today's behavior), so a quirky engine never hides the always-available voice.
- An already selected system voice keeps working whatever the check says (it's only a hint for choosing).
- ARB (hu + en) for new strings.
- **Follow-up (2026-11-03):** the history list's title now follows the speech language like the seeded lists do (`historyTitle` in each `assets/seed/<lang>.json`, stored on the history row by `ListsRepository.syncHistoryTitle`, called when a voice is chosen and at app start). Before, it came from the UI-language ARB, so it showed "Előzmények" next to Swedish lists. An empty title falls back to the ARB string. New seed files must include `historyTitle`.
- **Checks:** `flutter analyze`, `flutter test` (widget tests with a fake catalog of hu + sv and a fake availability service: selector hidden with one language; defaults to the UI language on first run and to the selected voice's language from settings; switching to Svéd shows the sv system row + NST + Alma and no Hungarian voices; `missingData` shows the hint and no select button; `unsupported` hides the row for sv but shows the hint for the UI language; the installed marker appears on a language with a downloaded voice; picking `system-sv` calls `onSelect` with language `sv`).

### [x] T17d (You): Voice picker by language
1. Settings → voice: the selector shows "Magyar". Switch to Svéd: system row, NST, Alma. Play the samples.
2. If the Swedish system row says the voice isn't downloaded: tap the button, install Swedish in Google's voice data, come back: the row is selectable now. Select it and type "Hej, hur mår du?": it speaks Swedish. Check it with airplane mode on (a network-only voice would fail here, which means `isLanguageInstalled` isn't telling the truth on this phone; note it).
3. Download NST, switch the selector back to Magyar: Svéd shows the installed marker in the language list.
Done → commit.

### [x] T18 (Agent): Settings screen + lists overview
Read architecture.md "Settings and editing" first. Editing is never a mode on the speaking screen: it lives in separate screens reached through settings, so a stray tap can't leave the speaking screen silently editing.
- **Speaking screen app bar:** remove the edit icon (and the `editComingSoon` placeholder + ARB key). Replace the voice icon (`Icons.record_voice_over`) with a cog (`Icons.settings`, tooltip "Beállítások"), the only action in the app bar. Empty-list hint becomes "Ez a lista üres. Szerkesztés: ⚙ Beállítások → Listák".
- **New `lib/ui/settings_screen.dart`:** a plain list of large rows (≥ 72 dp, icon + title + subtitle), back arrow to leave:
  - "Hang és nyelv" (subtitle: current voice label + language, e.g. "Imre · Magyar") → the existing voice picker (`firstRun: false`, as the old voice icon did).
  - "Listák" (subtitle: "Listák és mondatok szerkesztése") → lists overview.
  - Nothing else yet (About, speech speed etc. come later as more rows; don't add placeholders).
- **Lists overview (`lib/ui/lists_screen.dart`):** one large row per list in `position` order: title, a pin marker (📌 icon + "Kitűzve" text, not color only), sentence count. The list that is open on the speaking screen is marked "Most megnyitva" so the user finds it at once.
  - Tap a row → per-list editor (T18b; until then, a placeholder screen with the list's title).
  - Drag handle on the right → reorder (`reorderLists`). History can be reordered too (it's just a chip position).
  - A ⋮ button per row (≥ 48 dp) opens a bottom sheet with large rows: "Átnevezés" (dialog), "Kitűzés" / "Kitűzés megszüntetése" (`setPinned`), "Törlés" (confirm dialog naming the list and its sentence count: "Törlöd a(z) „Orvos” listát és a 12 mondatát?"). History: no rename, no delete (its title follows the speech language), pin/unpin allowed. T18a adds "Szín" here.
  - **"Új lista"** button at the bottom (full width, ≥ 56 dp) → dialog: name field + kind choice with two large radio rows: "Mondatlista" (`everyday`) / "Beszélgetés" ("Előre megírt mondatok, Következő gombbal", `conversation`). New lists are pinned by default (otherwise a freshly prepared conversation is hidden behind ▾); after creating, open its editor directly.
  - "Alapértelmezett listák visszaállítása" row at the bottom, only if a seed list of the current speech language is missing (`restoreDefaultLists(voice.language)`, see T17a).
  - Deleting the list that's open on the speaking screen: the speaking screen falls back as in T17a (first `everyday` list).
- All strings via ARB (hu + en).
- **Checks:** `flutter analyze`, `flutter test` (update existing tests that used the voice icon; widget tests: cog → settings → "Hang és nyelv" opens the picker; "Listák" shows all lists with the open one marked; create a conversation list → it exists, is pinned, has kind `conversation`; delete asks first and cancel keeps the list; history has no rename/delete; restore row appears only when a seed list is missing).

### [x] T18b (Agent): Per-list sentence editor
Do after T18. Opened from a row in the lists overview.
- App bar: the list's title. One row per sentence (keeps sentence ids, so recordings and `said` survive edits). Tap a row = edit its text (dialog with a large multi-line field). Drag handle to reorder, delete icon (with undo snackbar). A large multi-line "Új sor(ok)" field at the bottom with a "Hozzáadás" button: **each non-empty line becomes one row** (trimmed), appended in order. No splitting inside a line, so a row can hold several sentences that are spoken in one go ("Vegyetek sütit! Tegnap csináltuk."). Pasting a list from phone notes (one item per line) gives one row per line.
- **No sentence splitting** (decided 2026-11-04): splitting on punctuation was error-prone (ordinals, dates, abbreviations) and would break up multi-sentence rows the user wants to say in one tap. Line breaks are the only separator, because the user sees and controls them.
- "Alapértelmezett mondatok visszaállítása" on seeded lists, only shown when `hasMissingDefaults` is true.
- **Per-row actions:** each row has one ⋮ button (≥ 48 dp) opening a bottom sheet with large rows: "Másolás listába…", "Áthelyezés listába…", "Törlés" (undo snackbar). The two list actions open a picker of the other lists (large rows, history excluded as a target). Delete stays as its own icon too only if it fits without crowding; otherwise it's just in the sheet.
- **History list:** same per-row sheet (copy = "keep it and also save it", move = take it out of history), so saving a phrase works the same as moving between any two lists. No tap-to-edit, no drag reorder (newest first is the order), no add field. Rows can be deleted (privacy: something said to the doctor shouldn't stay on screen for visitors). The history list itself can't be renamed or deleted (T18).
- **No "save free text" button** on the speaking screen (decided 2026-11-04): everything spoken lands in history anyway, so "speak it, then save it from history" covers it without another target on the speaking screen. Sentences written ahead of time go in through this editor's "Új sor(ok)" field.
- Conversation lists: "Újrakezdés" button (`resetSaid`).
- All strings via ARB (hu + en).
- List-level actions (rename, pin, delete, color) stay in the overview's ⋮ menu only; this screen is just for sentences.
- **Checks:** `flutter analyze`, `flutter test` (widget tests: three lines with blank lines between → 3 rows in order; "Vegyetek sütit! Tegnap csináltuk." → 1 row; editing a row keeps its id).

### [x] T18a (Agent): List colors
Each list has a color; its chip, its tile in the ▾ grid and all its sentence rows use it, so the user sees which list they're in without reading the chip row. See architecture.md "List colors".
- Schema v3 (v2 is T17a): `sentence_lists.color` nullable text = a **palette key** (e.g. `"blue"`), not an ARGB value. `null` = neutral. Migration: `addColumn`, then give existing lists their seed color (by `seedLanguage` + `seedKey`) or the next palette color. Regenerate `*.g.dart`.
- `lib/ui/list_colors.dart`: a fixed palette of ~8 keys (blue, green, orange, purple, teal, pink, yellow, brown) → `ListColor { chip, row, rowActive }` for light theme (dark theme: return darker tones from the same function, even if the app has no dark mode yet). All tones keep body text at WCAG AA contrast (≥ 4.5:1) with the normal text color, including the greyed-out `said` text (raise its alpha if needed). Unknown key → neutral (forward compatible).
- Seed JSON: optional `"color"` per list (`everyday`: blue, `example-conversation`: orange). History is always neutral grey, no color option. `restoreDefaultLists` uses the seed color.
- `createList` picks the first palette color not used by any list (round robin when all are used).
- Speaking screen: chips filled with their list color, the selected chip additionally gets a thick dark border (color must not be the only cue); grid tiles likewise; rows use `row`, the tapped/speaking row uses `rowActive` + the existing spinner (not `primaryContainer` anymore).
- App bar title on the speaking screen: the **current list's name** instead of the app name (history: its localized title), so the screen says which list is open in words as well as color. Long names: one line, ellipsized (the chip row and the rows themselves stay unchanged). The app name "Mondom" no longer appears on the speaking screen (it was the same word as the speak button).
- **Where it's edited:** lists overview (T18). Each list's ⋮ sheet gets a "Szín" row (with the current color shown as a swatch next to the label); tapping it opens a dialog with a grid of large swatches (≥ 48 dp, selected one with a check mark) plus "Nincs" (neutral). Tapping a swatch saves at once (`setColor(listId, key?)`) and closes the dialog; no separate OK button. History has no "Szín" row (always neutral grey).
- Lists overview rows themselves also show the list's color (tinted row or a wide color stripe at the start), so the overview matches the chips.
- ARB (hu + en) for new strings; color names only as semantics labels for TalkBack.
- **Checks:** `flutter analyze`, `flutter test` (migration v2→v3 test with drift's schema tools or a hand-built v2 DB, plus v1→v3; seeding sets colors; `createList` picks unused colors; contrast unit test over every palette entry for both `said` and normal text; widget test: rows of a colored list have its row color; the app bar shows the current list name and changes when switching lists; overview ⋮ → Szín → pick green → the list's color is `green` and its rows on the speaking screen use it; "Nincs" sets `null`; history's sheet has no Szín row).

### [x] T18c (Agent): Editing UI fixes (restore into menus, color on create)
Problem (own use, 2026-11-04): the "Alapértelmezett mondatok visszaállítása" row in the sentence editor shows up as soon as a single seed sentence is deleted (very common), and then permanently takes space from the sentence list. Restoring is rare, so it belongs in a menu.
- **Sentence editor (`list_editor_screen.dart`):** remove the restore row and the `_missing` stream.
- **Lists overview ⋮ sheet (`lists_screen.dart` `_actions`):** add "Alapértelmezett mondatok visszaállítása" (`Icons.restore`), only when `hasMissingDefaults(l.id)` is true (await it before showing the sheet; never for history). On tap: `restoreDefaultSentences(l.id)`, then a snackbar with the count ("2 mondat visszaállítva"), because the restored rows aren't visible from the overview.
- **Lists overview restore-lists row:** remove the bottom row. Put "Alapértelmezett listák visszaállítása" in a ⋮ overflow menu in the app bar (`PopupMenuButton`, ≥ 48 dp, tooltip "További műveletek"), enabled only when `watchHasMissingDefaultLists` is true (hide the ⋮ entirely if it's the only item and nothing is missing). Snackbar with the count afterwards.
- **"Újrakezdés" (`resetSaid`) in the editor** has the same problem (a permanent row on every conversation list): move it to the overview ⋮ sheet too (conversation lists only, confirm dialog as in T19). The speaking screen's "Minden elhangzott → Újrakezdés" (T19) is unaffected.
- **Color in the "Új lista" dialog:** below the kind choice, a "Szín" row of the same large swatches as the color dialog (≥ 48 dp, check mark on the selected one, color names as semantics labels) plus "Nincs". Preselect the color `createList` would pick today (`nextListColor` over the existing lists), so not touching it behaves as before. Pass the choice to `createList` (new optional `color` parameter: omitted = automatic pick as now, `null` = neutral). Rename keeps its current dialog without colors (color is edited via ⋮ → Szín). If the dialog gets too tall on a small screen, it scrolls (it's already a `SingleChildScrollView`); the name field stays at the top.
- Repository: only the `createList` `color` parameter above. Strings via ARB (hu + en; plural-aware count).
- **Checks:** `flutter analyze`, `flutter test` (update the T18 "restore row" test to the app-bar menu; widget tests: delete a seed sentence → the editor has no restore row; the list's ⋮ sheet shows the restore entry, tapping it brings the sentence back and shows the snackbar; with nothing missing the entry is absent; history's sheet never has it; Újrakezdés appears only for conversation lists; create dialog: untouched swatches → same color as the automatic pick, picking green → new list is `green`, "Nincs" → `null`).

### [x] T19 (Agent): Prepared conversations
- In a `conversation` list, speaking a row (tap or Következő) sets its `said = true`.
- **"Következő ▶"** button below the rows (conversation lists only, fixed position, large): speaks the first unsaid sentence in order. When all are said, it's disabled and shows "Minden elhangzott" with an "Újrakezdés" action next to it (confirm first; this is the one place the speaking screen changes data besides `said`).
- The next unsaid sentence gets a subtle highlight (border/marker, no size change, no auto-scroll jumping; if it's off-screen, scroll it into view only after a Következő tap, never during the user's own scrolling).
- `said` survives app restarts (it's in the DB).
- **Checks:** `flutter analyze`, `flutter test` (Következő order, skipping sentences already said by direct tap, all-said state, reset).

### [x] T19a (Agent): Load sentences into the free-text field (one-shot builder mode)
Goal: say a variation of a saved sentence ("Kérek egy pohár vizet!" → "Kérek egy pohár teát!") or build a sentence from pieces, without breaking "a tap on a row speaks".
- **Button:** a large (≥ 48 dp) button in the app bar, left of Settings (moved there from the bottom bar so the free-text field gets the full width) (`Icons.arrow_downward`, the same arrow the banner and rows show when armed; `playlist_add` was tried and read as "edit lists"; TalkBack label "Mondat betöltése a szövegmezőbe"). Pressing it **arms** builder mode; pressing it again cancels.
- **One-shot:** while armed, the next tap on a sentence row (any list, including history) **appends** its text to the free-text field and builder mode **turns off automatically**. To add several pieces, press the button again before each one. Builder mode never stays on: it is cancelled by pressing the button again, the banner's ✕, switching lists (chip or ▾ grid), pressing Mondom, or the app going to the background.
- **Append rule:** empty field → the sentence text; otherwise `field.trimRight() + " " + text`. Cursor at the end. Don't focus the field or open the keyboard automatically (it would cover the list and block adding more pieces); the user taps the field to edit.
- **Loading is not speaking:** it doesn't speak, doesn't call `addToHistory`, doesn't set `said`, doesn't reorder anything.
- **Visual cues while armed (must be unmistakable):** the button shows an active state (filled/highlighted); a banner at the top of the sentence area: "Koppints a mondatra, amit a szövegmezőbe töltenél" with a ✕; sentence rows get a clearly different look (e.g. dashed border plus a small ↓ icon at the end, or a distinct tint) so a row never looks like it will speak when it won't. The banner appearing is a layout change triggered by a dedicated button, which the interaction rules allow; make sure nothing else shifts. In conversation lists, hide or disable Következő while armed.
- Update architecture.md "Interaction rules": "One tap = one fixed meaning" gets the exception: the one-shot load button, which changes the meaning of exactly the next row tap, with a strong visual cue, and then turns itself off. Add one line on why it isn't a toggle (a mode left on by accident would make a tap silent in an urgent moment), and the rejected alternatives: long-press (slow ALS fingers exceed the long-press time, so a tap meant to speak would load instead; also undiscoverable), a per-row icon (second small target next to the big one, mis-taps), swipe (unreliable with shaky hands, conflicts with scrolling), suggestions above the keyboard (too crowded next to the keyboard's own suggestion row).
- All strings via ARB (hu + en).
- **Checks:** `flutter analyze`, `flutter test` (widget tests with the fake `Speaker`: armed + row tap → text in field, nothing spoken, history unchanged, mode off afterwards; second row tap after that speaks normally; appending to existing text adds one space; cancel via button / ✕ / chip switch / Mondom; a conversation row loaded while armed stays unsaid).

### [x] T19b (Agent): Settings into a drawer (hamburger menu)
Goal (own use, 2026-11-04): the settings screen holds only two rows, so it's an extra screen for nothing; and with the builder button (T19a) next to the cog, the right side of the app bar has two targets side by side (mis-tap risk). A drawer saves a tap and leaves the builder button alone on the right.
- **Speaking screen app bar:** a hamburger button (`Icons.menu`, ≥ 48 dp, tooltip/TalkBack "Menü") as `leading`, left of the list name. The cog is removed; `actions` holds only the builder button (T19a). Remove the 16 dp spacer that separated it from the cog (keep the normal end padding).
- **Drawer (`Scaffold.drawer`)**, opened **only by the button**: `drawerEnableOpenDragGesture: false` (an edge swipe conflicts with Android's back gesture and opens it by accident while scrolling). Contents = today's settings rows, same large rows (≥ 72 dp, icon + title + subtitle): "Hang és nyelv" (current voice · language) → voice picker; "Listák" → lists overview. A small header with the app name "Mondom" is fine (it no longer appears anywhere else on the speaking screen). Tapping a row closes the drawer, then pushes the screen (so back returns to the speaking screen, not to an open drawer). The voice subtitle must be current each time the drawer opens (it was refreshed after the picker returned before).
- **Remove `settings_screen.dart`**: move `_SettingsRow` into the drawer widget (e.g. `lib/ui/main_drawer.dart`). Rows planned for later (speech speed, About, bell/emergency setup) go into the drawer; update the "Later" notes below that say "a row in the settings screen".
- **Texts:** empty-list hint "Ez a lista üres. Szerkesztés: ⚙ Beállítások → Listák" → "Ez a lista üres. Szerkesztés: ☰ Menü → Listák" (hu + en). Drop `settingsTooltip` if unused; screen titles of the voice picker / lists overview are unchanged.
- Update architecture.md "Settings and editing" (settings screen → drawer; editing still never happens on the speaking screen itself, it stays in separate screens reached from the drawer).
- **Checks:** `flutter analyze`, `flutter test` (update tests that tap the cog; widget tests: hamburger → drawer shows both rows with the current voice; "Hang és nyelv" opens the picker; "Listák" shows the lists overview with the open list marked; back from the overview lands on the speaking screen with the drawer closed; the app bar has no cog; a horizontal drag from the left edge does not open the drawer).

### [x] T19c (Agent): Tests use a fixture seed, not the shipped seed files
Problem (2026-11-05): the seed files were rewritten (`hu.json` by hand; `en.json` / `sv.json` translated from it): now 5 lists (`everyday`, `questions`, `food`, `shop`, `example-conversation`) with short phrases and builder pieces. 27 tests broke, none of them an app bug. They load the real `assets/seed/*.json` (the `_fileSeed` helpers) and assert its old contents: exactly 2 seeded lists, texts like "Kérek vizet!" / "Mi újság a suliban?", which palette colors are taken. Every future edit to the phrases would break them again.
- **Don't change the seed files or app code.** Only tests (and a test helper).
- Add a small fixture seed in `test/` (e.g. `test/fixture_seed.dart`, a Dart `Seed` built in code, no asset loading) with `hu` and `en` variants: an `everyday` list (pinned, blue, a few sentences), an `example-conversation` list (kind `conversation`, orange, 3 sentences) and whatever else the existing tests need (e.g. a second pinned everyday list for chip tests). Keep the keys and texts the tests already use where possible, so the edits stay small. Pass it via `AppDatabase(..., loadSeed: fixtureSeed)` everywhere a test uses `_fileSeed` today, and remove the `_fileSeed` helpers.
- Keep each test's intent; only the data source changes. Tests with color expectations (`list_colors_test`, `settings_test`) should follow from the fixture's colors.
- One separate **sanity test** for the shipped files (`test/seed_files_test.dart`): every `assets/seed/*.json` parses with `Seed.fromJson`; each has an `everyday` list; list `seedKey`s are unique per file and sentence `seedKey`s unique per list; every `color` is in `listColorKeys`; `kind` values are valid; and all languages have the same list keys and sentence keys in the same order as `hu.json` (the translations mirror it). No assertions on texts or counts.
- **Checks:** `flutter analyze`, `flutter test` (all green; then change one text in `assets/seed/hu.json` locally, confirm nothing fails, and revert it).

### [x] T20 (You): A real prepared conversation
1. The evening before talking to someone (a family member is fine), create a conversation list in the editor: add 5–10 rows (typed, or pasted from notes one per line), at least one with two sentences in it. Pin it.
2. Next day, open the app: the list is already open. Hold the conversation using only Következő, list taps and the occasional typed sentence; jump to Alap and back at least once.
3. Note what felt slow, confusing or missing (and what the other person noticed). These notes feed Phase 4 and the ALS group / logopédus questions.
Done → commit.

---

## Phase 4: Riasztás (alarm)

Goal: a loud alarm without a new button: a seeded, pinned "Riasztás" list whose rows are sentences with a built-in sound, and an `alarm` flag on any row. Read `docs/architecture.md` "Alarm" first (and "Storage", "Sentence lists"). 112 / emergency SMS is dropped (`docs/TODO.md` "Emergency").

### [x] T21 (Agent): Built-in sounds, schema v4, Riasztás seed
- New `tool/make_sounds.py` (Python stdlib only: `wave`, `math`, `struct`; run with `uv run` or plain `python`) generating `assets/sounds/siren.wav` (rising/falling sweep, ~2 s, loops seamlessly: start and end at zero phase/amplitude), `bell.wav` (two-tone doorbell-like chime with decaying harmonics, ~2 s), `horn.wav` (short loud two-tone horn, ~1 s). Mono, 22050 Hz, 16-bit, normalized to about -1 dBFS. Commit the script and the WAVs; register `assets/sounds/` in `pubspec.yaml`.
- New `lib/speech/sounds.dart`: `const builtInSounds = {'siren': BuiltInSound(asset: 'sounds/siren.wav', loops: true), 'bell': …, 'horn': …}` and `const alarmLoopLimit = Duration(minutes: 2)`.
- Schema v4: `sentences.soundKey` (text, nullable) and `sentences.alarm` (bool, default false), with a migration from v3. Regenerate `database.g.dart`.
- Repository: copy/move keep `soundKey`, `alarm` (and `recordingPath`). Seed parsing reads optional `"sound"` and `"alarm"` per sentence.
- New palette color `red` in `lib/ui/list_colors.dart` (light and dark, WCAG AA for row text like the others). Not picked automatically for new user lists ahead of the existing colors (keep the current "next unused" order, `red` last).
- Seed files `hu`, `en`, `sv`: a new last list `{ "seedKey": "alarm", "kind": "everyday", "pinned": true, "color": "red" }`, titles "Riasztás" / "Alarm" / "Larm", rows: "Vészhelyzet!" (siren), "Gyere ide!" (bell), "Figyelj rám!" (horn), all `"alarm": true`; en: "Emergency!", "Come here!", "Listen to me!"; sv: "Nödläge!", "Kom hit!", "Lyssna på mig!". Keep the test fixture seed in sync where tests need it (T19c).
- Tests: migration v3→v4 keeps data; seed rows get `soundKey`/`alarm`; copy/move keep them; restore-defaults re-adds the Riasztás list.
- **Checks:** `flutter analyze`, `flutter test`.

### [x] T22 (Agent): Alarm playback on the speaking screen
- `Speaker` gets a row-level entry, e.g. `play(SentenceRowData)` (text, soundKey, alarm), used by row taps and Következő; `speak(text)` stays for free text. What plays: known `soundKey` → its asset; otherwise TTS of the text (unknown key = TTS). Last-utterance reuse stays for TTS.
- Alarm rows play on a **separate** `AudioPlayer` with an alarm `AudioContext` (Android usage `alarm`, content type `sonification`, transient audio focus), so the speech player's context is never changed. Non-alarm sound rows play on the normal player. Looping sounds use `ReleaseMode.loop` and are stopped by a timer after `alarmLoopLimit`.
- Only one thing plays at a time: any row tap, Mondom, Következő or Leállítás stops what's playing (alarm or speech) first. Tapping the same alarm row again restarts it.
- `Speaker` exposes `alarmPlaying` (it's a `ChangeNotifier`). While true, the speaking screen shows a large **"Leállítás"** button in the Következő spot (any list kind; in a conversation list it replaces Következő until stopped).
- Alarm rows are not added to history (both row taps and Következő). `said` and builder load behave as for any row.
- Row look (speaking screen): alarm rows only get a leading badge: `Icons.campaign` (megaphone), white in a filled red circle; nothing for non-alarm rows, whether or not they have a sound. List editor rows: a leading icon for a built-in sound (bell → `Icons.notifications_active`, horn → e.g. `Icons.surround_sound`, siren → e.g. `Icons.crisis_alert`) plus the same alarm badge. (A mic icon for recordings comes with message banking.)
- Playback uses the alarm stream's current volume in this task (the setting is T24).
- ARB: "Leállítás" (+ en "Stop").
- Tests: alarm row tap doesn't touch history; Leállítás appears while an alarm plays and stops it (fake player); loop stops after the limit (fake timer / injectable duration).
- **Checks:** `flutter analyze`, `flutter test`.

### [x] T23 (Agent): Alarm toggle in the list editor
- In the per-row ⋮ sheet of the list editor: a switch "Riasztásként szóljon (hangosan)" that sets `alarm`. Short help text under it: "Riasztás hangerején szól, és nem kerül az előzmények közé."
- Not offered on the history list's rows (history rows are never alarms; copying one into a list and flagging it there is fine).
- Choosing a row's sound is not part of this task (later, with message banking).
- **Checks:** `flutter analyze`, `flutter test`.

### [x] T24 (Agent): Alarm volume setting (raise and restore)
- Native: in `MainActivity.kt`, a small channel (e.g. `mondom/alarm_volume`): `get` (current/max of `STREAM_ALARM`), `set(level)`. No new permission. Dart wrapper `lib/speech/alarm_volume.dart`.
- Setting in `shared_preferences`: `alarmVolumeMode` = `system` | `custom` (default `custom`), `alarmVolumeLevel` 0.0–1.0 (default 1.0).
- Drawer row "Riasztás hangereje" → small screen: two large radio rows "A telefon ébresztési hangereje" / "Saját hangerő", a slider (enabled for Saját), and a "Kipróbálás" button that plays the bell as an alarm (stoppable).
- `custom` mode, around each alarm playback: if no `alarmVolumeSaved` pref exists, save the current level; set the stream to the slider level (rounded to the stream's steps; remember the level we set). On end/stop/loop limit: if the stream is still at the level we set, restore the saved level; then delete the pref either way. On app start: if `alarmVolumeSaved` exists (app was killed mid-alarm), do the same restore check.
- Tests (Dart side, fake channel): save/raise/restore; no restore when the user changed the level; startup restore; a second alarm while one plays doesn't overwrite the saved level.
- **Checks:** `flutter analyze`, `flutter test`.

### [x] T25 (You): Try the alarm
1. On the existing install: ☰ → Listák → "Alapértelmezett listák visszaállítása": the red Riasztás chip appears last.
2. Tap each row. Bell and horn play once, the siren loops; Leállítás stops it. Let the siren run to check it stops after 2 minutes. Nothing appears in Előzmények.
3. Turn the alarm volume low with the phone settings, set Saját hangerő to max, play the siren from another room's distance, stop it: the phone's alarm volume is back to low. Try with Do Not Disturb on, and with the phone's volume buttons pressed during the siren.
4. In the editor, flag "Kérek vizet!" as an alarm: it's spoken loudly and stays out of history.
5. Note: is the siren too annoying / not loud enough, do the sentences fit, would a family member hear the bell from the next room?
Done → commit.

### [x] T26 (Agent): Louder output (speech and alarms)
Done 2026-11-07, awaiting the human check on the Pixel 6a. Measured (`python tool/measure_loudness.py`, peak / RMS dBFS): imre -2.5 / -21.5, anna -4.5 / -21.4, berta **-12.8 / -28.7** (quietest), alma -4.6 / -17.8, nst -2.7 / -19.2; old sounds: bell -1 / -14.7, horn -1 / -3.4, siren -1 / -4.0. System TTS has no sample in the repo, so it wasn't measured (the same function runs on it). Piper peak-normalization alone would give +1.5 dB (imre) but +11.8 dB (berta); the +6 dB gain and soft limiter (knee -6 dBFS, ceiling -1 dBFS) add the rest. New sounds: bell -1 / -7.1, horn -1 / -2.2, siren -1 / -2.1 (tanh squash, siren loop still seamless). Not done: `LoudnessEnhancer` (only if still too quiet).
Problem (2026-11-06, Pixel 6a): everything is audible but quieter than a phone call on speaker; the phone has to be turned up high. Goal: noticeably louder at the same phone volume, without audible distortion.
Background: peak normalization alone may gain little (Piper output and the built-in sounds may already peak near 0 dBFS, the sounds are at -1 dBFS). Perceived loudness follows RMS, so the real gain comes from **compression/limiting**: raise the gain, then soft-limit the peaks. All audio already passes through WAV files, so one Dart function can handle it.
- **Measure first:** a small debug log (or `tool/` script for assets) printing peak and RMS dBFS of a Piper sentence (imre, berta), a system TTS sentence, and the three built-in sounds. Put the numbers in the summary.
- New `lib/speech/loudness.dart`: pure function on float samples (−1..1): normalize the peak, apply a fixed make-up gain (start around +6 dB, constant `speechGainDb`), then a smooth soft limiter (e.g. `tanh`-style or a simple look-ahead limiter) with ceiling about -1 dBFS. No per-sentence pumping: keep it static and simple. Plus a helper that reads/writes a 16-bit PCM WAV for the system TTS path.
- Piper: apply it in the isolate on `audio.samples` before `writeWave` (`lib/voices/piper_engine.dart`). System TTS: post-process the file written by `synthesizeToFile` (`lib/voices/system_engine.dart`); if the file isn't 16-bit PCM WAV, leave it unchanged.
- Built-in sounds: re-run `tool/make_sounds.py` with the same treatment (siren and horn can be much more compressed/square-ish, they're meant to be loud; keep the siren loop seamless). Regenerate and commit the WAVs.
- Optional, only if the above isn't enough: Android `LoudnessEnhancer` audio effect on the player's audio session (native, `MainActivity.kt`). Note it in the summary rather than doing it unasked.
- Apply it on the fly, behind one flag `speechBoost` (`shared_preferences`, default `true`, no UI yet: T27 adds the switch). The flag covers TTS speech only, including TTS-spoken alarm rows. Built-in sounds are fixed assets, already loud by design, so they're processed offline in `tool/make_sounds.py` (above), not at runtime, and the flag doesn't affect them. Message-banking recordings are out of scope here (that task decides how to treat them).
- Out of scope: the settings UI (T27).
- Tests: the function never exceeds the ceiling; silence stays silence; a quiet sine comes out louder (RMS up); WAV read/write round-trip.
- **Checks:** `flutter analyze`, `flutter test`. Human verifies on the Pixel 6a: compare loudness and distortion before/after with imre, berta, system TTS and the siren; compare against a speakerphone call.

### [x] T27 (Agent): "Beállítások" screen (replaces the alarm volume screen)
Do after T26. Goal: one screen for the small sound settings, instead of a drawer row per setting (the drawer would otherwise grow with speech speed, loudness, alarm volume, …).
- Drawer row "Riasztás hangereje" → **"Beállítások"** (`Icons.tune`, subtitle e.g. "Hangosítás, riasztás hangereje"). "Hang és nyelv" and "Listák" stay separate rows (they're whole screens of their own); About will be its own row too.
- **Drawer order:** Listák, Beállítások, Hang és nyelv (Listák is used most, so it goes first; it was in the middle). About will go last.
- The screen (rename `alarm_volume_screen.dart` → `settings_screen.dart`), large rows, section headers:
  - **Beszéd**: switch "Hangosítás" (`speechBoost` from T26), help text "Hangosabb beszéd. Kapcsold ki, ha torznak hallod." Room for the speech speed slider later.
  - **Riasztás**: the current alarm volume controls unchanged (radio rows, slider, Kipróbálás).
- ARB (hu + en) for the new texts; drop unused alarm-volume drawer strings.
- Update `docs/architecture.md` "Settings and editing" (drawer rows) and the "Later" notes in this file that say "a row in the drawer".
- Tests: the switch persists `speechBoost`; the alarm volume widget tests still pass on the new screen.
- **Checks:** `flutter analyze`, `flutter test`.

---

## Phase 5: Cleaner loudness

Goal: keep the loudness gained in T26, but remove the overdriven sound it brought (human's description, 2026-11-08: "as if the loudspeakers were overdriven"; a speakerphone call sounds a bit like that too, so this is polish, not a blocker).

Findings (2026-11-08, `voices/samples`, after today's `boostLoudness`): the limiter is a per-sample `tanh` waveshaper, and 5–19% of samples land above its knee, with peaks squashed by up to 7 dB. Reshaping each sample separately is what creates harmonic distortion. The total gain is 8.5–18.8 dB (berta most), and it lifts the noise in the pauses by the same amount.

| voice | gain dB | speech level dBFS (75th pct of 20 ms frame RMS) | pause floor dBFS (10th pct) |
|---|---|---|---|
| imre | 8.5 | -14.6 | -51.7 |
| berta | 18.8 | -9.4 | -48.5 |
| anna | 10.5 | -9.3 | -41.2 |
| alma | 10.6 | -6.1 | -44.2 |
| nst | 8.7 | -8.5 | -42.7 |

The Piper `noiseScale` / `noiseW` sliders are **not** coming back. They change how the voice varies (latent sampling, phoneme durations), not background hiss. T3 found them inaudible (`docs/measurements.md`), and families shouldn't have to tune model parameters.

### [x] T28 (Agent): Replace the waveshaper with a look-ahead limiter
All in `lib/speech/loudness.dart`; `boostLoudness` gets a required `sampleRate` (update the callers in `piper_engine.dart` and `boostWavFile`). The chain, in order:
1. **High-pass**: 2nd-order Butterworth biquad at about 120 Hz (`speechHighPassHz`). Phone speakers can't reproduce that range; it only eats headroom and makes the speaker buzz.
2. **Gain**: unchanged (normalize the peak, then `speechGainDb`).
3. **Look-ahead limiter** replacing the `tanh` knee: ~5 ms look-ahead, gain = the minimum needed over the look-ahead window so no sample exceeds `speechCeilingDb`, smoothed, ~80 ms release. O(n) (e.g. monotonic deque, no window rescans). A final clamp to the ceiling guards rounding. Expose it as a reusable function (T30 uses it too).

All time constants derive from `sampleRate` (Piper is 22050, system TTS varies). Remove `_tanh` and `_kneeLinear` if unused. Add a "Loudness" section to `docs/architecture.md` (the chain and why).
- **Acceptance:** a test reads `voices/samples/*.wav` and prints speech level and pause floor (definitions in the table above). Speech level within 1 dB of the table (`speechGainDb` may go up to 8 if needed); pause floor no higher than the table. Put the numbers in the summary.
- Tests: existing ones (ceiling, silence, quiet sine gets louder, WAV round-trip), plus: the limiter never exceeds the ceiling on a sine at +12 dB; a 1 kHz sine with 6 dB of limiting has its 3rd harmonic at least 35 dB below the fundamental (Goertzel); a 50 Hz sine is attenuated.
- **Checks:** `flutter analyze`, `flutter test`.

### [x] T29 (You): Listen on the Pixel 6a
Compare with imre and berta, at the volume you usually use: the same sentences with Hangosítás on and off, and against the previous build if you still have it.
1. Is the overdriven, crackly sound on loud syllables gone or reduced? Does it still sound as loud?
2. If hiss between words bothers you, note it. A pause expander was left out of T28 because the complaint was distortion, not hiss.
3. If loud syllables still buzz at high phone volume with Hangosítás off too, that's the phone's speaker reaching its limit, and no processing will fix it. Note it.
Done → commit.

Result (2026-11-08): `limitPeaks` look-ahead limiter + 120 Hz high-pass, `speechGainDb` 8. The T28 table targets were not reachable with a true limiter (speech level 0.4–4.5 dB below the old tanh chain, imre closest; pause floor within ~2 dB except nst, which is lower). Listening on the Pixel 6a (imre, berta): cleaner than before, still loud enough, the Hangosítás on/off difference is very audible. Accepted. A pause expander was left out; revisit only if hiss bothers someone.
