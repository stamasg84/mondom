import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mondom/speech/speaker.dart';
import 'package:mondom/voices/elevenlabs_cache.dart';
import 'package:mondom/voices/elevenlabs_client.dart';
import 'package:mondom/voices/elevenlabs_engine.dart';
import 'package:mondom/voices/voice.dart';
import 'package:mondom/voices/voice_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'sk_test_SECRET_KEY_123';

/// Fallback that records what it was asked and writes a tiny file.
class _Fallback implements VoiceEngine {
  _Fallback(this.dir);
  final Directory dir;
  final texts = <String>[];
  final urgentFlags = <bool>[];
  final speeds = <double>[];
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
  }) async {
    texts.add(text);
    urgentFlags.add(urgent);
    speeds.add(speed);
    final f = File('${dir.path}/fb_${texts.length}.wav')
      ..writeAsStringSync(text);
    return SynthResult(f.path, 1, 1);
  }

  @override
  void dispose() {}
}

class _Player implements WavPlayer {
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

class _NoSound implements SoundPlayer {
  @override
  Future<void> playAsset(String asset, {bool loop = false}) async {}
  @override
  Future<void> playFile(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Stream<void> get onComplete => const Stream.empty();
  @override
  void dispose() {}
}

/// Raw 16-bit mono PCM (0.5 s square wave), as the API returns it.
Uint8List _pcm() {
  const n = 11025;
  final out = Uint8List(n * 2);
  final d = ByteData.sublistView(out);
  for (var i = 0; i < n; i++) {
    d.setInt16(i * 2, i % 50 < 25 ? 3000 : -3000, Endian.little);
  }
  return out;
}

http.Response _error(int code, String status) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'detail': {'status': status, 'message': 'x'},
    }),
  ),
  code,
);

