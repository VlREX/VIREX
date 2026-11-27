# VIREX Test Studio 3.0.1 Preview – Command Center

[**Hordozható Windows ZIP letöltése**](https://github.com/VlREX/VIREX/releases/download/studio-preview/VIREX-Test-Studio-3.0.1-Preview-Windows.zip) · [GitHub-kiadás](https://github.com/VlREX/VIREX/releases/tag/studio-preview)

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

## 2.2.1 – Crash Diagnostics

AUTO L3 workspace teszt esetén a STATUS_ACCESS_VIOLATION / 0xc0000005 és egyértelmű Cargo -p package --lib újrafuttatási javaslat automatikus diagnosztikai ágat indít. Az eredeti hibás riport külön ORIGINAL-FAIL.txt fájlban marad, L4 nem fut. Egy soros crate lib újrateszt, legfeljebb egy pontos gyanús teszt újrafuttatása (ha a soros napló be nem fejezett tesztnevet mutat), majd helyi Application Error eseménynapló lekérdezés. Az eredmény mindig megőrzi az eredeti FAIL státuszt. Egy sikeres újrateszt nem igazolja a hibajavítást. A gyanús teszt nem bizonyított hibaforrás; a natív stack trace vagy dump nem automatikus. A Windows eseménynapló csak a futtatás óta keletkezett, megfelelő exe-nevű Application Error eseményeket keresi; hiányzó esemény lehetséges. Nem módosít registryt és nem gyűjt dumpot. Nincs automatikus feltöltés. A CI szintetikus kilépési kóddal ellenőrzi az ágat, nem valódi GPU-crashsel.

MANUAL módban a Test Lab új crate, pontos tesztnév, egy szál mezőit is használhatod a workspace teszt opcióval. A JSON v2 a v1 mezőin felül crate, test, threads mezőket vár; threads 0 (Cargo alapértelmezett) vagy 1. A crate név és a tesztnév szigorúan ellenőrzött, nem parancssori szöveg. Példa:

```json
{"v":2,"target":"https://github.com/Belobug/VIctory-Belobug-AMD/commit/2083466bb80691d99b917d09cd9d55084338c55a","check":false,"workspace":true,"clippy":false,"repeat":1,"agility":true,"depth":false,"crate":"victory-shader","test":"","threads":1}
```

## 2.2.0 – AUTO / MANUAL Test Lab

Az AUTO mód a Rust workspace célokra érhető el; a régi egyedi benchmark presetek MANUAL módban maradnak. Válaszd ki a PR-t vagy a workspace-t, kapcsold AUTO-ra a módválasztót, és válassz General Rust vagy D3D12/Agility profilt. A Belobug #360 kiválasztása után AUTO-ra váltáskor a D3D12 profil az alapértelmezett. Egyetlen jóváhagyás után L0: runner és revízió, L1: Agility (D3D12 profil) és check, L2: pontos GPU-teszt háromszor (D3D12 profil), L3: teljes workspace-teszt egyszer, L4: strict Clippy. A tesztek ugyanazt a checkoutot és cache-t használják; nincs ismételt fetch vagy újraindítás. A Cargo saját párhuzamosítását és inkrementális fordítását használjuk, nem erőltetjük az összes CPU-magot vagy párhuzamos GPU-tesztfolyamatokat. Hibánál megáll, a későbbi szintek NOT RUN állapotúak. A riportmappában szintenként LEVEL-N.txt, végül összesített riport és nyers naplók. A Clippy előzetesen meglévő figyelmeztetés miatt is megállhat. 

MANUAL módban a Test Lab GPT test profile mezőjébe másolható a következő JSON v1 (a cél lehet PR-, branch- vagy teljes commit-link):

```json
{"v":1,"target":"https://github.com/Belobug/VIctory-Belobug-AMD/pull/360","check":true,"workspace":true,"clippy":false,"repeat":1,"agility":true,"depth":true}
```

A profil csak a felsorolt mezőket fogadja, nem futtat beillesztett shell-parancsot vagy tetszőleges Cargo-argumentumokat, nem indít tesztet automatikusan. A felhasználó ellenőrzi a beállításokat és jóváhagyja a futtatást. Nincs közvetlen ChatGPT API-üzenetküldés vagy automatikus feltöltés; a riportot kézzel lehet másolni. Az upstream kód futtatása továbbra sem sandboxolt.

## 2.1.2 – Tárhely és hardver

A **Tárhely / hardver** fülön válassz helyi SSD-mappát. A Studio saját VIREX-Studio-Cache almappát hoz létre és elmenti a választást. Csak a menedzselt távoli projektek Cargo buildcache-e kerül oda, a Git checkoutok, riportok, Cargo home és TEMP a korábbi helyükön maradnak. A helyi saját projektek Cargo-beállításait nem írja felül. A régi cache nem mozdul és nem törlődik automatikusan; az alapértelmezett cache visszaválasztásával törölhető. A törlés csak a cache és target almappákra vonatkozik, külön megerősítéssel, átirányított elemek esetén megszakad. A mérés és törlés háttérben fut, közben nem indítható build vagy frissítés.

Indításkor minimum 5 GiB szabad cache-hely és 1 GiB a riport, TEMP, Cargo home meghajtóin szükséges. 20 GiB alatt figyelmeztet. Ezek nem garantált buildigények. A teljes workspace mérete nagyobb lehet. A Windows számlálóiból rendszerterhelést mintavételez: CPU, RAM, legterheltebb GPU-motor és összes dedikált GPU-memória. Nem folyamatonkénti mérés, nem garantált minden driveren, a rövid terhelési csúcsokat kihagyhatja. N/A jelzi a hiányzó adatot. A riport az észlelt csúcsokat tartalmazza; nem játék FPS. 

## 2.1.1 – Windows 10 / D3D12 Agility

A Windows buildszámot a Studio felismeri, de nem telepít semmit automatikusan. A Belobug #360 PR (vagy a megfelelő pontos commit) kiválasztása után jelöld be az **Agility SDK előkészítés** és **D3D12 depth bounds teszt** opciókat. Az Agility csak jóváhagyással, a kiválasztott forrás saját `cargo xtask agility` parancsával fut. Az upstream parancs a Microsoft NuGet csomagját tölti le és ellenőrzi annak SHA-512 értékét. A Studio külön, -agility végű Cargo-cache-t használ; nem módosít Windows-rendszerfájlokat. Az eredeti baseline cache megmarad. A revíziónak tartalmaznia kell a szükséges Agility forrásfájlokat. A Studio a parancs kilépési kódját és a két staging DLL meglétét ellenőrzi; ez önmagában nem bizonyítja a tényleges GPU runtime betöltését.

Célzott futtatáshoz kapcsold ki a munkaterület-tesztet és a Clippyt, jelöld be a háromszoros ismétlést. A pontos GPU-teszt nevére és az egyetlen sikeres tesztre külön gate van, az explicit DXC/depth-bounds kihagyás nem PASS. Egyes upstream tesztek néma korai visszatérést használnak, így az eredmény nem igazolja önmagában a GPU-útvonal futását. A riport tartalmazza a Windows buildszámot, a staging állapotát és a tesztelt SHA-t. A CI offline, inert staging fixture-t használ; a valódi SDK és fizikai GPU ellenőrzése a felhasználó gépén szükséges. A távoli forrás nem sandboxolt.

## 2.1.0 – PR Manager

A PR Manager fülön illeszd be a GitHub PR-, branch- vagy teljes commit-linket, majd válaszd a **Tesztcél betöltése** gombot. A meglévő Cargo ellenőrzéseket a **Futtatás** gomb indítja, külön jóváhagyással. A PR URL a GitHub által közzétett refs/pull/N/head revíziót tölti le, nem a merge commitot. A branch és PR aktuális revíziója változhat; a riport és a run.json rögzíti a tényleges SHA-t. Teljes commit-linknél eltérő SHA esetén nincs teszt. A Studio nem nyit PR-t és nem pushol, valamint nem futtat automatikusan kódot a link megadásakor. A forrásnak továbbra is megbízhatónak kell lennie. A stabil frissítési csatorna változatlan.

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

A távoli GitHub-mód saját klónt használ. Futtatás előtt ellenőrzi a munkafa tisztaságát és az origin címét, majd lekéri a megadott ágat, kiválasztja a `FETCH_HEAD` commitot és kiolvassa a SHA-t. Módosított klónnál a futás leáll. A tesztelendő repó kiválasztása kizárólag a tesztcélra hat. A stabil Studio a **VlREX/VIREX** kiadási csatornáján keres frissítést. Az előnézet a studio-preview GitHub-kiadást ellenőrzi.

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

3. A kimenet `artifacts\installer\VIREX-Test-Studio-2.1.2-Setup.exe`, a verziószám a `VERSION` értékét követi. A szkript kiírja a végleges fájl SHA-256 értékét. Ha a kiadó aláírja a telepítőt, a már aláírt bájtokat kell feltölteni. A telepítő stabil AppId-ja biztosítja az egymásra telepíthetőséget.
4. Egy külön Windows-felhasználónál ellenőrizd a tiszta telepítést, a Start menüs indítást, a meglévő riportok elérését, majd a régebbi telepített verzióról történő frissítést és az eltávolítást.
5. Amikor a tulajdonos kiadást kér, a **VlREX/VIREX** repó **studio-stable** címkéjű stabil GitHub Release-éhez töltsd fel a verziózott telepítőt release assetként. A kliens az ottani legmagasabb verziót ajánlja fel. A kiadás közzététele után ellenőrizd egy korábbi telepített példányon a letöltés, bezárás, telepítés és újraindítás teljes menetét.

### Ellenőrzési állapot az átadáskor

- **Windows alatt ellenőrizve**: a natív felület, a célváltás, az AI Review lapok, az átméretezés, a helyi Cargo-munkafolyamat, a folyamatfa-leállítás és a riportképzés. A Belobug-profil Git-műveletei helyi mintarepóval futottak. A konzolablak nélküli Windows-indító lefordult, a csomagolási receptben szereplő összes bemeneti fájl ellenőrzése sikerült.
- **Hálózat nélkül ellenőrizve**: verziók sorrendje, stabil kiadás kiválasztása, hibás URL, hibás méret, rossz SHA-256, hiányos vagy túl nagy letöltés, ismételt letöltés, hálózati hiba és a külön Python-híd tesztjei.
- **Az élő Belobug repón ellenőrizve**: a pontos repócím, az alapértelmezett ág és a gyökérben lévő Cargo-workspace. A futtatókörnyezetből a közvetlen Git HTTPS-kapcsolat nem volt elérhető, ezért a teljes távoli Rust-tesztcsomag és a GPU-futás eredménye nyitott.
- **2.0.1 ellenőrzése**: az új release workflow az integrációs tesztet és a Setup buildet is megköveteli; az élő verzióváltást és a magas DPI-s többmonitoros próbát külön kell igazolni.

Ha másik modell veszi át a munkát, először a `VERSION` fájlból és a fenti ellenőrzésekből állapítsa meg a kiinduló állapotot. A következő konkrét feladat a telepítési és élő frissítési próba. A vizsgált Belobug-revíziót mindig a legfrissebb futás `run.json` fájljából vegye át.


### Optimalizált benchmark futtatása

A Test Lab MANUAL módjában adj meg egy crate-et és pontos tesztnevet, kapcsold be a tesztelést és a Release build opciót. Az ignored opciót akkor válaszd, ha a teszten szerepel a Rust #[ignore] attribútum. Az ismétlések összesítése a riportban és a benchmark-summary.json fájlban jelenik meg.

A v3 JSON-profil a v2 mezőket két logikai mezővel, release és ignored, egészíti ki. A target értéke teljes SHA-t tartalmazó GitHub commit URL. Példa a snapshot sweep benchmarkra:

~~~json
{"v":3,"target":"https://github.com/VlREX/VIctory-Belobug-AMD/commit/e4ee797c4aa5f919d06234d60fd854220674d262","check":false,"workspace":true,"clippy":false,"repeat":3,"agility":false,"depth":false,"crate":"victory-gpu","test":"shadow::snapshot_sweep_tests::benchmark_snapshot_sweep","threads":1,"release":true,"ignored":false}
~~~


### D3D12-validáció

Ha a naplóban nincs igazolt GPU-visszaolvasás, a D3D12-ellenőrzés `NOT VERIFIED` állapotot kap. Kifejezett kihagyásnál `SKIPPED` jelenik meg. Ez az AUTO szintjelentésben és az összesített futási eredményben is látszik. A későbbi CPU-ellenőrzések ettől még lefutnak. A teszt valódi hibája továbbra is `FAIL`.

Az instrumentált depth-bounds teszt az ellenőrzött képpontok visszaolvasása után írhatja ki a következő sort, ha a DXGI-adapter natív hardveres adapter: `NATIVE DEPTH READBACK PASSED: <adapter> PCI <vendor>:<device>`. A Studio csak a sikeresen befejezett, pontosan célzott teszthez fogadja el ezt a sort. A gyári, jelzés nélküli upstream teszt `NOT VERIFIED` minősítést kap.

### Előnézeti telepítő

A `packaging/Build.ps1 -Preview` külön előnézeti Setup.exe-t készít. A `packaging/Build-Portable.ps1 -Preview` az ugyanígy megjelölt hordozható ZIP-et hozza létre. Az előnézeti ablak címsorában megjelenik az „Előnézet” jelölés. Az előnézet a studio-preview GitHub-előkiadásból keresi a Preview-Setup.exe végű telepítőket. Ha a csatornán még nincs kiadás, az előnézet az elérhető csomagból kézzel frissíthető. Az előnézet külön telepítési mappát és eltávolítási bejegyzést használ. Az alkalmazás a meglévő Studio-adatmappát használja, így a riportok mindkét kiadásból elérhetők. A Setup.exe /PORTABLE=1 /DIR="C:\VIREX-Preview" kapcsolóval parancsikon és eltávolítási bejegyzés nélkül is kicsomagolható egy írható mappába.

## 3.0.1 – vizuális frissítés

A referencia alapján natív, dupla pufferelt Command Center, valódi tesztállapotok, rendszerszintű CPU/RAM/GPU idősorok és cache-meghajtó adatok. A folyamatjelző a befejezett lépések arányát mutatja, nem becsült futási időt. Az Animáció kapcsoló kikapcsolja a folyamatjelző mozgását. A hiányzó vagy 15 másodpercnél régebbi hardvermintákat N/A jelöli. Az eredeti tesztmotor, GPU-validáció, benchmarkfeldolgozás és preview frissítő változatlan. A CI képernyőkép szintetikus UI tesztadatokat tartalmaz, nem hardveres validációt.
