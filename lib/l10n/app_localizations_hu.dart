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
  String get settingsSpeedTitle => 'Beszéd sebessége';

  @override
  String settingsSpeedFor(String voice) {
    return '$voice hangjára';
  }

  @override
  String get settingsSpeedSlower => 'Lassabb';

  @override
  String get settingsSpeedFaster => 'Gyorsabb';

  @override
  String get settingsSpeedReset => 'Visszaállítás';

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
  String recordProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get recordSkip => 'Kihagyom';

  @override
  String recordSummary(int count) {
    return '$count felvétel mentve';
  }

  @override
  String get recordListAction => 'Felvétel';

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

  @override
  String get backupSection => 'Mentés';

  @override
  String get backupCreate => 'Biztonsági mentés készítése';

  @override
  String get backupCreateHelp =>
      'A listák és a felvételek egy fájlba kerülnek. Mentheted Google Drive-ra vagy a telefonra.';

  @override
  String get backupRestore => 'Visszaállítás fájlból';

  @override
  String get backupRestoreHelp =>
      'Hozzáadja a mentés listáit és felvételeit. A meglévőket nem írja felül.';

  @override
  String get backupWorking => 'Egy pillanat…';

  @override
  String backupDone(int n) {
    return 'Kész. $n felvétel mentve.';
  }

  @override
  String restoreDone(int added, int skipped, int recordings) {
    return '$added lista hozzáadva, $skipped már megvolt, $recordings felvétel másolva.';
  }

  @override
  String get backupFailed => 'Nem sikerült a mentés.';

  @override
  String get restoreFailed =>
      'Nem sikerült a visszaállítás. Nem változott semmi.';

  @override
  String get restoreErrorVersion =>
      'Ez a mentés a Mondom újabb verziójából való. Frissítsd az appot.';

  @override
  String get restoreErrorFormat =>
      'Ez nem Mondom-mentés, vagy sérült. Nem változott semmi.';

  @override
  String get closeAction => 'Bezár';

  @override
  String get elevenLabsFallbackTooltip => 'Miért más hang szólt?';

  @override
  String elevenLabsFallbackOffline(String voice) {
    return 'Nincs internet, $voice beszél helyette.';
  }

  @override
  String elevenLabsFallbackQuota(String voice) {
    return 'Elfogyott az ElevenLabs-kredit, $voice beszél helyette.';
  }

  @override
  String elevenLabsFallbackBadKey(String voice) {
    return 'Az ElevenLabs-kulcs nem érvényes, $voice beszél helyette.';
  }

  @override
  String elevenLabsFallbackOther(String voice) {
    return 'Az ElevenLabs most nem elérhető, $voice beszél helyette.';
  }

  @override
  String elevenLabsFallbackPaidOnly(String voice) {
    return 'Ez az ElevenLabs-hang csak fizetős ElevenLabs-előfizetéssel használható, $voice beszél helyette.';
  }

  @override
  String get elevenLabsPaidOnly =>
      'Ez az ElevenLabs hangtárából való hang, és csak fizetős ElevenLabs-előfizetéssel használható.';

  @override
  String get elevenLabsSection => 'ElevenLabs';

  @override
  String get elevenLabsSectionSubtitle =>
      'Saját ElevenLabs-fiókkal, internettel';

  @override
  String get elevenLabsSetup => 'ElevenLabs beállítása';

  @override
  String get elevenLabsSettings => 'ElevenLabs beállításai';

  @override
  String get elevenLabsTrial => 'Próba';

  @override
  String get elevenLabsNoInternet => 'Nincs internet';

  @override
  String get elevenLabsListFailed =>
      'Az ElevenLabs-hangok most nem érhetők el. Nézd meg a beállításokat.';

  @override
  String get elevenLabsScreenTitle => 'ElevenLabs-hang';

  @override
  String get elevenLabsIntro =>
      'Az ElevenLabs egy külső, a Mondomtól független felhőszolgáltatás. Használatához saját ElevenLabs API-kulcs és internetkapcsolat kell. A felolvasandó szövegeket a Mondom elküldi az ElevenLabs szervereire, ezekre az ElevenLabs adatkezelési feltételei vonatkoznak.';

  @override
  String get elevenLabsManualLink => 'Részletek a súgóban';

  @override
  String get elevenLabsKeyHint =>
      'Szükséges jogosultságok: Text to Speech, Voices (olvasás). Nem kötelező: User (olvasás), a kreditek kijelzéséhez.';

  @override
  String get elevenLabsKeyLabel => 'ElevenLabs API-kulcs';

  @override
  String get elevenLabsCheck => 'Ellenőrzés';

  @override
  String get elevenLabsKeySaved => 'A kulcs működik, elmentve.';

  @override
  String get elevenLabsErrBadKey => 'Ez a kulcs nem érvényes.';

  @override
  String get elevenLabsErrPermission =>
      'A kulcsnak nincs meg minden szükséges jogosultsága. Nézd meg a jogosultságait az ElevenLabs honlapján.';

  @override
  String get elevenLabsErrOffline =>
      'Nincs internet, így nem lehet ellenőrizni a kulcsot.';

  @override
  String get elevenLabsErrOther =>
      'Az ElevenLabs most nem válaszol. Próbáld újra később.';

  @override
  String elevenLabsCredit(String used, String limit, String date) {
    return 'Felhasznált kredit: $used / $limit, újraindul: $date';
  }

  @override
  String elevenLabsCreditNoDate(String used, String limit) {
    return 'Felhasznált kredit: $used / $limit';
  }

  @override
  String get elevenLabsFallbackChoice => 'Tartalék hang, ha nincs internet:';

  @override
  String get elevenLabsExpressive => 'Kifejezőbb hang';

  @override
  String get elevenLabsExpressiveSubtitle =>
      'Lassabban indul, és kétszer annyi kreditbe kerül.';

  @override
  String get elevenLabsDeleteKey => 'Kulcs törlése';

  @override
  String get elevenLabsDeleteKeyQuestion =>
      'Törlöd a kulcsot? A listákba mentett ElevenLabs-felvételek megmaradnak, a többi kimondott mondat legközelebb a tartalék hangon szól.';

  @override
  String get aboutTitle => 'Névjegy';

  @override
  String get aboutSubtitle => 'Verzió, licencek, tárhely';

  @override
  String get aboutTagline =>
      'Ingyenes, reklám nélküli, nyílt forráskódú beszédsegítő. Nincs fiók, minden adat a telefonon marad.';

  @override
  String aboutVersion(String version) {
    return 'Verzió $version';
  }

  @override
  String get aboutGithub => 'A projekt a GitHubon';

  @override
  String get aboutPrivacy => 'Adatkezelés';

  @override
  String get aboutVoices => 'Hangok';

  @override
  String aboutVoiceLine(String name, String license) {
    return '$name: $license';
  }

  @override
  String get aboutAlmaCredit =>
      'Alma: a hangmodell az NST svéd beszédadatbázison (Språkbanken, Norvég Nemzeti Könyvtár) készült, licenc: CC BY 4.0.';

  @override
  String get aboutModelCard => 'Hangmodell adatlapja';

  @override
  String get aboutSystemVoiceLine =>
      'Android alapértelmezett: a telefon saját hangja';

  @override
  String get aboutSoftware => 'Felhasznált szoftverek';

  @override
  String get aboutAllLicenses => 'Összes licenc';

  @override
  String get aboutStorage => 'Tárhely';

  @override
  String get aboutRecordings => 'Saját felvételek';

  @override
  String get aboutDownloadedVoices => 'Letöltött hangok';

  @override
  String aboutMegabytes(String mb) {
    return '$mb MB';
  }

  @override
  String get aboutTrademark =>
      'Az ElevenLabs az ElevenLabs védjegye; a Mondom nem kapcsolódik hozzá.';

  @override
  String get aboutLinkFailed => 'Nem sikerült megnyitni. A cím:';
}
