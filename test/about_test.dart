import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mondom/main.dart';
import 'package:mondom/speech/speaker.dart';
import 'package:mondom/storage/database.dart';
import 'package:mondom/storage/lists_repository.dart';
import 'package:mondom/ui/about_screen.dart';
import 'package:mondom/ui/speaking_screen.dart';
import 'package:mondom/voices/catalog.dart';
import 'package:mondom/voices/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_seed.dart';

const _catalogJson = '''
{"schemaVersion":1,"sampleText":{},"voices":[
 {"id":"hu_HU-imre-medium","language":"hu","gender":"male","label":"Imre",
  "url":"u","sizeBytes":1,"sha256":"aa","modelFile":"m","sampleUrl":"s",
  "license":"MIT"},
 {"id":"sv_SE-alma-medium","language":"sv","gender":"female","label":"Alma",
  "url":"u","sizeBytes":1,"sha256":"aa","modelFile":"m","sampleUrl":"s",
  "license":"CC BY 4.0"}]}''';

class _FakeSpeaker extends Speaker {
  _FakeSpeaker()
    : super(
        engineFactory: (Voice _) async => throw UnimplementedError(),
        player: _NoPlayer(),
      );
  @override
  bool get ready => true;
  @override
  bool get loading => false;
}

class _NoPlayer implements WavPlayer {
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  final catalog = Catalog.parse(_catalogJson, appVersion: '1.0.0')!;

  Future<void> pumpAbout(
    WidgetTester tester, {
    List<String>? opened,
    bool openOk = true,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      MondomApp(
        home: AboutScreen(
          catalog: catalog,
          openUrl: (url) async {
            opened?.add(url);
            return openOk;
          },
          loadVersion: () async => '1.2.3',
          loadSizes: () async =>
              (recordings: 3 * 1024 * 1024, voices: 130 * 1024 * 1024),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('shows version, catalog voice licenses, Alma credit, sizes', (
    tester,
  ) async {
    await pumpAbout(tester);
    expect(find.text('Verzió 1.2.3'), findsOneWidget);
    expect(find.text('Imre: MIT'), findsOneWidget);
    expect(find.text('Alma: CC BY 4.0'), findsOneWidget);
    expect(find.textContaining('NST'), findsOneWidget);
    expect(find.text('Saját felvételek: 3.0 MB'), findsOneWidget);
    expect(find.text('Letöltött hangok: 130.0 MB'), findsOneWidget);
    expect(find.textContaining('nem kapcsolódik'), findsOneWidget);
  });

  testWidgets('sizes show an ellipsis until computed', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final never = Completer<StorageSizes>();
    await tester.pumpWidget(
      MondomApp(
        home: AboutScreen(
          catalog: catalog,
          loadVersion: () async => '1',
          loadSizes: () => never.future,
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Saját felvételek: …'), findsOneWidget);
  });

  testWidgets('links call the channel; failure shows selectable URL', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpAbout(tester, opened: opened, openOk: false);
    await tester.tap(find.text('A projekt a GitHubon'));
    await settle(tester);
    expect(opened, [projectUrl]);
    expect(find.text(projectUrl), findsOneWidget);
    await tester.tap(find.text('Adatkezelés'));
    await settle(tester);
    expect(opened, [projectUrl, privacyUrl]);
  });

  testWidgets('drawer row Névjegy is last and opens the screen', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory(), loadSeed: fixtureSeed);
    final repo = ListsRepository(db);
    tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.runAsync(() => repo.addSeedLists('hu'));
    await tester.pumpWidget(
      MondomApp(
        home: SpeakingScreen(
          speaker: _FakeSpeaker(),
          repo: repo,
          voice: () => Voice.system('hu'),
          catalog: () => catalog,
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Menü'));
    await settle(tester);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Névjegy'), greaterThan(y('Hang és nyelv')));
    await tester.tap(find.text('Névjegy'));
    await settle(tester);
    expect(find.text('Imre: MIT'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  });
}
