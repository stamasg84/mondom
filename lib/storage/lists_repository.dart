import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../speech/speaker.dart' show normalizeText;
import 'database.dart';
import 'seed.dart';

export 'database.dart'
    show ListKind, Sentence, SentenceList, listColorKeys, nextListColor;

/// Maximum number of rows in the history list.
const historyCap = 30;

const _lastListKey = 'lastListId';
const _declinedSeedKey = 'declinedSeedLanguages';
const _autoColor = Object();

/// The only storage API the UI uses.
class ListsRepository {
  ListsRepository(this._db);
  final AppDatabase _db;

  $SentenceListsTable get _lists => _db.sentenceLists;
  $SentencesTable get _sentences => _db.sentences;

  // ---- Lists ----

  Stream<List<SentenceList>> watchLists() => (_db.select(
    _lists,
  )..orderBy([(t) => OrderingTerm.asc(t.position)])).watch();

  /// Number of sentences per list id (lists without sentences are absent).
  Stream<Map<int, int>> watchSentenceCounts() => _db
      .select(_sentences)
      .watch()
      .map(
        (rows) => {
          for (final id in rows.map((s) => s.listId).toSet())
            id: rows.where((s) => s.listId == id).length,
        },
      );

  /// Whether some seed list of [language] is missing; re-evaluated whenever
  /// the lists change.
  Stream<bool> watchHasMissingDefaultLists(String language) =>
      watchLists().asyncMap((_) => hasMissingDefaultLists(language));

  Future<bool> hasMissingDefaultLists(String language) async {
    final (used, seed) = await _db.resolveSeed(language);
    final existing = {
      for (final l in await _db.select(_lists).get())
        if (l.seedLanguage == used && l.seedKey != null) l.seedKey,
    };
    return seed.lists.any((l) => !existing.contains(l.seedKey));
  }

  /// [color]: omitted = the next unused palette color; null = neutral.
  Future<int> createList(
    String title, {
    ListKind kind = ListKind.everyday,
    bool pinned = false,
    Object? color = _autoColor,
  }) async {
    final last = await _lastListPosition();
    final String? chosen = identical(color, _autoColor)
        ? await nextColorForNewList()
        : color as String?;
    return _db
        .into(_lists)
        .insert(
          SentenceListsCompanion.insert(
            title: title.trim(),
            kind: kind,
            pinned: Value(pinned),
            position: last + 1,
            color: Value(chosen),
          ),
        );
  }

  /// The color [createList] picks when none is given.
  Future<String> nextColorForNewList() async =>
      nextListColor([for (final l in await _db.select(_lists).get()) l.color]);

  /// Sets the palette key ([listColorKeys]); null = neutral. Not for history.
  Future<void> setColor(int id, String? key) async {
    await _requireNotHistory(id, 'colored');
    await (_db.update(_lists)..where((l) => l.id.equals(id))).write(
      SentenceListsCompanion(color: Value(key)),
    );
  }

  Future<void> renameList(int id, String title) async {
    await _requireNotHistory(id, 'renamed');
    final t = title.trim();
    if (t.isEmpty) return;
    await (_db.update(_lists)..where((l) => l.id.equals(id))).write(
      SentenceListsCompanion(title: Value(t)),
    );
  }

  /// Deletes the list and (cascade) its sentences. Not allowed for history.
  Future<void> deleteList(int id) async {
    await _requireNotHistory(id, 'deleted');
    await (_db.delete(_lists)..where((l) => l.id.equals(id))).go();
  }

  Future<void> setPinned(int id, bool pinned) =>
      (_db.update(_lists)..where((l) => l.id.equals(id))).write(
        SentenceListsCompanion(pinned: Value(pinned)),
      );

