# TODO

Loose ideas and reminders that don't belong to a task in `docs/tasks.md` yet.

## Emergency: 112 / SMS to family (dropped from the MVP, 2026-11-05)
Dropped because of the implicit responsibility: users (or families) might rely on the app instead of really calling 112, while Android limits what an app can do. Facts gathered:
- Android apps can't inject audio into a cellular call; only speakerphone playback next to the phone would work.
- Android sends the caller's location to 112 automatically (AML), so the app adds little there. Unknown whether Hungary's 112 accepts SMS.
- Google Play restricts the `SEND_SMS` permission to default SMS apps and a few exceptions; sending SMS in the background would mean a policy declaration and review. iOS can't send SMS in the background at all.
If users ask for it: the cheap, honest version is a "message family" action that opens the SMS app (`ACTION_SENDTO`, no permission) with a predefined text (+ location, which needs the location permission) filled in, and the user taps send. It never looks like the app sends anything by itself. Could be a row flag like `alarm`.

## APK size: ABIs
The debug APK is ~293 MB because it includes sherpa-onnx's native libraries for all four ABIs (CPU types): `arm64-v8a` (64-bit ARM, nearly all modern phones), `armeabi-v7a` (32-bit ARM, old/cheap phones), `x86_64` and `x86` (emulators, rare devices). Before releasing, build with `flutter build apk --split-per-abi` (or use an app bundle for Play) so each phone only gets its own ABI. **Decided (T43): keep `armeabi-v7a`**, since cheap old phones are exactly the target; per-ABI sizes (38–54 MB) are in `docs/release.md`. Voices are downloaded at runtime, so they don't add to the APK.

## Upgrade sherpa_onnx to 2.x (own phonemization)
`pubspec.yaml` is pinned to `sherpa_onnx: ^1.13.8` because 2.0.0+ removed the built-in espeak-ng phonemizer (`dataDir` is ignored), so Piper fails with "phoneme_codepoints is empty, no lexicon, and no frontend available". To use the latest version, phonemize the text ourselves (e.g. `piper_phonemize` or espeak-ng through our own plugin) and pass `OfflineTtsGenerationConfig.phonemeCodepoints`, or use a lexicon. Check that the Hungarian output matches the 1.x output. See the note under T3 in `docs/done.md`.

## Mirror voice files if needed
The catalog points at sherpa-onnx's `tts-models` release (`.tar.bz2`, each with its own espeak-ng-data copy). If extraction is too slow on a cheap phone or a URL breaks, repackage (zip, shared espeak archive, maybe int8 models) into our own GitHub release and update the catalog URLs.

## int8 voice models
Check whether sherpa-onnx has int8 variants of the Hungarian Piper voices (~1/3 size). If they sound the same, use them in the catalog (faster download).

## flutter_tts applies the Kotlin Gradle Plugin (build warning)
Builds warn: "Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): flutter_tts. Future versions of Flutter will fail to build if your app uses plugins that apply KGP." `flutter_tts` 4.2.5 (latest as of 2026-11-01) hasn't migrated to Built-in Kotlin. Harmless for now. When upgrading Flutter, check for a newer `flutter_tts`; if there is none, replace it with our own small platform channel around Android's `TextToSpeech.synthesizeToFile` (used by `SystemEngine`).


## Audio caching (only if needed)
Decided 2026-11-02 not to cache synthesized audio: generation on the Pixel 6a is under ~0.5 s, acceptable even mid-conversation, and a cache costs storage and complexity (invalidation on voice/speed change). If testing on cheap phones shows noticeable waits, add it: synthesize each sentence on save or voice change, store the WAV, play it on tap (the same path as message-banking recordings). A cheaper middle step: synthesize the *next* unsaid sentence of a prepared conversation in the background while the current one plays.

## Sentence streaming for long text (only if needed)
Decided 2026-11-02 not to split typed text into sentences and stream them: typed messages are short (1–3 sentences, ~130 ms per short phrase on the Pixel 6a), and sherpa-onnx already splits sentences internally, so splitting ourselves only shortens the wait before the first sound. It would cost a playback queue, cancel handling and multi-file Ismétlés. If cheap phones show multi-second waits for longer typed text, add it then: split on `.`, `!`, `?`, `…` and newlines (keep the punctuation), play the first sentence as soon as it's ready and queue the rest. Check first whether the 1.x Dart API exposes sherpa-onnx's per-sentence generation callback, which would avoid splitting by hand.

## Test "Más nyelvek" on the phone
Swedish voices (`sv_SE-nst-medium`, `sv_SE-alma-medium`) were added to the catalog on 2026-11-03, so the "Más nyelvek" section now appears on a Hungarian phone. Test there: the section shows, Swedish voices download/select/delete, and a Swedish (or English) UI lists its own voices first. Seeding by voice language is tested in T17b.

## Optional ElevenLabs voice (idea 2026-11-05, planned 2026-11-13)
ElevenLabs' [Impact Program](https://elevenlabs.io/impact-program) gives people with permanent voice loss (ALS/MND etc.) a free, extendable 5-year Pro license, including a Professional Voice Clone of their own voice (works from a few minutes of audio, even old recordings), and its multilingual models speak Hungarian. ElevenLabs has no AAC app of its own (checked 2026-11-05); patients use the clone through AAC apps that integrate its API: Predictable, Grid (Smartbox), Spoken and Speech Assistant AAC. The last two are among Mondom's reference competitors, so this is becoming an expected feature.

Planned as Phase 7 in `docs/tasks.md` (2026-11-13); design and API facts in `docs/architecture.md` "ElevenLabs voice".
Ask the ALS group first: "Do you already have your voice at ElevenLabs?"

## More languages where Google's system voice has only one gender (checked 2026-11-03)
Google's Android TTS only has a female voice for Slovak, Romanian, Serbian, Finnish and Ukrainian (Swedish has both). A Piper male voice is a real edge there. Candidates (license = training data license on the Piper model card; all are in sherpa-onnx's `tts-models` release):
- **Romanian:** `ro_RO-mihai-medium`, male, CC0, 63 MB.
- **Finnish:** `fi_FI-harri-medium`, male, CC0, 63 MB.
- **Ukrainian:** `uk_UA-ukrainian_tts-medium`, CC0, 77 MB, **one model with 3 speakers** (lada f, mykyta m, tetiana f). Needs an optional `speakerId` per catalog entry (passed as sherpa-onnx's `sid`; voices sharing an archive share one download/install dir, and deleting one must not delete the files the other still uses). Piper also has separate `mykyta`/`oleksa`/`tetiana` *high* models (114 MB each), but sherpa-onnx doesn't publish them, so we'd have to convert and host them.
- Not worth it: **Slovak** (`sk_SK-lili-medium` is female too, no edge over Google). **Serbian:** `sr_RS-serbski_institut-medium` is actually Sorbian (speakers `dsb`/`hsb`) and CC BY-NC-SA, so unusable.
Before adding any: listen to the samples ([Piper samples](https://rhasspy.github.io/piper-samples/)), ideally with a native speaker, since a small single-speaker dataset can be as flat as Imre or worse. Each new language also needs `sampleText`, an `assets/seed/<lang>.json` (proofread by a native speaker), and ARB strings if the UI should be translated.
