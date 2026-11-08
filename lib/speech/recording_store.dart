import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';

/// Files younger than this are never swept (a save may be in progress).
const recordingSweepMinAge = Duration(hours: 24);

/// Message-banking files under `<appSupport>/recordings/`. The DB stores the
/// **file name only**; this class maps it to a path. A recording is
/// irreplaceable, so nothing here deletes anything except [sweep].
class RecordingStore {
  /// [directory] is for tests; the app uses `<appSupport>/recordings/`.
  RecordingStore({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;
  static final _random = math.Random();

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/recordings');
  }

  Future<Directory> _dir() async {
    final d = await _directory();
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Moves the finished take at [tempWavPath] into the store under a new
  /// unique name (copy, then delete the temp). Returns the file name to store.
  Future<String> adopt(String tempWavPath) async {
    final dir = await _dir();
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_'
        '${_random.nextInt(1 << 32).toRadixString(36)}.wav';
    final source = File(tempWavPath);
    final target = await source.copy('${dir.path}/$name');
    // The sweep's age guard must see "now", whatever the copy preserved.
    await target.setLastModified(DateTime.now());
    await source.delete();
    return name;
  }

  /// Absolute path of [fileName], or null if the file is missing (or the name
  /// is not a plain file name).
  Future<String?> resolve(String fileName) async {
    if (!_isPlainName(fileName)) return null;
    final file = File('${(await _dir()).path}/$fileName');
    return await file.exists() ? file.path : null;
  }

  /// Deletes every file that is not in [referenced]. Guards: does nothing when
  /// [referenced] is empty (a lost or reset DB must not wipe the recordings),
  /// and skips files modified less than [recordingSweepMinAge] ago. Returns
  /// how many files were deleted. [now] is for tests.
  Future<int> sweep(Set<String> referenced, {DateTime? now}) async {
    if (referenced.isEmpty) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(recordingSweepMinAge);
    var deleted = 0;
    try {
      await for (final entity in (await _dir()).list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (referenced.contains(name)) continue;
        try {
          if ((await entity.lastModified()).isAfter(cutoff)) continue;
          await entity.delete();
          deleted++;
        } catch (_) {}
      }
    } catch (_) {}
    return deleted;
  }

  bool _isPlainName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains('/') &&
      !name.contains(r'\');
}
