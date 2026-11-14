[English: README.md](README.md)

# Mondom

A Mondom egy ingyenes, nyílt forráskódú beszédsegítő Androidra. Olyan felnőtteknek készült, akik írni-olvasni tudnak, de elvesztették a beszédüket vagy éppen elveszítik: ALS (főleg bulbáris), agyvérzés, gégeeltávolítás, SM. Beírod a szöveget vagy rábböksz egy kész mondatra, a telefon pedig kimondja. Elsősorban magyarul működik, de más nyelveken is használható.

<!-- Képernyőképek: a fájlokat az ember teszi be. -->
<!-- ![Beszédképernyő](docs/screenshots/speaking.png) -->
<!-- ![Listák](docs/screenshots/lists.png) -->
<!-- ![Hangválasztó](docs/screenshots/voices.png) -->

## Miért készült

- Ingyenes, reklám nélkül, fiók nélkül. Semmi nincs fizetés vagy bejelentkezés mögé zárva.
- Egy hang letöltése után internet nélkül is működik. Az adataid a telefonodon maradnak.
- Természetes hangok, anélkül hogy hangmotort kellene beállítanod: telepíted az alkalmazást, kiválasztasz egy hangot egy rövid listából, és előtte meghallgathatod a mintáját.
- Minden egy telepítésben: mondatok, hangok, felvételek, mentés.

## Mit tud