void main() {
  late Directory dir;
  late _Fallback fallback;
  late ElevenLabsCache cache;
  late Voice voice;
  var requests = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({'speechBoost': false});
    dir = Directory.systemTemp.createTempSync('eleven_engine_test');
    fallback = _Fallback(dir);
    cache = ElevenLabsCache(Directory('${dir.path}/cache'));
    voice = Voice.elevenLabs('hu', 'abc123', 'Brian');
    requests = 0;
  });

  tearDown(() => dir.deleteSync(recursive: true));

  ElevenLabsEngine engine(MockClient? m, {String Function()? model}) =>
      ElevenLabsEngine(
        voice: voice,
        client: m == null ? null : ElevenLabsClient(m, _key),
        fallback: fallback,
        fallbackVoice: Voice.system('hu'),
        cache: cache,
        tempDir: dir,
        modelId: model == null
            ? ElevenLabsEngine.defaultModel
            : () async => model(),
      );

  MockClient respond(http.Response Function() r) => MockClient((req) async {
    requests++;
    return r();
  });

  MockClient ok() => respond(() => http.Response.bytes(_pcm(), 200));

  test('voice id and kind', () {
    expect(voice.id, 'elevenlabs:hu:abc123');
    expect(voice.kind, VoiceKind.elevenlabs);
    expect(voice.elevenLabsVoiceId, 'abc123');
    expect(voice.label, 'Brian');
  });

  test(
    'success writes the cache; the second call is a hit, no request',
    () async {
      final e = engine(ok());
      final first = await e.synthesizeToWav('Kérek vizet!');
      expect(requests, 1);
      expect(e.lastFallback, isNull);
      expect(fallback.texts, isEmpty);
      expect(File(first.path).existsSync(), isTrue);
      expect(Directory('${dir.path}/cache').listSync(), hasLength(1));

      final second = await e.synthesizeToWav('Kérek vizet!');
      expect(requests, 1);
      expect(second.path, isNot(first.path));
      expect(
        File(second.path).readAsBytesSync(),
        File(first.path).readAsBytesSync(),
      );
    },
  );

  test('the returned path is never a cache file', () async {
    final e = engine(ok());
    for (var i = 0; i < 2; i++) {
      final r = await e.synthesizeToWav('Szia!');
      expect(File(r.path).parent.path, isNot(cache.dir.path));
      File(r.path).deleteSync(); // as the speaker does
    }
    expect(cache.lookup('abc123', elevenLabsFlashModel, 'Szia!'), isNotNull);
  });

  test('a different model is a different cache entry', () async {
    var model = elevenLabsFlashModel;
    final e = engine(ok(), model: () => model);
    await e.synthesizeToWav('Szia!');
    model = elevenLabsExpressiveModel;
    await e.synthesizeToWav('Szia!');
    expect(requests, 2);
  });

  final reasons = <String, (http.Response Function(), ElevenLabsFailure)>{
    'bad key': (() => _error(401, 'invalid_api_key'), ElevenLabsFailure.badKey),
    'quota': (() => _error(402, 'quota_exceeded'), ElevenLabsFailure.quota),
    'server': (() => http.Response('oops', 503), ElevenLabsFailure.server),
    'unsupported language': (
      () => _error(400, 'unsupported_language'),
      ElevenLabsFailure.unsupportedLanguage,
    ),
  };
  for (final entry in reasons.entries) {
    test('${entry.key} falls back and is exposed', () async {
      final e = engine(respond(entry.value.$1));
      final r = await e.synthesizeToWav('Segíts!');
      expect(fallback.texts, ['Segíts!']);
      expect(File(r.path).readAsStringSync(), 'Segíts!');
      expect(e.lastFallback, entry.value.$2);
      expect(Directory('${dir.path}/cache').existsSync(), isFalse);
    });
  }

  test('offline (socket error) falls back', () async {
    final e = engine(MockClient((_) async => throw const SocketException('x')));
    await e.synthesizeToWav('Szia');
    expect(e.lastFallback, ElevenLabsFailure.offline);
  });

  test('empty audio falls back', () async {
    final e = engine(respond(() => http.Response('', 200)));
    await e.synthesizeToWav('Szia');
    expect(e.lastFallback, ElevenLabsFailure.server);
    expect(fallback.texts, ['Szia']);
  });

  test('no key: always falls back with badKey', () async {
    final e = engine(null);
    await e.synthesizeToWav('Szia');
    expect(e.lastFallback, ElevenLabsFailure.badKey);
  });

  test('lastFallback clears after a success and after a cache hit', () async {
    var fail = true;
    final e = engine(
      respond(
        () => fail
            ? _error(402, 'quota_exceeded')
            : http.Response.bytes(_pcm(), 200),
      ),
    );
    await e.synthesizeToWav('A');
    expect(e.lastFallback, ElevenLabsFailure.quota);
    fail = false;
    await e.synthesizeToWav('A');
    expect(e.lastFallback, isNull);
    fail = true;
    await e.synthesizeToWav('B');
    expect(e.lastFallback, ElevenLabsFailure.quota);
    await e.synthesizeToWav('A'); // cache hit
    expect(e.lastFallback, isNull);
  });

  test('urgent never calls the client, but uses a cache hit', () async {
    final e = engine(ok());
    await e.synthesizeToWav('Vész!', urgent: true);
    expect(requests, 0);
    expect(fallback.texts, ['Vész!']);
    expect(fallback.urgentFlags, [true]);

    await e.synthesizeToWav('Vész!'); // fills the cache
    expect(requests, 1);
    await e.synthesizeToWav('Vész!', urgent: true);
    expect(requests, 1);
    expect(fallback.texts, hasLength(1));
  });

  test('load only loads the fallback: no request', () async {
    final e = engine(ok());
    await e.load();
    expect(requests, 0);
    expect(e.isLoaded, isTrue);
  });

  group('cache', () {
    test('eviction keeps the newest files under the cap', () async {
      final small = ElevenLabsCache(
        Directory('${dir.path}/small'),
        maxBytes: 250,
      );
      for (var i = 0; i < 4; i++) {
        await small.put('v', 'm', 'text $i', Uint8List(100));
      }
      final now = DateTime.now();
      for (var i = 0; i < 4; i++) {
        small
            .lookup('v', 'm', 'text $i')!
            .setLastModifiedSync(now.subtract(Duration(minutes: 10 - i)));
      }
      await small.evict();
      expect(small.dir.listSync(), hasLength(2));
      expect(small.lookup('v', 'm', 'text 3'), isNotNull);
      expect(small.lookup('v', 'm', 'text 2'), isNotNull);
      expect(small.lookup('v', 'm', 'text 0'), isNull);
      expect(small.lookup('v', 'm', 'text 1'), isNull);
    });

    test('a hit refreshes the last-used time', () async {
      await cache.put('v', 'm', 't', Uint8List(100));
      final f = cache.lookup('v', 'm', 't')!;
      f.setLastModifiedSync(DateTime(2020));
      cache.lookup('v', 'm', 't');
      expect(f.lastModifiedSync().year, greaterThan(2020));
    });

    test('clear removes everything', () async {
      await cache.put('v', 'm', 't', Uint8List(100));
      await cache.clear();
      expect(cache.lookup('v', 'm', 't'), isNull);
    });
  });

  group('speaker', () {
    test('alarm rows pass urgent, normal rows do not', () async {
      final fb = _Fallback(dir);
      final speaker = Speaker(
        engineFactory: (_) async => fb,
        player: _Player(),
        soundPlayer: _NoSound(),
        alarmPlayer: _NoSound(),
      );
      addTearDown(speaker.dispose);
      await speaker.setVoice(Voice.system('hu'));
      await speaker.play(const SentenceRowData(text: 'Normál'));
      await speaker.play(const SentenceRowData(text: 'Vész', alarm: true));
      expect(fb.urgentFlags, [false, true]);
    });

    test('exposes the engine fallback reason and voice', () async {
      final e = engine(respond(() => _error(402, 'quota_exceeded')));
      final speaker = Speaker(
        engineFactory: (_) async => e,
        player: _Player(),
        soundPlayer: _NoSound(),
        alarmPlayer: _NoSound(),
      );
      addTearDown(speaker.dispose);
      await speaker.setVoice(voice);
      expect(speaker.lastFallback, isNull);
      await speaker.speak('Szia');
      expect(speaker.lastFallback, ElevenLabsFailure.quota);
      expect(speaker.fallbackVoice, Voice.system('hu'));
    });
  });
}
