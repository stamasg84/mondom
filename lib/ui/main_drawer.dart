import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../speech/alarm_volume.dart';
import '../speech/speaker.dart';
import '../speech/voice_recorder.dart';
import '../storage/lists_repository.dart';
import '../voices/language_names.dart';
import '../voices/voice.dart';
import 'lists_screen.dart';
import 'settings_screen.dart';

/// The speaking screen's menu: a plain list of large rows. Editing lives
/// behind it, never on the speaking screen itself. Opened only by the app bar
/// button (no edge swipe).
class MainDrawer extends StatelessWidget {
  const MainDrawer({
    super.key,
    required this.repo,
    required this.voice,
    required this.onOpenVoicePicker,
    required this.currentListId,
    required this.alarmVolume,
    required this.speaker,
    required this.recorderFactory,
  });

  final VoiceRecorder Function() recorderFactory;
  final AlarmVolume alarmVolume;
  final Speaker speaker;

  final ListsRepository repo;

  /// The active voice, read each time the drawer is built (i.e. opened).
  final Voice Function() voice;
  final Future<void> Function() onOpenVoicePicker;

  /// The list open on the speaking screen, if any.
  final int? Function() currentListId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ui = Localizations.localeOf(context).languageCode;
    final v = voice();
    final voiceName = v.kind == VoiceKind.system ? l10n.systemVoice : v.label;
    // Close the drawer first, then push, so back returns to the speaking
    // screen and not to an open drawer.
    final navigator = Navigator.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            _DrawerRow(
              icon: Icons.list_alt,
              title: l10n.settingsListsTitle,
              subtitle: l10n.settingsListsSubtitle,
              onTap: () {
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => ListsScreen(
                      repo: repo,
                      currentListId: currentListId(),
                      speechLanguage: () => voice().languageCode,
                      speaker: speaker,
                      recorderFactory: recorderFactory,
                    ),
                  ),
                );
              },
            ),
            _DrawerRow(
              icon: Icons.tune,
              title: l10n.settingsTitle,
              subtitle: l10n.settingsSubtitle,
              onTap: () {
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(
                      alarmVolume: alarmVolume,
                      speaker: speaker,
                    ),
                  ),
                );
              },
            ),
            _DrawerRow(
              icon: Icons.record_voice_over,
              title: l10n.settingsVoiceTitle,
              subtitle: l10n.settingsVoiceSubtitle(
                voiceName,
                languageName(v.languageCode, ui),
              ),
              onTap: () {
                navigator.pop();
                onOpenVoicePicker();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
