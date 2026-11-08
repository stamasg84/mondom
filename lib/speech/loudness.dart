import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Static make-up gain (dB) applied after peak normalization, before limiting.
const speechGainDb = 8.0;

/// Output ceiling (dBFS) of the limiter.
const speechCeilingDb = -1.0;

/// Corner of the speech high-pass (Hz). Phone speakers can't play this range;
/// it only eats headroom and makes the speaker buzz.
const speechHighPassHz = 120.0;

/// Limiter look-ahead and release times (seconds).
const _limiterLookAheadSec = 0.005;
const _limiterReleaseSec = 0.080;

/// `shared_preferences` key of the speech boost switch (default on).
const speechBoostKey = 'speechBoost';

Future<bool> speechBoostEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(speechBoostKey) ?? true;
  } catch (_) {
    return true;
  }
}

double _fromDb(double db) => math.pow(10, db / 20).toDouble();

/// Makes [samples] (−1..1, at [sampleRate]) louder: high-passes at
/// [speechHighPassHz], normalizes the peak to full scale, adds [gainDb] of
/// make-up gain, then runs the look-ahead [limitPeaks] to [ceilingDb]. Static,
/// so no per-sentence pumping. Silence stays silence. Returns a new list.
Float32List boostLoudness(
  Float32List samples, {
  required int sampleRate,
  double gainDb = speechGainDb,
  double ceilingDb = speechCeilingDb,
}) {
  final hp = highPass(samples, sampleRate, speechHighPassHz);
  var peak = 0.0;
  for (final s in hp) {
    final a = s.abs();
    if (a > peak) peak = a;
  }
  if (peak < 1e-6) return Float32List(samples.length); // silence: leave it
  final gain = _fromDb(gainDb) / peak;
  for (var i = 0; i < hp.length; i++) {
    hp[i] *= gain;
  }
  return limitPeaks(hp, sampleRate: sampleRate, ceilingDb: ceilingDb);
}

/// 2nd-order Butterworth high-pass biquad at [cutoffHz]. Returns a new list.
Float32List highPass(Float32List samples, int sampleRate, double cutoffHz) {
  final w0 = 2 * math.pi * cutoffHz / sampleRate;
  final alpha = math.sin(w0) / (2 * math.sqrt1_2); // Q = 1/sqrt(2)
  final cosW = math.cos(w0);
  final a0 = 1 + alpha;
  final b0 = (1 + cosW) / 2 / a0;
  final b1 = -(1 + cosW) / a0;
  final b2 = b0;
  final a1 = -2 * cosW / a0;
  final a2 = (1 - alpha) / a0;
  final out = Float32List(samples.length);
  var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
  for (var i = 0; i < samples.length; i++) {
    final x = samples[i].toDouble();
    final y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    out[i] = y;
  }
  return out;
}

/// Look-ahead peak limiter: no output sample exceeds [ceilingDb]. The gain
/// needed at each sample is the minimum over the next ~5 ms (sliding-window
/// minimum, O(n)), smoothed by a 5 ms moving average (ramps down before a
/// peak, never above the needed gain) and a ~80 ms release. Unlike a per-sample
/// waveshaper it scales whole stretches of the waveform, so it adds almost no
/// harmonic distortion. Time constants derive from [sampleRate]. Returns a new
/// list.
Float32List limitPeaks(
  Float32List samples, {
  required int sampleRate,
  double ceilingDb = speechCeilingDb,
}) {
  final n = samples.length;
  final out = Float32List(n);
  if (n == 0) return out;
  final ceiling = _fromDb(ceilingDb);
  final look = math.max(1, (_limiterLookAheadSec * sampleRate).round());

  // Gain each sample needs on its own.
  final need = Float64List(n);
  for (var i = 0; i < n; i++) {
    final a = samples[i].abs();
    need[i] = a > ceiling ? ceiling / a : 1.0;
  }

  // m[k] = min(need[k .. k+look]) via a monotonic deque of indices.
  final m = Float64List(n);
  final dq = Int32List(n);
  var head = 0, tail = 0;
  for (var j = 0; j < n; j++) {
    while (tail > head && need[dq[tail - 1]] >= need[j]) {
      tail--;
    }
    dq[tail++] = j;
    while (dq[head] < j - look) {
      head++;
    }
    // Window [j-look, j] ends at j, so it is m[j-look]'s window.
    final k = j - look;
    if (k >= 0) m[k] = need[dq[head]];
  }
  // Tail: windows clipped by the end of the signal.
  for (var k = math.max(0, n - look); k < n; k++) {
    while (dq[head] < k) {
      head++;
    }
    m[k] = need[dq[head]];
  }

  // s[i] = mean(m[i-look .. i]) <= need[i]; then one-pole release.
  final release = math.exp(-1 / (_limiterReleaseSec * sampleRate));
  var sum = 0.0;
  var r = 1.0;
  for (var i = 0; i < n; i++) {
    sum += m[i];
    if (i > look) sum -= m[i - look - 1];
    final count = math.min(i, look) + 1;
    final s = sum / count;
    r = s < r ? s : release * r + (1 - release) * s;
    final y = (samples[i] * r).clamp(-ceiling, ceiling);
    out[i] = y.toDouble();
  }
  return out;
}