- **Mondatlisták.** Ami egyetlen koppintással kimondható, az egy lista egy sora, egész mondatokkal. A mindennapi magyar mondatok előre fel vannak töltve, a saját listáidat (például „Orvos”, „Éjszaka”) te adod hozzá.
- **Szabad szöveg.** A beírómező és a Mondom gomb mindig a főképernyőn van. Ha ugyanazzal a szöveggel újra megnyomod a gombot, azonnal megismétli.
- **Mondat összerakása darabokból.** Egy gombnyomással bármelyik lista (vagy az előzmények) egy sorát kimondás helyett a beírómezőbe töltheted, így a mentett részeket gépelt szavakkal kiegészítve mondhatod ki.
- **Előzmények.** Az utolsó 30 kimondott szöveg: újra kimondhatod, vagy elmentheted egy listába.
- **Előre elkészített beszélgetések.** A mondatokat előre megírhatod, például a látogatás előtti este, aztán a „Következő” gombbal egyenként mondod ki őket. A már elhangzott mondatok szürkék lesznek.
- **Saját hangú felvételek.** Bármelyik mondathoz felveheted a saját hangodat, ezt játssza le a gép a szintetikus hang helyett, internet nélkül is. A biztonsági mentés fájl a listáidat és a felvételeidet is megőrzi.
- **Riasztás.** Egy sor lehet riasztás: szirénahang vagy csengő, esetleg egy mondat, amely hangosan, a telefon ébresztési hangerején szól.
- **Hangok.**
  - Offline Piper-hangok (férfi és női magyar hang, más nyelveken is), az alkalmazásból letöltve, egyszer.
  - A telefon saját hangja („Android alapértelmezett”), amely azonnal használható.
  - Ha akarod, a saját ElevenLabs-fiókod (lásd: [ElevenLabs](#elevenlabs)). Egy egész lista elmenthető felvételekként az ElevenLabs-hangodon, és ezek a felvételek internet nélkül is megmaradnak, akkor is, ha a kulcsot már letörölted.
- **Beszédsebesség** hangonként, és opcionális hangosítás a telefon hangszórójához.

## Használati útmutató

Képernyőképek: `docs/screenshots/*.png` (később kerülnek ide).

1. **Első indítás.** A Mondom hangot kér választani. Az „Android alapértelmezett” azonnal működik, a többi hangot egyszer le kell tölteni (kb. 60 MB, érdemes wifin), utána internet nélkül is megy. A sor lejátszó gombjával előbb meghallgathatod a mintát. A hangot később is cserélheted: ☰ → „Hang és nyelv”.
2. **Mondat kimondása.** Koppints egy mondatra, és kimondja. Ha még egyszer rákoppintasz, megismétli. A felül lévő listagombokkal a kitűzött listák között váltasz, a ▾ gombbal az összes listát látod.
3. **Gépelés.** Írj a képernyő alján lévő mezőbe, és nyomd meg a Mondom gombot. A szöveg a mezőben marad, így újabb nyomásra megismétli; az ✕ törli. A jobb felső sarokban, a listagombok fölött lévő ↓ gombbal a következő megkoppintott sort kimondás helyett a mezőbe töltheted, így mondatot rakhatsz össze darabokból.
4. **Listák szerkesztése.** ☰ → „Listák”. Itt létrehozhatsz, átnevezhetsz, színezhetsz, kitűzhetsz és átrendezhetsz listákat; egy lista megnyitásával a mondatait szerkeszted. A szerkesztés szándékosan két koppintásra van, hogy egy véletlen érintés beszélgetés közben ne vigyen szerkesztőképernyőre.
5. **Beszélgetés előkészítése.** A „Listák” között hozz létre beszélgetés típusú listát, és írj be soronként egy mondatot. A látogatáskor nyisd meg, és a „Következő” gombbal mondd ki a soron következő, még el nem hangzott mondatot, vagy koppints bármelyik sorra.
6. **Saját hang felvétele.** A lista szerkesztőjében a mikrofon gombbal az egész listához, egy sor ⋮ menüjével egyetlen mondathoz vehetsz fel hangot. Koppints a kezdéshez, koppints a leállításhoz, hallgasd meg, majd mentsd. A felvett sorok a te hangodon szólnak a szintetikus helyett.
7. **Biztonsági mentés.** ☰ → „Beállítások” → „Mentés”: készíts mentésfájlt (listák és felvételek), és tedd el Google Drive-ra vagy máshová. A visszaállítás csak hozzáad, a telefonon lévőket sosem írja felül.
8. **Riasztás.** A kitűzött piros „Riasztás” listában vannak a riasztósorok (sziréna, csengő, kürt). A saját sorodat is megjelölheted riasztásnak. Amíg egy riasztás szól, nagy „Leállítás” gomb jelenik meg. A riasztás hangerejét a „Beállítások” között állíthatod.

## ElevenLabs

Az ElevenLabs egy online hangszolgáltatás. A Mondom használni tudja a **saját** ElevenLabs-fiókodat, például a saját hangodról készült másolatot. Ez nem kötelező, alapból ki van kapcsolva, és a Mondom minden más funkciója nélküle is működik. A Mondomnak nincs saját ElevenLabs-fiókja vagy kulcsa, és nem áll kapcsolatban az ElevenLabsszel. Az ElevenLabs időnként ingyenes hangklónozást kínált ALS-es és más beszédet érintő betegséggel élő embereknek; a jelenlegi lehetőségeket keresd az ő weboldalukon.

Az ElevenLabs-hanggal kimondott szövegek az ElevenLabs szervereire kerülnek, és megjelennek az ElevenLabs-előzményeidben. Ehhez internet kell.

**Beállítás**
1. Az ElevenLabs-fiókodban hozz létre egy API-kulcsot (az ElevenLabs weboldalán: Developers → API Keys). Ezeket a jogosultságokat add neki: **Text to Speech** és **Voices (olvasás)**. Nem kötelező a **User (olvasás)**, ettől a Mondom ki tudja írni a megmaradt krediteket.
2. A Mondomban nyisd meg: ☰ → „Hang és nyelv”. Az ElevenLabs szakaszban válaszd az „ElevenLabs beállítása” gombot, másold be a kulcsot, és mentsd. A Mondom ellenőrzi, hogy működik-e.
3. Válaszd ki a fiókod egyik hangját a listából. A hangok név szerint szerepelnek; a saját klónod is köztük van.
4. Válaszd ki a **tartalék hangot**: egy offline hangot, amely akkor szólal meg, ha az ElevenLabs nem érhető el (nincs internet, elfogyott a kredit, érvénytelen a kulcs). A Mondom így sosem marad néma; a felső sávban egy felhő ikon jelzi, ha a tartalék hang szólt, és megmondja, miért.

**Jó tudni**
- **A már kimondott mondatokat** a telefon megőrzi (gyorsítótár, legfeljebb 100 MB, a legrégebben használtak törlődnek először), ezért ezek internet nélkül is az ElevenLabs-hangodon szólnak, és nem fogyasztanak újra krediteket. A riasztósorok sosem várnak a hálózatra.
- **„Kifejezőbb hang”**: lassabban induló, kifejezőbb modellt használ, és kétszer annyi kreditbe kerül.
- **Egy lista felvételeinek elkészítése.** A lista szerkesztőjében a felhő gombbal a lista minden sorát elmentheted felvételként az ElevenLabs-hangodon. A Mondom előtte kiírja a becsült költséget. Azokat a sorokat, amelyekhez saját felvétel tartozik, csak akkor cseréli le, ha te is úgy akarod. Egyetlen sorhoz használd a ⋮ menü „ElevenLabs-hangon mentés” pontját; mentés előtt meghallgathatod.
- **A generált felvételek végleg megmaradnak.** Közönséges felvételek: internet nélkül is lejátszódnak, benne vannak a biztonsági mentésben, és nem érinti őket a kulcs törlése, egy lejárt előfizetés vagy más hang kiválasztása. A későbbi sebesség- vagy modellváltoztatást nem követik.
- **A kulcs törlése** csak a gyorsítótárat üríti. A listákba mentett felvételek megmaradnak, a többi mondatot ezután a tartalék hang mondja ki.

## Telepítés

- Google Play: _a link hamarosan_ (helyőrző).
- APK-fájlok: [GitHub Releases](https://github.com/stamasg84/mondom/releases). Válaszd a telefonodnak megfelelő fájlt (a legtöbb mai telefonhoz az `arm64-v8a` való).
- Fordítás forrásból (Flutter): `flutter build apk --split-per-abi`

## Adatkezelés

A Mondomnak nincs fiókja, nincs reklámja és nem követ, minden, amit írsz és felveszel, a telefonodon marad. A hálózatot csak az opcionális hangletöltésekhez használja, és ha bekapcsolod, az ElevenLabshez. A részletek: [PRIVACY.md](PRIVACY.md).

## Licenc

GPL-3.0, lásd: [LICENSE](LICENSE). A hangoknak saját licencük van, ezek hangonként a [voices/catalog.json](voices/catalog.json) fájlban és az alkalmazás „Névjegy” képernyőjén találhatók.

## Visszajelzés

Hibajelentés, ötlet, kérdés: [GitHub issues](https://github.com/stamasg84/mondom/issues).
