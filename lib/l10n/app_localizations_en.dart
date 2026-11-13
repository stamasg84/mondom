// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mondom';

  @override
  String get textHint => 'Type here…';

  @override
  String get loading => 'Loading…';

  @override
  String get speak => 'Speak';

  @override
  String get clearText => 'Clear text';

  @override
  String get replayed => 'Replayed (no synthesis)';

  @override
  String modelLoadTime(int ms) {
    return 'Model load: $ms ms';
  }

  @override
  String synthesisStats(int synthMs, int audioMs, String rtf) {
    return 'Synthesis: $synthMs ms, audio: $audioMs ms, RTF: $rtf';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get stopAlarm => 'Stop';

  @override
  String get voicePickerTitle => 'Choose a voice';

  @override
  String languageSelectorLabel(String name) {
    return 'Language: $name';
  }

  @override
  String installedVoicesCount(int count) {
    return '$count downloaded';
  }

  @override
  String get systemVoiceMissing => 'The voice isn\'t downloaded on this phone.';

  @override
  String get downloadInAndroidSettings => 'Download in Android settings';

  @override
  String get systemVoiceUnsupported => 'This phone can\'t speak this language.';

  @override
  String get systemVoice => 'Android default';

  @override
  String get systemVoiceInfo => 'Works right away, even offline';

  @override
  String get download => 'Download';

  @override
  String get select => 'Select';

  @override
  String get selected => 'Selected';

  @override
  String get deleteVoice => 'Delete voice';

  @override
  String get playSample => 'Play sample';

  @override
  String get sampleUnavailable => 'The sample is not available';

  @override
  String get downloadsNeedInternet =>
      'Downloading voices needs internet. The Android default voice works offline.';

  @override
  String get downloadFailed =>
      'The download failed. Check your internet connection.';

  @override
  String get genderMale => 'male';

  @override
  String get genderFemale => 'female';

  @override
  String voiceSizeMb(int mb) {
    return '$mb MB';
  }

  @override
  String get installing => 'Installing… (this can take a while)';

  @override
  String get historyTitle => 'History';

  @override
  String get allLists => 'All lists';

  @override
  String get emptyListHint => 'This list is empty. To edit: ☰ Menu → Lists';

  @override
  String get menuTooltip => 'Menu';

  @override
  String get settingsVoiceTitle => 'Voice and language';

  @override
  String settingsVoiceSubtitle(String voice, String language) {
    return '$voice · $language';
  }

  @override
  String get settingsListsTitle => 'Lists';

  @override
  String get settingsListsSubtitle => 'Edit lists and sentences';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Louder speech, alarm volume';

  @override
  String get settingsSpeechSection => 'Speech';

  @override
  String get settingsBoostTitle => 'Louder speech';

  @override
  String get settingsBoostHelp =>
      'Makes speech louder. Turn off if it sounds distorted.';

  @override
  String get settingsAlarmSection => 'Alarm';

  @override
  String get alarmVolumeSystem => 'The phone\'s alarm volume';

  @override
  String get alarmVolumeCustom => 'Own volume';

  @override
  String get alarmVolumeTest => 'Try it';

  @override
  String get pinnedLabel => 'Pinned';

  @override
  String sentenceCount(int count) {
    return '$count sentences';
  }

  @override
  String get currentlyOpen => 'Currently open';

  @override
  String get reorderHandle => 'Move';

  @override
  String get moreActions => 'More actions';

  @override
  String get renameList => 'Rename';

  @override
  String get pinList => 'Pin';

  @override
  String get unpinList => 'Unpin';

  @override
  String get deleteList => 'Delete';

  @override
  String deleteListQuestion(String title, int count) {
    return 'Delete the list “$title” and its $count sentences?';
  }

  @override
  String get deleteAction => 'Delete';

  @override
  String get saveAction => 'Save';

  @override
  String get newList => 'New list';

  @override
  String get listNameLabel => 'List name';

  @override
  String get kindEveryday => 'Sentence list';

  @override
  String get kindConversation => 'Conversation';

  @override
  String get kindConversationInfo =>
      'Sentences written ahead, with a Next button';

  @override
  String get createAction => 'Create';

  @override
  String get restoreDefaultLists => 'Restore default lists';

  @override
  String addSeedListsQuestion(String language) {
    return 'Add the default $language lists?';
  }

  @override
  String get addAction => 'Add';

  @override
  String get noAction => 'No';

  @override
  String get newLinesLabel => 'New line(s)';

  @override
  String get newLinesHint => 'One sentence per line';

  @override
  String get copyToList => 'Copy to list…';

  @override
  String get alarmToggle => 'Play as an alarm (loud)';

  @override
  String get alarmToggleHelp =>
      'Plays at the alarm volume and is not added to history.';

  @override
  String get moveToList => 'Move to list…';

  @override
  String get chooseListTitle => 'Which list?';

  @override
  String get editSentenceTitle => 'Edit sentence';

  @override
  String get sentenceDeleted => 'Sentence deleted';

  @override
  String get undoAction => 'Undo';

  @override
  String get restoreDefaultSentences => 'Restore default sentences';

  @override
  String get resetSaid => 'Start over';

  @override
  String restoredSentences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sentences restored',
      one: '$count sentence restored',
    );
    return '$_temp0';
  }

  @override
  String restoredLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lists restored',
      one: '$count list restored',
    );
    return '$_temp0';
  }

  @override
  String get resetSaidQuestion =>
      'Start over: all sentences will be unsaid again. Continue?';

  @override
  String get emptyEditorList => 'No sentences yet. Write below, one per line.';

  @override
  String get listColorLabel => 'Color';

  @override
  String get listColorNone => 'None';

  @override
  String get listColorDialogTitle => 'List color';

  @override
  String get colorName_blue => 'blue';

  @override
  String get colorName_green => 'green';

  @override
  String get colorName_orange => 'orange';

  @override
  String get colorName_purple => 'purple';

  @override
  String get colorName_teal => 'teal';

  @override
  String get colorName_pink => 'pink';

  @override
  String get colorName_yellow => 'yellow';

  @override
  String get colorName_brown => 'brown';

  @override
  String get colorSelected => 'selected';

  @override
  String get nextSentence => 'Next';

  @override
  String get allSaid => 'All said';

  @override
  String get loadSentence => 'Load a sentence into the text field';

  @override
  String get loadBanner =>
      'Tap the sentence you want to load into the text field';

  @override
  String get recordAction => 'Record';

  @override
  String get recordDone => 'Done';

  @override
  String get recordListen => 'Listen';

  @override
  String get recordAgain => 'Again';

  @override
  String get recordDiscardTitle => 'Discard the recording?';

  @override
  String get recordDiscard => 'Discard';

  @override
  String get micDenied => 'Microphone permission is needed to record.';

  @override
  String get openAppSettings => 'Open settings';

  @override
  String get recordFailed => 'Recording failed.';

  @override
  String recordProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get recordSkip => 'Skip';

  @override
  String recordSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings saved',
      one: '1 recording saved',
    );
    return '$_temp0';
  }

  @override
  String get recordListAction => 'Record';

  @override
  String get recordOwnVoice => 'Record my own voice';

  @override
  String get recordingListen => 'Listen to the recording';

  @override
  String get recordingNew => 'New recording';

  @override
  String get recordingDelete => 'Delete the recording';

  @override
  String get recordingDeleteQuestion => 'Delete the recording?';

  @override
  String get keepRecordingQuestion =>
      'The recording still says the old text. Keep it?';

  @override
  String get keepRecording => 'Keep';

  @override
  String get removeRecording => 'Delete';

  @override
  String get backupSection => 'Backup';

  @override
  String get backupCreate => 'Create a backup';

  @override
  String get backupCreateHelp =>
      'Lists and recordings go into one file. Save it to Google Drive or to the phone.';

  @override
  String get backupRestore => 'Restore from a file';

  @override
  String get backupRestoreHelp =>
      'Adds the backup\'s lists and recordings. Nothing existing is overwritten.';

  @override
  String get backupWorking => 'One moment…';

  @override
  String backupDone(int n) {
    return 'Done. $n recordings saved.';
  }

  @override
  String restoreDone(int added, int skipped, int recordings) {
    return '$added lists added, $skipped already there, $recordings recordings copied.';
  }

  @override
  String get backupFailed => 'The backup failed.';

  @override
  String get restoreFailed => 'The restore failed. Nothing was changed.';

  @override
  String get restoreErrorVersion =>
      'This backup comes from a newer version of Mondom. Update the app.';

  @override
  String get restoreErrorFormat =>
      'This is not a Mondom backup, or it is damaged. Nothing was changed.';

  @override
  String get closeAction => 'Close';

  @override
  String get elevenLabsFallbackTooltip => 'Why did another voice speak?';

  @override
  String elevenLabsFallbackOffline(String voice) {
    return 'No internet, $voice is speaking instead.';
  }

  @override
  String elevenLabsFallbackQuota(String voice) {
    return 'The ElevenLabs credit has run out, $voice is speaking instead.';
  }

  @override
  String elevenLabsFallbackBadKey(String voice) {
    return 'The ElevenLabs key isn\'t valid, $voice is speaking instead.';
  }

  @override
  String elevenLabsFallbackOther(String voice) {
    return 'ElevenLabs isn\'t available right now, $voice is speaking instead.';
  }

  @override
  String get elevenLabsSection => 'ElevenLabs';

  @override
  String get elevenLabsSectionSubtitle =>
      'Needs internet and your own ElevenLabs account';

  @override
  String get elevenLabsSetup => 'Set up';

  @override
  String get elevenLabsSettings => 'Settings';

  @override
  String get elevenLabsTrial => 'Try';

  @override
  String get elevenLabsNoInternet => 'No internet';

  @override
  String get elevenLabsListFailed =>
      'The ElevenLabs voices aren\'t available right now. Check the settings.';

  @override
  String get elevenLabsScreenTitle => 'ElevenLabs voice';

  @override
  String get elevenLabsIntro =>
      'This is optional. It needs your own ElevenLabs account and internet. What you say is sent to ElevenLabs and appears in your ElevenLabs history. The free plan has a monthly credit limit. Without internet another voice speaks instead; sentences said before still use the ElevenLabs voice offline.';

  @override
  String get elevenLabsPermissions =>
      'The key needs these permissions: Text to Speech and Voices. User (read) is optional, but then the used credit is shown.';

  @override
  String get elevenLabsKeyLabel => 'ElevenLabs API key';

  @override
  String get elevenLabsCheck => 'Check';

  @override
  String get elevenLabsKeySaved => 'The key works and is saved.';

  @override
  String get elevenLabsErrBadKey => 'This key isn\'t valid.';

  @override
  String get elevenLabsErrPermission =>
      'The key doesn\'t have the Voices permission.';

  @override
  String get elevenLabsErrOffline => 'No internet, couldn\'t check.';

  @override
  String get elevenLabsErrOther =>
      'ElevenLabs isn\'t answering right now. Try again later.';

  @override
  String elevenLabsCredit(String used, String limit, String date) {
    return 'Credit used: $used / $limit, resets: $date';
  }

  @override
  String elevenLabsCreditNoDate(String used, String limit) {
    return 'Credit used: $used / $limit';
  }

  @override
  String get elevenLabsFallbackChoice => 'Without internet, this voice speaks:';

  @override
  String get elevenLabsExpressive =>
      'More expressive voice (slower, twice the credit)';

  @override
  String get elevenLabsDeleteKey => 'Delete key';

  @override
  String get elevenLabsDeleteKeyQuestion =>
      'Delete the key? The saved ElevenLabs audio is deleted too.';
}
