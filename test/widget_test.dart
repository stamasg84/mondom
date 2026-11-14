import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mondom/main.dart';
import 'package:mondom/speech/speaker.dart';
import 'package:mondom/storage/database.dart';
import 'package:mondom/storage/lists_repository.dart';
import 'package:mondom/storage/seed.dart';
import 'package:mondom/ui/speaking_screen.dart';
import 'package:mondom/voices/voice.dart';
import 'package:mondom/voices/voice_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoEngine implements VoiceEngine {
  @override
  int get loadMs => 0;
  @override
  bool get isLoaded => true;
  @override
  Future<void> load() async {}
  @override
  Future<SynthResult> synthesizeToWav(
    String text, {
    bool urgent = false,
    double speed = 1.0,
  }) async => throw UnimplementedError();
  @override
  void dispose() {}
}

class _NoPlayer implements WavPlayer {
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

// setVoice is never called, so the speaker stays in its "loading" state.
Speaker _loadingSpeaker() => Speaker(
  engineFactory: (Voice _) => Future<VoiceEngine>.value(_NoEngine()),
  player: _NoPlayer(),
);

Future<void> _pump(WidgetTester tester, Locale locale) async {
  SharedPreferences.setMockInitialValues({});
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final db = AppDatabase(
    NativeDatabase.memory(),
    loadSeed: (_) async => const Seed([]),
  );
  addTearDown(db.close);
  await tester.pumpWidget(
    MondomApp(
      home: SpeakingScreen(
        speaker: _loadingSpeaker(),
        repo: ListsRepository(db),
      ),
    ),
  );
}

void main() {
  testWidgets('Hungarian phone shows Hungarian strings', (tester) async {
    await _pump(tester, const Locale('hu', 'HU'));
    expect(find.text('Betöltés…'), findsOneWidget);
    expect(find.text('Ismétlés'), findsNothing);
  });

  testWidgets('other locales fall back to English', (tester) async {
    await _pump(tester, const Locale('de', 'DE'));
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.text('Repeat'), findsNothing);
  });
}
