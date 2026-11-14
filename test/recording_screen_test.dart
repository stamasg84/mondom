import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mondom/main.dart';
import 'package:mondom/speech/recording_store.dart';
import 'package:mondom/speech/speaker.dart';
import 'package:mondom/speech/voice_recorder.dart';
import 'package:mondom/storage/database.dart';
import 'package:mondom/storage/lists_repository.dart';
import 'package:mondom/ui/recording_screen.dart';
import 'package:mondom/ui/speaking_screen.dart';
import 'package:mondom/voices/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_seed.dart';
import 'speaker_test.dart' show FakePlayer, FakeSoundPlayer;

class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.permission = true});
  bool permission;
  int starts = 0;
  int stops = 0;
  bool recording = false;
  String? path;
  final level = StreamController<double>.broadcast();

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> start(String p) async {
    starts++;
    recording = true;
    path = p;
    File(p).writeAsStringSync('take $starts');
  }

  @override
  Future<String?> stop() async {
    stops++;
    recording = false;
    return path;
  }

  @override
  Stream<double> get levels => level.stream;

  @override
  Future<void> dispose() async {}
}

class _RecordingSpeaker extends Speaker {
  _RecordingSpeaker(RecordingStore store, this.player)
    : super(
        engineFactory: (Voice _) async => throw UnimplementedError(),
        player: player,
        soundPlayer: FakeSoundPlayer(),
        alarmPlayer: FakeSoundPlayer(),
        recordings: store,
      );
  final FakePlayer player;
  final previews = <String>[];

  @override
  bool get ready => true;
  @override
  bool get loading => false;
  @override
  Future<bool> previewRecording(String path) async {
    previews.add(path);
    return true;
  }
}

