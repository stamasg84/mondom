import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mondom/l10n/app_localizations.dart';
import 'package:mondom/ui/voice_picker.dart';
import 'package:mondom/voices/catalog.dart';
import 'package:mondom/voices/elevenlabs_access.dart';
import 'package:mondom/voices/elevenlabs_cache.dart';
import 'package:mondom/voices/elevenlabs_client.dart';
import 'package:mondom/voices/elevenlabs_key_store.dart';
import 'package:mondom/voices/system_tts_info.dart';
import 'package:mondom/voices/voice.dart';
import 'package:mondom/voices/voice_installer.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'sk_test_SECRET_KEY_123';

class _Previewer implements VoicePreviewer {
  final played = <Uint8List>[];
  @override
  Future<bool> playSample(String url) async => true;
  @override
  Future<bool> playBytes(Uint8List wav) async {
    played.add(wav);
    return true;
  }

  @override
  Future<void> speakSystem(String text, String language) async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

class _SystemInfo implements SystemTtsInfo {
  @override
  Future<SystemVoiceAvailability> availability(String language) async =>
      SystemVoiceAvailability.installed;
  @override
  Future<bool> openInstallVoiceData() async => true;
}

class _Installer extends VoiceInstaller {
  _Installer(Directory root, this.done) : super(root: root);
  final Set<String> done;
  @override
  Future<bool> isInstalled(String id) async => done.contains(id);
}

http.Response _json(int code, Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json'},
);

final _voicesBody = {
  'voices': [
    {'voice_id': 'b1', 'name': 'Brian - Deep', 'category': 'premade'},
    {'voice_id': 'm1', 'name': 'Máté - clone', 'category': 'cloned'},
  ],
};

void main() {
  late Directory dir;
  late ElevenLabsCache cache;
  late InMemoryElevenLabsKeyStore keys;
  late _Previewer previewer;
  late List<Voice> selected;
  late List<String> requests;
  late bool offline;
  late int voicesStatus;

  final catalog = Catalog(
    voices: [
      CatalogVoice(
        id: 'imre',
        language: 'hu',
        gender: VoiceGender.male,
        label: 'Imre',
        url: 'https://example.com/imre.tar.bz2',
        sizeBytes: 63000000,
        sha256: 'ab' * 32,
        modelFile: 'imre.onnx',
        sampleUrl: 'https://example.com/imre.wav',
        license: 'MIT',
        minAppVersion: '1.0.0',
      ),
    ],
    sampleText: const {'hu': 'Szia, ez egy minta.'},
  );

  Future<void> tall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('elscreen');
    addTearDown(() => dir.deleteSync(recursive: true));
    cache = ElevenLabsCache(Directory('${dir.path}/cache'));
    keys = InMemoryElevenLabsKeyStore();
    previewer = _Previewer();
    selected = [];
    requests = [];
    offline = false;
    voicesStatus = 200;
  });

  ElevenLabsAccess access() => ElevenLabsAccess(
    keyStore: keys,
    cache: cache,
    clientFactory: (key) => ElevenLabsClient(
      MockClient((req) async {
        if (offline) throw const SocketException('offline');
        requests.add('${req.method} ${req.url.path}');
        if (req.url.path == '/v2/voices') {
          return voicesStatus == 200
              ? _json(200, _voicesBody)
              : _json(voicesStatus, {
                  'detail': {'status': 'invalid_api_key'},
                });
        }
        if (req.url.path == '/v1/user/subscription') {
          return _json(200, {
            'character_count': 1234,
            'character_limit': 10000,
            'next_character_count_reset_unix': 1800000000,
          });
        }
        // PCM: 100 samples.
        return http.Response.bytes(Uint8List(200), 200);
      }),
      key,
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> pumpPicker(
    WidgetTester tester, {
    String selectedId = '',
    String? label,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hu'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('home')),
      ),
    );
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => VoicePickerScreen(
          catalog: catalog,
          installer: _Installer(dir, {'imre'}),
          systemInfo: _SystemInfo(),
          previewer: previewer,
          selectedId: selectedId,
          selectedLabel: label,
          elevenLabs: access(),
          onSelect: (v) async => selected.add(v),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('no key: header and a setup button, no gear, no voices', (
    tester,
  ) async {
    await pumpPicker(tester);
    expect(find.byKey(const Key('elevenlabs-header')), findsOneWidget);
    expect(find.text('Saját ElevenLabs-fiókkal, internettel'), findsOneWidget);
    expect(find.byKey(const Key('elevenlabs-setup')), findsOneWidget);
    expect(find.text('ElevenLabs beállítása'), findsOneWidget);
    expect(find.byKey(const Key('elevenlabs-gear')), findsNothing);
    expect(find.byKey(const Key('elevenlabs-settings')), findsNothing);
    expect(requests, isEmpty);
  });

  testWidgets('key: the account voices by name, select, Próba is cached', (
    tester,
  ) async {
    await keys.write(_key);
    await pumpPicker(tester);
    expect(find.text('Máté'), findsOneWidget);
    expect(find.text('Brian'), findsOneWidget);
    expect(find.byKey(const Key('elevenlabs-gear')), findsOneWidget);
    expect(find.byTooltip('ElevenLabs beállításai'), findsOneWidget);
    expect(find.byKey(const Key('elevenlabs-settings')), findsNothing);
    expect(find.byKey(const Key('elevenlabs-setup')), findsNothing);

    // Próba twice: one synthesis request, both play.
    final play = find.descendant(
      of: find.byKey(const Key('voice-elevenlabs:hu:b1')),
      matching: find.byIcon(Icons.play_circle_outline),
    );
    await tester.ensureVisible(play);
    await tester.tap(play);
    await settle(tester);
    await tester.tap(play);
    await settle(tester);
    expect(previewer.played, hasLength(2));
    expect(
      requests.where((r) => r.contains('/v1/text-to-speech/b1')),
      hasLength(1),
    );

    final select = find.descendant(
      of: find.byKey(const Key('voice-elevenlabs:hu:b1')),
      matching: find.text('Kiválasztás'),
    );
    await tester.tap(select);
    await settle(tester);
    expect(selected.single.id, 'elevenlabs:hu:b1');
    expect(selected.single.label, 'Brian');
  });

  testWidgets('offline: only the selected voice and a note', (tester) async {
    await keys.write(_key);
    offline = true;
    await pumpPicker(tester, selectedId: 'elevenlabs:hu:m1', label: 'Máté');
    expect(find.text('Nincs internet'), findsOneWidget);
    expect(find.text('Máté'), findsOneWidget);
    expect(find.text('Brian'), findsNothing);
    expect(find.byKey(const Key('elevenlabs-gear')), findsOneWidget);
  });

  group('setup screen', () {
    Future<void> openSetup(WidgetTester tester) async {
      final button = find.byKey(const Key('elevenlabs-setup'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await settle(tester);
    }

    Future<void> openViaGear(WidgetTester tester) async {
      final gear = find.byKey(const Key('elevenlabs-gear'));
      await tester.ensureVisible(gear);
      await tester.tap(gear);
      await settle(tester);
    }

    testWidgets('setup screen: short intro, manual link, permission hint', (
      tester,
    ) async {
      await pumpPicker(tester);
      await openSetup(tester);
      expect(find.textContaining('külső, a Mondomtól független'), findsOneWidget);
      expect(find.text('Részletek a súgóban'), findsOneWidget);
      expect(find.byKey(const Key('elevenlabs-manual-url')), findsOneWidget);
      expect(find.textContaining('Szükséges jogosultságok'), findsOneWidget);
    });

    testWidgets('a bad key is not stored', (tester) async {
      voicesStatus = 401;
      await pumpPicker(tester);
      await openSetup(tester);
      await tester.enterText(find.byKey(const Key('elevenlabs-key')), _key);
      await tester.tap(find.byKey(const Key('elevenlabs-check')));
      await settle(tester);
      expect(find.text('Ez a kulcs nem érvényes.'), findsOneWidget);
      expect(await keys.read(), isNull);
      expect(find.byKey(const Key('elevenlabs-delete')), findsNothing);
    });

    testWidgets('a good key is stored; credit line; picker lists voices', (
      tester,
    ) async {
      await pumpPicker(tester);
      await openSetup(tester);
      await tester.enterText(
        find.byKey(const Key('elevenlabs-key')),
        ' $_key ',
      );
      await tester.tap(find.byKey(const Key('elevenlabs-check')));
      await settle(tester);
      expect(await keys.read(), _key);
      expect(find.byKey(const Key('elevenlabs-saved')), findsOneWidget);
      expect(
        find.textContaining('Felhasznált kredit: 1 234 / 10 000'),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text('Brian'), findsOneWidget);
    });

    testWidgets('an offline check shows the reason, nothing stored', (
      tester,
    ) async {
      await pumpPicker(tester);
      await openSetup(tester);
      offline = true;
      await tester.enterText(find.byKey(const Key('elevenlabs-key')), _key);
      await tester.tap(find.byKey(const Key('elevenlabs-check')));
      await settle(tester);
      expect(
        find.text('Nincs internet, így nem lehet ellenőrizni a kulcsot.'),
        findsOneWidget,
      );
      expect(await keys.read(), isNull);
    });

    testWidgets('fallback voice: system + installed Piper, saved', (
      tester,
    ) async {
      await tall(tester);
      await keys.write(_key);
      await pumpPicker(tester);
      await openViaGear(tester);
      final imre = find.byKey(const Key('fallback-imre'));
      await tester.ensureVisible(imre);
      expect(find.byKey(const Key('fallback-system-hu')), findsOneWidget);
      await tester.tap(imre);
      await settle(tester);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(elevenLabsFallbackKey), 'imre');
      final expressive = find.byKey(const Key('elevenlabs-expressive'));
      await tester.ensureVisible(expressive);
      await tester.tap(expressive);
      await settle(tester);
      expect(prefs.getBool(elevenLabsExpressiveKey), isTrue);
    });

    testWidgets('delete key: confirm, clears key and cache, switches voice', (
      tester,
    ) async {
      await tall(tester);
      await keys.write(_key);
      SharedPreferences.setMockInitialValues({elevenLabsFallbackKey: 'imre'});
      await tester.runAsync(() => cache.put('b1', 'm', 'x', Uint8List(100)));
      await pumpPicker(tester, selectedId: 'elevenlabs:hu:b1', label: 'Brian');
      await openViaGear(tester);
      final delete = find.byKey(const Key('elevenlabs-delete'));
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await settle(tester);
      // Cancel first: nothing happens.
      await tester.tap(find.text('Mégse'));
      await settle(tester);
      expect(await keys.read(), _key);
      await tester.tap(delete);
      await settle(tester);
      await tester.tap(find.text('Kulcs törlése').last);
      await settle(tester);
      expect(await keys.read(), isNull);
      expect(cache.dir.existsSync(), isFalse);
      expect(selected.single.id, 'imre');
    });
  });
}
