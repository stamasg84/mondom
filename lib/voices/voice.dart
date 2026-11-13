enum VoiceKind { system, piper, elevenlabs }

enum VoiceGender { male, female, unknown }

/// One selectable voice (system TTS or a Piper model).
class Voice {
  const Voice({
    required this.id,
    required this.languageCode,
    required this.gender,
    required this.label,
    required this.kind,
  });

  final String id;

  /// Language of the voice, e.g. `hu`.
  final String languageCode;
  final VoiceGender gender;
  final String label;
  final VoiceKind kind;

  @override
  bool operator ==(Object other) => other is Voice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// An ElevenLabs voice chosen while the picker language was [languageCode].
  /// [name] is the display name, kept so the picker can show it offline.
  factory Voice.elevenLabs(String languageCode, String voiceId, String name) =>
      Voice(
        id: 'elevenlabs:$languageCode:$voiceId',
        languageCode: languageCode,
        gender: VoiceGender.unknown,
        label: name,
        kind: VoiceKind.elevenlabs,
      );

  /// The ElevenLabs voice id inside an `elevenlabs:<lang>:<voiceId>` [id].
  String get elevenLabsVoiceId => id.split(':').skip(2).join(':');

  /// The system voice for [languageCode]. The label is a placeholder; UI
  /// shows a localized name.
  factory Voice.system(String languageCode) => Voice(
    id: 'system-$languageCode',
    languageCode: languageCode,
    gender: VoiceGender.unknown,
    label: 'Android',
    kind: VoiceKind.system,
  );
}