  /// Lists named in [ids] get that order; any others follow in their old order.
  Future<void> reorderLists(List<int> ids) => _db.transaction(() async {
    final all = await (_db.select(
      _lists,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    final order = _merge(ids, [for (final l in all) l.id]);
    for (final (i, id) in order.indexed) {
      await (_db.update(_lists)..where((l) => l.id.equals(id))).write(
        SentenceListsCompanion(position: Value(i)),
      );
    }
  });

  // ---- Sentences ----

  /// Ordered by position (history: newest first).
  Stream<List<Sentence>> watchSentences(int listId) =>
      (_db.select(_sentences)
            ..where((s) => s.listId.equals(listId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();

  /// Inserts [texts] (trimmed, empty ones skipped) at index [at] (default:
  /// end). Returns the new ids.
  Future<List<int>> addSentences(int listId, List<String> texts, {int? at}) =>
      _db.transaction(() async {
        final old = await _sentenceIds(listId);
        final ids = <int>[];
        for (final t in texts) {
          if (t.trim().isEmpty) continue;
          ids.add(await _insertSentence(listId, t.trim()));
        }
        if (at != null && ids.isNotEmpty) {
          final i = at.clamp(0, old.length);
          await _writeOrder(listId, [...old.take(i), ...ids, ...old.skip(i)]);
        }
        return ids;
      });

  Future<void> updateSentenceText(int id, String text) {
    final t = text.trim();
    if (t.isEmpty) return Future.value();
    return (_db.update(
      _sentences,
    )..where((s) => s.id.equals(id))).write(SentencesCompanion(body: Value(t)));
  }

  /// Attaches (or, with null, detaches) a message-banking recording, by file
  /// name. The file itself is never deleted here; the app-start sweep removes
  /// files nothing references.
  Future<void> setSentenceRecording(int id, String? fileName) =>
      (_db.update(_sentences)..where((s) => s.id.equals(id))).write(
        SentencesCompanion(recordingPath: Value(fileName)),
      );

  /// File names of recordings referenced by rows of permanent lists, for the
  /// sweep. History rows don't count: deleting a row must free its recording
  /// without waiting for history to drop it (a history row then just falls
  /// back to TTS).
  Future<Set<String>> referencedRecordings() async {
    final history = await _historyList();
    return {
      for (final s in await _db.select(_sentences).get())
        if (s.recordingPath != null && s.listId != history.id) s.recordingPath!,
    };
  }

  Future<void> setSentenceAlarm(int id, bool alarm) =>
      (_db.update(_sentences)..where((s) => s.id.equals(id))).write(
        SentencesCompanion(alarm: Value(alarm)),
      );

  Future<void> deleteSentence(int id) => _db.transaction(() async {
    final s = await _sentenceById(id);
    if (s == null) return;
    await (_db.delete(_sentences)..where((x) => x.id.equals(id))).go();
    await _writeOrder(s.listId, await _sentenceIds(s.listId));
  });

  /// Undo of [deleteSentence]: re-inserts [s] (same id, recording, seed
  /// identity, `said`) at index [at] of its list.
  Future<void> restoreSentence(Sentence s, int at) => _db.transaction(() async {
    final ids = await _sentenceIds(s.listId);
    await _db.into(_sentences).insert(s, mode: InsertMode.insertOrReplace);
    ids.remove(s.id);
    ids.insert(at.clamp(0, ids.length), s.id);
    await _writeOrder(s.listId, ids);
  });

  /// Moves to the end of [toListId]. The seed identity is dropped.
  Future<void> moveSentence(int id, int toListId) => _db.transaction(() async {
    final s = await _sentenceById(id);
    if (s == null || s.listId == toListId) return;
    final end = await _lastSentencePosition(toListId);
    await (_db.update(_sentences)..where((x) => x.id.equals(id))).write(
      SentencesCompanion(
        listId: Value(toListId),
        position: Value(end + 1),
        seedKey: const Value(null),
        spokenAt: const Value(null),
      ),
    );
    await _writeOrder(s.listId, await _sentenceIds(s.listId));
  });

  /// Copies to the end of [toListId] (keeps recording, sound and alarm flag,
  /// resets `said`).
  Future<int?> copySentence(int id, int toListId) async {
    final s = await _sentenceById(id);
    if (s == null) return null;
    return _insertSentence(
      toListId,
      s.body,
      recordingPath: s.recordingPath,
      soundKey: s.soundKey,
      alarm: s.alarm,
    );
  }

  /// [ids] get that order; any others in the list follow in their old order.
  Future<void> reorderSentences(int listId, List<int> ids) => _db.transaction(
    () async => _writeOrder(listId, _merge(ids, await _sentenceIds(listId))),
  );

  Future<void> setSaid(int id, bool said) =>
      (_db.update(_sentences)..where((s) => s.id.equals(id))).write(
        SentencesCompanion(said: Value(said)),
      );

  Future<void> resetSaid(int listId) =>
      (_db.update(_sentences)..where((s) => s.listId.equals(listId))).write(
        const SentencesCompanion(said: Value(false)),
      );

  // ---- History ----

  /// Records a spoken text at the top of history; the same normalized text is
  /// moved instead of duplicated. Oldest rows beyond [historyCap] are dropped.
  /// Newest-first order is kept by giving the new row the lowest position.
  ///
  /// [recordingPath] (a recording's file name) is stored on a new row and
  /// overwrites an existing row's only when non-null, so re-tapping from
  /// history plays the same voice.
  Future<void> addToHistory(String text, {String? recordingPath}) =>
      _db.transaction(() async {
        final normalized = normalizeText(text);
        if (normalized.isEmpty) return;
        final history = await _historyList();
        final rows =
            await (_db.select(_sentences)
                  ..where((s) => s.listId.equals(history.id))
                  ..orderBy([(t) => OrderingTerm.asc(t.position)]))
                .get();
        final now = DateTime.now();
        final top = rows.isEmpty ? 0 : rows.first.position - 1;
        final same = rows
            .where((r) => normalizeText(r.body) == normalized)
            .toList();
        if (same.isNotEmpty) {
          await (_db.update(
            _sentences,
          )..where((s) => s.id.equals(same.first.id))).write(
            SentencesCompanion(
              position: Value(top),
              spokenAt: Value(now),
              recordingPath: recordingPath == null
                  ? const Value.absent()
                  : Value(recordingPath),
            ),
          );
        } else {
          await _db
              .into(_sentences)
              .insert(
                SentencesCompanion.insert(
                  listId: history.id,
                  body: normalized,
                  position: top,
                  spokenAt: Value(now),
                  recordingPath: Value(recordingPath),
                ),
              );
        }
        final ids = await _sentenceIds(history.id);
        for (final id in ids.skip(historyCap)) {
          await (_db.delete(_sentences)..where((s) => s.id.equals(id))).go();
        }
      });

  // ---- Defaults ----

  /// Whether some seed sentences of the list are missing from it.
  Future<bool> hasMissingDefaults(int listId) async =>
      (await _missingSeedSentences(listId)).isNotEmpty;

  /// Re-adds missing seed sentences at their seed position, from the list's
  /// own seed language. Never deletes or changes anything. Returns how many
  /// were added.
  Future<int> restoreDefaultSentences(int listId) => _db.transaction(() async {
    final missing = await _missingSeedSentences(listId);
    for (final (index, s) in missing) {
      final ids = await _sentenceIds(listId);
      final newId = await _insertSentence(
        listId,
        s.text,
        soundKey: s.sound,
        alarm: s.alarm,
        seedKey: s.seedKey,
      );
      ids.insert(index.clamp(0, ids.length), newId);
      await _writeOrder(listId, ids);
    }
    return missing.length;
  });

  /// Re-creates the seed lists of [language] (the current speech language)
  /// that are missing. Lists of other languages are left alone. Returns how
  /// many were added.
  Future<int> restoreDefaultLists(String language) =>
      _db.transaction(() => _addMissingSeedLists(language));

  /// Whether any seed was ever inserted.
  Future<bool> isSeeded() => _db.isSeeded();

  /// Languages of the seed lists currently present.
  Future<Set<String>> seedLanguages() async => {
    for (final l in await _db.select(_lists).get())
      if (l.seedLanguage != null) l.seedLanguage!,
  };

  /// Appends the default lists of [language] (falling back to `en` when there
  /// is no seed file) after the existing ones. Lists already present are not
  /// duplicated.
  Future<void> addSeedLists(String language) => _db.transaction(() async {
    await _addMissingSeedLists(language);
    await syncHistoryTitle(language);
    await _db.markSeeded();
  });

  /// Gives the history list the title of [language]'s seed, so it matches the
  /// seeded lists (the speech language, not the UI language). No-op without a
  /// seed file for [language] or if the title is already right.
  Future<void> syncHistoryTitle(String language) async {
    if (!await _db.hasSeed(language)) return;
    final title = (await _db.resolveSeed(language)).$2.historyTitle;
    if (title == null) return;
    final history = await _historyList();
    if (history.title == title) return;
    await (_db.update(_lists)..where((l) => l.id.equals(history.id))).write(
      SentenceListsCompanion(title: Value(title)),
    );
  }

  /// Called when a voice of [language] becomes the speech language. Seeds on
  /// first use; later, when the speech language changed ([languageChanged]),
  /// asks (via [ask]) once whether to add that language's default lists.
  /// Switching between voices of the same language never asks, even if the
  /// user deleted that language's seed lists. Returns whether lists were
  /// added.
  Future<bool> offerSeedLists(
    String language, {
    required Future<bool> Function() ask,
    bool languageChanged = true,
  }) async {
    await syncHistoryTitle(language);
    if (!await isSeeded()) {
      await addSeedLists(language);
      return true;
    }
    if (!languageChanged) return false;
    if ((await seedLanguages()).contains(language)) return false;
    if (!await _db.hasSeed(language)) return false;
    final prefs = await SharedPreferences.getInstance();
    final declined = prefs.getStringList(_declinedSeedKey) ?? const [];
    if (declined.contains(language)) return false;
    if (await ask()) {
      await addSeedLists(language);
      return true;
    }
    await prefs.setStringList(_declinedSeedKey, [...declined, language]);
    return false;
  }

  // ---- Backup ----

  /// Every permanent (non-history) list with its sentences, as plain JSON
  /// data for the backup file. `said` is not saved: a restored conversation
  /// starts fresh.
  Future<Map<String, Object?>> exportBackupData() async {
    final lists =
        await (_db.select(_lists)
              ..where((l) => l.kind.equalsValue(ListKind.history).not())
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final out = <Map<String, Object?>>[];
    for (final l in lists) {
      final rows =
          await (_db.select(_sentences)
                ..where((s) => s.listId.equals(l.id))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      out.add({
        'title': l.title,
        'kind': l.kind.name,
        'pinned': l.pinned,
        'color': l.color,
        'seedKey': l.seedKey,
        'seedLanguage': l.seedLanguage,
        'sentences': [
          for (final s in rows)
            {
              'text': s.body,
              'recording': s.recordingPath,
              'sound': s.soundKey,
              'alarm': s.alarm,
              'seedKey': s.seedKey,
            },
        ],
      });
    }
    return {'lists': out};
  }

  /// Adds the lists of a backup after the existing ones; never changes or
  /// deletes anything. A list with the same title and identical sentence
  /// texts is skipped. The seed identity of an imported list is kept only if
  /// no list has it yet (it is unique). Malformed data throws
  /// [FormatException] and changes nothing. Returns (added, skipped).
  Future<(int, int)> importBackupData(Map<String, Object?> data) =>
      _db.transaction(() async {
        final raw = data['lists'];
        if (raw is! List) throw const FormatException('lists');
        final existing = await _db.select(_lists).get();
        final signatures = <String>{};
        for (final l in existing) {
          if (l.kind == ListKind.history) continue;
          signatures.add(_signature(l.title, await _bodies(l.id)));
        }
        final identities = {
          for (final l in existing)
            if (l.seedKey != null && l.seedLanguage != null)
              '${l.seedLanguage}/${l.seedKey}',
        };
        final historyWasLast = await _historyIsLast();
        var added = 0;
        var skipped = 0;
        for (final item in raw) {
          if (item is! Map) throw const FormatException('list');
          final title = (item['title'] as String).trim();
          final kind = ListKind.values.byName(item['kind'] as String);
          if (kind == ListKind.history) throw const FormatException('kind');
          final rows = item['sentences'] as List;
          final texts = [for (final s in rows) (s as Map)['text'] as String];
          if (!signatures.add(_signature(title, texts))) {
            skipped++;
            continue;
          }
          final seedKey = item['seedKey'] as String?;
          final seedLanguage = item['seedLanguage'] as String?;
          final identity = '$seedLanguage/$seedKey';
          final keepIdentity =
              seedKey != null &&
              seedLanguage != null &&
              !identities.contains(identity);
          if (keepIdentity) identities.add(identity);
          final listId = await _db
              .into(_lists)
              .insert(
                SentenceListsCompanion.insert(
                  title: title,
                  kind: kind,
                  pinned: Value(item['pinned'] as bool? ?? false),
                  position: await _lastListPosition() + 1,
                  color: Value(item['color'] as String?),
                  seedKey: Value(keepIdentity ? seedKey : null),
                  seedLanguage: Value(keepIdentity ? seedLanguage : null),
                ),
              );
          for (final (i, s) in rows.indexed) {
            final m = s as Map;
            await _db
                .into(_sentences)
                .insert(
                  SentencesCompanion.insert(
                    listId: listId,
                    body: m['text'] as String,
                    position: i,
                    recordingPath: Value(m['recording'] as String?),
                    soundKey: Value(m['sound'] as String?),
                    alarm: Value(m['alarm'] as bool? ?? false),
                    seedKey: Value(m['seedKey'] as String?),
                  ),
                );
          }
          added++;
        }
        if (added > 0 && historyWasLast) await _moveHistoryLast();
        return (added, skipped);
      });

  String _signature(String title, List<String> texts) =>
      [title, ...texts].join('\u0000');

  Future<List<String>> _bodies(int listId) async => [
    for (final s
        in await (_db.select(_sentences)
              ..where((x) => x.listId.equals(listId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get())
      s.body,
  ];

  Future<bool> _historyIsLast() async {
    final history = await _historyList();
    return history.position == await _lastListPosition();
  }

  /// Moves the history list behind all others, as [_addMissingSeedLists] does.
  Future<void> _moveHistoryLast() async {
    final history = await _historyList();
    await (_db.update(_lists)..where((x) => x.id.equals(history.id))).write(
      SentenceListsCompanion(position: Value(await _lastListPosition() + 1)),
    );
  }

  // ---- Last used list ----

  Future<int?> lastUsedListId() async =>
      (await SharedPreferences.getInstance()).getInt(_lastListKey);

  Future<void> setLastUsedListId(int id) async =>
      (await SharedPreferences.getInstance()).setInt(_lastListKey, id);

  // ---- Helpers ----

  Future<SentenceList> _historyList() => (_db.select(
    _lists,
  )..where((l) => l.kind.equalsValue(ListKind.history))).getSingle();

  Future<void> _requireNotHistory(int id, String action) async {
    final l = await (_db.select(
      _lists,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (l?.kind == ListKind.history) {
      throw StateError('The history list cannot be $action');
    }
  }

  Future<Sentence?> _sentenceById(int id) =>
      (_db.select(_sentences)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> _lastListPosition() async {
    final max = _lists.position.max();
    final row = await (_db.selectOnly(_lists)..addColumns([max])).getSingle();
    return row.read(max) ?? -1;
  }

  Future<int> _lastSentencePosition(int listId) async {
    final max = _sentences.position.max();
    final row =
        await (_db.selectOnly(_sentences)
              ..addColumns([max])
              ..where(_sentences.listId.equals(listId)))
            .getSingle();
    return row.read(max) ?? -1;
  }

  Future<int> _insertSentence(
    int listId,
    String text, {
    String? recordingPath,
    String? soundKey,
    bool alarm = false,
    String? seedKey,
  }) async => _db
      .into(_sentences)
      .insert(
        SentencesCompanion.insert(
          listId: listId,
          body: text,
          position: await _lastSentencePosition(listId) + 1,
          recordingPath: Value(recordingPath),
          soundKey: Value(soundKey),
          alarm: Value(alarm),
          seedKey: Value(seedKey),
        ),
      );

  /// Sentence ids of a list in position order.
  Future<List<int>> _sentenceIds(int listId) async => [
    for (final s
        in await (_db.select(_sentences)
              ..where((x) => x.listId.equals(listId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get())
      s.id,
  ];

  Future<void> _writeOrder(int listId, List<int> ids) async {
    for (final (i, id) in ids.indexed) {
      await (_db.update(_sentences)..where((s) => s.id.equals(id))).write(
        SentencesCompanion(position: Value(i)),
      );
    }
  }

  /// [first] (only ids that exist in [all]), then the rest of [all] in order.
  List<int> _merge(List<int> first, List<int> all) {
    final known = all.toSet();
    final head = [
      for (final id in first.toSet())
        if (known.contains(id)) id,
    ];
    return [...head, ...all.where((id) => !head.contains(id))];
  }

  /// Inserts the seed lists of [language] that are missing, after the existing
  /// ones; the history list stays last if it was last. Returns how many.
  Future<int> _addMissingSeedLists(String language) async {
    final (used, seed) = await _db.resolveSeed(language);
    final all = await (_db.select(
      _lists,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    final history = all.where((l) => l.kind == ListKind.history).firstOrNull;
    final historyLast = history != null && all.last.id == history.id;
    final existing = {
      for (final l in all)
        if (l.seedLanguage == used && l.seedKey != null) l.seedKey,
    };
    var added = 0;
    for (final l in seed.lists) {
      if (existing.contains(l.seedKey)) continue;
      await _db.insertSeedList(
        l,
        await _lastListPosition() + 1,
        language: used,
      );
      added++;
    }
    if (added > 0 && historyLast) {
      await (_db.update(_lists)..where((x) => x.id.equals(history.id))).write(
        SentenceListsCompanion(position: Value(await _lastListPosition() + 1)),
      );
    }
    return added;
  }

  /// Seed sentences (with their seed index) missing from the list, from the
  /// list's own seed language. Empty for lists without a seed (user lists,
  /// history).
  Future<List<(int, SeedSentence)>> _missingSeedSentences(int listId) async {
    final list = await (_db.select(
      _lists,
    )..where((l) => l.id.equals(listId))).getSingleOrNull();
    if (list?.seedKey == null || list?.seedLanguage == null) return const [];
    final (_, seed) = await _db.resolveSeed(list!.seedLanguage!);
    final seedList = seed.lists
        .where((l) => l.seedKey == list.seedKey)
        .firstOrNull;
    if (seedList == null) return const [];
    final have = {
      for (final s in await (_db.select(
        _sentences,
      )..where((x) => x.listId.equals(listId))).get())
        if (s.seedKey != null) s.seedKey,
    };
    return [
      for (final (i, s) in seedList.sentences.indexed)
        if (!have.contains(s.seedKey)) (i, s),
    ];
  }
}
