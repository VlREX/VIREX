# VIREX Test Studio 2.0.1

[**Hordozható Windows ZIP letöltése**](https://github.com/VlREX/VIREX/releases/download/studio-stable/VIREX-Test-Studio-2.0.1-Windows.zip) · [GitHub-kiadás](https://github.com/VlREX/VIREX/releases/tag/studio-stable)

Magyar nyelvű Windows-alkalmazás Rust-projektek teszteléséhez. A kezdőképernyőn a **Belobug · VIctory AMD** cél van kiválasztva. A Studio lekéri az `a-publier` ágat, külön munkapéldányban futtatja a kiválasztott Cargo-ellenőrzéseket, és a riportba írja a ténylegesen tesztelt commitot. A saját fejlesztői példányodat a **Helyi projekt megnyitása** gombbal tudod tesztelni.

## Indítás a forráscsomagból

**Git-klónból** lépj a `tools/virex-test-studio` könyvtárba. Első alkalommal
az alábbi két paranccsal állítsd elő az alkalmazás ikonjait. A hordozható
Windows ZIP már tartalmazza az ikonokat.

```powershell
python -m pip install Pillow==12.3.0
python .\packaging\make_icons.py
```

1. Csomagold ki a teljes ZIP-et egy saját mappába. A `START-VIREX.cmd` és a mellette lévő PowerShell-fájlok maradjanak egy könyvtárban.
2. A kiadott hordozható ZIP-ben indítsd el a **`VIREX-Test-Studio.exe`** fájlt. A forrásból közvetlenül a `START-VIREX.cmd` is indítja ugyanazt a felületet. A futtatáshoz Windows PowerShell 5.1 és a Windows beépített .NET Framework környezete kell. Ha a Windows megjelöli az internetről letöltött fájlokat, a megbízhatónak ítélt ZIP tulajdonságainál, kicsomagolás előtt oldható fel a tiltás. Az indítók RemoteSigned házirendet kérnek a saját folyamatukra. Szervezeti házirend esetén az ott engedélyezett módon indítsd az alkalmazást.
3. A teszteléshez legyen a PATH-on a Cargo és a Rust fordító. GitHub-célhoz Git is kell. A Clippy jelölőnégyzethez a használt Rust-toolchain Clippy komponense szükséges. A Belobug Windows-buildjéhez a repo által rögzített Rust-toolchain és az MSVC C++ buildeszközök szükségesek.
4. Első Belobug-próbának elég a **Fordításellenőrzés**. Kapcsold ki a munkaterület-teszteket és a Clippyt, ha csak a buildkörnyezetet szeretnéd ellenőrizni. Kattints a **Futtatás** gombra, nézd át a cél URL-jét és az ágat, majd erősítsd meg. A függőségek és a toolchain első letöltése időt igényelhet.
5. A **Napló** mutatja az aktív parancsot. Befejezés után a **Riport** fülön látható az összesítés. A **Riportmappa** gombbal megnyithatók a pontos parancsok, kilépési kódok és a nyers kimenetek. Az **F1** ezt a fájlt nyitja meg.

## 2.0.1 változások

- GPT-only felület és API-híd; korábbi mentett riportok megmaradnak.
- A futtató saját hibáját `RUNNER_ERROR` jelöli, nem a Rust-teszt bukásaként.
- A release pipeline Windows integrációs tesztet és verziózott Setup.exe-t készít; a már telepített 2.0.0 Frissítés gomb ezt a fájlt keresi.
- A GitHub-források tesztelése továbbra is a felhasználó jogaival fut, nem sandboxban. A Job Object nem biztonsági határ; a folyamatindítás és a hozzárendelés közötti versenyhelyzet még fennáll.
- A korábbi ellenőrzési állapot történeti, nem 2.0.1-es futási bizonyíték.

## Belobug és saját fejlesztői ág

| Mit szeretnél tesztelni? | Mit válassz? | Mi kerül a riportba? |
| --- | --- | --- |
| Belobug közzétett változatát | **Belobug · VIctory AMD**. Minden futás az `a-publier` ágat kéri le. | Repócím, ág, a letöltött és kiválasztott 40 jegyű SHA |
| Saját módosításodat, forkodat vagy fejlesztői ágadat | **Saját Cargo-projekt…**. Válaszd ki a szerkesztett munkapéldány gyökerét, ahol a `Cargo.toml` van. | A tesztelt helyi mappa, az ellenőrzések és az eredmények |
| Egy másik nyilvános GitHub Cargo-projektet | **Másik GitHub-repó…**, majd **GitHub-cím megadása…**. HTTPS-cím és `tulajdonos/repó` alak is használható. | Repócím, `HEAD` és a ténylegesen tesztelt SHA |
| Egy korábbi VIREX mérés megismétlését | A 17 eredeti tesztcél egyike a listában | A presetben rögzített SHA, ág, tesztszűrő és az elérhető benchmark adatai |

Belobug repója a [Belobug/VIctory-Belobug-AMD](https://github.com/Belobug/VIctory-Belobug-AMD). A projekt gyökerében Cargo workspace található. Ha már dolgozol benne, nyisd meg **a saját meglévő mappádat**. A helyi mód az aktuális fájljaiddal fut, a nem commitolt módosításokkal együtt. A Studio ebben a módban nem klónoz, nem kér le ágat és nem vált commitot. Kódírás, commit, push és pull request a megszokott szerkesztődből és Git-kliensedből végezhető.

A távoli GitHub-mód saját klónt használ. Futtatás előtt ellenőrzi a munkafa tisztaságát és az origin címét, majd lekéri a megadott ágat, kiválasztja a `FETCH_HEAD` commitot és kiolvassa a SHA-t. Módosított klónnál a futás leáll. A tesztelendő repó kiválasztása kizárólag a tesztcélra hat. A Studio frissítéseit mindig a **VlREX/VIREX** kiadási csatornáján keresi.

## Ellenőrzések és eredmények

- A helyi és az általános GitHub-mód a repo gyökerében futtatja a `cargo check --workspace`, `cargo test --workspace -- --nocapture` és `cargo clippy --workspace --all-targets -- -D warnings` parancsok kiválasztott részét. Meglévő `Cargo.lock` mellett `--locked` kapcsolót ad hozzá. Lockfájl nélkül a Cargo létrehozhatja azt. A helyi módban a Cargo szokásos célmappája vagy az indításkor örökölt `CARGO_TARGET_DIR` érvényes.
- A **Tesztek háromszor** a kiválasztott teszteket ismétli. A fordításellenőrzés, a Clippy és a benchmark egyszer fut. A tesztlépés PASS állapotához legalább egy sikeres tesztet is látni kell a Cargo kimenetében.
- A **Teljes crate-teszt**, a **WARP** és a célhoz kötött **Benchmark** a korábbi, rögzített VIREX-profiloknál használható. A távoli és a helyi munkaterület-teszt az egész Cargo-workspace-re vonatkozik. A grafikus fülön megjelenő szintetikus mérések időegysége soronként látható.
- A futtató minden menet elején ellenőrzi a 0 és 7 kilépési kódot, a két naplócsatornát és egy rövid gyermekfolyamatfa leállítását. A **Leállítás** a futó lépés Windows Job Objectjének megszakítását kéri. A Studio megvárja a folyamatfa és a naplócsatornák lezárását. Ha ez nem igazolható, hibát jelez, és újraindítást kér.
- A **Riport másolása** működő futás után a rövid, megosztható szöveget másolja. Az AI Review fülön betöltheted a riportot, szerkesztheted, átmásolhatod közvetlenül a ChatGPT-be, majd helyben mentheted a GPT válaszát. Másik AI-szolgáltató nem szükséges. A külön `START-AI-REVIEW.cmd` az opcionális, kizárólag OpenAI API-hidat indítja. Ahhoz Python 3.9+, szolgáltatói kulcs és hívásonkénti megerősítés szükséges.
- A Studio célja a fejlesztői validáció. A játék futtatása, a renderer kapcsolói és az FPS-mérés a Belobug projekt saját eszközeihez tartoznak. Játékadatot a Studio nem csomagol.

## Adatok és telepítés

| Hely | Tartalom |
| --- | --- |
| `%LOCALAPPDATA%\VIREX Test Studio\repo` és `target` | Az 1.3.1-ből örökölt, rögzített VIREX-célok klónja és buildcache-e |
| `%LOCALAPPDATA%\VIREX Test Studio\repositories\<azonosító>` | Egy kezelt klón GitHub-repónként. Az azonosító a kisbetűsített tulajdonos/repó név SHA-256 értékének első 24 hexadecimális karaktere. |
| `%LOCALAPPDATA%\VIREX Test Studio\cache\<azonosító>` | A megfelelő GitHub-projekt elkülönített Cargo buildcache-e |
| `%LOCALAPPDATA%\VIREX Test Studio\reports` | Futásonkénti időbélyeges könyvtár. `REPORT.txt`, `FULL-LOG.txt`, `run.json`, nyers stdout és stderr, méréseknél `benchmark.csv` |
| `%LOCALAPPDATA%\VIREX Test Studio\updates` | Ellenőrzött telepítők. A félbemaradt vagy hibás letöltést a letöltő hibakezelője eltávolítja. |
| `%LOCALAPPDATA%\Programs\VIREX Test Studio` | A tervezett telepített program helye. A telepítő csak a programfájlokat kezeli. |

A megosztható szöveges riport a Windows-profilmappa elérési útját maszkolja. A strukturált `run.json`, az egyedi projektnevek és a nyers naplók más helyi adatokat is tartalmazhatnak. A **Riportmappa** gombbal megosztás előtt átnézhetők.

## A Frissítés gomb működése

1. A felhasználó kattintására háttérfolyamatként futó PowerShell-munkamenet kéri le a [studio-stable GitHub Release-t](https://github.com/VlREX/VIREX/releases/tag/studio-stable). A felület az eredményt az alsó állapotsorban jelzi. Ha a csatornát még nem tették közzé vagy nem elérhető, a telepített verzió használható tovább.
2. A kliens a megadott címkéjű stabil kiadás feltöltött `VIREX-Test-Studio-X.Y.Z-Setup.exe` fájljait olvassa. Numerikusan választ verziót, így például a 2.10.0 újabb a 2.9.9-nél. Azonos vagy régebbi verzióhoz nem kínál telepítést.
3. Újabb kiadásnál a felhasználó dönt a letöltésről. A kliens az adott repó kiadásához tartozó pontos asset-URL-t, a méretet és a GitHub által közölt SHA-256 értéket ellenőrzi. A letöltés felső határa 128 MiB. Az ideiglenes fájl csak egyezés után válik telepítővé.
4. A Studio külön megkérdezi, hogy bezárható-e, hogy a szerkesztett AI-vélemények előtte menthetők legyenek. Bezárás után a hash-t ismét ellenőrzi, majd elindítja a Windows-telepítőt. Futó teszt alatt a Frissítés gomb inaktív. Hálózati hiba esetén újra megnyomható.
5. A hash-ellenőrzés a repóbeli bájtok egyezését vizsgálja. A kiadói Authenticode-aláírás külön kiadási művelet.

## Fejlesztői átadás

Az alap a `VIREX_Test_Studio_v1.3.1.zip` helyi forráscsomag volt. A kiinduló ZIP SHA-256 azonosítója `8B6088B169EAF5253351F9C43991DAA41791509F7902D8A5D3EAB2D4B22D9841`. A régi útmutató a `docs/README-HU-1.3.1.txt` fájlban maradt meg történeti hivatkozásként. A mostani változat különálló Windows-kliens. A Belobug és a VlREX tesztelt Rust-kódja kívül van ezen a forráscsomagon.

| Fájl | Felelőssége és a változás oka |
| --- | --- |
| `VIREX-Test-Studio.ps1` | Alkalmazásindítás, 17 eredeti preset, natív folyamatkezelés, lépéssor, leállítás, riport és benchmark. A munkakönyvtár célonként változik. A Cargo kilépése után esetleg életben maradó segédfolyamatok lezárását csak a saját Job Objectben kéri. |
| `Desktop.ps1` | Átméretezhető Windows Forms ablak, magyar vezérlők, célválasztó, kezdőnézet, gyorsbillentyűk, állapotsor, közös gomb- és fülmegjelenés. |
| `Targets.ps1` és `Repository.ps1` | A felület négy célmódja, helyi mappaválasztás, GitHub-cím értelmezése, Belobug alapértelmezés, klónellenőrzés és Cargo-parancsok. A távoli futás a checkout után olvassa ki a commitot és választja meg a lockfájl kezelését. |
| `StudioUpdate.ps1` | GUI nélküli kiadásválasztás, letöltés és hash-ellenőrzés. Itt található a kiadási csatorna címe és a mérethatár. |
| `DesktopUpdate.ps1` | Háttérben indított ellenőrzés, két felhasználói döntés, hibák megjelenítése és az ellenőrzött telepítő indítása. |
| `AI-Review.ps1`, `ai_review.py` | A kézi AI Review felület és az opcionális API-híd. A felület több sorba tördeli a műveletgombokat keskeny ablakban. |
| `VERSION` | Közös háromtagú verzió a felülethez, a riporthoz, a frissítőhöz és a telepítő nevéhez. |
| `packaging/StudioLauncher.cs`, `packaging/Studio.iss`, `packaging/Build.ps1` | Konzolablak nélküli Windows-indító, felhasználónkénti telepítés, Start menü, opcionális asztali ikon, eltávolítás és reprodukálható buildparancs. |
| `tests/Desktop.Tests.ps1`, `tests/Update.Tests.ps1`, `test_ai_review.py` | Natív felületi és Git/Cargo-integrációs próba, frissítési hibautak és a Python-híd öt tesztje. |

### Ellenőrzés fejlesztőként

A következő parancsokat a kicsomagolt projekt gyökerében futtasd. Az asztali próbát külön Windows PowerShell 5.1 folyamatban indítsd. Előtte zárd be a Studiót, mert az egyidejű futást a régi verzióval közös mutex védi.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -STA -File .\tests\Update.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -STA -File .\tests\Desktop.Tests.ps1 -WithCargo
python -m unittest -v test_ai_review
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\packaging\Build.ps1 -ValidateOnly
```

A `-WithCargo` valódi helyi Rust-tesztet futtat szóközös, ékezetes útvonalon. Egy ideiglenes Git-repóval ellenőrzi a Belobug mód klónozását, az `a-publier` ág letöltését, a SHA rögzítését és a módosított munkafa védelmét. Csak a Git hálózati irányát helyettesíti helyi adattal. A felületi Frissítés gomb ellenőrzése szintén rögzített kiadásválasszal történik. A próbák saját ideiglenes adatkönyvtárat használnak. A `-ValidateOnly` lefordítja a .NET Framework indítót és ellenőrzi az Inno-recept összes csomagolandó forrását.

### A hordozható GitHub-kiadás reprodukálása

A Git-klónban generáld az ikonokat az indítási fejezet szerint. A következő parancs lefordítja a Windows-indítót, majd a telepítő receptjéből és a fejlesztői fájlok listájából elkészíti a ZIP-et.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\packaging\Build-Portable.ps1
```

A helyi kimenet az `artifacts\portable` mappába kerül. Az első nyilvános 2.0.0-s csomag Windows GitHub Actions futtatón épült. A kiadási feladat visszatöltötte a közzétett mellékletet, és összehasonlította a build során számolt SHA-256 értékkel. A publikus 2.0.0 ZIP SHA-256 értéke `7d487c8a458bf542f22f286cd9b98aeb6dc0d4d54615c833ac82873b88063199`. [Ellenőrzött kiadási futás](https://github.com/VlREX/VIREX/actions/runs/45906769307)

A `.github/workflows/studio-portable.yml` a `release/studio-X.Y.Z` nevű kiadási ág push eseményére indul. A verziónak egyeznie kell a Studio `VERSION` fájljával. A Windows build után külön közzétételi feladat csatolja a verziózott ZIP-et és Setup.exe-t a `studio-stable` kiadáshoz, csak sikeres tesztek után. Azonos nevű meglévő mellékletet nem ír felül. Az alkalmazáson belüli telepítős frissítéshez a következő fejezet szerinti Setup szükséges.

### Windows-telepítő készítése a következő kiadáshoz

1. Windows alatt telepítsd az Inno Setup 6 fordítót a magyar nyelvi fájllal együtt. A .NET Framework C# fordítóját a buildszkript a Windowsból használja. Verzióváltáskor szerkeszd a `VERSION` fájlt, futtasd a fenti ellenőrzéseket, és frissítsd ezt az átadást.
2. Futtasd a csomagolást. Egyedi telepítési helyen add meg a teljes `ISCC.exe` útvonalat a `-Compiler` paraméterrel.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\packaging\Build.ps1
```

3. A kimenet `artifacts\installer\VIREX-Test-Studio-2.0.1-Setup.exe`, a verziószám a `VERSION` értékét követi. A szkript kiírja a végleges fájl SHA-256 értékét. Ha a kiadó aláírja a telepítőt, a már aláírt bájtokat kell feltölteni. A telepítő stabil AppId-ja biztosítja az egymásra telepíthetőséget.
4. Egy külön Windows-felhasználónál ellenőrizd a tiszta telepítést, a Start menüs indítást, a meglévő riportok elérését, majd a régebbi telepített verzióról történő frissítést és az eltávolítást.
5. Amikor a tulajdonos kiadást kér, a **VlREX/VIREX** repó **studio-stable** címkéjű stabil GitHub Release-éhez töltsd fel a verziózott telepítőt release assetként. A kliens az ottani legmagasabb verziót ajánlja fel. A kiadás közzététele után ellenőrizd egy korábbi telepített példányon a letöltés, bezárás, telepítés és újraindítás teljes menetét.

### Ellenőrzési állapot az átadáskor

- **Windows alatt ellenőrizve**: a natív felület, a célváltás, az AI Review lapok, az átméretezés, a helyi Cargo-munkafolyamat, a folyamatfa-leállítás és a riportképzés. A Belobug-profil Git-műveletei helyi mintarepóval futottak. A konzolablak nélküli Windows-indító lefordult, a csomagolási receptben szereplő összes bemeneti fájl ellenőrzése sikerült.
- **Hálózat nélkül ellenőrizve**: verziók sorrendje, stabil kiadás kiválasztása, hibás URL, hibás méret, rossz SHA-256, hiányos vagy túl nagy letöltés, ismételt letöltés, hálózati hiba és a külön Python-híd tesztjei.
- **Az élő Belobug repón ellenőrizve**: a pontos repócím, az alapértelmezett ág és a gyökérben lévő Cargo-workspace. A futtatókörnyezetből a közvetlen Git HTTPS-kapcsolat nem volt elérhető, ezért a teljes távoli Rust-tesztcsomag és a GPU-futás eredménye nyitott.
- **2.0.1 ellenőrzése**: az új release workflow az integrációs tesztet és a Setup buildet is megköveteli; az élő verzióváltást és a magas DPI-s többmonitoros próbát külön kell igazolni.

Ha másik modell veszi át a munkát, először a `VERSION` fájlból és a fenti ellenőrzésekből állapítsa meg a kiinduló állapotot. A következő konkrét feladat a telepítési és élő frissítési próba. A vizsgált Belobug-revíziót mindig a legfrissebb futás `run.json` fájljából vegye át.
