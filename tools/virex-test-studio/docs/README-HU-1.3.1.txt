VIREX TEST STUDIO 1.3.1
Helyi Rust tesztlabor | Windows 10 / 11 | Windows PowerShell 5.1

ÚJDONSÁGOK – 1.3.0
- 3x tests: a célzott és a teljes Rust crate-teszt háromszor fut, ha be van
  jelölve (alapértelmezett). Hiba esetén a meglévő hibakapuk megállítják a
  futást. A check, Clippy és benchmark továbbra is egyszer fut.
- AI Review fül: USE CURRENT REPORT vagy LOAD REPORT / TEXT; ellenőrizd,
  szükség esetén szerkeszd/maszkold a jelentést. COPY CLAUDE TASK másolja
  a feladatot. Illeszd Claude-ba, majd a válaszát a második alfülbe.
  COPY GPT TASK a jelentést és Claude válaszát együtt másolja. Illeszd
  ChatGPT-be, majd a választ a harmadik alfülbe. SAVE SESSION helyi mentés.
  Ez a mód nem igényel API-t, és semmit sem küld el automatikusan.
- Opcionális API-híd: EXPORT EVIDENCE, majd START-AI-REVIEW.cmd.
  Python 3.9+ szükséges, nincs telepítendő Python-csomag. A konzolban add meg
  az exportált TXT útvonalát és a szolgáltatóknál elérhető API-modellazonosítót.
  Minden szolgáltatóhoz külön SEND jóváhagyás és API-kulcs kell. A kulcsot
  nem mentjük, a válaszok helyi mappába kerülnek az exportált fájl mellé.
  A két hívás díjköteles lehet, egyenként 3000 kimeneti token felső korláttal.
  A második hívás elhagyható; a Claude-válasz akkor is megmarad.
  Az API-híd legfeljebb 120 000 karakteres UTF-8 jelentést fogad.
  Az API-kulcsokat ne tárold a tesztelő környezeti változóiban, és ne futtass
  nem megbízható tesztkódot az API-híd használata közben.
  Sem a kézi, sem az API-mód nem ír át kódot vagy küld GitHub PR-t.
- Frissítés: csomagold ki új mappába. A korábbi helyi riportok és tesztklón
  változatlan helyen maradnak; az előző verziót ne futtasd párhuzamosan.

ELLENŐRZÉSI ÁLLAPOT
A Python API-híd mock tesztjei: python -m unittest -v test_ai_review
A Windows GUI és az élő API-hívások itt nem voltak futtathatók; első helyi
indításkor ellenőrizd a füleket, majd futtass egy ismert tesztcélt.
Az API-khoz külön szolgáltatói hozzáférés szükséges, a chat-előfizetés nem
helyettesíti az API-kulcsot. A jelentések tartalmát megosztás előtt nézd át.

INDÍTÁS
1. A ZIP-et mentsd le. Ha a Windows blokkolja a letöltött fájlokat,
   a ZIP tulajdonságainál oldd fel a tiltást (Unblock), miután megbízhatónak
   ítélted a csomagot. Csomagold ki egy külön mappába.
2. Kattints duplán a START-VIREX.cmd fájlra. Nem kell admin jogosultság.
3. Válassz célpontot. A VIEW SOURCE megnyitja a futtatandó, rögzített commitot.
   Csak megbízható kódot és függőségeket futtass. A GitHubon lévő forrás
   fordításakor build script és tesztkód is futhat a saját jogosultságoddal.
4. Pipáld be, mit szeretnél futtatni, majd RUN SELECTED. A megerősítés után
   az első futtatás külön repót klónoz, a többi ugyanazt a tesztklónt használja.
5. A Live terminal fülön követheted a naplót. Benchmark data: táblázat és
   soronkénti összehasonlító sávdiagram. Shareable report: rövid jelentés.
6. COPY REPORT, majd Ctrl+V ebbe a ChatGPT-beszélgetésbe. A teljes napló
   a COPY FULL LOG gombbal másolható, vagy fájlként csatolható.

ELSŐ JAVASOLT MÉRÉS
Válaszd a #1869 | Adaptive memory range index célpontot. A Benchmark (release)
beállítás legyen bejelölve. Ha csak mérni szeretnél, a többi jelölést kapcsold ki.
96 konfiguráció: eredeti, indexelt és adaptív keresés. Az indexépítés költsége
beleszámít. A hét futás mediánja jelenik meg, mikroszekundumban. Az összevetés
szintetikus, nem játék-FPS. A teszt a három változat kimenetét is ellenőrzi.

MIT FOG CSINÁLNI?
- Egyetlen futás egyszerre; STOP megpróbálja a teljes gyermekfolyamatfát leállítani.
- A meglévő C:\Users\TP-LINK\VIREX mappát NEM használja és nem módosítja.
- Külön mappa: %LOCALAPPDATA%\VIREX Test Studio\repo
- Fordítási cache: %LOCALAPPDATA%\VIREX Test Studio\target
- Jelentések: %LOCALAPPDATA%\VIREX Test Studio\reports
- A commit SHA ellenőrzése kötelező. Ha a forráság eltűnt, vagy a revízió
  már nem elérhető, a futás leáll. Nincs automatikus átváltás más commitra.
