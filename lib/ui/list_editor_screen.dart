import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../storage/lists_repository.dart';
import 'row_badges.dart';

/// Per-list sentence editor: edit, reorder, delete, copy/move, add lines.
/// List-level actions (rename, pin, delete) live in the lists overview.
class ListEditorScreen extends StatefulWidget {
  const ListEditorScreen({super.key, required this.repo, required this.listId});

  final ListsRepository repo;
  final int listId;

  @override
  State<ListEditorScreen> createState() => _ListEditorScreenState();
}

class _ListEditorScreenState extends State<ListEditorScreen> {
  late final Stream<List<SentenceList>> _lists = widget.repo
      .watchLists()
      .asBroadcastStream();
  late final Stream<List<Sentence>> _sentences = widget.repo
      .watchSentences(widget.listId)
      .asBroadcastStream();
  final _newLines = TextEditingController();

  @override
  void dispose() {
    _newLines.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<SentenceList>>(
      stream: _lists,
      builder: (context, listSnap) {
        final list = listSnap.data
            ?.where((l) => l.id == widget.listId)
            .firstOrNull;
        final isHistory = list?.kind == ListKind.history;
        final title = list == null
            ? ''
            : (isHistory && list.title.isEmpty
                  ? l10n.historyTitle
                  : list.title);
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<Sentence>>(
                    stream: _sentences,
                    builder: (context, snap) {
                      final rows = snap.data ?? const <Sentence>[];
                      if (rows.isEmpty && snap.hasData) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.emptyEditorList,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        );
                      }
                      if (isHistory) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: rows.length,
                          itemBuilder: (context, i) =>
                              _row(l10n, rows[i], i, isHistory: true),
                        );
                      }
                      return ReorderableListView.builder(
                        padding: const EdgeInsets.all(12),
                        buildDefaultDragHandles: false,
                        itemCount: rows.length,
                        onReorderItem: (from, to) {
                          final ids = [for (final s in rows) s.id];
                          ids.insert(to, ids.removeAt(from));
                          widget.repo.reorderSentences(widget.listId, ids);
                        },
                        itemBuilder: (context, i) =>
                            _row(l10n, rows[i], i, isHistory: false),
                      );
                    },
                  ),
                ),
                if (list != null && !isHistory) _addField(l10n),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _addField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _newLines,
            minLines: 2,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l10n.newLinesLabel,
              hintText: l10n.newLinesHint,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(l10n.addAction, style: const TextStyle(fontSize: 22)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final lines = _newLines.text.split(RegExp(r'\r?\n'));
    if (lines.every((t) => t.trim().isEmpty)) return;
    _newLines.clear();
    await widget.repo.addSentences(widget.listId, lines);
  }

  Widget _row(
    AppLocalizations l10n,
    Sentence s,
    int index, {
    required bool isHistory,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey(s.id),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isHistory ? null : () => _edit(l10n, s),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Row(
                children: [
                  // What plays (own recording, else built-in sound), then the
                  // alarm flag; the two are independent.
                  if (s.recordingPath != null)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.mic, size: 30),
                    )
                  else if (soundIcon(s.soundKey) case final icon?)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(icon, size: 30),
                    ),
                  if (s.alarm)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: AlarmBadge(),
                    ),
                  Expanded(
                    child: Text(s.body, style: const TextStyle(fontSize: 22)),
                  ),
                  IconButton(
                    iconSize: 28,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: l10n.moreActions,
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _actions(l10n, s, isHistory: isHistory),
                  ),
                  if (isHistory)
                    const SizedBox(width: 4)
                  else
                    ReorderableDragStartListener(
                      index: index,
                      child: Semantics(
                        label: l10n.reorderHandle,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.drag_handle, size: 28),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _edit(AppLocalizations l10n, Sentence s) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _EditDialog(initial: s.body),
    );
    if (text != null) await widget.repo.updateSentenceText(s.id, text);
  }

  Future<void> _actions(
    AppLocalizations l10n,
    Sentence s, {
    required bool isHistory,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isHistory) _AlarmSwitch(repo: widget.repo, sentence: s),
            _sheetRow(context, Icons.copy, l10n.copyToList, 'copy'),
            _sheetRow(
              context,
              Icons.drive_file_move_outline,
              l10n.moveToList,
              'move',
            ),
            _sheetRow(context, Icons.delete, l10n.deleteAction, 'delete'),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        final target = await _pickList(l10n);
        if (target != null) await widget.repo.copySentence(s.id, target);
      case 'move':
        final target = await _pickList(l10n);
        if (target != null) await widget.repo.moveSentence(s.id, target);
      case 'delete':
        await _delete(l10n, s);
    }
  }

  Future<void> _delete(AppLocalizations l10n, Sentence s) async {
    final ids = await widget.repo.watchSentences(widget.listId).first;
    final index = ids.indexWhere((x) => x.id == s.id);
    await widget.repo.deleteSentence(s.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.sentenceDeleted),
        action: SnackBarAction(
          label: l10n.undoAction,
          onPressed: () => widget.repo.restoreSentence(s, index),
        ),
      ),
    );
  }

  /// Picker of the other lists; history is never a target.
  Future<int?> _pickList(AppLocalizations l10n) async {
    final all = await widget.repo.watchLists().first;
    if (!mounted) return null;
    final targets = [
      for (final l in all)
        if (l.kind != ListKind.history && l.id != widget.listId) l,
    ];
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chooseListTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final l in targets)
                InkWell(
                  onTap: () => Navigator.of(context).pop(l.id),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          l.title,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Widget _sheetRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 64,
          minWidth: double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 16),
              Text(label, style: const TextStyle(fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alarm flag switch in the row's ⋮ sheet; writes immediately.
class _AlarmSwitch extends StatefulWidget {
  const _AlarmSwitch({required this.repo, required this.sentence});
  final ListsRepository repo;
  final Sentence sentence;

  @override
  State<_AlarmSwitch> createState() => _AlarmSwitchState();
}

class _AlarmSwitchState extends State<_AlarmSwitch> {
  late bool _value = widget.sentence.alarm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(l10n.alarmToggle, style: const TextStyle(fontSize: 22)),
      subtitle: Text(
        l10n.alarmToggleHelp,
        style: const TextStyle(fontSize: 16),
      ),
      value: _value,
      onChanged: (v) {
        setState(() => _value = v);
        widget.repo.setSentenceAlarm(widget.sentence.id, v);
      },
    );
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.initial});
  final String initial;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editSentenceTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 22),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}
