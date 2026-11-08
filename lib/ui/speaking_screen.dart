import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../speech/alarm_volume.dart';
import '../speech/speaker.dart';
import '../storage/lists_repository.dart';
import '../voices/voice.dart';
import 'list_colors.dart';
import 'main_drawer.dart';
import 'row_badges.dart';

/// Main screen: list chips, big sentence rows, always-visible free text.
class SpeakingScreen extends StatefulWidget {
  const SpeakingScreen({
    super.key,
    required this.speaker,
    required this.repo,
    this.voice,
    this.onOpenVoicePicker,
  });

  final Speaker speaker;
  final ListsRepository repo;

  /// The active voice, shown in settings. Defaults to the Hungarian system voice.
  final Voice Function()? voice;
  final Future<void> Function()? onOpenVoicePicker;

  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late final Stream<List<SentenceList>> _lists;
  StreamSubscription<List<SentenceList>>? _listsSub;
  int? _lastUsedId;
  Stream<List<Sentence>>? _sentences;
  int? _currentId;
  bool _currentIsHistory = false;
  bool _currentIsConversation = false;

  /// After "Következő": the id of the sentence just said; once its `said`
  /// flag arrives, the new next row is scrolled into view (never otherwise).
  int? _scrollAfterId;
  final _scrollController = ScrollController();
  final _nextKey = GlobalKey();

  /// The open list was chosen by the fallback rule, not by the user or the
  /// remembered last list, so it may be replaced when lists appear later
  /// (e.g. the first seed is inserted after this screen is built).
  bool _autoPicked = false;
  int? _tappedId;
  bool _expanded = false;

