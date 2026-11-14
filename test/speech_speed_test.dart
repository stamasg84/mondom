import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mondom/main.dart';
import 'package:mondom/speech/alarm_volume.dart';
import 'package:mondom/speech/speaker.dart';
import 'package:mondom/speech/speech_speed.dart';
import 'package:mondom/ui/settings_screen.dart';
import 'package:mondom/voices/elevenlabs_cache.dart';
import 'package:mondom/voices/elevenlabs_client.dart';
import 'package:mondom/voices/elevenlabs_engine.dart';
import 'package:mondom/voices/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'speaker_test.dart' show FakeEngine, FakePlayer, FakeSoundPlayer;

Uint8List _pcm() => Uint8List(2000);

void main() {
  late Directory dir;

  setUp(() {
    SharedPreferences.setMockInitialValues({'speechBoost': false});
    dir = Directory.systemTemp.createTempSync('speed_test');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('speed is stored per voice, default 1.0', () async {
    expect(await speechSpeed('a'), 1.0);
    await setSpeechSpeed('a', 1.25);
    await setSpeechSpeed('b', 0.8);
    expect(await speechSpeed('a'), 1.25);
    expect(await speechSpeed('b'), 0.8);
    await setSpeechSpeed('a', 1.0);
    expect(await speechSpeed('a'), 1.0);
    expect(await speechSpeed('b'), 0.8);
  });

  test(
    'the speaker passes the voice speed and re-synthesizes on change',
    () async {
      final engine = FakeEngine(dir);
      final speaker = Speaker(
        engineFactory: (_) async => engine,
        player: FakePlayer(),
        soundPlayer: FakeSoundPlayer(),
        alarmPlayer: FakeSoundPlayer(),
      );
      final voice = Voice.system('hu');
      await speaker.setVoice(voice);
      await speaker.speak('Szia');
      await setSpeechSpeed(voice.id, 1.2);
      await speaker.speak('Szia');
      await speaker.speak('Szia'); // same speed: replay
      expect(engine.speeds, [1.0, 1.2]);
      speaker.dispose();
    },
  );

  group('ElevenLabs', () {
    final bodies = <Map>[];
    late ElevenLabsCache cache;
    late FallbackEngine fallback;

    setUp(() {
      bodies.clear();
      cache = ElevenLabsCache(Directory('${dir.path}/cache'));
      fallback = FallbackEngine(FakeEngine(dir));
    });

    ElevenLabsEngine engine(String model) => ElevenLabsEngine(
      voice: Voice.elevenLabs('hu', 'abc', 'Brian'),
      client: ElevenLabsClient(
        MockClient((req) async {
          bodies.add(jsonDecode(utf8.decode(req.bodyBytes)) as Map);
          return http.Response.bytes(_pcm(), 200);
        }),
        'k',
      ),
      fallback: fallback.engine,
      fallbackVoice: Voice.system('hu'),
      cache: cache,
      tempDir: dir,
      modelId: () async => model,
    );

    test(
      'clamped speed in the body; different speeds, different cache keys',
      () async {
        final e = engine(elevenLabsFlashModel);
        await e.synthesizeToWav('Szia', speed: 1.3);
        expect(bodies.single['voice_settings'], {'speed': 1.2});
        await e.synthesizeToWav('Szia', speed: 1.3); // cached
        expect(bodies, hasLength(1));
        await e.synthesizeToWav('Szia', speed: 0.9);
        expect(bodies, hasLength(2));
        expect(bodies.last['voice_settings'], {'speed': 0.9});
        expect(
          cache.lookup('abc', elevenLabsFlashModel, 'Szia', speed: 0.9),
          isNotNull,
        );
        expect(cache.lookup('abc', elevenLabsFlashModel, 'Szia'), isNull);
      },
    );

    test('eleven_v3 gets no speed', () async {
      await engine(elevenLabsExpressiveModel)
          .synthesizeToWav('Szia', speed: 0.8);
      expect(bodies.single.containsKey('voice_settings'), isFalse);
    });

    test('the fallback uses its own voice speed', () async {
      await setSpeechSpeed(Voice.system('hu').id, 0.75);
      final e = ElevenLabsEngine(
        voice: Voice.elevenLabs('hu', 'abc', 'Brian'),
        client: null,
        fallback: fallback.engine,
        fallbackVoice: Voice.system('hu'),
        cache: cache,
        tempDir: dir,
      );
      await e.synthesizeToWav('Szia', speed: 1.2);
      expect(fallback.engine.speeds, [0.75]);
    });
  });

  group('settings slider', () {
    Future<void> pump(WidgetTester tester, {Voice? voice}) async {
      await tester.pumpWidget(
        MondomApp(
          home: SettingsScreen(
            alarmVolume: AlarmVolume(),
            speaker: Speaker(
              engineFactory: (_) async => throw UnimplementedError(),
              player: FakePlayer(),
              soundPlayer: FakeSoundPlayer(),
              alarmPlayer: FakeSoundPlayer(),
            ),
            voice: voice,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    testWidgets('hidden without a voice', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('speech-speed')), findsNothing);
    });

    testWidgets('shown with a voice; reset only when not 1.0', (tester) async {
      final voice = Voice.system('hu');
      await setSpeechSpeed(voice.id, 1.2);
      await pump(tester, voice: voice);
      expect(find.byKey(const Key('speech-speed')), findsOneWidget);
      expect(find.byKey(const Key('speech-speed-reset')), findsOneWidget);
      await tester.tap(find.byKey(const Key('speech-speed-reset')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(await speechSpeed(voice.id), 1.0);
      expect(find.byKey(const Key('speech-speed-reset')), findsNothing);
    });
  });
}

/// Wraps a [FakeEngine] so tests read `engine.speeds`.
class FallbackEngine {
  FallbackEngine(this.engine);
  final FakeEngine engine;
}
