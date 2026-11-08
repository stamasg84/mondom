# Tasks

How to use: start a Sonnet session (`claude --model sonnet`) and say "Do task T28 from docs/tasks.md". Read `docs/architecture.md` first.
**Agent** tasks: stay in scope, run the listed checks, finish with a short summary of what changed and what the human should verify. Don't commit; the human commits after testing.
**You** tasks: done by the human (new to Flutter) on Windows + a Pixel 6a. Flutter SDK and Android Studio are installed, `flutter doctor` is OK, developer mode is on.
Mark tasks done by changing `[ ]` to `[x]`. When a phase is finished, move it to `docs/done.md`.

---

## Phase 6: Message banking

Goal: record your own voice for any sentence, played instead of TTS. Design: `docs/architecture.md` "Message banking" (read it first). No schema change: `sentences.recordingPath` already exists.

### [x] T30 (Agent): Playing recordings (no recording UI yet)
- New `lib/speech/recording_store.dart`: `RecordingStore` over `<appSupport>/recordings/`: `adopt(tempWavPath)` (copy in under a new unique file name, delete the temp, return the file name), `resolve(fileName)` → absolute path or null if the file is missing. `sweep(Set<String> referenced)` at app start deletes unreferenced files, with the guards from the architecture doc. The DB stores the **file name only**.
- `lib/speech/loudness.dart`: `prepareRecording(PcmWav)`: drop the first and last 100 ms (button clicks), trim silence at both ends (20 ms frames, threshold 40 dB below the loudest frame, keep 100 ms of padding), high-pass at 80 Hz, normalize speech level to `recordingTargetRmsDb` (start at -16 dBFS) with the gain capped at +15 dB, then the T28 limiter. No `speechGainDb`. Never modifies the original.
- `SentenceRowData.recordingPath` (file name). In `Speaker.play`, priority is recording > sound > TTS. A recording: resolve, read, `prepareRecording` in an `Isolate.run`, write a temp WAV, play on the speech or alarm player per `alarm`, reusing the last-utterance mechanism (key `rec\0<fileName>`) so a second tap replays instantly. Only that temp file may ever be deleted by `_forgetLast`. Must work with no voice loaded (`canPlay` true when `recordingPath != null`). File missing or unreadable → fall through to sound/TTS, no error shown.
- `speaking_screen.dart`: pass `recordingPath` for row taps and Következő.
- `ListsRepository`: `setSentenceRecording(id, fileName?)`; `addToHistory(text, {recordingPath})` stores it on a new row, and overwrites on an existing row only when non-null, so re-tapping from Előzmények plays the same voice. `referencedRecordings()` for the sweep. `main.dart` runs the sweep at start, without blocking the UI.
- Editor rows: a leading `Icons.mic` when `recordingPath != null` (next to the sound icon logic). Nothing new on the speaking screen.
- Tests: `prepareRecording` (trim, gain cap, ceiling, silence stays silence); playback priority; missing file → TTS; recording plays with no voice loaded; alarm + recording uses the alarm player; replay doesn't reprocess; the original file is never touched; sweep keeps referenced and young files, and does nothing when no reference exists; history carries the recording.
- **Checks:** `flutter analyze`, `flutter test`.

### [x] T31 (Agent): Recording screen, one sentence
- Add the `record` package (`flutter pub add record`; approved 2026-11-08, BSD-3-Clause, 7.1.2 resolves with our constraints) and `RECORD_AUDIO` to the manifest. Hide it behind `abstract class VoiceRecorder` so widget tests can fake it. WAV, 44100 Hz, mono, 16-bit; autoGain, echoCancel and noiseSuppress off.
- New `lib/ui/recording_screen.dart`, taking a list of sentences and showing one at a time (T32 passes many; here it gets one). Huge sentence text, then by state:
  - **Idle**: one large "Felvétel" button.
  - **Recording**: red dot plus a live level bar (from the amplitude stream), one large "Kész" button. Tap to start, tap to stop, **never press-and-hold** (weak hands). Auto-stop at 60 s (`maxRecordingLength`).
  - **Review**: "Meghallgatom" (plays through `prepareRecording`, so it sounds as it will), "Újra", "Mentés". Saving is the only thing that touches the DB; an old recording stays until then.
