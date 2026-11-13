import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hu'),
  ];

  /// App name, shown in the app bar and task switcher.
  ///
  /// In hu, this message translates to:
  /// **'Mondom'**
  String get appTitle;

  /// Placeholder in the free-text field.
  ///
  /// In hu, this message translates to:
  /// **'Írj ide…'**
  String get textHint;

  /// Shown instead of the speak button while the voice model is loading.
  ///
  /// In hu, this message translates to:
  /// **'Betöltés…'**
  String get loading;

  /// Button that speaks the typed text.
  ///
  /// In hu, this message translates to:
  /// **'Mondom'**
  String get speak;

  /// Tooltip of the ✕ button that clears the text field.
  ///
  /// In hu, this message translates to:
  /// **'Szöveg törlése'**
  String get clearText;

  /// Timing line shown when the last phrase was replayed instead of synthesized.
  ///
  /// In hu, this message translates to:
  /// **'Újrajátszva (szintézis nélkül)'**
  String get replayed;

  /// Timing info: how long loading the voice model took.
  ///
  /// In hu, this message translates to:
  /// **'Modell betöltés: {ms} ms'**
  String modelLoadTime(int ms);

  /// Timing info for the last synthesis (real-time factor, RTF).
  ///
  /// In hu, this message translates to:
  /// **'Szintézis: {synthMs} ms, hang: {audioMs} ms, RTF: {rtf}'**
  String synthesisStats(int synthMs, int audioMs, String rtf);

  /// Cancels a running voice download.
  ///
  /// In hu, this message translates to:
  /// **'Mégse'**
  String get cancel;

  /// Large button shown while an alarm plays; stops it.
  ///
  /// In hu, this message translates to:
  /// **'Leállítás'**
  String get stopAlarm;

  /// Title of the voice picker screen.
  ///
  /// In hu, this message translates to:
  /// **'Hang kiválasztása'**
  String get voicePickerTitle;

  /// Button at the top of the voice picker showing the chosen language.
  ///
  /// In hu, this message translates to:
  /// **'Nyelv: {name}'**
  String languageSelectorLabel(String name);

  /// Marker on a language in the language list: downloaded voices.
  ///
  /// In hu, this message translates to:
  /// **'{count} letöltve'**
  String installedVoicesCount(int count);

  /// System voice row: the engine knows the language but has no voice data.
  ///
  /// In hu, this message translates to:
  /// **'A hang nincs letöltve a telefonon.'**
  String get systemVoiceMissing;

  /// Button opening Android's voice data install screen.
  ///
  /// In hu, this message translates to:
  /// **'Letöltés az Android beállításaiban'**
  String get downloadInAndroidSettings;

  /// System voice row: the engine can't speak this language.
  ///
  /// In hu, this message translates to:
  /// **'A telefon nem tud ezen a nyelven beszélni.'**
  String get systemVoiceUnsupported;

  /// Name of the Android system TTS voice.
  ///
  /// In hu, this message translates to:
  /// **'Android alapértelmezett'**
  String get systemVoice;

  /// Subtitle of the system voice row.
  ///
  /// In hu, this message translates to:
  /// **'Azonnal működik, internet nélkül is'**
  String get systemVoiceInfo;

  /// Button that downloads a voice.
  ///
  /// In hu, this message translates to:
  /// **'Letöltés'**
  String get download;

  /// Button that selects an installed voice.
  ///
  /// In hu, this message translates to:
  /// **'Kiválasztás'**
  String get select;

  /// State label of the currently selected voice.
  ///
  /// In hu, this message translates to:
  /// **'Kiválasztva'**
  String get selected;

  /// Tooltip of the button that deletes a downloaded voice.
  ///
  /// In hu, this message translates to:
  /// **'Hang törlése'**
  String get deleteVoice;

  /// Tooltip of the sample play button.
  ///
  /// In hu, this message translates to:
  /// **'Minta meghallgatása'**
  String get playSample;

  /// Shown when a voice sample cannot be loaded.
  ///
  /// In hu, this message translates to:
  /// **'A minta nem érhető el'**
  String get sampleUnavailable;

  /// Shown when the voice catalog could not be fetched.
  ///
  /// In hu, this message translates to:
  /// **'A hangok letöltéséhez internet kell. Az Android alapértelmezett hang internet nélkül is működik.'**
  String get downloadsNeedInternet;

  /// Shown when a voice download fails.
  ///
  /// In hu, this message translates to:
  /// **'A letöltés nem sikerült. Ellenőrizd az internetkapcsolatot.'**
  String get downloadFailed;

  /// Voice gender.
  ///
  /// In hu, this message translates to:
  /// **'férfi'**
  String get genderMale;

  /// Voice gender.
  ///
  /// In hu, this message translates to:
  /// **'női'**
  String get genderFemale;

  /// Download size.
  ///
  /// In hu, this message translates to:
  /// **'{mb} MB'**
  String voiceSizeMb(int mb);

  /// Shown while a downloaded voice is verified and unpacked.
  ///
  /// In hu, this message translates to:
  /// **'Telepítés… (ez eltarthat egy ideig)'**
  String get installing;

  /// Title of the automatic history list (chip and list grid).
  ///
  /// In hu, this message translates to:
  /// **'Előzmények'**
  String get historyTitle;

  /// Tooltip of the ▾ button that shows all lists.
  ///
  /// In hu, this message translates to:
  /// **'Összes lista'**
  String get allLists;

  /// Hint shown in an empty sentence list.
  ///
  /// In hu, this message translates to:
  /// **'Ez a lista üres. Szerkesztés: ☰ Menü → Listák'**
  String get emptyListHint;

  /// Tooltip of the hamburger button in the speaking screen's app bar.
  ///
  /// In hu, this message translates to:
  /// **'Menü'**
  String get menuTooltip;

  /// Settings row opening the voice picker.
  ///
  /// In hu, this message translates to:
  /// **'Hang és nyelv'**
  String get settingsVoiceTitle;

  /// Subtitle of the voice row: current voice and its language.
  ///
  /// In hu, this message translates to:
  /// **'{voice} · {language}'**
  String settingsVoiceSubtitle(String voice, String language);

  /// Settings row opening the lists overview; also its screen title.
  ///
  /// In hu, this message translates to:
  /// **'Listák'**
  String get settingsListsTitle;

  /// Subtitle of the lists row.
  ///
  /// In hu, this message translates to:
  /// **'Listák és mondatok szerkesztése'**
  String get settingsListsSubtitle;

  /// Drawer row and screen title for the sound settings.
  ///
  /// In hu, this message translates to:
  /// **'Beállítások'**
  String get settingsTitle;

  /// Subtitle of the settings drawer row.
  ///
  /// In hu, this message translates to:
  /// **'Hangosítás, riasztás hangereje'**
  String get settingsSubtitle;

  /// Section header for speech settings.
  ///
  /// In hu, this message translates to:
  /// **'Beszéd'**
  String get settingsSpeechSection;

  /// Switch: louder speech.
  ///
  /// In hu, this message translates to:
  /// **'Hangosítás'**
  String get settingsBoostTitle;

  /// Help text under the speech boost switch.
  ///
  /// In hu, this message translates to:
  /// **'Hangosabb beszéd. Kapcsold ki, ha torznak hallod.'**
  String get settingsBoostHelp;

  /// Section header for alarm settings.
  ///
  /// In hu, this message translates to:
  /// **'Riasztás'**
  String get settingsAlarmSection;

  /// Radio option: use the phone's own alarm volume.
  ///
  /// In hu, this message translates to:
  /// **'A telefon ébresztési hangereje'**
  String get alarmVolumeSystem;

  /// Radio option: Mondom raises the alarm volume to the slider level while an alarm plays, then restores it.
  ///
  /// In hu, this message translates to:
  /// **'Saját hangerő'**
  String get alarmVolumeCustom;

  /// Button that plays the bell as an alarm.
  ///
  /// In hu, this message translates to:
  /// **'Kipróbálás'**
  String get alarmVolumeTest;

  /// Marker on a list that has a chip on the speaking screen.
  ///
  /// In hu, this message translates to:
  /// **'Kitűzve'**
  String get pinnedLabel;

  /// Number of sentences in a list.
  ///
  /// In hu, this message translates to:
  /// **'{count} mondat'**
  String sentenceCount(int count);

  /// Marker on the list that is open on the speaking screen.
  ///
  /// In hu, this message translates to:
  /// **'Most megnyitva'**
  String get currentlyOpen;

  /// Semantics label of the drag handle of a list row.
  ///
  /// In hu, this message translates to:
  /// **'Mozgatás'**
  String get reorderHandle;

  /// Tooltip of the ⋮ button of a list row.
  ///
  /// In hu, this message translates to:
  /// **'További műveletek'**
  String get moreActions;

  /// List action: rename.
  ///
  /// In hu, this message translates to:
  /// **'Átnevezés'**
  String get renameList;

  /// List action: pin to the chip row.
  ///
  /// In hu, this message translates to:
  /// **'Kitűzés'**
  String get pinList;

  /// List action: remove from the chip row.
  ///
  /// In hu, this message translates to:
  /// **'Kitűzés megszüntetése'**
  String get unpinList;

  /// List action: delete.
  ///
  /// In hu, this message translates to:
  /// **'Törlés'**
  String get deleteList;

  /// Confirmation before deleting a list.
  ///
  /// In hu, this message translates to:
  /// **'Törlöd a(z) „{title}” listát és a {count} mondatát?'**
  String deleteListQuestion(String title, int count);

  /// Confirm button of a delete dialog.
  ///
  /// In hu, this message translates to:
  /// **'Törlés'**
  String get deleteAction;

  /// Confirm button of the rename dialog.
  ///
  /// In hu, this message translates to:
  /// **'Mentés'**
  String get saveAction;

  /// Button and dialog title for creating a list.
  ///
  /// In hu, this message translates to:
  /// **'Új lista'**
  String get newList;

  /// Name field of the new list / rename dialogs.
  ///
  /// In hu, this message translates to:
  /// **'A lista neve'**
  String get listNameLabel;

  /// List kind: plain sentence list.
  ///
  /// In hu, this message translates to:
  /// **'Mondatlista'**
  String get kindEveryday;

  /// List kind: prepared conversation.
  ///
  /// In hu, this message translates to:
  /// **'Beszélgetés'**
  String get kindConversation;

  /// Explains the conversation list kind.
  ///
  /// In hu, this message translates to:
  /// **'Előre megírt mondatok, Következő gombbal'**
  String get kindConversationInfo;

  /// Confirm button of the new list dialog.
  ///
  /// In hu, this message translates to:
  /// **'Létrehozás'**
  String get createAction;

  /// Row that re-creates deleted default lists.
  ///
  /// In hu, this message translates to:
  /// **'Alapértelmezett listák visszaállítása'**
  String get restoreDefaultLists;

  /// Dialog asking whether to add the default sentence lists of another language. The language name is lowercase in Hungarian.
  ///
  /// In hu, this message translates to:
  /// **'Hozzáadjam a(z) {language} alapértelmezett listákat?'**
  String addSeedListsQuestion(String language);

  /// Confirm button of the add-default-lists dialog.
  ///
  /// In hu, this message translates to:
  /// **'Hozzáadás'**
  String get addAction;

  /// Decline button of the add-default-lists dialog.
  ///
  /// In hu, this message translates to:
  /// **'Nem'**
  String get noAction;

  /// Text field label for adding new sentences, one per line.
  ///
  /// In hu, this message translates to:
  /// **'Új sor(ok)'**
  String get newLinesLabel;

  /// Hint of the add-sentences field.
  ///
  /// In hu, this message translates to:
  /// **'Soronként egy mondat'**
  String get newLinesHint;

  /// Row action: copy a sentence to another list.
  ///
  /// In hu, this message translates to:
  /// **'Másolás listába…'**
  String get copyToList;

  /// Switch in a row's ⋮ sheet: play this sentence as an alarm.
  ///
  /// In hu, this message translates to:
  /// **'Riasztásként szóljon (hangosan)'**
  String get alarmToggle;

  /// Help text under the alarm switch.
  ///
  /// In hu, this message translates to:
  /// **'Riasztás hangerején szól, és nem kerül az előzmények közé.'**
  String get alarmToggleHelp;

  /// Row action: move a sentence to another list.
  ///
  /// In hu, this message translates to:
  /// **'Áthelyezés listába…'**
  String get moveToList;

  /// Title of the target list picker.
  ///
  /// In hu, this message translates to:
  /// **'Melyik listába?'**
  String get chooseListTitle;

  /// Title of the edit-sentence dialog.
  ///
  /// In hu, this message translates to:
  /// **'Mondat szerkesztése'**
  String get editSentenceTitle;

  /// Snackbar after deleting a sentence.
  ///
  /// In hu, this message translates to:
  /// **'Mondat törölve'**
  String get sentenceDeleted;

  /// Undo button of a snackbar.
  ///
  /// In hu, this message translates to:
  /// **'Visszavonás'**
  String get undoAction;

  /// Row that re-adds deleted default sentences.
  ///
  /// In hu, this message translates to:
  /// **'Alapértelmezett mondatok visszaállítása'**
  String get restoreDefaultSentences;

  /// Button that clears the said marks of a conversation.
  ///
  /// In hu, this message translates to:
  /// **'Újrakezdés'**
  String get resetSaid;

  /// Snackbar after restoring default sentences.
  ///
  /// In hu, this message translates to:
  /// **'{count, plural, one{{count} mondat visszaállítva} other{{count} mondat visszaállítva}}'**
  String restoredSentences(int count);

  /// Snackbar after restoring default lists.
  ///
  /// In hu, this message translates to:
  /// **'{count, plural, one{{count} lista visszaállítva} other{{count} lista visszaállítva}}'**
  String restoredLists(int count);

  /// Confirmation before clearing the said marks of a conversation.
  ///
  /// In hu, this message translates to:
  /// **'Újrakezdés: az összes mondat újra elhangzatlan lesz. Folytatod?'**
  String get resetSaidQuestion;

  /// Hint in an empty list editor.
  ///
  /// In hu, this message translates to:
  /// **'Még nincs mondat. Írj alább, soronként egyet.'**
  String get emptyEditorList;

  /// Row in the list actions sheet that opens the color dialog.
  ///
  /// In hu, this message translates to:
  /// **'Szín'**
  String get listColorLabel;

  /// Neutral (no color) choice.
  ///
  /// In hu, this message translates to:
  /// **'Nincs'**
  String get listColorNone;

  /// No description provided for @listColorDialogTitle.
  ///
  /// In hu, this message translates to:
  /// **'Lista színe'**
  String get listColorDialogTitle;

  /// Color names are only semantics labels for screen readers.
  ///
  /// In hu, this message translates to:
  /// **'kék'**
  String get colorName_blue;

  /// No description provided for @colorName_green.
  ///
  /// In hu, this message translates to:
  /// **'zöld'**
  String get colorName_green;

  /// No description provided for @colorName_orange.
  ///
  /// In hu, this message translates to:
  /// **'narancs'**
  String get colorName_orange;

  /// No description provided for @colorName_purple.
  ///
  /// In hu, this message translates to:
  /// **'lila'**
  String get colorName_purple;

  /// No description provided for @colorName_teal.
  ///
  /// In hu, this message translates to:
  /// **'türkiz'**
  String get colorName_teal;

  /// No description provided for @colorName_pink.
  ///
  /// In hu, this message translates to:
  /// **'rózsaszín'**
  String get colorName_pink;

  /// No description provided for @colorName_yellow.
  ///
  /// In hu, this message translates to:
  /// **'sárga'**
  String get colorName_yellow;

  /// No description provided for @colorName_brown.
  ///
  /// In hu, this message translates to:
  /// **'barna'**
  String get colorName_brown;

  /// No description provided for @colorSelected.
  ///
  /// In hu, this message translates to:
  /// **'kiválasztva'**
  String get colorSelected;

  /// Button in a conversation list that speaks the first unsaid sentence.
  ///
  /// In hu, this message translates to:
  /// **'Következő'**
  String get nextSentence;

  /// Shown in place of the next button when every sentence of a conversation is said.
  ///
  /// In hu, this message translates to:
  /// **'Minden elhangzott'**
  String get allSaid;

  /// Tooltip/TalkBack label of the one-shot button that makes the next row tap load the sentence into the text field instead of speaking it.
  ///
  /// In hu, this message translates to:
  /// **'Mondat betöltése a szövegmezőbe'**
  String get loadSentence;

  /// Banner shown while the load-into-text-field mode is armed.
  ///
  /// In hu, this message translates to:
  /// **'Koppints a mondatra, amit a szövegmezőbe töltenél'**
  String get loadBanner;

  /// Record button and screen title.
  ///
  /// In hu, this message translates to:
  /// **'Felvétel'**
  String get recordAction;

  /// Stops the recording.
  ///
  /// In hu, this message translates to:
  /// **'Kész'**
  String get recordDone;

  /// Plays the take as it will sound.
  ///
  /// In hu, this message translates to:
  /// **'Meghallgatom'**
  String get recordListen;

  /// Discards the take and records again.
  ///
  /// In hu, this message translates to:
  /// **'Újra'**
  String get recordAgain;

  /// Asked when leaving with an unsaved take.
  ///
  /// In hu, this message translates to:
  /// **'Elveted a felvételt?'**
  String get recordDiscardTitle;

  /// Confirm discarding the take.
  ///
  /// In hu, this message translates to:
  /// **'Elvetem'**
  String get recordDiscard;

  /// Shown when the microphone permission is denied.
  ///
  /// In hu, this message translates to:
  /// **'A felvételhez engedélyezni kell a mikrofon használatát.'**
  String get micDenied;

  /// Opens the app's Android settings.
  ///
  /// In hu, this message translates to:
  /// **'Beállítások megnyitása'**
  String get openAppSettings;

  /// Recording could not start.
  ///
  /// In hu, this message translates to:
  /// **'Nem sikerült a felvétel.'**
  String get recordFailed;

  /// Position in the batch recording of a list.
  ///
  /// In hu, this message translates to:
  /// **'{current} / {total}'**
  String recordProgress(int current, int total);

  /// Skips this sentence when recording a whole list.
  ///
  /// In hu, this message translates to:
  /// **'Kihagyom'**
  String get recordSkip;

  /// Summary after recording a whole list.
  ///
  /// In hu, this message translates to:
  /// **'{count} felvétel mentve'**
  String recordSummary(int count);

  /// Tooltip of the app bar button that records the rows of a list one after another.
  ///
  /// In hu, this message translates to:
  /// **'Felvétel'**
  String get recordListAction;

  /// Sheet row: record a sentence.
  ///
  /// In hu, this message translates to:
  /// **'Saját hang felvétele'**
  String get recordOwnVoice;

  /// Sheet row: play the recording.
  ///
  /// In hu, this message translates to:
  /// **'Felvétel meghallgatása'**
  String get recordingListen;

  /// Sheet row: record again.
  ///
  /// In hu, this message translates to:
  /// **'Új felvétel'**
  String get recordingNew;

  /// Sheet row: remove the recording.
  ///
  /// In hu, this message translates to:
  /// **'Felvétel törlése'**
  String get recordingDelete;

  /// Confirm dialog for removing a recording.
  ///
  /// In hu, this message translates to:
  /// **'Törlöd a felvételt?'**
  String get recordingDeleteQuestion;

  /// Asked after editing the text of a recorded row.
  ///
  /// In hu, this message translates to:
  /// **'A felvétel még a régi szöveget mondja. Megtartod?'**
  String get keepRecordingQuestion;

  /// Keep the recording.
  ///
  /// In hu, this message translates to:
  /// **'Megtartom'**
  String get keepRecording;

  /// Remove the recording.
  ///
  /// In hu, this message translates to:
  /// **'Törlöm'**
  String get removeRecording;

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'Mentés'**
  String get backupSection;

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'Biztonsági mentés készítése'**
  String get backupCreate;

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'A listák és a felvételek egy fájlba kerülnek. Mentheted Google Drive-ra vagy a telefonra.'**
  String get backupCreateHelp;

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'Visszaállítás fájlból'**
  String get backupRestore;

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'Hozzáadja a mentés listáit és felvételeit. A meglévőket nem írja felül.'**
  String get backupRestoreHelp;

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'Egy pillanat…'**
  String get backupWorking;

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'Kész. {n} felvétel mentve.'**
  String backupDone(int n);

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'{added} lista hozzáadva, {skipped} már megvolt, {recordings} felvétel másolva.'**
  String restoreDone(int added, int skipped, int recordings);

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'Nem sikerült a mentés.'**
  String get backupFailed;

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'Nem sikerült a visszaállítás. Nem változott semmi.'**
  String get restoreFailed;

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'Ez a mentés a Mondom újabb verziójából való. Frissítsd az appot.'**
  String get restoreErrorVersion;

  /// Settings > Mentés (backup to a file).
  ///
  /// In hu, this message translates to:
  /// **'Ez nem Mondom-mentés, vagy sérült. Nem változott semmi.'**
  String get restoreErrorFormat;

  /// Closes an information dialog.
  ///
  /// In hu, this message translates to:
  /// **'Bezár'**
  String get closeAction;

  /// Speaking screen app bar icon, shown while the offline fallback spoke instead of the ElevenLabs voice.
  ///
  /// In hu, this message translates to:
  /// **'Miért más hang szólt?'**
  String get elevenLabsFallbackTooltip;

  /// Fallback dialog: no network or timeout.
  ///
  /// In hu, this message translates to:
  /// **'Nincs internet, {voice} beszél helyette.'**
  String elevenLabsFallbackOffline(String voice);

  /// Fallback dialog: ElevenLabs credits used up.
  ///
  /// In hu, this message translates to:
  /// **'Elfogyott az ElevenLabs kredit, {voice} beszél helyette.'**
  String elevenLabsFallbackQuota(String voice);

  /// Fallback dialog: no key stored or the key was rejected.
  ///
  /// In hu, this message translates to:
  /// **'Az ElevenLabs kulcs nem érvényes, {voice} beszél helyette.'**
  String elevenLabsFallbackBadKey(String voice);

  /// Fallback dialog: any other ElevenLabs failure.
  ///
  /// In hu, this message translates to:
  /// **'Az ElevenLabs most nem elérhető, {voice} beszél helyette.'**
  String elevenLabsFallbackOther(String voice);

  /// Voice picker: header of the ElevenLabs section.
  ///
  /// In hu, this message translates to:
  /// **'ElevenLabs'**
  String get elevenLabsSection;

  /// Voice picker: subtitle under the ElevenLabs header.
  ///
  /// In hu, this message translates to:
  /// **'Internet és saját ElevenLabs-fiók kell'**
  String get elevenLabsSectionSubtitle;

  /// Voice picker: opens the ElevenLabs setup screen when no key is stored.
  ///
  /// In hu, this message translates to:
  /// **'Beállítás'**
  String get elevenLabsSetup;

  /// Voice picker: opens the ElevenLabs setup screen when a key is stored.
  ///
  /// In hu, this message translates to:
  /// **'Beállítások'**
  String get elevenLabsSettings;

  /// Voice picker: tooltip of the play button of an ElevenLabs voice.
  ///
  /// In hu, this message translates to:
  /// **'Próba'**
  String get elevenLabsTrial;

  /// Voice picker: the ElevenLabs voice list could not be fetched offline.
  ///
  /// In hu, this message translates to:
  /// **'Nincs internet'**
  String get elevenLabsNoInternet;

  /// Voice picker: the ElevenLabs voice list failed for a reason other than being offline.
  ///
  /// In hu, this message translates to:
  /// **'Az ElevenLabs hangjai most nem érhetők el. Nézd meg a beállításokat.'**
  String get elevenLabsListFailed;

  /// Title of the ElevenLabs setup screen.
  ///
  /// In hu, this message translates to:
  /// **'ElevenLabs hang'**
  String get elevenLabsScreenTitle;

  /// Setup screen: what the ElevenLabs voice means.
  ///
  /// In hu, this message translates to:
  /// **'Ez nem kötelező. Saját ElevenLabs-fiók és internet kell hozzá. Amit kimondatsz, azt a Mondom elküldi az ElevenLabsnek, és megjelenik az ElevenLabs-előzményeidben. Az ingyenes csomagban havi kreditkeret van. Ha nincs internet, egy másik hang beszél helyette; a korábban kimondott mondatok internet nélkül is az ElevenLabs hangján szólnak.'**
  String get elevenLabsIntro;

  /// Setup screen: required API key permissions.
  ///
  /// In hu, this message translates to:
  /// **'A kulcsnak ezek a jogosultságok kellenek: Text to Speech és Voices. A User (olvasás) nem kötelező, de akkor látszik a felhasznált kredit.'**
  String get elevenLabsPermissions;

  /// Setup screen: label of the key field.
  ///
  /// In hu, this message translates to:
  /// **'ElevenLabs API-kulcs'**
  String get elevenLabsKeyLabel;

  /// Setup screen: checks and saves the key.
  ///
  /// In hu, this message translates to:
  /// **'Ellenőrzés'**
  String get elevenLabsCheck;

  /// Setup screen: shown after a successful check.
  ///
  /// In hu, this message translates to:
  /// **'A kulcs működik, elmentettem.'**
  String get elevenLabsKeySaved;

  /// Setup screen: check failed, bad key.
  ///
  /// In hu, this message translates to:
  /// **'Ez a kulcs nem érvényes.'**
  String get elevenLabsErrBadKey;

  /// Setup screen: check failed, missing permission.
  ///
  /// In hu, this message translates to:
  /// **'A kulcsnak nincs meg a Voices jogosultsága.'**
  String get elevenLabsErrPermission;

  /// Setup screen: check failed, offline.
  ///
  /// In hu, this message translates to:
  /// **'Nincs internet, nem tudtam ellenőrizni.'**
  String get elevenLabsErrOffline;

  /// Setup screen: check failed, other reason.
  ///
  /// In hu, this message translates to:
  /// **'Az ElevenLabs most nem válaszol. Próbáld újra később.'**
  String get elevenLabsErrOther;

  /// Setup screen: credit line.
  ///
  /// In hu, this message translates to:
  /// **'Felhasznált kredit: {used} / {limit}, újraindul: {date}'**
  String elevenLabsCredit(String used, String limit, String date);

  /// Setup screen: credit line without a reset date.
  ///
  /// In hu, this message translates to:
  /// **'Felhasznált kredit: {used} / {limit}'**
  String elevenLabsCreditNoDate(String used, String limit);

  /// Setup screen: fallback voice choice.
  ///
  /// In hu, this message translates to:
  /// **'Ha nincs internet, ez a hang beszél:'**
  String get elevenLabsFallbackChoice;

  /// Setup screen: switch for eleven_v3.
  ///
  /// In hu, this message translates to:
  /// **'Kifejezőbb hang (lassabb, kétszer annyi kredit)'**
  String get elevenLabsExpressive;

  /// Setup screen: removes the API key.
  ///
  /// In hu, this message translates to:
  /// **'Kulcs törlése'**
  String get elevenLabsDeleteKey;

  /// Setup screen: confirm dialog.
  ///
  /// In hu, this message translates to:
  /// **'Törlöd a kulcsot? Az ElevenLabs hangok gyorsítótára is törlődik.'**
  String get elevenLabsDeleteKeyQuestion;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hu':
      return AppLocalizationsHu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
