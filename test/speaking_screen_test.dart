import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture_seed.dart';

import 'package:mondom/main.dart';
import 'package:mondom/speech/speaker.dart';

import 'speaker_test.dart' show FakeSoundPlayer;

import 'package:mondom/storage/database.dart';
import 'package:mondom/storage/lists_repository.dart';
import 'package:mondom/ui/speaking_screen.dart';
import 'package:mondom/voices/elevenlabs_client.dart';
import 'package:mondom/voices/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSpeaker extends Speaker {
  _FakeSpeaker()
    : super(
        engineFactory: (Voice _) async => throw UnimplementedError(),
        player: _NoPlayer(),
      );
  final spoken = <String>[];
  ElevenLabsFailure? fallback;
  @override
  ElevenLabsFailure? get lastFallback => fallback;
  @override
  Voice? get fallbackVoice => Voice.system('hu');
  @override
  bool get ready => true;
  @override
  bool get loading => false;
  @override
  Future<void> speak(String text) async => spoken.add(text);
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
    await tester.pump();
  }
}

void main() {
  late AppDatabase db;
  late ListsRepository repo;
  late _FakeSpeaker speaker;
  WidgetTester? tester0;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory(), loadSeed: fixtureSeed);
    repo = ListsRepository(db);
    speaker = _FakeSpeaker();
  });

  // Disposes the tree so drift's stream timers are gone before the test ends.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pumpScreen(WidgetTester tester, {bool seed = true}) async {
    // Seeding normally happens when the first voice is chosen.
    if (seed) await tester.runAsync(() => repo.addSeedLists('hu'));
    tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      MondomApp(
        home: SpeakingScreen(speaker: speaker, repo: repo),
      ),
    );
    await settle(tester);
  }

  testWidgets('cloud_off icon only while the last utterance fell back', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.byIcon(Icons.cloud_off), findsNothing);
    await finish(tester);

    speaker.fallback = ElevenLabsFailure.offline;
    await pumpScreen(tester, seed: false);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    await tester.tap(find.byIcon(Icons.cloud_off));
    await settle(tester);
    expect(
      find.text('Nincs internet, Android alapértelmezett beszél helyette.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Bezár'));
    await settle(tester);
    await finish(tester);
  });

  testWidgets('opens on everyday list; tapping a row speaks and logs history', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Kérek vizet!'), findsOneWidget);

    await tester.tap(find.text('Kérek vizet!'));
    await settle(tester);
    expect(speaker.spoken, ['Kérek vizet!']);

    final rows = await tester.runAsync(() async {
      final history = (await repo.watchLists().first).firstWhere(
        (l) => l.kind == ListKind.history,
      );
      return repo.watchSentences(history.id).first;
    });
    expect(rows!.map((s) => s.body), ['Kérek vizet!']);
    await finish(tester);
  });

  Future<List<String>> historyBodies() async =>
      (await tester0!.runAsync(() async {
        final history = (await repo.watchLists().first).firstWhere(
          (l) => l.kind == ListKind.history,
        );
        return (await repo.watchSentences(history.id).first)
            .map((s) => s.body)
            .toList();
      }))!;

  testWidgets('lists that appear after the screen is built get opened', (
    tester,
  ) async {
    await pumpScreen(tester, seed: false);
    expect(find.text('Kérek vizet!'), findsNothing);
    await tester.runAsync(() => repo.addSeedLists('hu'));
    await settle(tester);
    expect(find.text('Kérek vizet!'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('history: row tap leaves order; other lists and free text '
      'move to top', (tester) async {
    tester0 = tester;
    await tester.runAsync(() async {
      await repo.addToHistory('C');
      await repo.addToHistory('B');
      await repo.addToHistory('A');
    });
    await pumpScreen(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Előzmények'));
    await settle(tester);
    expect(await historyBodies(), ['A', 'B', 'C']);

    await tester.tap(find.text('C'));
    await settle(tester);
    expect(speaker.spoken, ['C']);
    expect(await historyBodies(), ['A', 'B', 'C']);

    // Free text while history is shown goes in at the top.
    await tester.enterText(find.byType(TextField), 'Új');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Mondom'));
    await settle(tester);
    expect(await historyBodies(), ['Új', 'A', 'B', 'C']);

    // A row in another list moves a matching history entry to the top.
    await tester.runAsync(() => repo.addToHistory('Kérek vizet!'));
    await tester.runAsync(() => repo.addToHistory('Új'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Alap'));
    await settle(tester);
    await tester.tap(find.text('Kérek vizet!'));
    await settle(tester);
    expect((await historyBodies()).first, 'Kérek vizet!');
    tester0 = null;
    await finish(tester);
  });

  testWidgets('chips switch lists; grid shows all lists', (tester) async {
    await pumpScreen(tester);
    // Pinned: Alap + Előzmények; the example conversation is not a chip.
    expect(find.widgetWithText(ChoiceChip, 'Alap'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Előzmények'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Példa beszélgetés'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Előzmények'));
    await settle(tester);
    expect(find.text('Kérek vizet!'), findsNothing);
    expect(find.textContaining('Ez a lista üres'), findsOneWidget);

    await tester.tap(find.byTooltip('Összes lista'));
    await tester.pump();
    expect(
      find.widgetWithText(FilledButton, 'Példa beszélgetés'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Példa beszélgetés'));
    await settle(tester);
    // Grid closed; the unpinned list is now a temporary chip.
    expect(
      find.widgetWithText(ChoiceChip, 'Példa beszélgetés'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Példa beszélgetés'),
      findsNothing,
    );
    await finish(tester);
  });

  testWidgets('free text: Mondom speaks, ✕ clears', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'Szia!');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Mondom'));
    await settle(tester);
    expect(speaker.spoken, ['Szia!']);
    expect(find.text('Szia!'), findsOneWidget); // text stays for repeat
    await tester.tap(find.byTooltip('Szöveg törlése'));
    await tester.pump();
    expect(find.text('Szia!'), findsNothing);
    await finish(tester);
  });

  group('load into text field (T19a)', () {
    final load = find.byTooltip('Mondat betöltése a szövegmezőbe');
    String fieldText(WidgetTester t) =>
        t.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('armed row tap loads, does not speak, turns itself off', (
      tester,
    ) async {
      tester0 = tester;
      await pumpScreen(tester);
      await tester.tap(load);
      await tester.pump();
      expect(find.textContaining('Koppints a mondatra'), findsOneWidget);

      await tester.tap(find.text('Kérek vizet!'));
      await settle(tester);
      expect(fieldText(tester), 'Kérek vizet!');
      expect(speaker.spoken, isEmpty);
      expect(await historyBodies(), isEmpty);
      expect(find.textContaining('Koppints a mondatra'), findsNothing);

      // Mode is off: the next tap speaks.
      await tester.tap(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.text('Kérek vizet!'),
        ),
      );
      await settle(tester);
      expect(speaker.spoken, ['Kérek vizet!']);
      tester0 = null;
      await finish(tester);
    });

    testWidgets('appends with one space', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'Szia!  ');
      await tester.tap(load);
      await tester.pump();
      await tester.tap(find.text('Kérek vizet!'));
      await settle(tester);
      expect(fieldText(tester), 'Szia! Kérek vizet!');
      await finish(tester);
    });

    testWidgets('cancel via button, banner ✕, chip, Mondom', (tester) async {
      await pumpScreen(tester);
      final banner = find.textContaining('Koppints a mondatra');

      await tester.tap(load);
      await tester.pump();
      await tester.tap(load);
      await tester.pump();
      expect(banner, findsNothing);

      await tester.tap(load);
      await tester.pump();
      await tester.tap(find.byTooltip('Mégse'));
      await tester.pump();
      expect(banner, findsNothing);

      await tester.tap(load);
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Előzmények'));
      await settle(tester);
      expect(banner, findsNothing);

      await tester.tap(load);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Szia!');
      await tester.tap(find.widgetWithText(FilledButton, 'Mondom'));
      await settle(tester);
      expect(banner, findsNothing);
      expect(speaker.spoken, ['Szia!']);
      await finish(tester);
    });

    testWidgets('conversation row loaded while armed stays unsaid', (
      tester,
    ) async {
      tester0 = tester;
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('Összes lista'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Példa beszélgetés'));
      await settle(tester);
      await tester.tap(load);
      await tester.pump();
      await tester.tap(find.text('Ki kéne cserélni a villanykörtét.'));
      await settle(tester);
      expect(fieldText(tester), 'Ki kéne cserélni a villanykörtét.');
      final said = await tester.runAsync(() async {
        final conv = (await repo.watchLists().first).firstWhere(
          (l) => l.kind == ListKind.conversation,
        );
        return (await repo.watchSentences(conv.id).first).map((s) => s.said);
      });
      expect(said!.any((x) => x), isFalse);
      tester0 = null;
      await finish(tester);
    });
  });

  group('prepared conversation', () {
    Future<void> openConversation(WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('Összes lista'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Példa beszélgetés'));
      await settle(tester);
    }

    Future<List<bool>> saidFlags() async => (await tester0!.runAsync(() async {
      final conv = (await repo.watchLists().first).firstWhere(
        (l) => l.kind == ListKind.conversation,
      );
      return (await repo.watchSentences(conv.id).first)
          .map((s) => s.said)
          .toList();
    }))!;

    const a = 'Ki kéne cserélni a villanykörtét.';
    const b = 'Légyszi vegyetek a boltban trappistát!';
    const c = 'Mi újság a suliban?';

    testWidgets('Következő speaks in order, skips said, then resets', (
      tester,
    ) async {
      tester0 = tester;
      await openConversation(tester);
      final next = find.widgetWithText(FilledButton, 'Következő');

      // Direct tap on the 2nd row marks it said.
      await tester.tap(find.text(b));
      await settle(tester);
      expect(await saidFlags(), [false, true, false]);

      await tester.tap(next);
      await settle(tester);
      await tester.tap(next);
      await settle(tester);
      expect(speaker.spoken, [b, a, c]);
      expect(await saidFlags(), [true, true, true]);

      // All-said state.
      expect(next, findsNothing);
      expect(find.text('Minden elhangzott'), findsOneWidget);

      // Cancel keeps; confirm resets.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Újrakezdés'));
      await settle(tester);
      await tester.tap(find.text('Mégse'));
      await settle(tester);
      expect(await saidFlags(), [true, true, true]);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Újrakezdés'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Újrakezdés'));
      await settle(tester);
      expect(await saidFlags(), [false, false, false]);
      expect(next, findsOneWidget);
      tester0 = null;
      await finish(tester);
    });

    testWidgets('everyday lists have no Következő and no said marks', (
      tester,
    ) async {
      tester0 = tester;
      await pumpScreen(tester);
      expect(find.text('Következő'), findsNothing);
      await tester.tap(find.text('Kérek vizet!'));
      await settle(tester);
      final everyday = await tester.runAsync(() async {
        final l = (await repo.watchLists().first).firstWhere(
          (l) => l.seedKey == 'everyday',
        );
        return repo.watchSentences(l.id).first;
      });
      expect(everyday!.any((s) => s.said), isFalse);
      tester0 = null;
      await finish(tester);
    });

    testWidgets('free text in a conversation list marks nothing said', (
      tester,
    ) async {
      tester0 = tester;
      await openConversation(tester);
      await tester.enterText(find.byType(TextField), 'Szia!');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Mondom'));
      await settle(tester);
      expect(await saidFlags(), [false, false, false]);
      expect(find.text(c), findsOneWidget);
      tester0 = null;
      await finish(tester);
    });
  });

  testWidgets('alarm row: badge, not in history, Leállítás stops it', (
    tester,
  ) async {
    tester0 = tester;
    final alarms = FakeSoundPlayer();
    final real = Speaker(
      engineFactory: (Voice _) async => throw UnimplementedError(),
      player: _NoPlayer(),
      soundPlayer: FakeSoundPlayer(),
      alarmPlayer: alarms,
    );
    addTearDown(real.dispose);
    await tester.runAsync(() => repo.addSeedLists('hu'));
    tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      MondomApp(
        home: SpeakingScreen(speaker: real, repo: repo),
      ),
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Riasztás'));
    await settle(tester);
    expect(find.byIcon(Icons.campaign), findsNWidgets(3));
    expect(find.text('Leállítás'), findsNothing);

    await tester.tap(find.text('Vészhelyzet!'));
    await settle(tester);
    expect(alarms.played, ['sounds/siren.wav']);
    expect(find.text('Leállítás'), findsOneWidget);
    expect(await historyBodies(), isEmpty);

    await tester.tap(find.text('Leállítás'));
    await settle(tester);
    expect(find.text('Leállítás'), findsNothing);
    expect(real.alarmPlaying, isFalse);
    tester0 = null;
    await finish(tester);
  });
}