- Stop all playback before recording. App going to the background while recording: stop and go to Review. Back with an unsaved take: "Elveted a felvételt?".
- Mic permission: requested on the first "Felvétel". Denied: a short explanation and a button to the app's Android settings (small addition to the channel in `MainActivity.kt`).
- ⋮ sheet in the list editor (not for history): no recording → "Saját hang felvétele". Has one → "Felvétel meghallgatása", "Új felvétel", "Felvétel törlése" (with a confirm dialog; clears `recordingPath`).
- Editing the text of a row with a recording: after the edit dialog, ask "A felvétel még a régi szöveget mondja. Megtartod?", with "Megtartom" and "Törlöm". Never delete silently.
- ARB (hu + en). Tests with the fake recorder: the state machine; 60 s auto-stop; save sets the recording; Újra keeps the old one until Mentés; back asks; the sheet shows the right rows; the text-edit question appears only for rows with a recording.
- **Checks:** `flutter analyze`, `flutter test`.

### [ ] T32 (Agent): Record a whole list in one sitting
Voice and energy are limited, so recording many sentences must not mean opening a sheet for each.
- List editor app bar: `Icons.mic` button "Felvétel" (not for history, disabled when nothing qualifies). It opens the T31 screen with the list's rows, in order, that have neither a recording nor a built-in sound.
- The screen shows progress ("3 / 12") and adds "Kihagyom". Mentés moves on to the next row, in Idle, without further taps. After the last row: a short summary ("9 felvétel mentve") and back to the editor. Leaving midway keeps what was saved; re-opening continues with what's left.
- ARB (hu + en). Tests: rows with recordings/sounds are skipped; Mentés advances; Kihagyom saves nothing; the summary count.
- **Checks:** `flutter analyze`, `flutter test`.

### [ ] T33 (Agent): Backup to a file
Recordings can't be made again once the voice is gone, and a lost phone must not mean losing them. Android's auto-backup caps at 25 MB, so it isn't enough.
- Beállítások, new section "Mentés": "Biztonsági mentés készítése" and "Visszaállítás fájlból".
- Export: in an isolate, write a zip (`archive`, streaming to disk, no full read into memory) to temp: `backup.json` (`version`; all non-history lists with sentences, including `recording` file names, `soundKey`, `alarm`, colors, kind, pinned) plus `recordings/*.wav`. Hand it to Android's file picker (`ACTION_CREATE_DOCUMENT`, default name `mondom-mentes-<date>.zip`) via a small channel in `MainActivity.kt`, streaming the copy. No permission; Google Drive shows up in the picker, with no Drive code on our side.
- Import (`ACTION_OPEN_DOCUMENT`): **non-destructive**, like restore defaults. Lists are appended; a list with the same title and identical sentence texts is skipped. Recording files are copied in under their names and existing ones are never overwritten. Unknown `version` → an error message and no changes. Reject zip entries with paths outside `recordings/`.
- Show progress (the zip may be 100 MB+), and a result line.
- ARB (hu + en). Tests: round-trip into an empty DB; importing twice adds nothing; bad version; a malicious entry path is rejected.
- **Checks:** `flutter analyze`, `flutter test`.

### [ ] T34 (You): Try message banking
1. In a list, ☰ → Listák → a list → the mic button: record 5+ sentences in one go. Grant the mic permission at the first one. Include one at arm's length and one in a noisy room.
2. On the speaking screen, tap them: is it your voice, as loud as TTS, with no clicks or long silence at the ends? Note how long a tap takes before sound starts.
3. Airplane mode, a list with recordings, with a Piper voice selected and with no voice loaded yet (tap right after launch).
4. Flag a recorded row as an alarm: loud, not in Előzmények. Tap a non-alarm recorded row, then re-tap it from Előzmények: your voice.
5. Edit the text of a recorded row: you get the question. Delete a row and press Visszavonás: the recording still plays.
6. Make a backup to Drive or the Downloads folder, uninstall the app, reinstall, restore: lists and recordings are back.
Done → commit.

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
