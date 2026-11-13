import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mondom/l10n/app_localizations.dart';
import 'package:mondom/ui/voice_picker.dart';
import 'package:mondom/voices/catalog.dart';
import 'package:mondom/voices/system_tts_info.dart';
import 'package:mondom/voices/voice.dart';
import 'package:mondom/voices/voice_installer.dart';

class FakePreviewer implements VoicePreviewer {
  final spoken = <String>[];
  bool sampleOk = false;

  @override
  Future<bool> playSample(String url) async => sampleOk;
  @override
  Future<bool> playBytes(Uint8List wav) async => false;
  @override
  Future<void> speakSystem(String text, String language) async =>
      spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

class FakeSystemInfo implements SystemTtsInfo {
  final status = <String, SystemVoiceAvailability>{};
  int opened = 0;

  @override
  Future<SystemVoiceAvailability> availability(String language) async =>
      status[language] ?? SystemVoiceAvailability.installed;

  @override
  Future<bool> openInstallVoiceData() async {
    opened++;
    return true;
  }
}

CatalogVoice cv(String id, String lang, VoiceGender g) => CatalogVoice(
  id: id,
  language: lang,
  gender: g,
  label: id,
  url: 'https://example.com/$id.tar.bz2',
  sizeBytes: 63000000,
  sha256: 'ab' * 32,
  modelFile: '$id.onnx',
  sampleUrl: 'https://example.com/$id.wav',
  license: 'MIT',
  minAppVersion: '1.0.0',
);

class _InstantInstaller extends VoiceInstaller {
  _InstantInstaller(Directory root) : super(root: root);
  final done = <String>{};
  @override
  Future<bool> isInstalled(String id) async => done.contains(id);
  @override
  Future<void> install(
    CatalogVoice voice, {
    void Function(int received, int total)? onProgress,
    InstallCancelToken? cancel,
    void Function(InstallStage stage)? onStage,
  }) async {
    done.add(voice.id);
  }
}

void main() {
  final catalog = Catalog(
    voices: [
      cv('imre', 'hu', VoiceGender.male),
      cv('berta', 'hu', VoiceGender.female),
      cv('nst', 'sv', VoiceGender.male),
      cv('alma', 'sv', VoiceGender.female),
    ],
    sampleText: const {
      'hu': 'Szia, ez egy minta.',
      'sv': 'Hej, det här är ett prov.',
    },
  );
  late FakeSystemInfo info;

  Future<(FakePreviewer, List<Voice>)> pump(
    WidgetTester tester, {
    bool firstRun = true,
    bool instantInstall = false,
    String selectedId = '',
    Catalog? withCatalog,
    Set<String> installedIds = const {},
  }) async {
    info = FakeSystemInfo();
    final previewer = FakePreviewer();
    final selected = <Voice>[];
    final dir = Directory.systemTemp.createTempSync('picker');
    addTearDown(() => dir.deleteSync(recursive: true));
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
          catalog: withCatalog ?? catalog,
          installer: instantInstall || installedIds.isNotEmpty
              ? (_InstantInstaller(dir)..done.addAll(installedIds))
              : VoiceInstaller(root: dir),
          systemInfo: info,
          selectedId: selectedId,
          firstRun: firstRun,
          previewer: previewer,
          onSelect: (v) async => selected.add(v),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (previewer, selected);
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  Future<void> switchTo(WidgetTester tester, String code) async {
    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('language-$code')));
    await tester.pumpAndSettle();
  }

  Finder inSystemRow(Finder f) =>
      find.descendant(of: find.byKey(const Key('voice-system')), matching: f);