/// Target speech level (dBFS, 75th percentile of 20 ms frame RMS) of a
/// message-banking recording on playback.
const recordingTargetRmsDb = -16.0;

/// Largest gain [prepareRecording] adds (it may attenuate without limit).
const recordingMaxGainDb = 15.0;

/// Corner of the recording high-pass (Hz).
const recordingHighPassHz = 80.0;

const _recordingClickSec = 0.100;
const _recordingFrameSec = 0.020;
const _recordingSilenceDb = -40.0;
const _recordingPaddingSec = 0.100;

/// Playback-time cleanup of a message-banking recording; never touches the
/// file. Drops the first and last 100 ms (button clicks), trims silence at
/// both ends (20 ms frames, 40 dB below the loudest frame, 100 ms padding
/// kept), high-passes at [recordingHighPassHz], normalizes the speech level to
/// [recordingTargetRmsDb] (gain at most [recordingMaxGainDb]) and applies the
/// look-ahead [limitPeaks]. Multi-channel input is downmixed to mono. Silence
/// stays silence. Returns a new [PcmWav].
PcmWav prepareRecording(PcmWav wav) {
  final rate = wav.sampleRate;
  var x = _toMono(wav);
  final click = (_recordingClickSec * rate).round();
  x = x.length > 2 * click
      ? Float32List.sublistView(x, click, x.length - click)
      : Float32List(0);
  final frame = math.max(1, (_recordingFrameSec * rate).round());
  var rms = _frameRms(x, frame);
  final loudest = rms.isEmpty ? 0.0 : rms.reduce(math.max);
  if (loudest < 1e-5) return PcmWav(Float32List(x.length), rate, 1);

  // Trim silence, keeping some padding.
  final threshold = loudest * _fromDb(_recordingSilenceDb);
  final first = rms.indexWhere((r) => r >= threshold);
  final last = rms.lastIndexWhere((r) => r >= threshold);
  final pad = (_recordingPaddingSec * rate).round();
  final start = math.max(0, first * frame - pad);
  final end = math.min(x.length, (last + 1) * frame + pad);
  x = Float32List.fromList(Float32List.sublistView(x, start, end));

  x = highPass(x, rate, recordingHighPassHz);

  // Speech level: 75th percentile of frame RMS over the non-silent frames.
  rms = _frameRms(x, frame)..removeWhere((r) => r < threshold);
  if (rms.isEmpty) return PcmWav(Float32List(x.length), rate, 1);
  rms.sort();
  final level = rms[((rms.length - 1) * 0.75).round()];
  if (level < 1e-6) return PcmWav(Float32List(x.length), rate, 1);
  final gainDb = math.min(
    recordingMaxGainDb,
    recordingTargetRmsDb - 20 * math.log(level) / math.ln10,
  );
  final gain = _fromDb(gainDb);
  for (var i = 0; i < x.length; i++) {
    x[i] *= gain;
  }
  return PcmWav(limitPeaks(x, sampleRate: rate), rate, 1);
}