  /// One-shot builder mode: the next row tap loads its text into the field
  /// instead of speaking, then this turns itself off.
  bool _loadArmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lists = widget.repo.watchLists().asBroadcastStream();
    _focusNode.addListener(_onFieldFocus);
    _start();
  }

  /// On gaining focus, put the caret at the end of the text. The field is
  /// narrow and shows at most 3 lines, so the tap that focuses it often lands
  /// mid-sentence of a long loaded text; continuing to type at the end is
  /// what's almost always wanted. Focus listeners run after the tap has set
  /// its selection, so this wins. Taps on an already focused field still
  /// place the caret where tapped.
  void _onFieldFocus() {
    if (!_focusNode.hasFocus) return;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _loadArmed) {
      setState(() => _loadArmed = false);
    }
  }

  /// Appends [text] to the free-text field (cursor at the end) and turns the
  /// builder mode off. Neither speaks, logs history nor sets `said`.
  void _loadIntoField(String text) {
    final old = _controller.text.trimRight();
    final next = old.isEmpty ? text : '$old $text';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() => _loadArmed = false);
  }

  Future<void> _start() async {
    _lastUsedId = await widget.repo.lastUsedListId();
    if (!mounted) return;
    _listsSub = _lists.listen(_onLists);
  }

  /// Opens the last used list, else the first `everyday` list, else any
  /// non-history list, else history. Re-evaluated whenever the lists change
  /// while no valid list is open (or only a fallback history is).
  void _onLists(List<SentenceList> lists) {
    final current = lists.where((l) => l.id == _currentId).firstOrNull;
    if (current != null && !(_autoPicked && _currentIsHistory)) return;
    final lastUsed = lists.where((l) => l.id == _lastUsedId).firstOrNull;
    final initial =
        lastUsed ??
        lists.where((l) => l.seedKey == 'everyday').firstOrNull ??
        lists.where((l) => l.kind != ListKind.history).firstOrNull ??
        lists.firstOrNull;
    if (initial == null || initial.id == _currentId) return;
    _autoPicked = lastUsed == null;
    _showList(initial, remember: false);
  }

  void _showList(SentenceList list, {bool remember = true}) {
    final id = list.id;
    if (remember) _autoPicked = false;
    setState(() {
      _currentId = id;
      _currentIsHistory = list.kind == ListKind.history;
      _currentIsConversation = list.kind == ListKind.conversation;
      _scrollAfterId = null;
      _sentences = widget.repo.watchSentences(id);
      _expanded = false;
      _loadArmed = false;
    });
    if (remember) widget.repo.setLastUsedListId(id);
  }

  Future<void> _speak(String text, {Sentence? row}) async {
    final speaker = widget.speaker;
    final data = row == null
        ? null
        : SentenceRowData(text: text, soundKey: row.soundKey, alarm: row.alarm);
    final canPlay = data == null ? speaker.ready : speaker.canPlay(data);
    if (!canPlay || text.trim().isEmpty) return;
    final rowId = row?.id;
    setState(() {
      _tappedId = rowId;
      _loadArmed = false;
    });
    if (rowId != null && _currentIsConversation) {
      unawaited(widget.repo.setSaid(rowId, true));
    }
    // Tapping a row in the history list must not reorder it under the finger;
    // alarm rows are never logged.
    if ((rowId == null || !_currentIsHistory) && !(row?.alarm ?? false)) {
      unawaited(widget.repo.addToHistory(text));
    }
    await (data == null ? speaker.speak(text) : speaker.play(data));
    if (mounted) setState(() => _tappedId = null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listsSub?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _title(AppLocalizations l10n, SentenceList l) =>
      l.kind == ListKind.history && l.title.isEmpty
      ? l10n.historyTitle
      : l.title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<SentenceList>>(
      stream: _lists,
      builder: (context, snap) {
        final lists = snap.data ?? const <SentenceList>[];
        final current = lists.where((l) => l.id == _currentId).firstOrNull;
        return Scaffold(
          // Opened only by the hamburger: an edge swipe clashes with Android's
          // back gesture and opens by accident while scrolling.
          drawerEnableOpenDragGesture: false,
          drawer: MainDrawer(
            repo: widget.repo,
            voice: widget.voice ?? () => Voice.system('hu'),
            onOpenVoicePicker: widget.onOpenVoicePicker ?? () async {},
            currentListId: () => _currentId,
            alarmVolume: widget.speaker.alarmVolume ?? AlarmVolume(),
            speaker: widget.speaker,
          ),
          appBar: AppBar(
            leading: Builder(
              builder: (ctx) => IconButton(
                tooltip: l10n.menuTooltip,
                icon: const Icon(Icons.menu),
                onPressed: () {
                  // Otherwise the route/drawer restores focus to the text
                  // field on return and the keyboard pops up.
                  FocusManager.instance.primaryFocus?.unfocus();
                  Scaffold.of(ctx).openDrawer();
                },
              ),
            ),
            // The open list's name, so the screen says which list it is in
            // words as well as color.
            title: Text(
              current == null ? '' : _title(l10n, current),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [_loadButton(l10n), const SizedBox(width: 4)],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _chipRow(l10n, lists),
                if (_loadArmed) _loadBanner(l10n),
                Expanded(
                  child: _expanded
                      ? _listGrid(l10n, lists)
                      : _sentenceArea(l10n, current),
                ),
                _bottomBar(l10n),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builder-mode toggle. Lives in the app bar so the free-text field gets
  /// the full width of the bottom bar.
  Widget _loadButton(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    // Same corner radius as the sentence rows and the banner, not the
    // default circular IconButton shape.
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return IconButton(
      iconSize: 32,
      tooltip: l10n.loadSentence,
      isSelected: _loadArmed,
      style: _loadArmed
          ? IconButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: shape,
            )
          : IconButton.styleFrom(
              side: BorderSide(color: scheme.outline),
              shape: shape,
            ),
      icon: const Icon(Icons.arrow_downward),
      onPressed: () => setState(() => _loadArmed = !_loadArmed),
    );
  }

  Widget _loadBanner(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.arrow_downward, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  l10n.loadBanner,
                  style: TextStyle(
                    fontSize: 20,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            IconButton(
              iconSize: 32,
              tooltip: l10n.cancel,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _loadArmed = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow(AppLocalizations l10n, List<SentenceList> lists) {
    final shown = [
      for (final l in lists)
        if (l.pinned || l.id == _currentId) l,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            // Wraps instead of scrolling sideways: a chip scrolled off-screen
            // (often Előzmények, the last one) is effectively invisible.
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in shown)
                  ChoiceChip(
                    label: Text(
                      _title(l10n, l),
                      style: const TextStyle(fontSize: 20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    selected: l.id == _currentId,
                    showCheckmark: false,
                    backgroundColor: listColor(context, l.color).chip,
                    selectedColor: listColor(context, l.color).chip,
                    side: l.id == _currentId
                        ? BorderSide(
                            width: 4,
                            color: Theme.of(context).colorScheme.onSurface,
                          )
                        : BorderSide.none,
                    onSelected: (_) => _showList(l),
                  ),
              ],
            ),
          ),
          IconButton(
            iconSize: 36,
            tooltip: l10n.allLists,
            icon: Icon(_expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down),
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ),
    );
  }

  Widget _listGrid(AppLocalizations l10n, List<SentenceList> lists) {
    return GridView.count(
      padding: const EdgeInsets.all(12),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        for (final l in lists)
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: listColor(context, l.color).chip,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: l.id == _currentId
                  ? BorderSide(
                      width: 4,
                      color: Theme.of(context).colorScheme.onSurface,
                    )
                  : null,
            ),
            onPressed: () => _showList(l),
            child: Text(
              _title(l10n, l),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22),
            ),
          ),
      ],
    );
  }

  Widget _sentenceArea(AppLocalizations l10n, SentenceList? list) {
    final stream = _sentences;
    if (stream == null) return const SizedBox.shrink();
    return StreamBuilder<List<Sentence>>(
      stream: stream,
      builder: (context, snap) {
        final sentences = snap.data;
        if (sentences == null) return const SizedBox.shrink();
        if (sentences.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.emptyListHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          );
        }
        final conversation = list?.kind == ListKind.conversation;
        final next = conversation
            ? sentences.where((s) => !s.said).firstOrNull
            : null;
        final pending = _scrollAfterId;
        if (pending != null &&
            sentences.any((s) => s.id == pending && s.said)) {
          _scrollAfterId = null;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToNext(sentences),
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: widget.speaker,
                builder: (context, _) => ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: sentences.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _row(
                    sentences[i],
                    list?.color,
                    isNext: next != null && sentences[i].id == next.id,
                  ),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: widget.speaker,
              builder: (context, _) => widget.speaker.alarmPlaying
                  ? _stopBar(l10n)
                  : conversation
                  ? _nextBar(l10n, next)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  /// Brings the next unsaid row into view: exact if it is built, otherwise
  /// jump near it by an estimated row height first.
  void _scrollToNext(List<Sentence> sentences) {
    if (!mounted || !_scrollController.hasClients) return;
    final i = sentences.indexWhere((s) => !s.said);
    if (i < 0) return;
    final ctx = _nextKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      return;
    }
    final pos = _scrollController.position;
    _scrollController.jumpTo((i * 80.0).clamp(0, pos.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _nextKey.currentContext;
      if (mounted && c != null) Scrollable.ensureVisible(c);
    });
  }

  Future<void> _speakNext(Sentence next) async {
    _scrollAfterId = next.id;
    await _speak(next.body, row: next);
  }

  Future<void> _confirmReset(int listId) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          l10n.resetSaidQuestion,
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.resetSaid),
          ),
        ],
      ),
    );
    if (ok == true) await widget.repo.resetSaid(listId);
  }

  /// Replaces Következő (in any list kind) while an alarm plays.
  Widget _stopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SizedBox(
        width: double.infinity,
        height: 72,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: widget.speaker.stop,
          icon: const Icon(Icons.stop, size: 36),
          label: Text(l10n.stopAlarm, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }

  Widget _nextBar(AppLocalizations l10n, Sentence? next) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: next != null
          ? SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: widget.speaker.ready && !_loadArmed
                    ? () => _speakNext(next)
                    : null,
                icon: const Icon(Icons.play_arrow, size: 32),
                label: Text(
                  l10n.nextSentence,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            )
          : SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.allSaid,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 56),
                    ),
                    onPressed: _loadArmed
                        ? null
                        : () => _confirmReset(_currentId!),
                    child: Text(
                      l10n.resetSaid,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(Sentence s, String? colorKey, {bool isNext = false}) {
    final scheme = Theme.of(context).colorScheme;
    final tones = listColor(context, colorKey);
    final active = _tappedId == s.id;
    return Material(
      key: isNext ? _nextKey : null,
      color: active
          ? tones.rowActive
          : s.said
          ? Color.alphaBlend(scheme.surface.withValues(alpha: 0.7), tones.row)
          : tones.row,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _loadArmed
            ? BorderSide(width: 3, color: scheme.primary)
            : isNext
            ? BorderSide(width: 3, color: scheme.onSurface)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            _loadArmed ? _loadIntoField(s.body) : _speak(s.body, row: s),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 72,
            minWidth: double.infinity,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (s.alarm)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: AlarmBadge(),
                  ),
                Expanded(
                  child: Text(
                    s.body,
                    style: TextStyle(
                      fontSize: 24,
                      color: s.said
                          ? scheme.onSurface.withValues(alpha: saidTextAlpha)
                          : null,
                    ),
                  ),
                ),
                if (s.said && !_loadArmed)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(
                      Icons.check_circle,
                      size: 28,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                if (_loadArmed)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(
                      Icons.arrow_downward,
                      size: 32,
                      color: scheme.primary,
                    ),
                  ),
                if (active && widget.speaker.busy)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(AppLocalizations l10n) {
    return ListenableBuilder(
      listenable: widget.speaker,
      builder: (context, _) {
        final speaker = widget.speaker;
        final error = speaker.error;
        return Material(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      error,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 24),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: l10n.textHint,
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _controller,
                            builder: (context, value, _) => value.text.isEmpty
                                ? const SizedBox.shrink()
                                : IconButton(
                                    iconSize: 32,
                                    tooltip: l10n.clearText,
                                    icon: const Icon(Icons.close),
                                    onPressed: _controller.clear,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (speaker.loading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          l10n.loading,
                          style: const TextStyle(fontSize: 22),
                        ),
                      )
                    else
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: speaker.ready
                              ? () => _speak(_controller.text)
                              : null,
                          child: speaker.busy && _tappedId == null
                              ? const SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : Text(
                                  l10n.speak,
                                  style: const TextStyle(fontSize: 26),
                                ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