  testWidgets('first run: UI language, system row + its voices only', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Nyelv: Magyar'), findsOneWidget);
    expect(find.text('Android alapértelmezett'), findsOneWidget);
    expect(find.text('imre'), findsOneWidget);
    expect(find.text('berta'), findsOneWidget);
    expect(find.text('nst'), findsNothing);
    expect(find.text('férfi · 63 MB'), findsOneWidget);
    expect(find.text('Letöltés'), findsNWidgets(2));
  });

  testWidgets('selector is hidden with one language', (tester) async {
    await pump(
      tester,
      withCatalog: Catalog(
        voices: [cv('imre', 'hu', VoiceGender.male)],
        sampleText: const {'hu': 'x'},
      ),
    );
    expect(find.byKey(const Key('language-selector')), findsNothing);
    expect(find.text('imre'), findsOneWidget);
  });

  testWidgets("from settings: defaults to the selected voice's language", (
    tester,
  ) async {
    await pump(tester, firstRun: false, selectedId: 'alma');
    expect(find.text('Nyelv: Svéd'), findsOneWidget);
    expect(find.text('imre'), findsNothing);
  });

  testWidgets('switching to Svéd shows the sv system row, NST, Alma', (
    tester,
  ) async {
    final (previewer, selected) = await pump(tester, firstRun: false);
    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    // UI language first, "name (native name)" for the others.
    expect(find.text('Magyar'), findsOneWidget);
    expect(find.text('Svéd (Svenska)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('language-sv')));
    await tester.pumpAndSettle();

    expect(find.text('Nyelv: Svéd'), findsOneWidget);
    expect(find.byKey(const Key('voice-system')), findsOneWidget);
    expect(find.text('nst'), findsOneWidget);
    expect(find.text('alma'), findsOneWidget);
    expect(find.text('imre'), findsNothing);
    expect(find.text('berta'), findsNothing);
    // Switching the selector alone selects nothing.
    expect(selected, isEmpty);

    await tester.tap(inSystemRow(find.byIcon(Icons.play_circle_outline)));
    await tester.pump();
    expect(previewer.spoken, ['Hej, det här är ett prov.']);

    await tester.tap(inSystemRow(find.text('Kiválasztás')));
    await tester.pumpAndSettle();
    expect(selected.single.id, 'system-sv');
    expect(selected.single.languageCode, 'sv');
  });

  testWidgets('missingData: hint and settings button, no select; re-checks '
      'on resume', (tester) async {
    await pump(tester, firstRun: false);
    info.status['sv'] = SystemVoiceAvailability.missingData;
    await switchTo(tester, 'sv');

    expect(
      inSystemRow(find.text('A hang nincs letöltve a telefonon.')),
      findsOneWidget,
    );
    expect(inSystemRow(find.text('Kiválasztás')), findsNothing);
    await tester.tap(find.text('Letöltés az Android beállításaiban'));
    expect(info.opened, 1);

    info.status['sv'] = SystemVoiceAvailability.installed;
    await resume(tester);
    expect(inSystemRow(find.text('Kiválasztás')), findsOneWidget);
  });

  testWidgets('unsupported: hidden for sv, hint for the UI language', (
    tester,
  ) async {
    info = FakeSystemInfo();
    await pump(tester);
    info.status['hu'] = SystemVoiceAvailability.unsupported;
    info.status['sv'] = SystemVoiceAvailability.unsupported;
    await resume(tester);
    expect(
      inSystemRow(find.text('A telefon nem tud ezen a nyelven beszélni.')),
      findsOneWidget,
    );
    expect(find.text('imre'), findsOneWidget);

    await switchTo(tester, 'sv');
    expect(find.byKey(const Key('voice-system')), findsNothing);
    expect(find.text('nst'), findsOneWidget);
  });

  testWidgets('a selected system voice stays whatever the check says', (
    tester,
  ) async {
    await pump(tester, firstRun: false, selectedId: 'system-sv');
    info.status['sv'] = SystemVoiceAvailability.unsupported;
    await resume(tester);
    expect(find.byKey(const Key('voice-system')), findsOneWidget);
    expect(inSystemRow(find.text('Kiválasztva')), findsOneWidget);
  });

  testWidgets('installed marker on a language with a downloaded voice', (
    tester,
  ) async {
    await pump(tester, installedIds: {'nst'});
    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    expect(find.text('1 letöltve'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('language-sv')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('language-hu')),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
  });

  testWidgets('first run: selecting the system voice closes the picker', (
    tester,
  ) async {
    final (_, selected) = await pump(tester);
    expect(find.byKey(const Key('skip')), findsNothing);
    await tester.tap(inSystemRow(find.text('Kiválasztás')));
    await tester.pumpAndSettle();
    expect(selected.single.kind, VoiceKind.system);
    expect(find.byType(VoicePickerScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('first run: a finished download selects the voice and closes', (
    tester,
  ) async {
    final (_, selected) = await pump(tester, instantInstall: true);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('voice-imre')),
        matching: find.text('Letöltés'),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected.single.id, 'imre');
    expect(find.byType(VoicePickerScreen), findsNothing);
  });

  testWidgets('not first run: selecting keeps the picker open', (tester) async {
    final (_, selected) = await pump(tester, firstRun: false);
    await tester.tap(inSystemRow(find.text('Kiválasztás')));
    await tester.pumpAndSettle();
    expect(selected.single.kind, VoiceKind.system);
    expect(find.byType(VoicePickerScreen), findsOneWidget);
  });

  testWidgets('system preview speaks the sample text; failed sample shows '
      'message', (tester) async {
    final (previewer, _) = await pump(tester);
    await tester.tap(inSystemRow(find.byIcon(Icons.play_circle_outline)));
    await tester.pump();
    expect(previewer.spoken, ['Szia, ez egy minta.']);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('voice-imre')),
        matching: find.byIcon(Icons.play_circle_outline),
      ),
    );
    await tester.pump();
    expect(find.text('A minta nem érhető el'), findsOneWidget);
  });
}