/// WAV bytes in, prepared WAV bytes out; null if [bytes] is not 16-bit PCM
/// WAV. Top-level so it can run in `Isolate.run`.
Uint8List? prepareRecordingBytes(Uint8List bytes) {
  final wav = readPcm16Wav(bytes);
  if (wav == null) return null;
  return writePcm16Wav(prepareRecording(wav));
}

Float32List _toMono(PcmWav wav) {
  if (wav.channels == 1) return wav.samples;
  final n = wav.samples.length ~/ wav.channels;
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    var sum = 0.0;
    for (var c = 0; c < wav.channels; c++) {
      sum += wav.samples[i * wav.channels + c];
    }
    out[i] = sum / wav.channels;
  }
  return out;
}

/// RMS of each full or partial [frame]-sample frame.
List<double> _frameRms(Float32List x, int frame) {
  final out = <double>[];
  for (var s = 0; s < x.length; s += frame) {
    final e = math.min(x.length, s + frame);
    var sum = 0.0;
    for (var i = s; i < e; i++) {
      sum += x[i] * x[i];
    }
    out.add(math.sqrt(sum / (e - s)));
  }
  return out;
}

/// 16-bit PCM WAV contents.
class PcmWav {
  PcmWav(this.samples, this.sampleRate, this.channels);
  final Float32List samples;
  final int sampleRate;
  final int channels;
}

/// Parses a 16-bit PCM WAV, or returns null if it is anything else.
PcmWav? readPcm16Wav(Uint8List bytes) {
  if (bytes.length < 12) return null;
  final d = ByteData.sublistView(bytes);
  String tag(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
  int? rate, channels;
  var pos = 12;
  while (pos + 8 <= bytes.length) {
    final id = tag(pos);
    var size = d.getUint32(pos + 4, Endian.little);
    final body = pos + 8;
    if (id == 'fmt ') {
      if (body + 16 > bytes.length) return null;
      final format = d.getUint16(body, Endian.little);
      final bits = d.getUint16(body + 14, Endian.little);
      if (format != 1 || bits != 16) return null;
      channels = d.getUint16(body + 2, Endian.little);
      rate = d.getUint32(body + 4, Endian.little);
    } else if (id == 'data') {
      if (rate == null || channels == null || channels < 1) return null;
      // Streamed files may carry a bogus size: clamp to what is there.
      if (size > bytes.length - body) size = bytes.length - body;
      final n = size ~/ 2;
      final s = Float32List(n);
      for (var i = 0; i < n; i++) {
        s[i] = d.getInt16(body + i * 2, Endian.little) / 32768;
      }
      return PcmWav(s, rate, channels);
    }
    pos = body + size + (size.isOdd ? 1 : 0);
  }
  return null;
}

/// Encodes [wav] as a canonical 44-byte-header 16-bit PCM WAV.
Uint8List writePcm16Wav(PcmWav wav) {
  final n = wav.samples.length;
  final out = Uint8List(44 + n * 2);
  final d = ByteData.sublistView(out);
  void tag(int o, String t) => out.setRange(o, o + 4, t.codeUnits);
  tag(0, 'RIFF');
  d.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, wav.channels, Endian.little);
  d.setUint32(24, wav.sampleRate, Endian.little);
  d.setUint32(28, wav.sampleRate * wav.channels * 2, Endian.little);
  d.setUint16(32, wav.channels * 2, Endian.little);
  d.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  d.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = (wav.samples[i] * 32767).round().clamp(-32768, 32767);
    d.setInt16(44 + i * 2, v, Endian.little);
  }
  return out;
}

/// Boosts the WAV file at [path] in place. A file that isn't 16-bit PCM WAV
/// is left unchanged. Returns whether the file was changed.
bool boostWavFile(String path) {
  try {
    final file = File(path);
    final wav = readPcm16Wav(file.readAsBytesSync());
    if (wav == null) return false;
    file.writeAsBytesSync(
      writePcm16Wav(
        PcmWav(
          boostLoudness(wav.samples, sampleRate: wav.sampleRate),
          wav.sampleRate,
          wav.channels,
        ),
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
