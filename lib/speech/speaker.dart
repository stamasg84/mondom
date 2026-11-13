import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../voices/elevenlabs_client.dart';
import '../voices/elevenlabs_engine.dart';
import '../voices/voice.dart';
import '../voices/voice_engine.dart';
import 'alarm_volume.dart';
import 'loudness.dart';
import 'recording_store.dart';
import 'sounds.dart';

/// Plays WAV files. Abstracted so [Speaker] can be unit-tested.
abstract class WavPlayer {
  Future<void> play(String path);
  Future<void> stop();
  void dispose();
}

class AudioPlayersWavPlayer implements WavPlayer {
  final _player = AudioPlayer();

  @override
  Future<void> play(String path) => _player.play(DeviceFileSource(path));

  @override
  Future<void> stop() => _player.stop();

  @override
  void dispose() => _player.dispose();
}

/// Plays built-in sounds (assets) and WAV files for rows that bypass the
/// speech player. Two instances exist: a normal one and one with the Android
/// alarm audio context, so the speech player's context is never changed.
abstract class SoundPlayer {
  Future<void> playAsset(String asset, {bool loop = false});
  Future<void> playFile(String path);
  Future<void> stop();

  /// Fires when a non-looping sound finishes.
  Stream<void> get onComplete;
  void dispose();
}

/// audioplayers-backed [SoundPlayer]. The underlying player is created on
/// first use, so merely constructing a [Speaker] touches no platform channel.
class AudioPlayersSoundPlayer implements SoundPlayer {
  AudioPlayersSoundPlayer({this.alarm = false});

  /// Use Android's alarm usage / sonification content type / transient focus.
  final bool alarm;
  AudioPlayer? _player;
  final _complete = StreamController<void>.broadcast();
  StreamSubscription<void>? _sub;

  Future<AudioPlayer> _get() async {
    var p = _player;
    if (p != null) return p;
    p = _player = AudioPlayer();
    _sub = p.onPlayerComplete.listen((_) => _complete.add(null));
    if (alarm) {
      await p.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
        ),
      );
    }
    return p;
  }

  @override
  Future<void> playAsset(String asset, {bool loop = false}) async {
    final p = await _get();
    // MediaPlayer leaves an audible click/gap at each loop restart; SoundPool
    // (lowLatency) loops gaplessly. It sends no completion events and has a
    // ~1 MB decoded-size limit, both fine for short looping alarm sounds.
    await p.setPlayerMode(
      loop ? PlayerMode.lowLatency : PlayerMode.mediaPlayer,
    );
    await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
    await p.play(AssetSource(asset));
  }

  @override
  Future<void> playFile(String path) async {
    final p = await _get();
    await p.setPlayerMode(PlayerMode.mediaPlayer);
    await p.setReleaseMode(ReleaseMode.release);
    await p.play(DeviceFileSource(path));
  }

  @override
  Future<void> stop() async => _player?.stop();

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _player?.dispose();
    _complete.close();
  }
}

/// What a tapped row plays, by priority: its own recording ([recordingPath],
/// a file name in the [RecordingStore]), a known [soundKey] (built-in sound),
/// otherwise [text] is spoken. [alarm] rows play on the alarm stream.
class SentenceRowData {
  const SentenceRowData({
    required this.text,
    this.soundKey,
    this.recordingPath,
    this.alarm = false,
  });

  final String text;
  final String? soundKey;
  final String? recordingPath;
  final bool alarm;

  /// The built-in sound to play, or null (unknown key = TTS).
  BuiltInSound? get sound => soundKey == null ? null : builtInSounds[soundKey];
}

