import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture_seed.dart';

import 'package:mondom/main.dart';
import 'package:mondom/speech/speaker.dart';
import 'package:mondom/storage/database.dart';
import 'package:mondom/storage/lists_repository.dart';
import 'package:mondom/ui/list_colors.dart';
import 'package:mondom/ui/speaking_screen.dart';
import 'package:mondom/voices/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSpeaker extends Speaker {
  _FakeSpeaker()
    : super(
        engineFactory: (Voice _) async => throw UnimplementedError(),
        player: _NoPlayer(),
      );
  @override
  bool get ready => true;
  @override
  bool get loading => false;
  @override
  Future<void> speak(String text) async {}
}

class _NoPlayer implements WavPlayer {
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    // A duration lets route transitions finish, so covered screens go offstage.
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  late AppDatabase db;
  late ListsRepository repo;
  var pickerOpened = 0;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory(), loadSeed: fixtureSeed);
    repo = ListsRepository(db);
    pickerOpened = 0;
  });

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.runAsync(() => repo.addSeedLists('hu'));
    tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      MondomApp(
        home: SpeakingScreen(
          speaker: _FakeSpeaker(),
          repo: repo,
          voice: () => Voice.system('hu'),
          onOpenVoicePicker: () async => pickerOpened++,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> openLists(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Menü'));
    await settle(tester);
    await tester.tap(find.text('Listák'));
    await settle(tester);
  }

  Future<List<SentenceList>> lists(WidgetTester tester) async =>
      (await tester.runAsync(() => repo.watchLists().first))!;

  testWidgets('hamburger → drawer → Hang és nyelv opens the picker', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.byTooltip('Szerkesztés'), findsNothing);
    expect(find.byTooltip('Beállítások'), findsNothing); // no cog
    await tester.tap(find.byTooltip('Menü'));
    await settle(tester);
    expect(find.text('Listák'), findsOneWidget);
    expect(find.text('Android alapértelmezett · Magyar'), findsOneWidget);
    await tester.tap(find.text('Hang és nyelv'));
    await settle(tester);
    expect(pickerOpened, 1);
    expect(find.text('Listák'), findsNothing); // drawer closed
    await finish(tester);
  });

  testWidgets('drawer order: Listák, Beállítások, Hang és nyelv', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Menü'));
    await settle(tester);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Listák'), lessThan(y('Beállítások')));
    expect(y('Beállítások'), lessThan(y('Hang és nyelv')));
    await finish(tester);
  });

  testWidgets('Beállítások: the Hangosítás switch persists speechBoost', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Menü'));
    await settle(tester);
    await tester.tap(find.text('Beállítások'));
    await settle(tester);
    expect(find.text('Beszéd'), findsOneWidget);
    expect(find.text('Riasztás'), findsWidgets);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );
    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getBool('speechBoost'), false);
    expect(
      find.text('Kipróbálás', skipOffstage: false),
      findsOneWidget,
    ); // alarm controls still there
    await finish(tester);
  });

  testWidgets('leaving via the menu never refocuses the text field', (
    tester,
  ) async {
    bool fieldFocused() => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;
    List<String> inputCalls() =>
        tester.testTextInput.log.map((c) => c.method).toList();

    await pumpScreen(tester);
    await tester.tap(find.byType(TextField));
    await settle(tester);
    expect(fieldFocused(), isTrue);

    // Drawer dismissed by tapping the scrim.
    await tester.tap(find.byTooltip('Menü'));
    await settle(tester);
    tester.testTextInput.log.clear();
    await tester.tapAt(const Offset(780, 300));
    await settle(tester);
    expect(find.text('Listák'), findsNothing);
    expect(fieldFocused(), isFalse);
    expect(inputCalls(), isNot(contains('TextInput.show')));

    // Back from a page opened from the drawer.
    await tester.tap(find.byType(TextField));
    await settle(tester);
    await openLists(tester);
    tester.testTextInput.log.clear();
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(fieldFocused(), isFalse);
    expect(inputCalls(), isNot(contains('TextInput.show')));
    expect(tester.testTextInput.isVisible, isFalse);
    await finish(tester);
  });

  testWidgets('edge swipe does not open the drawer', (tester) async {
    await pumpScreen(tester);
    await tester.dragFrom(const Offset(2, 300), const Offset(300, 0));
    await settle(tester);
    expect(find.text('Hang és nyelv'), findsNothing);
    await finish(tester);
  });

  testWidgets('back from the overview lands on the speaking screen', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openLists(tester);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('Hang és nyelv'), findsNothing); // drawer not open
    expect(find.byTooltip('Menü'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('lists overview shows all lists, marks the open one', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openLists(tester);
    expect(find.text('Alap'), findsOneWidget);
    expect(find.text('Példa beszélgetés'), findsOneWidget);
    expect(find.text('Előzmények'), findsOneWidget);
    expect(find.text('Most megnyitva'), findsOneWidget);
    expect(
      find.text('Kitűzve'),
      findsNWidgets(3),
    ); // Alap + Riasztás + Előzmények
    await finish(tester);
  });

  testWidgets('new conversation list is created pinned', (tester) async {
    await pumpScreen(tester);
    await openLists(tester);
    await tester.tap(find.text('Új lista'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Kati');
    await tester.tap(find.text('Beszélgetés').last);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Létrehozás'));
    await settle(tester);
    final created = (await lists(tester)).firstWhere((l) => l.title == 'Kati');
    expect(created.kind, ListKind.conversation);
    expect(created.pinned, isTrue);
    await finish(tester);
  });

  testWidgets('delete asks first; cancel keeps the list', (tester) async {
    await pumpScreen(tester);
    await openLists(tester);
    Future<void> askDelete() async {
      await tester.tap(find.byTooltip('További műveletek').first);
      await settle(tester);
      await tester.tap(find.text('Törlés'));
      await settle(tester);
    }

    await askDelete();
    expect(find.textContaining('Törlöd a(z) „Alap” listát'), findsOneWidget);
    await tester.tap(find.text('Mégse'));
    await settle(tester);
    expect((await lists(tester)).any((l) => l.title == 'Alap'), isTrue);

    await askDelete();
    await tester.tap(find.widgetWithText(FilledButton, 'Törlés'));
    await settle(tester);
    expect((await lists(tester)).any((l) => l.title == 'Alap'), isFalse);
    await finish(tester);
  });

  testWidgets('history has no rename or delete', (tester) async {
    await pumpScreen(tester);
    await openLists(tester);
    await tester.tap(find.byTooltip('További műveletek').last);
    await settle(tester);
    expect(find.text('Átnevezés'), findsNothing);
    expect(find.text('Törlés'), findsNothing);
    expect(find.text('Kitűzés megszüntetése'), findsOneWidget);
    await finish(tester);
  });

  Future<void> openSheet(WidgetTester tester, int index) async {
    await tester.tap(find.byTooltip('További műveletek').at(index));
    await settle(tester);
  }

  testWidgets('restore lists lives in the app bar menu, with a snackbar', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openLists(tester);
    const restore = 'Alapértelmezett listák visszaállítása';
    final menu = find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip('További műveletek'),
    );
    expect(menu, findsNothing); // nothing missing: no menu at all
    expect(find.text(restore), findsNothing);

    final example = (await lists(tester))
        .firstWhere((l) => l.seedKey == 'example-conversation');
    await tester.runAsync(() => repo.deleteList(example.id));
    await settle(tester);
    expect(menu, findsOneWidget);

    await tester.tap(menu);
    await settle(tester);
    await tester.tap(find.text(restore));
    await settle(tester);
    expect(find.text('1 lista visszaállítva'), findsOneWidget);
    expect(menu, findsNothing);
    expect(find.text('Példa beszélgetés'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('sheet: restore sentences only when some are missing', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openLists(tester);
    const restore = 'Alapértelmezett mondatok visszaállítása';
    await openSheet(tester, 0);
    expect(find.text(restore), findsNothing);
    await tester.tapAt(const Offset(5, 5)); // dismiss the sheet
    await settle(tester);

    final alap = (await lists(tester)).firstWhere((l) => l.title == 'Alap');
    final first = (await tester.runAsync(
      () => repo.watchSentences(alap.id).first,
    ))!.first;
    await tester.runAsync(() => repo.deleteSentence(first.id));
    await settle(tester);

    await openSheet(tester, 0);
    expect(find.text(restore), findsOneWidget);
    await tester.tap(find.text(restore));
    await settle(tester);
    expect(find.text('1 mondat visszaállítva'), findsOneWidget);
    final back = (await tester.runAsync(
      () => repo.watchSentences(alap.id).first,
    ))!;
    expect(back.first.body, first.body);
    await finish(tester);
  });

  testWidgets('sheet: history never has restore; Újrakezdés only for '
      'conversations', (tester) async {
    await pumpScreen(tester);
    await openLists(tester);
    await openSheet(tester, 2); // history
    expect(find.text('Alapértelmezett mondatok visszaállítása'), findsNothing);
    expect(find.text('Újrakezdés'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    await openSheet(tester, 0); // everyday
    expect(find.text('Újrakezdés'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    final conv = (await lists(tester))
        .firstWhere((l) => l.seedKey == 'example-conversation');
    final sid = (await tester.runAsync(
      () => repo.watchSentences(conv.id).first,
    ))!.first.id;
    await tester.runAsync(() => repo.setSaid(sid, true));
    await openSheet(tester, 1);
    await tester.tap(find.text('Újrakezdés'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Újrakezdés'));
    await settle(tester);
    final after = (await tester.runAsync(
      () => repo.watchSentences(conv.id).first,
    ))!;
    expect(after.any((x) => x.said), isFalse);
    await finish(tester);
  });

  Future<void> openNewListDialog(WidgetTester tester) async {
    await tester.tap(find.text('Új lista'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Teszt');
  }

  testWidgets('new list dialog: untouched color = automatic pick', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openLists(tester);
    final expected = (await tester.runAsync(repo.nextColorForNewList))!;
    await openNewListDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Létrehozás'));
    await settle(tester);
    final created = (await lists(tester)).firstWhere((l) => l.title == 'Teszt');
    expect(created.color, expected);
    await finish(tester);
  });

  testWidgets('new list dialog: pick green, or Nincs', (tester) async {
    await pumpScreen(tester);
    await openLists(tester);
    await openNewListDialog(tester);
    await tester.tap(find.byKey(const ValueKey('swatch-green')));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Létrehozás'));
    await settle(tester);
    expect(
      (await lists(tester)).firstWhere((l) => l.title == 'Teszt').color,
      'green',
    );
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    await openNewListDialog(tester);
    await tester.enterText(find.byType(TextField), 'Semleges');
    await tester.tap(find.byKey(const ValueKey('swatch-none')));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Létrehozás'));
    await settle(tester);
    expect(
      (await lists(tester)).firstWhere((l) => l.title == 'Semleges').color,
      isNull,
    );
    await finish(tester);
  });

  testWidgets('overview ⋮ → Szín → green saves it; Nincs sets null', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openLists(tester);
    String? colorOf(List<SentenceList> ls) =>
        ls.firstWhere((l) => l.title == 'Alap').color;
    expect(colorOf(await lists(tester)), 'blue');

    await openSheet(tester, 0);
    await tester.tap(find.text('Szín'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('swatch-green')));
    await settle(tester);
    expect(find.text('Lista színe'), findsNothing); // closed at once
    expect(colorOf(await lists(tester)), 'green');

    await openSheet(tester, 0);
    await tester.tap(find.text('Szín'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('swatch-none')));
    await settle(tester);
    expect(colorOf(await lists(tester)), isNull);
    await finish(tester);
  });

  testWidgets('history sheet has no Szín row', (tester) async {
    await pumpScreen(tester);
    await openLists(tester);
    await openSheet(tester, 3);
    expect(find.text('Szín'), findsNothing);
    await finish(tester);
  });

  testWidgets('app bar shows the open list; rows use its color', (
    tester,
  ) async {
    await pumpScreen(tester);
    Finder inAppBar(String text) =>
        find.descendant(of: find.byType(AppBar), matching: find.text(text));
    expect(inAppBar('Alap'), findsOneWidget);
    expect(inAppBar('Mondom'), findsNothing);

    Color? rowColor() => tester
        .widget<Material>(
          find
              .ancestor(
                of: find.text('Kérek vizet!'),
                matching: find.byType(Material),
              )
              .first,
        )
        .color;
    expect(rowColor(), listColorFor('blue', Brightness.light)!.row);

    final alap = (await lists(tester)).firstWhere((l) => l.title == 'Alap');
    await tester.runAsync(() => repo.setColor(alap.id, 'green'));
    await settle(tester);
    expect(rowColor(), listColorFor('green', Brightness.light)!.row);

    // Switching lists changes the title.
    await tester.tap(
      find.descendant(
        of: find.byType(ChoiceChip),
        matching: find.text('Előzmények'),
      ),
    );
    await settle(tester);
    expect(inAppBar('Előzmények'), findsOneWidget);
    await finish(tester);
  });
}
