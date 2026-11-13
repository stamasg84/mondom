import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mondom/speech/loudness.dart';
import 'package:mondom/voices/elevenlabs_client.dart';
import 'package:mondom/voices/elevenlabs_key_store.dart';

const _key = 'sk_test_SECRET_KEY_123';

ElevenLabsClient _client(MockClient m, {Duration? timeout}) =>
    ElevenLabsClient(m, _key, timeout: timeout ?? const Duration(seconds: 1));

http.Response _json(int code, Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), code,
    headers: {'content-type': 'application/json'});

Future<ElevenLabsException> _fails(Future<Object?> f) async {
  try {
    await f;
  } on ElevenLabsException catch (e) {
    return e;
  }
  fail('expected ElevenLabsException');
}

void main() {
  test('listVoices: short names, own voices first, each group by name',
      () async {
    final c = _client(MockClient((req) async {
      expect(req.url.path, '/v2/voices');
      expect(req.url.queryParameters['page_size'], '100');
      expect(req.headers['xi-api-key'], _key);
      return _json(200, {
        'voices': [
          {
            'voice_id': 'b',
            'name': 'Brian - Deep, Resonant',
            'category': 'premade'
          },
          {'voice_id': 'z', 'name': 'Zsolt', 'category': 'professional'},
          {'voice_id': 'a', 'name': 'Alice - Clear', 'category': 'premade'},
          {'voice_id': 'm', 'name': 'Máté - my clone', 'category': 'cloned'},
        ]
      });
    }));
    final v = await c.listVoices();
    expect(v.map((e) => e.name), ['Máté', 'Zsolt', 'Alice', 'Brian']);
    expect(v.map((e) => e.id), ['m', 'z', 'a', 'b']);
    expect(v.map((e) => e.own), [true, true, false, false]);
  });

  test('synthesize sends key, UTF-8 JSON body, pcm_22050; returns WAV',
      () async {
    final pcm = Uint8List(2000); // 1000 samples
    for (var i = 0; i < 1000; i++) {
      ByteData.sublistView(pcm).setInt16(i * 2, i * 10, Endian.little);
    }
    final c = _client(MockClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/v1/text-to-speech/voice1');
      expect(req.url.queryParameters['output_format'], 'pcm_22050');
      expect(req.headers['xi-api-key'], _key);
      final body = jsonDecode(utf8.decode(req.bodyBytes)) as Map;
      expect(body['text'], 'Kérek vizet, légyszi!');
      expect(body['model_id'], 'eleven_flash_v2_5');
      expect(body['language_code'], 'hu');
      return http.Response.bytes(pcm, 200,
          headers: {'content-type': 'audio/pcm'});
    }));
    final wav = await c.synthesize(
        'Kérek vizet, légyszi!', 'voice1', 'eleven_flash_v2_5', 'hu');
    final parsed = readPcm16Wav(wav)!;
    expect(parsed.sampleRate, 22050);
    expect(parsed.channels, 1);
    expect(parsed.samples.length, 1000);
    expect(parsed.samples[100], closeTo(1000 / 32768, 1e-6));
  });

  test('subscription parses, and is null without the User permission',
      () async {
    final ok = _client(MockClient((req) async {
      expect(req.url.path, '/v1/user/subscription');
      return _json(200, {
        'tier': 'free',
        'character_count': 88,
        'character_limit': 10000,
        'next_character_count_reset_unix': 1800000000,
      });
    }));
    final s = (await ok.subscription())!;
    expect(s.used, 88);
    expect(s.limit, 10000);
    expect(s.resetsAt!.millisecondsSinceEpoch, 1800000000 * 1000);

    final noPerm = _client(MockClient((_) async => _json(401, {
          'detail': {
            'status': 'missing_permissions',
            'message': 'The API key you used is missing the permission user_read'
          }
        })));
    expect(await noPerm.subscription(), isNull);
  });

  Future<ElevenLabsFailure> reasonFor(int code, Object body) async {
    final c = _client(MockClient((_) async => _json(code, body)));
    return (await _fails(c.synthesize('x', 'v', 'm', 'hu'))).reason;
  }

  test('errors map to reasons', () async {
    expect(
        await reasonFor(401, {
          'detail': {'status': 'invalid_api_key', 'message': 'Invalid API key'}
        }),
        ElevenLabsFailure.badKey);
    expect(
        await reasonFor(401, {
          'detail': {'status': 'missing_permissions', 'message': 'missing'}
        }),
        ElevenLabsFailure.missingPermission);
    expect(
        await reasonFor(402, {
          'detail': {
            'status': 'paid_plan_required',
            'message': 'Free users cannot use library voices via the API.'
          }
        }),
        ElevenLabsFailure.voiceNotAllowed);
    expect(
        await reasonFor(402, {
          'detail': {'status': 'quota_exceeded', 'message': 'out of credits'}
        }),
        ElevenLabsFailure.quota);
    expect(await reasonFor(402, {'oops': 1}), ElevenLabsFailure.quota);
    expect(
        await reasonFor(400, {
          'detail': {
            'status': 'unsupported_language',
            'message': 'Model does not support the language code hu'
          }
        }),
        ElevenLabsFailure.unsupportedLanguage);
    expect(await reasonFor(503, {'detail': 'busy'}), ElevenLabsFailure.server);
    expect(await reasonFor(418, {'x': 1}), ElevenLabsFailure.server);
  });

  test('timeout and network errors are offline', () async {
    final slow = _client(MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 50));
    expect((await _fails(slow.listVoices())).reason, ElevenLabsFailure.offline);

    final dns =
        _client(MockClient((_) async => throw const SocketException('x')));
    expect((await _fails(dns.listVoices())).reason, ElevenLabsFailure.offline);

    final ce =
        _client(MockClient((_) async => throw http.ClientException('x')));
    expect((await _fails(ce.synthesize('x', 'v', 'm', 'hu'))).reason,
        ElevenLabsFailure.offline);
  });

  test('the key never appears in exception text', () async {
    final clients = [
      _client(MockClient((_) async => _json(401, {
            'detail': {'status': 'invalid_api_key', 'message': 'bad $_key'}
          }))),
      _client(
          MockClient((_) async => throw SocketException('failed for $_key'))),
      _client(MockClient((_) async => http.Response('not json $_key', 500))),
    ];
    for (final c in clients) {
      final e = await _fails(c.synthesize('x', 'v', 'm', 'hu'));
      expect(e.toString(), isNot(contains(_key)));
      expect(e.toString(), isNot(contains('SECRET')));
    }
  });

  test('in-memory key store', () async {
    final s = InMemoryElevenLabsKeyStore();
    expect(await s.read(), isNull);
    await s.write('k');
    expect(await s.read(), 'k');
    await s.clear();
    expect(await s.read(), isNull);
  });
}
