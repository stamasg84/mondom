[English: README.md](README.md)

# Mondom

A Mondom ingyenes, nyílt forráskódú beszédsegítő alkalmazás Androidra. Olyan felnőtteknek készült, akik tudnak írni és olvasni, de a beszédük elveszett vagy fokozatosan romlik, például ALS (különösen bulbáris ALS), stroke, gégeeltávolítás vagy SM miatt. Beírod, amit mondani szeretnél, vagy rákoppintasz egy kész mondatra, és a telefon kimondja. Bármilyen nyelven használható, amelyen a telefon hangja beszélni tud; maga az alkalmazás magyar és angol nyelvű.

## Miért készült

- Ingyenes, nincs benne reklám, és nem kell hozzá fiók. Egyetlen funkciója sincs fizetéshez vagy regisztrációhoz kötve.
- Ha egyszer letöltöttél egy hangot, internet nélkül is működik. Az adataid a telefonodon maradnak.
- Természetes hangok bonyolult beállítás nélkül: telepíted az alkalmazást, egy rövid listából kiválasztasz egy hangot, és előtte meg is hallgathatod.
- Minden egy helyen van: mondatok, hangok, felvételek, biztonsági mentés.

## Mit tud?

- **Mondatlisták.** Mindent, amit egy koppintással ki akarsz mondani, egész mondatként tárolhatsz listákban. A mindennapi mondatok előre be vannak töltve (magyarul, angolul és svédül), és saját listákat is készíthetsz (például „Orvos” vagy „Éjszaka”).
- **Szabad szöveg.** A szövegmező és a Mondom gomb mindig ott van a főképernyőn. Ha a szöveg változatlan, a gomb újbóli megnyomására azonnal megismétli.
- **Mondatok összerakása.** Bármelyik lista vagy az előzmények egy sorát kimondás helyett betöltheted a szövegmezőbe, így a kész mondatrészeket kiegészítheted, mielőtt kimondod őket.
- **Előzmények.** Az utolsó 30 kimondott szöveg. Bármelyiket újra kimondhatod, vagy elmentheted egy listába.
- **Előre megírt beszélgetések.** A mondatokat előre megírhatod, például egy látogatás előtti este, aztán a „Következő” gombbal egyenként mondhatod ki őket. A már elhangzott mondatok kiszürkülnek.
- **Felvételek a saját hangodon.** Bármelyik mondatot felveheted a saját hangodon, és a Mondom ezt játssza le a gépi hang helyett, internet nélkül is. A biztonsági mentés a listákat és a felvételeket is tartalmazza.
- **Riasztás.** Bármelyik sorból lehet riasztás: sziréna, csengő, vagy egy mondat, amely hangosan, az ébresztő hangerején szól.
- **Hangok.**
  - Piper-hangok (magyar férfi- és női hang, valamint más nyelvek hangjai): az alkalmazásban egyszer kell letölteni őket, utána internet nélkül is működnek.
  - A telefon saját hangja („Android alapértelmezett”), amely azonnal használható.
  - Ha szeretnéd, a saját ElevenLabs-fiókod hangjai (lásd: [ElevenLabs](#elevenlabs)). Egy teljes listát felvételként elmenthetsz az ElevenLabs-hangodon, és ezek a felvételek internet nélkül is megmaradnak, akkor is, ha a kulcsot később törlöd.
- **Beszédsebesség** hangonként külön, valamint igény szerint hangosítás a telefon hangszórójához.

## Használati útmutató

1. **Első indítás.** A Mondom először azt kéri, hogy válassz hangot. Az „Android alapértelmezett” azonnal működik, a többi hangot egyszer le kell tölteni (egyenként kb. 60 MB, érdemes wifin), utána internet nélkül is szólnak. A sor lejátszás gombjával előbb meghallgathatod a hangmintát. A hangot később is lecserélheted: ☰ → „Hang és nyelv”.
2. **Mondat kimondása.** Koppints egy mondatra, és a Mondom kimondja. Újabb koppintásra megismétli. A fenti listagombokkal a kitűzött listák között válthatsz, a ▾ gomb az összes listát megmutatja.
3. **Gépelés.** Írd be a szöveget a képernyő alján lévő mezőbe, és nyomd meg a Mondom gombot. A szöveg a mezőben marad, így újabb gombnyomásra megismétli; az ✕ törli. A jobb felső sarokban, a listagombok fölött lévő ↓ gomb megnyomása után a következő sor, amelyre koppintasz, nem hangzik el, hanem bekerül a szövegmezőbe. Így darabokból is összerakhatsz egy mondatot.
4. **Listák szerkesztése.** ☰ → „Listák”. Itt listákat hozhatsz létre, átnevezheted, kiszínezheted, kitűzheted és átrendezheted őket; egy listát megnyitva a mondatait szerkesztheted. A szerkesztés szándékosan két koppintásnyira van, hogy beszélgetés közben egy véletlen érintés ne vigyen át a szerkesztőbe.
5. **Beszélgetés előkészítése.** A „Listák” képernyőn hozz létre egy beszélgetés típusú listát, és írj bele soronként egy mondatot. A látogatáskor nyisd meg a listát: a „Következő” gomb a soron következő, még el nem hangzott mondatot mondja ki, de bármelyik sorra rá is koppinthatsz.
6. **Felvétel a saját hangodon.** A lista szerkesztőjében a mikrofon gombbal az egész lista mondatait, egy sor ⋮ menüjéből pedig csak azt az egy mondatot veheted fel. Koppints a felvétel indításához, majd újra a leállításához, hallgasd meg, és mentsd el. A felvett sorokat ezután a saját hangodon hallod a gépi hang helyett.
7. **Biztonsági mentés.** ☰ → „Beállítások” → „Mentés”: itt készíthetsz mentésfájlt a listáidról és a felvételeidről, amelyet a Google Drive-on vagy máshol tárolhatsz. A visszaállítás csak hozzáadja a mentés tartalmát, a telefonon lévő adatokat soha nem írja felül.
8. **Riasztás.** A kitűzött, piros „Riasztás” listában találod a riasztásokat (sziréna, csengő, duda). Bármelyik saját sorodat is megjelölheted riasztásként. Amíg a riasztás szól, egy nagy „Leállítás” gomb jelenik meg. A riasztás hangerejét a „Beállítások” között állíthatod be.
9. **Sebesség és hangerő.** ☰ → „Beállítások” → „Beszéd sebessége”: itt lassíthatod vagy gyorsíthatod a beszédet. A sebességet a Mondom minden hanghoz külön megjegyzi, a „Visszaállítás” pedig visszaállítja az eredetit. A „Hangosítás” felerősíti a beszédet a telefon hangszóróján; ha torzan szól, kapcsold ki.

## ElevenLabs

Az ElevenLabs egy online hangszolgáltatás. A Mondom a **saját** ElevenLabs-fiókod hangjait is tudja használni, például egy, a saját hangodról készült klónt. Ez nem kötelező, alapból ki van kapcsolva, és a Mondom minden más funkciója nélküle is működik. A Mondomnak nincs saját ElevenLabs-fiókja vagy -kulcsa, és nem áll kapcsolatban az ElevenLabsszel. Az ElevenLabs időnként ingyenes hangklónozást kínált ALS-sel vagy más, a beszédet érintő betegséggel élőknek; a mostani lehetőségekről a weboldalukon tájékozódhatsz.

Az ElevenLabs-hanggal kimondott szövegeket a Mondom elküldi az ElevenLabs szervereire, és ezek megjelennek az ElevenLabs-fiókod előzményeiben. Ehhez internetkapcsolat kell.

**Beállítás**
1. Az ElevenLabs weboldalán, a fiókodban hozz létre egy API-kulcsot (Developers → API Keys), és add meg neki ezeket a jogosultságokat: **Text to Speech** és **Voices (Read)**. A **User (Read)** nem kötelező, de ha megadod, a Mondom ki tudja írni, mennyi kredited maradt.
2. A Mondomban nyisd meg ezt: ☰ → „Hang és nyelv”. Az ElevenLabs részben koppints az „ElevenLabs beállítása” gombra, illeszd be a kulcsot, és mentsd el. A Mondom ellenőrzi, hogy a kulcs működik-e.
3. Válaszd ki a listából a fiókod egyik hangját. A hangok a nevükkel szerepelnek, a saját klónod is köztük van.
4. Válassz **tartalék hangot**: ez egy offline hang, amely akkor szólal meg, ha az ElevenLabs nem érhető el (nincs internet, elfogyott a kredit, vagy érvénytelen a kulcs). Így a Mondom sosem marad néma. Ha a tartalék hang szólalt meg, ezt egy felhő ikon jelzi a felső sávban, és rákoppintva megtudod, miért.

**Jó tudni**
- **A már kimondott mondatokat** a telefon megjegyzi (legfeljebb 100 MB-nyit; ha betelik, a legrégebben használtak törlődnek először). Ezek internet nélkül is az ElevenLabs-hangodon szólnak, és nem fogyasztanak újra kreditet. A riasztások soha nem várnak a hálózatra.
- **„Kifejezőbb hang”**: kifejezőbb, de lassabban induló modellt használ, és kétszer annyi kreditbe kerül.
- **Felvételek készítése egy egész listához.** A lista szerkesztőjében a felhő gombbal a lista minden sorát elmentheted felvételként az ElevenLabs-hangodon. A Mondom előtte kiírja, nagyjából mennyi kreditbe kerül. A saját hangodon felvett sorokat csak akkor cseréli le, ha ezt kifejezetten kéred. Egyetlen sorhoz a sor ⋮ menüjében válaszd az „ElevenLabs-hangon mentés” pontot; mentés előtt meg is hallgathatod.
- **Az így készült felvételek végleg megmaradnak.** Ugyanolyan felvételek, mint a többi: internet nélkül is lejátszhatók, bekerülnek a biztonsági mentésbe, és nem tűnnek el akkor sem, ha törlöd a kulcsot, lejár az előfizetésed, vagy másik hangot választasz. Ha később sebességet vagy modellt váltasz, az rájuk már nem hat.
- **A kulcs törlésekor** csak a megjegyzett mondatok törlődnek. A listákba mentett felvételek megmaradnak, minden más mondatot ezután a tartalék hang mond ki.

## Telepítés

- Google Play: _a link hamarosan_ (helyőrző).
- APK-fájlok: [GitHub Releases](https://github.com/stamasg84/mondom/releases). Válaszd a telefonodhoz illő fájlt (a legtöbb mai telefonhoz az `arm64-v8a` kell).
- Fordítás forráskódból (Flutter): `flutter build apk --split-per-abi`

## Adatkezelés

A Mondom nem kér fiókot, nem jelenít meg reklámot és nem követ téged: minden, amit beírsz vagy felveszel, a telefonodon marad. Internetet csak a választható hangletöltésekhez használ, és az ElevenLabshez, ha bekapcsolod. Részletek: [PRIVACY.md](PRIVACY.md).

## Licenc

GPL-3.0, lásd: [LICENSE](LICENSE). A hangoknak saját licencük van; ezek hangonként a [voices/catalog.json](voices/catalog.json) fájlban és az alkalmazás „Névjegy” képernyőjén olvashatók.

## Visszajelzés

Hibajelentés, ötlet, kérdés: [GitHub issues](https://github.com/stamasg84/mondom/issues).