/// Trim + collapse inner whitespace. Also used as the history key.
String normalizeText(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Owns the current [VoiceEngine] and the player. Remembers only the last
/// utterance (voice id + normalized text → WAV); not a cache.
class Speaker extends ChangeNotifier {
  Speaker({
    required Future<VoiceEngine> Function(Voice) engineFactory,
    WavPlayer? player,
    SoundPlayer? soundPlayer,
    SoundPlayer? alarmPlayer,
    this.loopLimit = alarmLoopLimit,
    this.alarmVolume,
    this.recordings,
    this.tempDir,
  }) : _createEngine = engineFactory,
       _player = player ?? AudioPlayersWavPlayer(),
       _soundPlayer = soundPlayer ?? AudioPlayersSoundPlayer(),
       _alarmPlayer = alarmPlayer ?? AudioPlayersSoundPlayer(alarm: true) {
    _alarmDone = _alarmPlayer.onComplete.listen((_) => _endAlarm());
  }

  /// Message-banking files; null = recordings are never played.
  final RecordingStore? recordings;

  /// Where prepared recordings are written (default: the system temp dir).
  final Directory? tempDir;

  /// Raises the alarm stream around alarms (custom volume mode); null = never.
  final AlarmVolume? alarmVolume;
  bool _volumeRaised = false;

  /// A looping alarm stops by itself after this long.
  final Duration loopLimit;
  final SoundPlayer _soundPlayer;
  final SoundPlayer _alarmPlayer;
  StreamSubscription<void>? _alarmDone;
  Timer? _loopTimer;
  bool _alarmPlaying = false;

  /// True while an alarm row is playing (sound, recording or TTS).
  bool get alarmPlaying => _alarmPlaying;

  final Future<VoiceEngine> Function(Voice) _createEngine;
  final WavPlayer _player;
  VoiceEngine? _engine;
  Voice? _voice;

  String? _lastKey;
  String? _lastPath;

  bool _busy = false;
  // True until the first voice is loaded (the app always sets one at start).
  bool _loading = true;
  String? _error;
  SynthResult? _lastResult;
  bool _lastReplayed = false;

  /// True while synthesizing.
  bool get busy => _busy;

  /// True while a voice is being loaded.
  bool get loading => _loading;
  String? get error => _error;
  SynthResult? get lastResult => _lastResult;

  /// Whether the last [speak] replayed the WAV instead of synthesizing.
  bool get lastReplayed => _lastReplayed;
  bool get ready => (_engine?.isLoaded ?? false) && !_loading && !_busy;
  int get loadMs => _engine?.loadMs ?? 0;

  /// Why the last utterance was spoken by the offline fallback instead of
  /// the selected ElevenLabs voice; null when it wasn't (or isn't ElevenLabs).
  ElevenLabsFailure? get lastFallback {
    final e = _engine;
    return e is ElevenLabsEngine ? e.lastFallback : null;
  }

  /// The voice that speaks when ElevenLabs can't, or null.
  Voice? get fallbackVoice {
    final e = _engine;
    return e is ElevenLabsEngine ? e.fallbackVoice : null;
  }

  /// Switches voice: disposes the old engine, loads the engine for [v] and
  /// forgets the last utterance.
  Future<void> setVoice(Voice v) async {
    _loading = true;
    _voice = v;
    _engine?.dispose();
    _engine = null;
    await _forgetLast();
    notifyListeners();
    try {
      final engine = await _createEngine(v);
      await engine.load();
      _engine = engine;
      _error = null;
    } catch (e) {
      _error = '$e';
    }
    _loading = false;
    notifyListeners();
  }

  /// Whether [row] can play now: a recording or built-in sound needs no
  /// voice, so they work even while the voice is still loading.
  bool canPlay(SentenceRowData row) =>
      row.recordingPath != null || row.sound != null || ready;

  /// Row-level entry: a recording plays first, then a known sound (its asset),
  /// anything else is spoken; alarm rows use the alarm stream. A missing or
  /// unreadable recording falls through silently. Only one thing plays at a
  /// time.
  Future<void> play(SentenceRowData row) async {
    final rec = row.recordingPath;
    if (rec != null && await _playRecording(rec, alarm: row.alarm)) return;
    final sound = row.sound;
    if (sound == null) {
      return row.alarm ? _speakText(row.text, alarm: true) : speak(row.text);
    }
    try {
      await _stopAll(restoreVolume: !row.alarm);
      _error = null;
      if (row.alarm) {
        await _raiseVolume();
        await _alarmPlayer.playAsset(sound.asset, loop: sound.loops);
        _startAlarm(loops: sound.loops);
      } else {
        await _soundPlayer.playAsset(sound.asset, loop: sound.loops);
      }
    } catch (e) {
      _error = '$e';
      notifyListeners();
      await _restoreVolume();
    }
  }

  /// Free text: speech on the normal player.
  Future<void> speak(String text) => _speakText(text, alarm: false);

  /// Plays the recording [fileName] (prepared into a temp WAV, replayed
  /// instantly on a second tap). Returns false, having shown no error, if it
  /// can't be played, so the caller falls through to sound/TTS.
  Future<bool> _playRecording(String fileName, {required bool alarm}) {
    final store = recordings;
    if (store == null) return Future.value(false);
    return _playPrepared(
      'rec $fileName',
      () => store.resolve(fileName),
      alarm: alarm,
    );
  }

  /// Plays an unsaved take at [path] exactly as it will sound once saved
  /// (through [prepareRecording]). False if it can't be played.
  Future<bool> previewRecording(String path) =>
      _playPrepared('preview $path', () async => path, alarm: false);

  Future<bool> _playPrepared(
    String key,
    Future<String?> Function() resolve, {
    required bool alarm,
  }) async {
    if (_busy) return true; // same as speech: ignore taps while preparing
    try {
      final last = _lastPath;
      if (key == _lastKey && last != null && File(last).existsSync()) {
        await _stopAll(restoreVolume: !alarm);
        _lastReplayed = true;
        _error = null;
        notifyListeners();
        await _playWav(last, alarm);
        return true;
      }
      final source = await resolve();
      if (source == null) return false;
      final bytes = await File(source).readAsBytes();
      await _stopAll(restoreVolume: !alarm);
      _busy = true;
      notifyListeners();
      Uint8List? prepared;
      try {
        prepared = await Isolate.run(() => prepareRecordingBytes(bytes));
      } finally {
        _busy = false;
      }
      if (prepared == null) {
        notifyListeners();
        return false;
      }
      final dir = tempDir ?? Directory.systemTemp;
      final out = File(
        '${dir.path}/mondom_rec_${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      await out.writeAsBytes(prepared, flush: true);
      final old = _lastPath;
      _lastKey = key;
      _lastPath = out.path;
      _lastReplayed = false;
      _error = null;
      if (old != null) await _deleteQuietly(old);
      notifyListeners();
      await _playWav(out.path, alarm);
      return true;
    } catch (_) {
      _busy = false;
      notifyListeners();
      await _restoreVolume();
      return false;
    }
  }

  Future<void> _speakText(String text, {required bool alarm}) async {
    final normalized = normalizeText(text);
    final engine = _engine;
    final voice = _voice;
    if (normalized.isEmpty || engine == null || voice == null || _busy) return;
    // The boost setting is part of the key, so toggling it re-synthesizes.
    final boost = await speechBoostEnabled();
    final key = '${voice.id}\u0000$boost\u0000$normalized';
    try {
      await _stopAll(restoreVolume: !alarm);
      if (key == _lastKey && _lastPath != null) {
        _lastReplayed = true;
        _error = null;
        notifyListeners();
        await _playWav(_lastPath!, alarm);
        return;
      }
      _busy = true;
      notifyListeners();
      final result = await engine.synthesizeToWav(normalized, urgent: alarm);
      final old = _lastPath;
      _lastKey = key;
      _lastPath = result.path;
      _lastResult = result;
      _lastReplayed = false;
      _error = null;
      if (old != null && old != result.path) await _deleteQuietly(old);
      _busy = false;
      notifyListeners();
      await _playWav(result.path, alarm);
    } catch (e) {
      _error = '$e';
      _busy = false;
      notifyListeners();
      await _restoreVolume();
    }
  }

  Future<void> _raiseVolume() async {
    final v = alarmVolume;
    if (v == null) return;
    _volumeRaised = true;
    await v.raise();
  }

  Future<void> _restoreVolume() async {
    if (!_volumeRaised) return;
    _volumeRaised = false;
    await alarmVolume?.restore();
  }

  Future<void> _playWav(String path, bool alarm) async {
    if (alarm) {
      await _raiseVolume();
      await _alarmPlayer.playFile(path);
      _startAlarm(loops: false);
    } else {
      await _player.play(path);
    }
  }

  void _startAlarm({required bool loops}) {
    _loopTimer?.cancel();
    _loopTimer = loops ? Timer(loopLimit, _stopAll) : null;
    _alarmPlaying = true;
    notifyListeners();
  }

  void _endAlarm() {
    _loopTimer?.cancel();
    _loopTimer = null;
    _restoreVolume();
    if (!_alarmPlaying) return;
    _alarmPlaying = false;
    notifyListeners();
  }

  /// Stops speech, sounds and alarms. [restoreVolume] is false when an alarm
  /// is about to start, so the originally saved level survives.
  Future<void> _stopAll({bool restoreVolume = true}) async {
    _loopTimer?.cancel();
    _loopTimer = null;
    await _player.stop();
    await _soundPlayer.stop();
    await _alarmPlayer.stop();
    if (_alarmPlaying) {
      _alarmPlaying = false;
      notifyListeners();
    }
    if (restoreVolume) await _restoreVolume();
  }

  Future<void> stop() => _stopAll();

  Future<void> _forgetLast() async {
    final old = _lastPath;
    _lastKey = null;
    _lastPath = null;
    if (old != null) await _deleteQuietly(old);
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _alarmDone?.cancel();
    _soundPlayer.dispose();
    _alarmPlayer.dispose();
    _player.dispose();
    _engine?.dispose();
    super.dispose();
  }
}
