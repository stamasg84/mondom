import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../speech/voice_recorder.dart' as platform;
import '../voices/catalog.dart';

const projectUrl = 'https://github.com/stamasg84/mondom';
const privacyUrl = 'https://github.com/stamasg84/mondom/blob/main/PRIVACY.md';
const almaModelCardUrl =
    'https://huggingface.co/rhasspy/piper-voices/blob/main/sv/sv_SE/alma/'
    'medium/MODEL_CARD';

/// Sizes in bytes of the app's own recordings and the downloaded voices.
typedef StorageSizes = ({int recordings, int voices});

/// Total size of the files under [path] (0 when it doesn't exist).
int directorySize(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return 0;
  var total = 0;
  for (final e in dir.listSync(recursive: true, followLinks: false)) {
    if (e is File) total += e.lengthSync();
  }
  return total;
}

Future<StorageSizes> defaultStorageSizes() async {
  final support = (await getApplicationSupportDirectory()).path;
  return Isolate.run(
    () => (
      recordings: directorySize('$support/recordings'),
      voices: directorySize('$support/voices'),
    ),
  );
}

Future<String> defaultVersion() async =>
    (await PackageInfo.fromPlatform()).version;

/// Version, links, voice credits, software licenses and storage use.
class AboutScreen extends StatefulWidget {
  const AboutScreen({
    super.key,
    required this.catalog,
    this.openUrl = platform.openUrl,
    this.loadSizes = defaultStorageSizes,
    this.loadVersion = defaultVersion,
  });

  final Catalog catalog;

  /// Opens a URL in the browser; false when nothing can (tests fake it).
  final Future<bool> Function(String url) openUrl;
  final Future<StorageSizes> Function() loadSizes;
  final Future<String> Function() loadVersion;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _version;
  StorageSizes? _sizes;

  /// URLs that couldn't be opened, shown as selectable text.
  final _failed = <String>[];

  @override
  void initState() {
    super.initState();
    widget
        .loadVersion()
        .then((v) {
          if (mounted) setState(() => _version = v);
        })
        // No version line when it can't be read.
        .catchError((_) {});
    widget
        .loadSizes()
        .then((s) {
          if (mounted) setState(() => _sizes = s);
        })
        // Unreadable storage: the sizes simply stay "…".
        .catchError((_) {});
  }

  Future<void> _open(String url) async {
    final ok = await widget.openUrl(url);
    if (!ok && mounted && !_failed.contains(url)) {
      setState(() => _failed.add(url));
    }
  }

  String _mb(AppLocalizations l10n, int? bytes) => bytes == null
      ? '…'
      : l10n.aboutMegabytes((bytes / (1024 * 1024)).toStringAsFixed(1));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final header = theme.textTheme.titleLarge;
    const body = TextStyle(fontSize: 18);
    final sizes = _sizes;
    final voices = widget.catalog.voices;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
            if (_version != null)
              Text(l10n.aboutVersion(_version!), style: body),
            const SizedBox(height: 8),
            Text(l10n.aboutTagline, style: body),
            const SizedBox(height: 8),
            _LinkRow(
              icon: Icons.code,
              label: l10n.aboutGithub,
              onTap: () => _open(projectUrl),
            ),
            _LinkRow(
              icon: Icons.privacy_tip_outlined,
              label: l10n.aboutPrivacy,
              onTap: () => _open(privacyUrl),
            ),
            for (final url in _failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(l10n.aboutLinkFailed), SelectableText(url)],
                ),
              ),
            const SizedBox(height: 16),
            Text(l10n.aboutVoices, style: header),
            const SizedBox(height: 4),
            for (final v in voices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  l10n.aboutVoiceLine(v.label, v.license),
                  style: body,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l10n.aboutSystemVoiceLine, style: body),
            ),
            if (voices.any((v) => v.id == 'sv_SE-alma-medium')) ...[
              const SizedBox(height: 8),
              Text(l10n.aboutAlmaCredit, style: body),
              _LinkRow(
                icon: Icons.open_in_new,
                label: l10n.aboutModelCard,
                onTap: () => _open(almaModelCardUrl),
              ),
            ],
            const SizedBox(height: 16),
            Text(l10n.aboutSoftware, style: header),
            const SizedBox(height: 4),
            for (final s in const [
              'sherpa-onnx (Apache-2.0)',
              'Piper (MIT)',
              'espeak-ng (GPL-3.0)',
              'Flutter (BSD-3-Clause)',
              'record (BSD-3-Clause)',
              'flutter_secure_storage (BSD-3-Clause)',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(s, style: body),
              ),
            _LinkRow(
              icon: Icons.description_outlined,
              label: l10n.aboutAllLicenses,
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: _version,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.aboutStorage, style: header),
            const SizedBox(height: 4),
            Text(
              '${l10n.aboutRecordings}: ${_mb(l10n, sizes?.recordings)}',
              style: body,
            ),
            Text(
              '${l10n.aboutDownloadedVoices}: ${_mb(l10n, sizes?.voices)}',
              style: body,
            ),
            const SizedBox(height: 24),
            Text(l10n.aboutTrademark, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  color: color,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
