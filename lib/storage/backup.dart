import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../speech/recording_store.dart';
import 'lists_repository.dart';

/// `version` written to, and required in, `backup.json`.
const backupVersion = 1;

const _jsonName = 'backup.json';
const _recordingsPrefix = 'recordings/';

/// Why a backup could not be read. [code]: `version` (made by a newer app),
/// `format` (not a Mondom backup, or damaged), `path` (an entry outside
/// `recordings/`).
class BackupException implements Exception {
  const BackupException(this.code);
  final String code;

  @override
  String toString() => 'BackupException($code)';
}

class BackupImportResult {
  const BackupImportResult({
    required this.listsAdded,
    required this.listsSkipped,
    required this.recordingsCopied,
  });
  final int listsAdded;
  final int listsSkipped;
  final int recordingsCopied;
}

/// Android's file picker, for the backup zip (tests fake it).
abstract class BackupFilePicker {
  /// Lets the user choose where to save; copies [sourcePath] there. False =
  /// cancelled.
  Future<bool> save(String sourcePath, String suggestedName);

  /// Lets the user choose a file; copies it to [destPath]. False = cancelled.
  Future<bool> pick(String destPath);
}

class MethodBackupFilePicker implements BackupFilePicker {
  static const _channel = MethodChannel('mondom/backup');

  @override
  Future<bool> save(String sourcePath, String suggestedName) async =>
      await _channel.invokeMethod<bool>('save', {
        'source': sourcePath,
        'name': suggestedName,
      }) ??
      false;

  @override
  Future<bool> pick(String destPath) async =>
      await _channel.invokeMethod<bool>('pick', {'dest': destPath}) ?? false;
}

/// Backup to, and restore from, a zip file the user places anywhere through
/// Android's file picker: `backup.json` (lists and sentences) plus
/// `recordings/*.wav`. Restoring only adds; nothing is overwritten.
class BackupService {
  BackupService({
    required this.repo,
    required this.recordings,
    BackupFilePicker? picker,
    Future<Directory> Function()? tempDirectory,
  }) : _picker = picker ?? MethodBackupFilePicker(),
       _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final ListsRepository repo;
  final RecordingStore recordings;
  final BackupFilePicker _picker;
  final Future<Directory> Function() _tempDirectory;

  /// Writes the backup through the picker. Returns the number of recordings
  /// saved, or null if the user cancelled.
  Future<int?> export({DateTime? now}) async {
    final dir = await _scratch();
    try {
      final zip = '${dir.path}/backup.zip';
      final count = await writeZip(zip);
      final d = now ?? DateTime.now();
      final name =
          'mondom-mentes-${d.year}-${_two(d.month)}-${_two(d.day)}.zip';
      return await _picker.save(zip, name) ? count : null;
    } finally {
      await _delete(dir);
    }
  }

  /// Reads a backup chosen through the picker. Null = the user cancelled.
  /// Throws [BackupException] without having changed anything.
  Future<BackupImportResult?> restore() async {
    final dir = await _scratch();
    try {
      final zip = '${dir.path}/backup.zip';
      if (!await _picker.pick(zip)) return null;
      return await importZip(zip);
    } finally {
      await _delete(dir);
    }
  }

  /// Builds the zip at [zipPath] (compressing in a background isolate).
  /// Returns how many recordings it holds.
  Future<int> writeZip(String zipPath) async {
    final json = jsonEncode({
      'version': backupVersion,
      ...await repo.exportBackupData(),
    });
    final recDir = (await recordings.directory()).path;
    final files = <String>[
      for (final name in await repo.referencedRecordings())
        if (RecordingStore.isPlainName(name) &&
            await File('$recDir/$name').exists())
          name,
    ];
    await Isolate.run(() => _zip(zipPath, json, recDir, files));
    return files.length;
  }

  /// Adds what [zipPath] holds. Throws [BackupException] before any change
  /// if the file is not acceptable.
  Future<BackupImportResult> importZip(String zipPath) async {
    final staging = await _scratch();
    try {
      final stagingPath = staging.path;
      final json = await Isolate.run(() => _extract(zipPath, stagingPath));
      final Map<String, Object?> data;
      try {
        data = (jsonDecode(json) as Map).cast<String, Object?>();
      } catch (_) {
        throw const BackupException('format');
      }
      final version = data['version'];
      if (version is! int) throw const BackupException('format');
      if (version != backupVersion) throw const BackupException('version');
      final (added, skipped) = await _importData(data);
      final copied = await _copyRecordings(staging);
      return BackupImportResult(
        listsAdded: added,
        listsSkipped: skipped,
        recordingsCopied: copied,
      );
    } finally {
      await _delete(staging);
    }
  }

  Future<(int, int)> _importData(Map<String, Object?> data) async {
    try {
      return await repo.importBackupData(data);
    } on FormatException {
      throw const BackupException('format');
    } on TypeError {
      throw const BackupException('format');
    } on ArgumentError {
      // Unknown list kind.
      throw const BackupException('format');
    }
  }

  /// Moves extracted recordings into the store; existing files stay.
  Future<int> _copyRecordings(Directory staging) async {
    final target = (await recordings.directory()).path;
    var copied = 0;
    await for (final e in staging.list(followLinks: false)) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (!RecordingStore.isPlainName(name)) continue;
      final dest = File('$target/$name');
      if (await dest.exists()) continue;
      await e.copy(dest.path);
      // The sweep's age guard must see "now".
      await dest.setLastModified(DateTime.now());
      copied++;
    }
    return copied;
  }

  Future<Directory> _scratch() async =>
      (await _tempDirectory()).createTemp('mondom-backup-');

  Future<void> _delete(Directory d) async {
    try {
      await d.delete(recursive: true);
    } catch (_) {}
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

// ---- Isolate work (top level: only plain data crosses the boundary) ----

Future<void> _zip(
  String zipPath,
  String json,
  String recDir,
  List<String> files,
) async {
  final encoder = ZipFileEncoder()..create(zipPath);
  encoder.addArchiveFile(ArchiveFile.string(_jsonName, json));
  for (final name in files) {
    await encoder.addFile(File('$recDir/$name'), '$_recordingsPrefix$name');
  }
  await encoder.close();
}

/// Checks every entry first (so a bad one extracts nothing), then writes
/// the recordings flat into [stagingPath] and returns `backup.json`.
/// Staging holds only the recordings: `backup.json` stays in memory.
Future<String> _extract(String zipPath, String stagingPath) async {
  final input = InputFileStream(zipPath);
  try {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } catch (_) {
      throw const BackupException('format');
    }
    ArchiveFile? jsonEntry;
    final wavs = <String, ArchiveFile>{};
    for (final f in archive) {
      final name = f.name;
      if (!f.isFile) {
        if (name == _recordingsPrefix) continue;
        throw const BackupException('path');
      }
      if (name == _jsonName) {
        jsonEntry = f;
      } else if (name.startsWith(_recordingsPrefix) &&
          RecordingStore.isPlainName(
            name.substring(_recordingsPrefix.length),
          )) {
        wavs[name.substring(_recordingsPrefix.length)] = f;
      } else {
        throw const BackupException('path');
      }
    }
    if (jsonEntry == null) throw const BackupException('format');
    final String json;
    try {
      json = utf8.decode(jsonEntry.readBytes() ?? const []);
    } catch (_) {
      throw const BackupException('format');
    }
    for (final entry in wavs.entries) {
      final out = OutputFileStream('$stagingPath/${entry.key}');
      try {
        entry.value.writeContent(out);
      } finally {
        await out.close();
      }
    }
    return json;
  } finally {
    await input.close();
  }
}
