import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mondom/speech/loudness.dart';
import 'package:mondom/speech/recording_store.dart';
import 'package:mondom/speech/speaker.dart';
import 'package:mondom/storage/database.dart';
import 'package:mondom/storage/lists_repository.dart';
import 'package:mondom/voices/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_seed.dart';
import 'speaker_test.dart' show FakeEngine, FakePlayer, FakeSoundPlayer;

const rate = 44100;

/// [seconds] of a 200 Hz tone at [amp], preceded/followed by [pad] seconds of
/// silence.
Float32List tone(double amp, double seconds, {double pad = 0}) {
  final n = (seconds * rate).round();
  final p = (pad * rate).round();
  return Float32List.fromList([
    for (var i = 0; i < p; i++) 0.0,
    for (var i = 0; i < n; i++) amp * math.sin(2 * math.pi * 200 * i / rate),
    for (var i = 0; i < p; i++) 0.0,
  ]);
}

double peak(Float32List s) => s.fold(0.0, (m, x) => math.max(m, x.abs()));

double rmsDb(Float32List s) {
  final r = math.sqrt(s.fold(0.0, (a, x) => a + x * x) / s.length);
  return 20 * math.log(r) / math.ln10;
}

void main() {
  group('prepareRecording', () {
    test('drops 100 ms at both ends and trims silence, keeping padding', () {
      // 1 s of silence, 1 s of tone, 1 s of silence.
      final out = prepareRecording(PcmWav(tone(0.3, 1.0, pad: 1.0), rate, 1));
      final seconds = out.samples.length / rate;
      // 1 s of tone + ~100 ms padding each side (+ up to a frame of slack).
      expect(seconds, inInclusiveRange(1.15, 1.30));
      expect(out.channels, 1);
    });

    test('a quiet recording is brought up to the target level', () {
      final out = prepareRecording(PcmWav(tone(0.05, 1.0, pad: 0.3), rate, 1));
      // Sine RMS = amp/sqrt2; the 75th-percentile frame is the tone itself.
      expect(rmsDb(out.samples), closeTo(recordingTargetRmsDb, 3));
    });

    test('gain is capped at +15 dB', () {
      final input = tone(0.003, 1.0, pad: 0.3); // far below target
      final out = prepareRecording(PcmWav(input, rate, 1));
      final gained = peak(out.samples) / 0.003;
      // High-pass leaves a 200 Hz tone alone (within ~0.2 dB).
      expect(20 * math.log(gained) / math.ln10, lessThan(15.5));
      expect(20 * math.log(gained) / math.ln10, greaterThan(14));
    });

    test('a loud recording is attenuated and never exceeds the ceiling', () {
      final out = prepareRecording(PcmWav(tone(1.0, 1.0, pad: 0.3), rate, 1));
      expect(
        peak(out.samples),
        lessThanOrEqualTo(math.pow(10, speechCeilingDb / 20)),
      );
      expect(rmsDb(out.samples), lessThan(-10));
    });

    test('silence stays silence', () {
      final out = prepareRecording(PcmWav(Float32List(rate * 2), rate, 1));
      expect(out.samples.every((x) => x == 0), isTrue);
    });

    test('the input is not modified', () {
      final input = tone(0.2, 1.0, pad: 0.3);
      final copy = Float32List.fromList(input);
      prepareRecording(PcmWav(input, rate, 1));
      expect(input, copy);
    });

    test('bytes round-trip; non-WAV bytes give null', () {
      final wav = writePcm16Wav(PcmWav(tone(0.2, 1.0, pad: 0.3), rate, 1));
      expect(prepareRecordingBytes(wav), isNotNull);
      expect(prepareRecordingBytes(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('RecordingStore', () {
    late Directory root;
    late RecordingStore store;
    setUp(() {
      root = Directory.systemTemp.createTempSync('rec_store');
      store = RecordingStore(
        directory: () async => Directory('${root.path}/recordings'),
      );
    });
    tearDown(() => root.deleteSync(recursive: true));

    File temp(String name, [String content = 'x']) =>
        File('${root.path}/$name')..writeAsStringSync(content);

    test('adopt copies under a unique name and deletes the temp', () async {
      final a = temp('a.wav', 'AAA');
      final b = temp('b.wav', 'BBB');
      final nameA = await store.adopt(a.path);
      final nameB = await store.adopt(b.path);
      expect(nameA, isNot(nameB));
      expect(nameA, isNot(contains('/')));
      expect(a.existsSync(), isFalse);
      expect(File((await store.resolve(nameA))!).readAsStringSync(), 'AAA');
    });

    test('resolve: missing file and path tricks give null', () async {
      expect(await store.resolve('nope.wav'), isNull);
      expect(await store.resolve('../x.wav'), isNull);
      expect(await store.resolve(''), isNull);
    });

    Future<String> adoptOld(String content, Duration age) async {
      final name = await store.adopt(temp('t.wav', content).path);
      final path = (await store.resolve(name))!;
      File(path).setLastModifiedSync(DateTime.now().subtract(age));
      return name;
    }

    test('sweep keeps referenced and young files, deletes the rest', () async {
      final kept = await adoptOld('1', const Duration(days: 3));
      final unreferencedOld = await adoptOld('2', const Duration(days: 3));
      final unreferencedYoung = await adoptOld('3', const Duration(hours: 1));
      final deleted = await store.sweep({kept});
      expect(deleted, 1);
      expect(await store.resolve(kept), isNotNull);
      expect(await store.resolve(unreferencedOld), isNull);
      expect(await store.resolve(unreferencedYoung), isNotNull);
    });

    test('sweep does nothing when no row references a recording', () async {
      final a = await adoptOld('1', const Duration(days: 3));
      expect(await store.sweep({}), 0);
      expect(await store.resolve(a), isNotNull);
    });
  });

  group('playback', () {
    late Directory dir;
    late Directory recDir;
    late RecordingStore store;
    late FakeEngine engine;
    late FakePlayer player;
    late FakeSoundPlayer sounds;
    late FakeSoundPlayer alarms;
    late Speaker speaker;
    late String recName;
    late String recPath;
    late Uint8List recBytes;

    Speaker make({bool loadVoice = true}) {
      final s = Speaker(
        engineFactory: (_) async => engine,
        player: player,
        soundPlayer: sounds,
        alarmPlayer: alarms,
        recordings: store,
        tempDir: dir,
      );
      return s;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('rec_play');
      recDir = Directory('${dir.path}/store');
      store = RecordingStore(directory: () async => recDir);
      engine = FakeEngine(dir);
      player = FakePlayer();
      sounds = FakeSoundPlayer();
      alarms = FakeSoundPlayer();
      recBytes = writePcm16Wav(PcmWav(tone(0.1, 1.0, pad: 0.3), rate, 1));
      final src = File('${dir.path}/take.wav')..writeAsBytesSync(recBytes);
      recName = await store.adopt(src.path);
      recPath = (await store.resolve(recName))!;
      speaker = make();
      await speaker.setVoice(Voice.system('hu'));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    SentenceRowData row({
      String? rec,
      String? sound,
      bool alarm = false,
      String text = 'Szia!',
    }) => SentenceRowData(
      text: text,
      recordingPath: rec ?? recName,
      soundKey: sound,
      alarm: alarm,
    );

    test('recording beats sound and TTS; the original is untouched', () async {
      await speaker.play(row(sound: 'bell'));
      expect(player.played, hasLength(1));
      expect(player.played.single, isNot(recPath));
      expect(engine.calls, 0);
      expect(sounds.played, isEmpty);
      expect(File(recPath).readAsBytesSync(), recBytes);
      // The played file is the prepared temp, a valid WAV.
      expect(
        readPcm16Wav(File(player.played.single).readAsBytesSync()),
        isNotNull,
      );
    });

    test('second tap replays the prepared file without reprocessing', () async {
      await speaker.play(row());
      final first = player.played.single;
      final stamp = File(first).lastModifiedSync();
      await speaker.play(row());
      expect(player.played, [first, first]);
      expect(File(first).lastModifiedSync(), stamp);
      expect(speaker.lastReplayed, isTrue);
    });

    test('another utterance deletes only the temp file', () async {
      await speaker.play(row());
      final temp = player.played.single;
      await speaker.speak('Más.');
      expect(File(temp).existsSync(), isFalse);
      expect(File(recPath).existsSync(), isTrue);
      await speaker.play(row());
      await speaker.setVoice(Voice.system('en')); // _forgetLast
      expect(File(recPath).existsSync(), isTrue);
    });

    test('missing file falls through to TTS, silently', () async {
      await speaker.play(row(rec: 'gone.wav'));
      expect(engine.calls, 1);
      expect(player.played, hasLength(1));
      expect(speaker.error, isNull);
    });

    test('unreadable (non-WAV) file falls through to the sound', () async {
      final bad = File('${dir.path}/bad.wav')..writeAsStringSync('not a wav');
      final name = await store.adopt(bad.path);
      await speaker.play(row(rec: name, sound: 'bell'));
      expect(sounds.played, ['sounds/bell.wav']);
      expect(speaker.error, isNull);
    });

    test('plays with no voice loaded', () async {
      final idle = make();
      expect(idle.ready, isFalse);
      expect(idle.canPlay(row()), isTrue);
      expect(idle.canPlay(const SentenceRowData(text: 'x')), isFalse);
      await idle.play(row());
      expect(player.played, hasLength(1));
      idle.dispose();
    });

    test('alarm + recording uses the alarm player', () async {
      await speaker.play(row(alarm: true));
      expect(alarms.played, hasLength(1));
      expect(player.played, isEmpty);
      expect(speaker.alarmPlaying, isTrue);
      await speaker.stop();
    });

    test('a speaker without a store ignores the recording', () async {
      final bare = Speaker(
        engineFactory: (_) async => engine,
        player: player,
        soundPlayer: sounds,
        alarmPlayer: alarms,
      );
      await bare.setVoice(Voice.system('hu'));
      await bare.play(row());
      expect(engine.calls, 1);
      bare.dispose();
    });
  });

  group('repository', () {
    late AppDatabase db;
    late ListsRepository repo;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory(), loadSeed: fixtureSeed);
      repo = ListsRepository(db);
      await repo.addSeedLists('hu');
    });
    tearDown(() => db.close());

    Future<Sentence> historyRow(String text) async {
      final history = (await repo.watchLists().first).firstWhere(
        (l) => l.kind == ListKind.history,
      );
      return (await repo.watchSentences(history.id).first).firstWhere(
        (s) => s.body == text,
      );
    }

    test('setSentenceRecording sets, clears and feeds the sweep', () async {
      final list = (await repo.watchLists().first).first;
      final id = (await repo.addSentences(list.id, ['Szia!'])).single;
      expect(await repo.referencedRecordings(), isEmpty);
      await repo.setSentenceRecording(id, 'a.wav');
      expect(await repo.referencedRecordings(), {'a.wav'});
      await repo.setSentenceRecording(id, null);
      expect(await repo.referencedRecordings(), isEmpty);
    });

    test('history carries the recording; null does not overwrite', () async {
      await repo.addToHistory('Szia!', recordingPath: 'a.wav');
      expect((await historyRow('Szia!')).recordingPath, 'a.wav');
      await repo.addToHistory('Szia!'); // typed again, no recording
      expect((await historyRow('Szia!')).recordingPath, 'a.wav');
      await repo.addToHistory('Szia!', recordingPath: 'b.wav');
      expect((await historyRow('Szia!')).recordingPath, 'b.wav');
      // History rows don't keep a file alive for the sweep.
      expect(await repo.referencedRecordings(), isEmpty);
    });
  });
}
