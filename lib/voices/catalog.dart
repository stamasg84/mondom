import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'voice.dart';

/// The only place the remote catalog URL lives.
const catalogUrl =
    'https://raw.githubusercontent.com/stamasg84/mondom/main/voices/catalog.json';

const bundledCatalogAsset = 'assets/catalog.json';

const supportedSchemaVersion = 1;

/// One downloadable Piper voice from the catalog.
class CatalogVoice {
  const CatalogVoice({
    required this.id,
    required this.language,
    required this.gender,
    required this.label,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    required this.modelFile,
    required this.sampleUrl,
    required this.license,
    required this.minAppVersion,
    this.modelCardUrl,
  });

  final String id;
  final String language;
  final VoiceGender gender;
  final String label;
  final String url;
  final int sizeBytes;
  final String sha256;
  final String modelFile;
  final String sampleUrl;
  final String license;
  final String minAppVersion;

  /// The voice's model card, linked from About (e.g. where the license
  /// asks for credit to the training data).
  final String? modelCardUrl;

  factory CatalogVoice.fromJson(Map<String, dynamic> j) => CatalogVoice(
    id: j['id'] as String,
    language: j['language'] as String,
    gender: VoiceGender.values.firstWhere(
      (g) => g.name == j['gender'],
      orElse: () => VoiceGender.unknown,
    ),
    label: j['label'] as String,
    url: j['url'] as String,
    sizeBytes: j['sizeBytes'] as int,
    sha256: (j['sha256'] as String).toLowerCase(),
    modelFile: j['modelFile'] as String,
    sampleUrl: j['sampleUrl'] as String,
    license: j['license'] as String,
    minAppVersion: j['minAppVersion'] as String? ?? '0.0.0',
    modelCardUrl: j['modelCardUrl'] as String?,
  );

  Voice toVoice() => Voice(
    id: id,
    languageCode: language,
    gender: gender,
    label: label,
    kind: VoiceKind.piper,
  );
}

class Catalog {
  const Catalog({
    required this.voices,
    required this.sampleText,
    this.isBundled = false,
  });

  final List<CatalogVoice> voices;

  /// True when the remote fetch failed and the bundled copy is used.
  final bool isBundled;

  /// Sample sentence per language code (also spoken live for the system voice).
  final Map<String, String> sampleText;

  static const empty = Catalog(voices: [], sampleText: {});

  /// Parses catalog JSON. Returns null for an unknown `schemaVersion` or
  /// malformed JSON. Entries that are malformed or need a newer app than
  /// [appVersion] are dropped.
  static Catalog? parse(String source, {required String appVersion}) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      if (json['schemaVersion'] != supportedSchemaVersion) return null;
      final voices = <CatalogVoice>[];
      for (final raw in json['voices'] as List<dynamic>) {
        try {
          final v = CatalogVoice.fromJson(raw as Map<String, dynamic>);
          if (compareVersions(v.minAppVersion, appVersion) <= 0) voices.add(v);
        } catch (_) {
          // Skip one broken entry, keep the rest.
        }
      }
      final text = (json['sampleText'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, v as String),
      );
      return Catalog(voices: voices, sampleText: text);
    } catch (_) {
      return null;
    }
  }

  List<CatalogVoice> forLanguage(String code) =>
      voices.where((v) => v.language == code).toList();

  CatalogVoice? byId(String id) {
    for (final v in voices) {
      if (v.id == id) return v;
    }
    return null;
  }
}

/// Compares dotted versions ("1.2.0" vs "1.10"); ignores a "+build" suffix.
int compareVersions(String a, String b) {
  List<int> parts(String s) =>
      s.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Loads the remote catalog, silently falling back to the bundled copy.
class CatalogRepository {
  CatalogRepository({
    required this.appVersion,
    http.Client? client,
    this.url = catalogUrl,
    this.timeout = const Duration(seconds: 5),
    Future<String> Function()? loadBundled,
  }) : _client = client ?? http.Client(),
       _loadBundled =
           loadBundled ?? (() => rootBundle.loadString(bundledCatalogAsset));

  final String appVersion;
  final String url;
  final Duration timeout;
  final http.Client _client;
  final Future<String> Function() _loadBundled;

  Future<Catalog> load() async {
    try {
      final res = await _client.get(Uri.parse(url)).timeout(timeout);
      if (res.statusCode == 200) {
        final catalog = Catalog.parse(
          utf8.decode(res.bodyBytes),
          appVersion: appVersion,
        );
        if (catalog != null) return catalog;
      }
    } catch (e) {
      debugPrint('Remote catalog unavailable, using bundled copy: $e');
    }
    final bundled = Catalog.parse(await _loadBundled(), appVersion: appVersion);
    if (bundled == null) return Catalog.empty;
    return Catalog(
      voices: bundled.voices,
      sampleText: bundled.sampleText,
      isBundled: true,
    );
  }
}
