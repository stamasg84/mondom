// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'Mondom';

  @override
  String get textHint => 'Írj ide…';

  @override
  String get loading => 'Betöltés…';

  @override
  String get speak => 'Mondom';

  @override
  String get clearText => 'Szöveg törlése';

  @override
  String get replayed => 'Újrajátszva (szintézis nélkül)';

  @override
  String modelLoadTime(int ms) {
    return 'Modell betöltés: $ms ms';
  }

  @override
  String synthesisStats(int synthMs, int audioMs, String rtf) {
    return 'Szintézis: $synthMs ms, hang: $audioMs ms, RTF: $rtf';
  }

  @override
  String get cancel => 'Mégse';

  @override
  String get stopAlarm => 'Leállítás';

  @override
  String get voicePickerTitle => 'Hang kiválasztása';

  @override
  String languageSelectorLabel(String name) {
    return 'Nyelv: $name';
  }

  @override
  String installedVoicesCount(int count) {
    return '$count letöltve';
  }

  @override
  String get systemVoiceMissing => 'A hang nincs letöltve a telefonon.';

  @override
  String get downloadInAndroidSettings => 'Letöltés az Android beállításaiban';

  @override
  String get systemVoiceUnsupported =>
      'A telefon nem tud ezen a nyelven beszélni.';

  @override
  String get systemVoice => 'Android alapértelmezett';

  @override
  String get systemVoiceInfo => 'Azonnal működik, internet nélkül is';

  @override
  String get download => 'Letöltés';

  @override
  String get select => 'Kiválasztás';

  @override
  String get selected => 'Kiválasztva';

  @override
  String get deleteVoice => 'Hang törlése';

  @override
  String get playSample => 'Minta meghallgatása';

  @override
  String get sampleUnavailable => 'A minta nem érhető el';

  @override
  String get downloadsNeedInternet =>
      'A hangok letöltéséhez internet kell. Az Android alapértelmezett hang internet nélkül is működik.';

  @override
  String get downloadFailed =>
      'A letöltés nem sikerült. Ellenőrizd az internetkapcsolatot.';

  @override
  String get genderMale => 'férfi';

  @override
  String get genderFemale => 'női';

  @override
  String voiceSizeMb(int mb) {
    return '$mb MB';
  }

  @override
  String get installing => 'Telepítés… (ez eltarthat egy ideig)';

  @override
  String get historyTitle => 'Előzmények';

  @override
  String get allLists => 'Összes lista';

  @override
  String get emptyListHint => 'Ez a lista üres. Szerkesztés: ☰ Menü → Listák';

  @override
  String get menuTooltip => 'Menü';

  @override
  String get settingsVoiceTitle => 'Hang és nyelv';

  @override
  String settingsVoiceSubtitle(String voice, String language) {
    return '$voice · $language';
  }

  @override
  String get settingsListsTitle => 'Listák';

  @override
  String get settingsListsSubtitle => 'Listák és mondatok szerkesztése';

  @override
  String get settingsTitle => 'Beállítások';

  @override
  String get settingsSubtitle => 'Hangosítás, riasztás hangereje';

  @override
  String get settingsSpeechSection => 'Beszéd';

  @override
  String get settingsBoostTitle => 'Hangosítás';

  @override
  String get settingsBoostHelp =>
      'Hangosabb beszéd. Kapcsold ki, ha torznak hallod.';

  @override
  String get settingsAlarmSection => 'Riasztás';

  @override
  String get alarmVolumeSystem => 'A telefon ébresztési hangereje';

  @override
  String get alarmVolumeCustom => 'Saját hangerő';

  @override
  String get alarmVolumeTest => 'Kipróbálás';

  @override
  String get pinnedLabel => 'Kitűzve';

  @override
  String sentenceCount(int count) {
    return '$count mondat';
  }

  @override
  String get currentlyOpen => 'Most megnyitva';

  @override
  String get reorderHandle => 'Mozgatás';

  @override
  String get moreActions => 'További műveletek';

  @override
  String get renameList => 'Átnevezés';

  @override
  String get pinList => 'Kitűzés';

  @override
  String get unpinList => 'Kitűzés megszüntetése';

  @override
  String get deleteList => 'Törlés';

  @override
  String deleteListQuestion(String title, int count) {
    return 'Törlöd a(z) „$title” listát és a $count mondatát?';
  }

  @override
  String get deleteAction => 'Törlés';

  @override
  String get saveAction => 'Mentés';

  @override
  String get newList => 'Új lista';

  @override
  String get listNameLabel => 'A lista neve';

  @override
  String get kindEveryday => 'Mondatlista';

  @override
  String get kindConversation => 'Beszélgetés';

  @override
  String get kindConversationInfo => 'Előre megírt mondatok, Következő gombbal';

  @override
  String get createAction => 'Létrehozás';

  @override
  String get restoreDefaultLists => 'Alapértelmezett listák visszaállítása';

  @override
  String addSeedListsQuestion(String language) {
    return 'Hozzáadjam a(z) $language alapértelmezett listákat?';
  }

  @override
  String get addAction => 'Hozzáadás';

  @override
  String get noAction => 'Nem';

  @override
  String get newLinesLabel => 'Új sor(ok)';

  @override
  String get newLinesHint => 'Soronként egy mondat';

  @override
  String get copyToList => 'Másolás listába…';

  @override
  String get alarmToggle => 'Riasztásként szóljon (hangosan)';

  @override
  String get alarmToggleHelp =>
      'Riasztás hangerején szól, és nem kerül az előzmények közé.';

  @override
  String get moveToList => 'Áthelyezés listába…';

  @override
  String get chooseListTitle => 'Melyik listába?';

  @override
  String get editSentenceTitle => 'Mondat szerkesztése';

  @override
  String get sentenceDeleted => 'Mondat törölve';

  @override
  String get undoAction => 'Visszavonás';

  @override
  String get restoreDefaultSentences =>
      'Alapértelmezett mondatok visszaállítása';

  @override
  String get resetSaid => 'Újrakezdés';

  @override
  String restoredSentences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mondat visszaállítva',
      one: '$count mondat visszaállítva',
    );
    return '$_temp0';
  }

  @override
  String restoredLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lista visszaállítva',
      one: '$count lista visszaállítva',
    );
    return '$_temp0';
  }

  @override
  String get resetSaidQuestion =>
      'Újrakezdés: az összes mondat újra elhangzatlan lesz. Folytatod?';

  @override
  String get emptyEditorList => 'Még nincs mondat. Írj alább, soronként egyet.';

  @override
  String get listColorLabel => 'Szín';

  @override
  String get listColorNone => 'Nincs';

  @override
  String get listColorDialogTitle => 'Lista színe';

  @override
  String get colorName_blue => 'kék';

  @override
  String get colorName_green => 'zöld';

  @override
  String get colorName_orange => 'narancs';

  @override
  String get colorName_purple => 'lila';

  @override
  String get colorName_teal => 'türkiz';

  @override
  String get colorName_pink => 'rózsaszín';

  @override
  String get colorName_yellow => 'sárga';

  @override
  String get colorName_brown => 'barna';

  @override
  String get colorSelected => 'kiválasztva';

  @override
  String get nextSentence => 'Következő';

  @override
  String get allSaid => 'Minden elhangzott';

  @override
  String get loadSentence => 'Mondat betöltése a szövegmezőbe';

  @override
  String get loadBanner => 'Koppints a mondatra, amit a szövegmezőbe töltenél';

  @override
  String get recordAction => 'Felvétel';

  @override
  String get recordDone => 'Kész';

  @override
  String get recordListen => 'Meghallgatom';

  @override
  String get recordAgain => 'Újra';

  @override
  String get recordDiscardTitle => 'Elveted a felvételt?';

  @override
  String get recordDiscard => 'Elvetem';

  @override
  String get micDenied =>
      'A felvételhez engedélyezni kell a mikrofon használatát.';

  @override
  String get openAppSettings => 'Beállítások megnyitása';

  @override
  String get recordFailed => 'Nem sikerült a felvétel.';

  @override
  String get recordOwnVoice => 'Saját hang felvétele';

  @override
  String get recordingListen => 'Felvétel meghallgatása';

  @override
  String get recordingNew => 'Új felvétel';

  @override
  String get recordingDelete => 'Felvétel törlése';

  @override
  String get recordingDeleteQuestion => 'Törlöd a felvételt?';

  @override
  String get keepRecordingQuestion =>
      'A felvétel még a régi szöveget mondja. Megtartod?';

  @override
  String get keepRecording => 'Megtartom';

  @override
  String get removeRecording => 'Törlöm';
}
