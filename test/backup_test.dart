import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mondom/speech/recording_store.dart';
import 'package:mondom/storage/backup.dart';
import 'package:mondom/storage/database.dart';
import 'package:mondom/storage/lists_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_seed.dart';

class _FakePicker implements BackupFilePicker {
  String? saved;
  String? savedName;
  String? toPick;

  @override
  Future<bool> save(String sourcePath, String suggestedName) async {
    saved = '${File(sourcePath).parent.path}/../kept.zip';
    await File(sourcePath).copy(saved!);
    savedName = suggestedName;
    return true;
  }

  @override
  Future<bool> pick(String destPath) async {
    if (toPick == null) return false;
    await File(toPick!).copy(destPath);
    return true;
  }
}

/// A whole app: DB + recordings directory + service.
class _App {
  _App(Directory root, {_FakePicker? picker})
    : db = AppDatabase(NativeDatabase.memory(), loadSeed: fixtureSeed),
      recDir = Directory('${root.path}/rec')..createSync(recursive: true) {
    repo = ListsRepository(db);
    store = RecordingStore(directory: () async => recDir);
    service = BackupService(
      repo: repo,
      recordings: store,
      picker: picker ?? _FakePicker(),
      tempDirectory: () async => root,
    );
  }

  final AppDatabase db;
  final Directory recDir;
  late final ListsRepository repo;
  late final RecordingStore store;
  late final BackupService service;

  File recording(String name, List<int> bytes) =>
      File('${recDir.path}/$name')..writeAsBytesSync(bytes);

  Future<List<SentenceList>> lists() async => [
    for (final l in await repo.watchLists().first)
      if (l.kind != ListKind.history) l,
  ];
}

