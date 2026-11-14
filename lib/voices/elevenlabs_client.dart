import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Hard limit for one synthesis request; after it the fallback voice speaks.
const elevenLabsTimeout = Duration(seconds: 4);

/// The languages of `eleven_flash_v2_5`; the picker offers ElevenLabs voices
/// only for these (see the architecture doc).
const elevenLabsLanguages = {
  'en', 'ja', 'zh', 'de', 'hi', 'fr', 'ko', 'pt', 'it', 'es', 'id', 'nl', //
  'tr', 'fil', 'pl', 'sv', 'bg', 'ro', 'ar', 'cs', 'el', 'fi', 'hr', 'ms',
  'sk', 'da', 'ta', 'uk', 'ru', 'hu', 'no', 'vi',
};

const _base = 'https://api.elevenlabs.io';
const _sampleRate = 22050;

class ElevenLabsVoice {
  const ElevenLabsVoice(this.id, this.name, {this.own = false});
  final String id;

  /// The API name before " - " ("Brian - Deep, Resonant..." -> "Brian").
  final String name;

  /// Not a `premade` voice (clone, designed, added from the library).
  final bool own;
}

class ElevenLabsSubscription {
  const ElevenLabsSubscription(this.used, this.limit, this.resetsAt);
  final int used;
  final int limit;
  final DateTime? resetsAt;
}

enum ElevenLabsFailure {
  offline,
  badKey,
  missingPermission,
  quota,
  unsupportedLanguage,
  voiceNotAllowed,
  server,
}

/// The only exception the client throws. Its text never contains the key.
class ElevenLabsException implements Exception {
  const ElevenLabsException(this.reason, [this.status]);
  final ElevenLabsFailure reason;

  /// The API's `detail.status` string, if any.
  final String? status;

  @override
  String toString() =>
      'ElevenLabsException(${reason.name}'
      '${status == null ? '' : ', $status'})';
}

class ElevenLabsClient {
  ElevenLabsClient(this._http, this._key, {this.timeout = elevenLabsTimeout});
  final http.Client _http;
  final String _key;
  final Duration timeout;

  /// Releases the underlying HTTP client.
  void close() => _http.close();

  Map<String, String> get _headers => {'xi-api-key': _key};

  Future<List<ElevenLabsVoice>> listVoices() async {
    final res = await _send(
      () => _http.get(
        Uri.parse('$_base/v2/voices?page_size=100'),
        headers: _headers,
      ),
    );
    final List raw;
    try {
      raw = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['voices'] as List;
    } catch (_) {
      throw const ElevenLabsException(ElevenLabsFailure.server);
    }
    final voices = <ElevenLabsVoice>[];
    for (final v in raw) {
      if (v is! Map || v['voice_id'] is! String) continue;
      final full = (v['name'] as String?) ?? '';
      final i = full.indexOf(' - ');
      final name = (i < 0 ? full : full.substring(0, i)).trim();
      voices.add(
        ElevenLabsVoice(
          v['voice_id'] as String,
          name,
          own: v['category'] != 'premade',
        ),
      );
    }
    int byName(ElevenLabsVoice a, ElevenLabsVoice b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return [
      ...voices.where((v) => v.own).toList()..sort(byName),
      ...voices.where((v) => !v.own).toList()..sort(byName),
    ];
  }

  /// A 16-bit mono 22050 Hz WAV.
  Future<Uint8List> synthesize(
    String text,
    String voiceId,
    String modelId,
    String languageCode, {
    double? speed,
  }) async {
    final res = await _send(
      () => _http.post(
        Uri.parse(
          '$_base/v1/text-to-speech/${Uri.encodeComponent(voiceId)}'
          '?output_format=pcm_$_sampleRate',
        ),
        headers: {
          ..._headers,
          'content-type': 'application/json; charset=utf-8',
        },
        body: utf8.encode(
          jsonEncode({
            'text': text,
            'model_id': modelId,
            'language_code': languageCode,
            if (speed != null) 'voice_settings': {'speed': speed},
          }),
        ),
      ),
    );
    final pcm = res.bodyBytes;
    if (pcm.length < 2) {
      throw const ElevenLabsException(ElevenLabsFailure.server);
    }
    return _wrapPcm(pcm.length.isOdd ? pcm.sublist(0, pcm.length - 1) : pcm);
  }

  /// Null when the key lacks the optional "User" permission.
  Future<ElevenLabsSubscription?> subscription() async {
    try {
      final res = await _send(
        () => _http.get(
          Uri.parse('$_base/v1/user/subscription'),
          headers: _headers,
        ),
      );
      final m = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      final reset = m['next_character_count_reset_unix'];
      return ElevenLabsSubscription(
        (m['character_count'] as num).toInt(),
        (m['character_limit'] as num).toInt(),
        reset is num
            ? DateTime.fromMillisecondsSinceEpoch(reset.toInt() * 1000)
            : null,
      );
    } on ElevenLabsException catch (e) {
      if (e.reason == ElevenLabsFailure.missingPermission) return null;
      rethrow;
    } catch (_) {
      throw const ElevenLabsException(ElevenLabsFailure.server);
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request().timeout(timeout);
    } on TimeoutException {
      throw const ElevenLabsException(ElevenLabsFailure.offline);
    } on SocketException {
      throw const ElevenLabsException(ElevenLabsFailure.offline);
    } on http.ClientException {
      throw const ElevenLabsException(ElevenLabsFailure.offline);
    } on HandshakeException {
      throw const ElevenLabsException(ElevenLabsFailure.offline);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    throw _failure(res);
  }

  ElevenLabsException _failure(http.Response res) {
    // The API isn't consistent about where the reason goes: some errors put
    // it in `detail.status`, others in `detail.code` (e.g. a library voice on
    // the free plan: code `paid_plan_required`, status `payment_required`).
    String? status;
    String? errCode;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final detail = body is Map ? body['detail'] : null;
      if (detail is Map) {
        if (detail['status'] is String) status = detail['status'] as String;
        if (detail['code'] is String) errCode = detail['code'] as String;
      }
    } catch (_) {}
    bool says(String s) => status == s || errCode == s;
    final code = res.statusCode;
    final ElevenLabsFailure reason;
    if (says('missing_permissions')) {
      reason = ElevenLabsFailure.missingPermission;
    } else if (says('paid_plan_required')) {
      reason = ElevenLabsFailure.voiceNotAllowed;
    } else if (says('quota_exceeded')) {
      // Only when the API says so: an unrecognised 402 is reported as an
      // unknown failure, not as "out of credit".
      reason = ElevenLabsFailure.quota;
    } else if (says('unsupported_language')) {
      reason = ElevenLabsFailure.unsupportedLanguage;
    } else if (code == 401) {
      reason = ElevenLabsFailure.badKey;
    } else {
      reason = ElevenLabsFailure.server;
    }
    return ElevenLabsException(reason, status);
  }
}

Uint8List _wrapPcm(Uint8List pcm) {
  final out = Uint8List(44 + pcm.length);
  final d = ByteData.sublistView(out);
  void tag(int o, String t) => out.setRange(o, o + 4, t.codeUnits);
  tag(0, 'RIFF');
  d.setUint32(4, 36 + pcm.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, 1, Endian.little);
  d.setUint32(24, _sampleRate, Endian.little);
  d.setUint32(28, _sampleRate * 2, Endian.little);
  d.setUint16(32, 2, Endian.little);
  d.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  d.setUint32(40, pcm.length, Endian.little);
  out.setRange(44, out.length, pcm);
  return out;
}