- Hibás build/teszt esetén leáll; a hibát nem tünteti el.
- A választott tesztek szerint workspace check, célzott vagy teljes crate-teszt,
  Clippy warnings denied, és az adott benchmark futtatható.
- WARP opció beállítja a két ismert VICTORY_WARP környezeti változót;
  a jelentés a kért beállítást rögzíti, nem állítja, hogy a GPU tényleg WARP volt.
- REPORT.txt: rövid napló + gép/driver + pontos commit + exit code.
- FULL-LOG.txt: teljes stdout/stderr (külön folyamok, nem időrendben összefűzve).
- run.json: strukturált lépésadatok. benchmark.csv: mérési sorok.
- A nyers naplók is megmaradnak. Megosztás előtt nézd át őket.
  A másolható jelentések a felhasználói mappa teljes útvonalát maszkolják,
  de egyéb esetleges személyes adatokat nem feltétlenül.

NINCS AI API, TOKEN, TÁVOLI ELÉRÉS, TELEMETRIA VAGY AUTOMATIKUS FELTÖLTÉS.
A program GitHubról tölt le forrást, a Cargo letöltheti a függőségeket.
A ChatGPT nem látja automatikusan a terminált: te döntöd el, mit másolsz be.
A Studio nem tölti fel a kódot vagy az eredményeket, nem nyit PR-t.
A 12 beépített célpont rögzített commit, nem élő PR-lista. Új PR-hoz vagy
friss commitokhoz a ps1 elején található presetlista módosítható.

HIBAELHÁRÍTÁS
- Rust/Git hiányzik: újraindítás után indítsd a programot; a Rust, Cargo és
  Git legyen elérhető a PATH-ból. Windows PowerShell 5.1 szükséges.
- Ha a Windows csak az aláírt szkripteket engedi, a szervezeti szabályokat
  ne kerüld meg. Otthoni gépen a letöltési jelölés feloldása lehet elég:
  a kicsomagolt fájl áttekintése után a mappában futtasd:
  Unblock-File -LiteralPath .\VIREX-Test-Studio.ps1
  A launcher csak saját folyamatára kér RemoteSigned házirendet.
- Ha a tesztklónban helyi változtatás van, a futtató nem törli azt. Nézd meg a
  külön repo mappát és kézzel dönts a változtatásokról.
- A shader/GPU teljes tesztjei platformfüggő, korábban is ismert hibákat
  jelezhetnek; a Studio nem tekinti ezeket automatikusan elfogadhatónak.
- A STOP nem biztonsági sandbox. A forrás és a függőségek futtatását csak
  ellenőrzött kódnál engedélyezd. Ne használd adminisztrátorként.

VERZIÓÁLLAPOT
1.1: javított folyamatkezelés, natív .NET Process és külön stdout/stderr
naplózás. A futtató minden indításkor két kontrollparanccsal ellenőrzi a
0 és 7 kilépési kódot és a két naplócsatornát. Ha ezek nem stimmelnek,
a teszt leáll. A korábbi külön tesztklón és fordítási cache megmarad.
Ha a klónozás tényleg megszakadt, és a repo mappa nem üres, de nem Git-repo,
a Studio bezárása után nevezd át csak a külön repo mappát (ne töröld),
majd indítsd újra. A meglévő saját VIREX checkoutot ne módosítsd.
A javítás statikusan ellenőrizve; Windows futás itt nem volt elérhető.

1.2: STOP nem vár korlátlanul a grafikus szálon. A futtató a gyermekfolyamatot
Windows Job Objecthez kapcsolja, STOP esetén annak leállítását kéri háttérszálon.
A kimeneti csatornák lezárását és a folyamatok befejezését a timer ellenőrzi.
Az automatikus leállítási önteszt egy rövid helyi cmd/ping folyamatot állít le.
12 másodperces STOP-határidő után, ha a leállítás nem igazolt, FAIL és új futás
tiltása következik. Ellenőrizd a Feladatkezelőt, majd indítsd újra a Studiót.
A Job Object a Process.Start után csatlakozik; ez nem biztonsági sandbox.
A live preview korlátozott, a teljes nyers napló megmarad.
#1840 célzott SCC-tesztekre váltott, a teljes csomag külön pipálható.
A #1840 BASELINE célpont a módosítás előtti rögzített commit.
A teljes shader-teszt platformfüggő hibáit továbbra is FAIL-ként kezeli.
A 1.2 javítás statikusan ellenőrzött, Windows natív teszt még szükséges.

1.2.1: #2479 frame interval synchronization, célzott frame::tests:: szűrő.
A #1840, #1846, #1862 BENCH célpontok a már kipróbált külön benchmark-
commitokat futtatják Cargo Release módban, táblázattal és CSV-exporttal.
A benchmark csak akkor PASS, ha a teszt sikeres és minden elvárt sor megvan.
A korábbi cache és jelentések megmaradnak. Az új GUI-integráció natív
Windows ellenőrzése még szükséges.


1.3.1 – ÚJ TESZTCÉL
#2747 FIX CANDIDATE | Alias flags fallback
A külön GitHub-ágon lévő kísérleti javítás: 838efa0843036ef80808eef7061276b5b5d139f4.
Az eredeti #2747 teszt továbbra is elérhető. A jelöltet futtasd először WARP nélkül, majd WARP-pal; Targeted Rust tests és 3x tests legyen bejelölve. A javítás még nincs GPU-n igazolva.