void main() {
  late Directory tmp;
  late _FakePicker picker;
  late _App a;
  late _App b;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('mondom-backup-test-');
    picker = _FakePicker();
    a = _App(Directory('${tmp.path}/a')..createSync(), picker: picker);
    b = _App(Directory('${tmp.path}/b')..createSync());
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
    await tmp.delete(recursive: true);
  });

  /// Lists in [a]: "Orvos" with a recording, a sound row and an alarm row.
  Future<void> fill() async {
    final id = await a.repo.createList(
      'Orvos',
      kind: ListKind.conversation,
      pinned: true,
      color: 'orange',
    );
    final ids = await a.repo.addSentences(id, ['Szia!', 'Segítség!', 'Hé!']);
    a.recording('one.wav', [1, 2, 3, 4]);
    a.recording('unused.wav', [9]);
    await a.repo.setSentenceRecording(ids[0], 'one.wav');
    await a.repo.setSentenceAlarm(ids[1], true);
    await a.repo.addToHistory('history only', recordingPath: 'unused.wav');
  }

  test('round trip into an empty DB', () async {
    await fill();
    final zip = '${tmp.path}/x.zip';
    expect(await a.service.writeZip(zip), 1);

    final result = await b.service.importZip(zip);
    expect(result.listsAdded, 1);
    expect(result.listsSkipped, 0);
    expect(result.recordingsCopied, 1);

    final lists = await b.lists();
    expect(lists.single.title, 'Orvos');
    expect(lists.single.kind, ListKind.conversation);
    expect(lists.single.pinned, isTrue);
    expect(lists.single.color, 'orange');
    final rows = await b.repo.watchSentences(lists.single.id).first;
    expect([for (final r in rows) r.body], ['Szia!', 'Segítség!', 'Hé!']);
    expect(rows[0].recordingPath, 'one.wav');
    expect(rows[1].alarm, isTrue);
    expect(rows[2].alarm, isFalse);
    expect(File('${b.recDir.path}/one.wav').readAsBytesSync(), [1, 2, 3, 4]);
    // History recordings are not part of a backup.
    expect(File('${b.recDir.path}/unused.wav').existsSync(), isFalse);
    // The history list stays out of the backup but is untouched in [b].
    expect((await b.repo.watchLists().first).length, 2);
  });

  test('importing twice adds nothing', () async {
    await fill();
    final zip = '${tmp.path}/x.zip';
    await a.service.writeZip(zip);
    await b.service.importZip(zip);
    final again = await b.service.importZip(zip);
    expect(again.listsAdded, 0);
    expect(again.listsSkipped, 1);
    expect(again.recordingsCopied, 0);
    expect(await b.lists(), hasLength(1));
  });

  test('an existing recording file is never overwritten', () async {
    await fill();
    final zip = '${tmp.path}/x.zip';
    await a.service.writeZip(zip);
    b.recording('one.wav', [7, 7]);
    final result = await b.service.importZip(zip);
    expect(result.recordingsCopied, 0);
    expect(File('${b.recDir.path}/one.wav').readAsBytesSync(), [7, 7]);
  });

  test('a list with the same title but other sentences is added', () async {
    await fill();
    final zip = '${tmp.path}/x.zip';
    await a.service.writeZip(zip);
    final id = await b.repo.createList('Orvos');
    await b.repo.addSentences(id, ['Másik']);
    final result = await b.service.importZip(zip);
    expect(result.listsAdded, 1);
    expect(await b.lists(), hasLength(2));
  });

  test('export and restore go through the picker', () async {
    await fill();
    expect(
      await a.service.export(now: DateTime(2026, 11, 9)),
      1,
    );
    expect(picker.savedName, 'mondom-mentes-2026-11-09.zip');

    picker.toPick = picker.saved;
    final result = await a.service.restore();
    expect(result!.listsSkipped, 1);

    picker.toPick = null;
    expect(await a.service.restore(), isNull);
  });

  Future<String> makeZip(Map<String, String> entries) async {
    final archive = Archive();
    for (final e in entries.entries) {
      archive.add(ArchiveFile.string(e.key, e.value));
    }
    final path = '${tmp.path}/made.zip';
    File(path).writeAsBytesSync(ZipEncoder().encode(archive));
    return path;
  }

  String json(Object? version) => jsonEncode({
    'version': version,
    'lists': [
      {
        'title': 'X',
        'kind': 'everyday',
        'sentences': [
          {'text': 'a'},
        ],
      },
    ],
  });

  test('an unknown version changes nothing', () async {
    final zip = await makeZip({'backup.json': json(2)});
    await expectLater(
      b.service.importZip(zip),
      throwsA(isA<BackupException>().having((e) => e.code, 'code', 'version')),
    );
    expect(await b.lists(), isEmpty);
  });

  test('a file that is not a backup is a format error', () async {
    File('${tmp.path}/junk.zip').writeAsStringSync('not a zip');
    await expectLater(
      b.service.importZip('${tmp.path}/junk.zip'),
      throwsA(isA<BackupException>().having((e) => e.code, 'code', 'format')),
    );
    final noJson = await makeZip({'recordings/a.wav': 'x'});
    await expectLater(
      b.service.importZip(noJson),
      throwsA(isA<BackupException>().having((e) => e.code, 'code', 'format')),
    );
    final badJson = await makeZip({
      'backup.json': jsonEncode({
        'version': 1,
        'lists': [
          {'title': 'X', 'kind': 'nonsense', 'sentences': []},
        ],
      }),
    });
    await expectLater(
      b.service.importZip(badJson),
      throwsA(isA<BackupException>().having((e) => e.code, 'code', 'format')),
    );
    expect(await b.lists(), isEmpty);
  });

  test('entries outside recordings/ are rejected, nothing is written', () async {
    for (final name in [
      'recordings/../evil.wav',
      '../evil.wav',
      'recordings/sub/evil.wav',
      '/etc/evil.wav',
      'other.txt',
    ]) {
      final zip = await makeZip({
        'backup.json': json(1),
        'recordings/good.wav': 'ok',
        name: 'bad',
      });
      await expectLater(
        b.service.importZip(zip),
        throwsA(isA<BackupException>().having((e) => e.code, 'code', 'path')),
        reason: name,
      );
    }
    expect(await b.lists(), isEmpty);
    expect(b.recDir.listSync(), isEmpty);
    expect(File('${tmp.path}/evil.wav').existsSync(), isFalse);
    expect(File('${tmp.path}/b/evil.wav').existsSync(), isFalse);
  });
}