/// Real file IO resumes one await per round, so saving needs many rounds.
Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  late AppDatabase db;
  late ListsRepository repo;
  late Directory root;
  late RecordingStore store;
  late _RecordingSpeaker speaker;
  late FakeRecorder recorder;
  late int listId;
  late List<int> ids;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory(), loadSeed: fixtureSeed);
    repo = ListsRepository(db);
    root = Directory.systemTemp.createTempSync('rec_screen');
    store = RecordingStore(
      directory: () async => Directory('${root.path}/recordings'),
    );
    speaker = _RecordingSpeaker(store, FakePlayer());
    recorder = FakeRecorder();
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> seedList(WidgetTester tester, List<String> lines) async {
    await tester.runAsync(() async {
      await repo.addSeedLists('hu');
      listId = await repo.createList('Orvos');
      ids = await repo.addSentences(listId, lines);
    });
  }

  Future<Sentence> row(WidgetTester tester, int id) async =>
      (await tester.runAsync(() => repo.watchSentences(listId).first))!
          .firstWhere((s) => s.id == id);

  /// RecordingScreen on its own, pushed over a home page so that popping works.
  Future<void> pumpRecording(WidgetTester tester, {int count = 1}) async {
    tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      MondomApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecordingScreen(
                    targets: [
                      for (var i = 0; i < count; i++)
                        RecordingTarget(id: ids[i], text: 'Mondat $i'),
                    ],
                    repo: repo,
                    store: store,
                    speaker: speaker,
                    recorder: recorder,
                    tempDir: root,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  testWidgets('idle → recording → review → save sets the recording', (
    tester,
  ) async {
    await seedList(tester, ['Egy', 'Kettő']);
    await pumpRecording(tester);
    expect(find.text('Mondat 0'), findsOneWidget);
    expect(find.text('Felvétel'), findsNWidgets(2)); // title + button

    await tester.tap(find.widgetWithText(FilledButton, 'Felvétel'));
    await settle(tester);
    expect(recorder.recording, isTrue);
    expect(find.text('Kész'), findsOneWidget);
    expect(find.byKey(const ValueKey('level')), findsOneWidget);

    recorder.level.add(0.5);
    await settle(tester);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byKey(const ValueKey('level')))
          .value,
      0.5,
    );

    await tester.tap(find.text('Kész'));
    await settle(tester);
    expect(find.text('Meghallgatom'), findsOneWidget);
    expect(find.text('Újra'), findsOneWidget);
    // Nothing saved yet.
    expect((await row(tester, ids[0])).recordingPath, isNull);

    await tester.tap(find.text('Meghallgatom'));
    await settle(tester);
    expect(speaker.previews, [recorder.path]);

    await tester.tap(find.text('Mentés'));
    await settle(tester, rounds: 20);
    final saved = (await row(tester, ids[0])).recordingPath;
    expect(saved, isNotNull);
    final path = await tester.runAsync(() => store.resolve(saved!));
    expect(File(path!).readAsStringSync(), 'take 1');
    expect(File(recorder.path!).existsSync(), isFalse); // temp take is gone
    expect(find.text('open'), findsOneWidget); // popped
    await finish(tester);
  });

  testWidgets('permission asked at the first Felvétel; denied explains', (
    tester,
  ) async {
    recorder.permission = false;
    await seedList(tester, ['Egy']);
    var opened = 0;
    tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      MondomApp(
        home: RecordingScreen(
          targets: [RecordingTarget(id: ids[0], text: 'Egy')],
          repo: repo,
          store: store,
          speaker: speaker,
          recorder: recorder,
          openSettings: () async => opened++,
          tempDir: root,
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Felvétel'));
    await settle(tester);
    expect(recorder.starts, 0);
    expect(find.textContaining('mikrofon'), findsOneWidget);
    await tester.tap(find.text('Beállítások megnyitása'));
    await settle(tester);
    expect(opened, 1);
    await finish(tester);
  });

  testWidgets('auto-stops at the maximum length', (tester) async {
    await seedList(tester, ['Egy']);
    await pumpRecording(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Felvétel'));
    await settle(tester);
    expect(recorder.recording, isTrue);
    await tester.pump(maxRecordingLength + const Duration(seconds: 1));
    await settle(tester);
    expect(recorder.recording, isFalse);
    expect(find.text('Meghallgatom'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Újra keeps the old recording until Mentés', (tester) async {
    await seedList(tester, ['Egy']);
    await tester.runAsync(() => repo.setSentenceRecording(ids[0], 'old.wav'));
    await pumpRecording(tester);

    Future<void> take() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Felvétel'));
      await settle(tester);
      await tester.tap(find.text('Kész'));
      await settle(tester);
    }

    await take();
    final first = recorder.path!;
    await tester.tap(find.text('Újra'));
    await settle(tester);
    expect(File(first).existsSync(), isFalse);
    expect((await row(tester, ids[0])).recordingPath, 'old.wav');

    await take();
    expect((await row(tester, ids[0])).recordingPath, 'old.wav');
    await tester.tap(find.text('Mentés'));
    await settle(tester, rounds: 20);
    final now = (await row(tester, ids[0])).recordingPath;
    expect(now, isNot('old.wav'));
    expect(now, isNotNull);
    await finish(tester);
  });

  testWidgets('back with an unsaved take asks; Mégse stays, Elvetem leaves', (
    tester,
  ) async {
    await seedList(tester, ['Egy']);
    await pumpRecording(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Felvétel'));
    await settle(tester);
    await tester.tap(find.text('Kész'));
    await settle(tester);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Elveted a felvételt?'), findsOneWidget);
    await tester.tap(find.text('Mégse'));
    await settle(tester);
    expect(find.text('Meghallgatom'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.text('Elvetem'));
    await settle(tester);
    expect(find.text('open'), findsOneWidget);
    expect(File(recorder.path!).existsSync(), isFalse);
    expect((await row(tester, ids[0])).recordingPath, isNull);
    await finish(tester);
  });

  testWidgets('going to the background while recording ends in review', (
    tester,
  ) async {
    await seedList(tester, ['Egy']);
    await pumpRecording(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Felvétel'));
    await settle(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // Frames stop while paused; the state change itself is what counts.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(recorder.recording, isFalse);
    expect(find.text('Meghallgatom'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('with several targets Mentés moves on to the next, idle', (
    tester,
  ) async {
    await seedList(tester, ['Egy', 'Kettő']);
    await pumpRecording(tester, count: 2);
    await tester.tap(find.widgetWithText(FilledButton, 'Felvétel'));
    await settle(tester);
    await tester.tap(find.text('Kész'));
    await settle(tester);
    await tester.tap(find.text('Mentés'));
    await settle(tester, rounds: 20);
    expect(find.text('Mondat 1'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Felvétel'), findsOneWidget);
    expect((await row(tester, ids[0])).recordingPath, isNotNull);
    await finish(tester);
  });

  testWidgets('batch: progress, Kihagyom saves nothing, summary counts', (
    tester,
  ) async {
    await seedList(tester, ['Egy', 'Kettő']);
    await pumpRecording(tester, count: 2);
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.text('Kihagyom'));
    await settle(tester);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Mondat 1'), findsOneWidget);
    expect((await row(tester, ids[0])).recordingPath, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Felvétel'));
    await settle(tester);
    await tester.tap(find.text('Kész'));
    await settle(tester);
    await tester.tap(find.text('Mentés'));
    await settle(tester, rounds: 20);
    expect(find.text('1 felvétel mentve'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Kész'));
    await settle(tester);
    expect(find.text('open'), findsOneWidget);
    expect((await row(tester, ids[1])).recordingPath, isNotNull);
    await finish(tester);
  });

  testWidgets('single target has no Kihagyom and no summary', (tester) async {
    await seedList(tester, ['Egy']);
    await pumpRecording(tester);
    expect(find.text('Kihagyom'), findsNothing);
    await finish(tester);
  });

  group('list editor', () {
    Future<void> openEditor(WidgetTester tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        MondomApp(
          home: SpeakingScreen(
            speaker: speaker,
            repo: repo,
            voice: () => Voice.system('hu'),
            onOpenVoicePicker: () async {},
            recorderFactory: () => recorder,
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('Menü'));
      await settle(tester);
      await tester.tap(find.text('Listák'));
      await settle(tester);
      await tester.tap(find.text('Orvos'));
      await settle(tester);
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byTooltip('További műveletek').first);
      await settle(tester);
    }

    testWidgets('sheet: no recording offers only "Saját hang felvétele"', (
      tester,
    ) async {
      await seedList(tester, ['Egy']);
      await openEditor(tester);
      await openSheet(tester);
      expect(find.text('Saját hang felvétele'), findsOneWidget);
      expect(find.text('Felvétel meghallgatása'), findsNothing);
      expect(find.text('Új felvétel'), findsNothing);
      expect(find.text('Felvétel törlése'), findsNothing);

      await tester.tap(find.text('Saját hang felvétele'));
      await settle(tester);
      expect(find.text('Egy'), findsOneWidget); // the recording screen
      expect(find.widgetWithText(FilledButton, 'Felvétel'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('sheet: with a recording, listen / new / delete (confirmed)', (
      tester,
    ) async {
      await seedList(tester, ['Egy']);
      await tester.runAsync(() async {
        final f = File('${root.path}/src.wav')..writeAsStringSync('x');
        final name = await store.adopt(f.path);
        await repo.setSentenceRecording(ids[0], name);
      });
      await openEditor(tester);
      expect(find.byIcon(Icons.mic), findsNWidgets(2)); // row icon + app bar
      await openSheet(tester);
      expect(find.text('Saját hang felvétele'), findsNothing);
      expect(find.text('Felvétel meghallgatása'), findsOneWidget);
      expect(find.text('Új felvétel'), findsOneWidget);

      await tester.tap(find.text('Felvétel törlése'));
      await settle(tester);
      expect(find.text('Törlöd a felvételt?'), findsOneWidget);
      await tester.tap(find.text('Mégse'));
      await settle(tester);
      expect((await row(tester, ids[0])).recordingPath, isNotNull);

      await openSheet(tester);
      await tester.tap(find.text('Felvétel törlése'));
      await settle(tester);
      await tester.tap(find.text('Törlés'));
      await settle(tester);
      expect((await row(tester, ids[0])).recordingPath, isNull);
      await finish(tester);
    });

    testWidgets('app bar mic records only rows without recording or sound', (
      tester,
    ) async {
      await seedList(tester, ['Egy', 'Kettő', 'Három']);
      await tester.runAsync(() async {
        await repo.setSentenceRecording(ids[1], 'a.wav');
      });
      await openEditor(tester);
      await tester.tap(find.byTooltip('Felvétel'));
      await settle(tester);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Egy'), findsOneWidget);
      await tester.tap(find.text('Kihagyom'));
      await settle(tester);
      expect(find.text('Három'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('app bar mic is disabled when nothing qualifies', (
      tester,
    ) async {
      await seedList(tester, ['Egy']);
      await tester.runAsync(() => repo.setSentenceRecording(ids[0], 'a.wav'));
      await openEditor(tester);
      final b = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.mic),
      );
      expect(b.onPressed, isNull);
      await finish(tester);
    });

    testWidgets('history rows have no recording actions', (tester) async {
      await seedList(tester, ['Egy']);
      await tester.runAsync(() => repo.addToHistory('Szia'));
      tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        MondomApp(
          home: SpeakingScreen(
            speaker: speaker,
            repo: repo,
            voice: () => Voice.system('hu'),
            onOpenVoicePicker: () async {},
            recorderFactory: () => recorder,
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('Menü'));
      await settle(tester);
      await tester.tap(find.text('Listák'));
      await settle(tester);
      await tester.tap(find.text('Előzmények'));
      await settle(tester);
      await openSheet(tester);
      expect(find.text('Saját hang felvétele'), findsNothing);
      await finish(tester);
    });

    Future<void> editText(WidgetTester tester, String text) async {
      await tester.tap(find.text('Egy'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, text);
      await tester.tap(find.text('Mentés'));
      await settle(tester);
    }

    testWidgets('editing a recorded row asks; Megtartom keeps', (tester) async {
      await seedList(tester, ['Egy']);
      await tester.runAsync(() => repo.setSentenceRecording(ids[0], 'a.wav'));
      await openEditor(tester);
      await editText(tester, 'Más');
      expect(
        find.text('A felvétel még a régi szöveget mondja. Megtartod?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Megtartom'));
      await settle(tester);
      final r = await row(tester, ids[0]);
      expect(r.body, 'Más');
      expect(r.recordingPath, 'a.wav');
      await finish(tester);
    });

    testWidgets('editing a recorded row asks; Törlöm removes it', (
      tester,
    ) async {
      await seedList(tester, ['Egy']);
      await tester.runAsync(() => repo.setSentenceRecording(ids[0], 'a.wav'));
      await openEditor(tester);
      await editText(tester, 'Más');
      await tester.tap(find.text('Törlöm'));
      await settle(tester);
      final r = await row(tester, ids[0]);
      expect(r.body, 'Más');
      expect(r.recordingPath, isNull);
      await finish(tester);
    });

    testWidgets('no question for a row without a recording', (tester) async {
      await seedList(tester, ['Egy']);
      await openEditor(tester);
      await editText(tester, 'Más');
      expect(find.text('Megtartom'), findsNothing);
      expect((await row(tester, ids[0])).body, 'Más');
      await finish(tester);
    });

    testWidgets('no question when the text did not change', (tester) async {
      await seedList(tester, ['Egy']);
      await tester.runAsync(() => repo.setSentenceRecording(ids[0], 'a.wav'));
      await openEditor(tester);
      await editText(tester, 'Egy ');
      expect(find.text('Megtartom'), findsNothing);
      expect((await row(tester, ids[0])).recordingPath, 'a.wav');
      await finish(tester);
    });
  });
}
