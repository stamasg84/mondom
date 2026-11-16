import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../speech/voice_recorder.dart' as platform;
import '../voices/catalog.dart';
import 'app_theme.dart';
import 'speak_glyph.dart';

const projectUrl = 'https://github.com/stamasg84/mondom';
const privacyUrl = 'https://github.com/stamasg84/mondom/blob/main/PRIVACY.md';

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
    final scheme = Theme.of(context).colorScheme;
    const body = TextStyle(fontSize: 18);
    final muted = TextStyle(fontSize: 16, color: scheme.onSurfaceVariant);
    final sizes = _sizes;
    final voices = widget.catalog.voices;
    Widget line(String text, {TextStyle style = body}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(text, style: style),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                SpeakGlyph(size: 56, color: scheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_version != null)
                        Text(
                          l10n.aboutVersion(_version!),
                          style: muted.copyWith(fontSize: 17),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.aboutTagline, style: body),
            const SizedBox(height: 16),
            _Card(
              children: [
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
              ],
            ),
            for (final url in _failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(l10n.aboutLinkFailed), SelectableText(url)],
                ),
              ),
            _Heading(l10n.aboutVoices),
            _Card(
              children: [
                for (final v in voices) ...[
                  Row(
                    children: [
                      Expanded(
                        child: line(l10n.aboutVoiceLine(v.label, v.license)),
                      ),
                      if (v.modelCardUrl case final url?)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: TextButton(
                            onPressed: () => _open(url),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.aboutModelCard,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (v.id == 'sv_SE-alma-medium')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: line(l10n.aboutAlmaCredit, style: muted),
                    ),
                ],
                line(l10n.aboutSystemVoiceLine),
              ],
            ),
            _Heading(l10n.aboutSoftware),
            _Card(
              children: [
                for (final s in const [
                  'sherpa-onnx (Apache-2.0)',
                  'Piper (MIT)',
                  'espeak-ng (GPL-3.0)',
                  'Flutter (BSD-3-Clause)',
                  'record (BSD-3-Clause)',
                  'flutter_secure_storage (BSD-3-Clause)',
                ])
                  line(s),
                _LinkRow(
                  icon: Icons.description_outlined,
                  label: l10n.aboutAllLicenses,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: l10n.appTitle,
                    applicationVersion: _version,
                  ),
                ),
              ],
            ),
            _Heading(l10n.aboutStorage),
            _Card(
              children: [
                line(
                  '${l10n.aboutRecordings}: ${_mb(l10n, sizes?.recordings)}',
                ),
                line(
                  '${l10n.aboutDownloadedVoices}: ${_mb(l10n, sizes?.voices)}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l10n.aboutTrademark, style: muted.copyWith(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    ),
  );
}

/// A white bordered card, as on the list screens, holding a section's rows.
class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: kBorderRadius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
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
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
