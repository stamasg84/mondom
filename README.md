[Magyarul: README.hu.md](README.hu.md)

# Mondom

Mondom ("I say it") is a free, open-source speech aid for Android. It is made for literate adults who have lost their speech or are losing it: ALS (especially bulbar), stroke, laryngectomy, MS. You type or tap a ready-made sentence, and the phone says it out loud. It works in any language your phone's voice can speak; the app itself is in English and Hungarian.

## Why Mondom

- Free, no ads, no accounts. Nothing is locked behind a payment or a sign-in.
- Works offline once a voice is downloaded. Your data stays on the phone.
- Natural voices without setting up a text-to-speech engine: install the app, pick a voice from a short list, listen to a sample first.
- Everything in one install: sentences, voices, recordings, backup.

## Features

- **Sentence lists.** Everything you can say with one tap is a row in a list of whole sentences. Everyday phrases are preloaded (in English, Hungarian and Swedish); you add your own lists ("Doctor", "Night").
- **Free text.** A text field and a speak button are always on the main screen. Press the button again with the same text and it repeats instantly.
- **Building sentences from pieces.** One button loads a row from any list (or history) into the text field instead of speaking it, so you can combine saved pieces with typed words before saying them.
- **History.** The last 30 things you said, ready to say again or save to a list.
- **Prepared conversations.** Write the sentences ahead of time, e.g. the evening before a visit, and say them one by one with a "Next" button. Sentences already said are greyed out.
- **Message banking.** Record your own voice for any sentence; it is played instead of the synthetic voice, offline. A backup file keeps your lists and recordings.
- **Alarm rows.** A row can be an alarm: a siren or a bell, or a sentence played loudly on the phone's alarm volume.
- **Voices.**
  - Offline Piper voices (a male and a female Hungarian voice, other languages too), downloaded once in the app.
  - The phone's own system voice, which works immediately.
  - Optionally your own ElevenLabs account (see [ElevenLabs](#elevenlabs)). A whole list can be saved as recordings in your ElevenLabs voice, and those recordings keep working offline even after the key is removed.
- **Speech speed**, set per voice, and an optional loudness boost for the phone speaker.

## Manual

1. **First launch.** Mondom asks you to pick a voice. "Android default" works immediately; the other voices are downloaded once (about 60 MB each, over Wi-Fi) and then work offline. Tap the play button on a row to hear a sample first. You can change the voice later in ☰ → "Voice and language".
2. **Speaking a row.** Tap a sentence and it is spoken. Tap it again to repeat it. The list chips at the top switch between your pinned lists; ▾ shows all lists.
3. **Typing.** Type in the field at the bottom and press the speak button. The text stays in the field, so pressing again repeats it; ✕ clears it. The ↓ button in the top right corner, above the list chips, loads the next tapped row into the text field instead of speaking it, so you can build a sentence from pieces.
4. **Editing lists.** ☰ → "Lists". Create, rename, color, pin and reorder lists; open a list to edit its sentences. Editing is deliberately two taps away, so a stray tap during a conversation can't leave you on an editing screen.
5. **Preparing a conversation.** In "Lists" create a list of the conversation kind and add one sentence per line. During the visit open it and tap "Next" to say the next unsaid sentence, or tap any row.
6. **Recording your own voice.** In a list's editor, use the microphone button for the whole list or a row's ⋮ menu for one sentence. Tap to start, tap to stop, listen, then save. Recorded rows play your voice instead of the synthetic one.
7. **Backup.** ☰ → "Settings" → "Backup": make a backup file (lists and recordings) and keep it on Google Drive or elsewhere. Restoring only adds, it never overwrites what is on the phone.
8. **Alarms.** The pinned red "Alarm" list has alarm rows (siren, bell, horn). Any row of yours can be marked as an alarm too. While an alarm plays, a big "Stop" button appears. The alarm volume can be set in "Settings".
9. **Speed and loudness.** ☰ → "Settings" → "Speech speed": make speech slower or faster. The speed is saved separately for each voice; "Reset" goes back to normal. "Louder speech" boosts the volume on the phone speaker; turn it off if it sounds distorted.

## ElevenLabs

ElevenLabs is an online voice service. Mondom can use **your own** ElevenLabs account, for example a voice clone of yourself. It is optional, off by default, and everything else in Mondom works without it. Mondom has no ElevenLabs account or key of its own and is not affiliated with ElevenLabs. ElevenLabs has at times offered free voice cloning to people with ALS and other speech-affecting conditions; search their website for current options.

Texts spoken with an ElevenLabs voice are sent to ElevenLabs and appear in your ElevenLabs history. This needs internet.

**Setup**
1. In your ElevenLabs account, create an API key (in the ElevenLabs web app: Developers → API Keys). Give it these permissions: **Text to Speech** and **Voices (read)**. Optionally **User (read)**, which only lets Mondom show your remaining credits.
2. In Mondom open ☰ → "Voice and language". In the ElevenLabs section choose "Set up ElevenLabs", paste the key and save. Mondom checks that it works.
3. Pick one of the voices of your account in the list. Voices are listed by name; your own clone is among them.
4. Choose the **fallback voice**: an offline voice that speaks instead when ElevenLabs can't be reached (no internet, no credit left, invalid key). Mondom is never silent; a cloud icon in the top bar tells you when the fallback spoke and why.

**Good to know**
- **Sentences you already said** are kept on the phone (a cache, up to 100 MB, oldest unused dropped first), so they work offline in the ElevenLabs voice and don't use credits again. Alarm rows never wait for the network.
- **"More expressive voice"** uses a slower, more expressive model that costs twice as many credits.
- **Generating a list's recordings.** In a list's editor, the cloud button saves every row of the list as a recording in your ElevenLabs voice. Mondom shows the estimated cost first. Rows that have your own recording are only replaced if you say so. For a single row use its ⋮ menu → "Save in ElevenLabs voice"; you can listen before saving.
- **Generated recordings are permanent.** They are normal recordings: they work offline, are part of the backup, and are not affected by removing the key, a lapsed subscription or a different selected voice. They do not follow later changes of speed or model.
- **Deleting the key** clears only the cache. Recordings saved into lists are kept; other sentences are spoken by the fallback voice from then on.

## Install

- Google Play: _link coming soon_ (placeholder).
- APK files: [GitHub Releases](https://github.com/stamasg84/mondom/releases). Choose the file for your phone (most modern phones use `arm64-v8a`).
- Build from source (Flutter): `flutter build apk --split-per-abi`

## Privacy

Mondom has no accounts, no ads and no tracking, and everything you write and record stays on your phone. The network is only used for the optional voice downloads and, if you turn it on, for ElevenLabs. Details: [PRIVACY.md](PRIVACY.md).

## License

GPL-3.0, see [LICENSE](LICENSE). The voices have their own licenses, listed per voice in [voices/catalog.json](voices/catalog.json) and in the app's "About" screen.

## Feedback

Bug reports, ideas, questions: [GitHub issues](https://github.com/stamasg84/mondom/issues).
