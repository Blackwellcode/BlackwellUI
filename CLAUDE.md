# BlackwellUI - Azeroth Survivors (WoW 1.12.1 / Benilla Engine)

## Projektübersicht
BlackwellUI ist eine modulare Cyberpunk/Sci-Fi HUD- und Analytics-Engine für **Azeroth Survivors** (Roguelite auf Basis des Vanilla WoW 1.12.1 Clients, Engine „benilla“). Das Addon läuft sowohl im nativen Windows-Client (`AzerothSurvivors.exe`) als auch im WebGPU/WebAssembly (WASM) Browser-Client.

* **Repository (Entwicklung):** `F:\aktiv\blackwellui`, Branch `main`
* **Live-Stand im Client:** `F:\aktiv\blackwellui-live`, git worktree auf Branch `live`
* **Client-Pfad:** `%USERPROFILE%\Documents\AzerothSurvivors\benilla-config\AddOns\BlackwellUI` ist eine Directory Junction auf den Live-Worktree (nicht auf das Entwicklungs-Repo)
* **Aktuelle Version:** 2.8.1-azs
* **TOC:** `BlackwellUI.toc` (Interface 11200, SavedVariables `BlackwellUIDB`)
* **Global Namespace:** `B` bzw. `BlackwellUI`

---

## Engine- & Sprachrestriktionen (WoW 1.12.1 / Lua 5.0)
Es läuft die Lua 5.0 Runtime der Vanilla 1.12.1 Engine. Folgende Regeln sind zwingend einzuhalten:

1. **Syntax & Operatoren:**
   * **KEIN `#`-Längenoperator:** Immer `table.getn(tbl)` oder `string.len(str)` verwenden.
   * **KEIN `%`-Modulo:** Immer `math.mod(a, b)` bzw. `math.fmod(a, b)`.
   * **KEINE String-Methoden:** Syntax wie `str:find(...)` crasht. Immer `string.find(str, ...)`, `string.gsub(...)`, `string.sub(...)`.
   * **KEIN `string.match` oder `string.gmatch`:** Immer `string.find` oder `string.gsub` mit Schleife nutzen.
   * **KEIN `select`, `wipe`, `strsplit`, `strtrim`:** Diese Funktionen existieren in Lua 5.0 nicht.
   * **Parameter:** Kein `...` außerhalb der Parameterdeklaration (in Lua 5.0 ist `arg` implizit die Argument-Tabelle).
   * **Float-Formatierung:** Bei `string.format("%d", x)` immer `math.floor(x)` übergeben.

2. **FrameXML & UI-APIs:**
   * **KEIN `SetSize(w, h)`:** Immer separat `SetWidth(w)` und `SetHeight(h)`.
   * **KEIN `SetColorTexture`:** Immer `tex:SetTexture(...)` mit `tex:SetVertexColor(r, g, b, a)` oder `B:Solid(...)` (`WHITE8X8`).
   * **KEIN `C_Timer`:** Updates laufen über den 0.1s OnUpdate-Ticker von `Core.lua` (`Core:Tick()`). Ereignisse rufen `B:RequestTick()` (Dirty-Flag, der Ticker bündelt es, max. 20 Hz), nie `B:Tick()` direkt.
   * **Tabellen im Takt wiederverwenden:** In `mod:Update` und OnUpdate keine neuen Tabellen je Tick (Puffer + Zähler, überzählige Einträge auf `nil`). Wiederverwendete Listen nie mit `table.insert` füllen: Lua 5.0 merkt sich die Länge dann per `setn`, und spätere Index-Zuweisungen zählt `table.getn` nicht mehr mit.
   * **KEIN `hooksecurefunc`:** Klassisches Function-Hooking (`local orig = Target; Target = function(...) orig(...) end`).
   * **Event-Handler:** Standardmäßig `this`, `event`, `arg1`..`arg9`.

3. **Cross-Platform & WASM:**
   * Texturen müssen **Power-of-Two** sein (16, 32, 64, 128, 256).
   * TGA-Dateien dürfen keine fehlerhaften Image-Descriptor-Flags aufweisen.
   * Klassenfarben: Sowohl numerische Klassen-IDs (WASM) als auch String-Token (`WARRIOR`) müssen aufgelöst werden (`B:GetClassColor`).

---

## Azeroth Survivors Engine-APIs (Extrahiert aus Binary)
Die Daten werden via `AZSApiFrame` oder Events bereitgestellt:
* `AZS_GetPhase()`: `"ready"`, `"playing"`, `"choosing"`, `"paused"`, `"dead"`, `"victory"`
* `AZS_GetRunTime()` / `AZS_GetRunLength()`
* `AZS_GetBosses()`, `AZS_GetGuardians()`, `AZS_GetUpcomingBosses()`
* `AZS_GetMeter()`: `{ name, dmg, dps, share, proc }`
* `AZS_RUN`: `{ t, ph, lvl, xp, xpn, hp, hpm, sh, gold, kills, lives, rr, dealt, taken, nb, nbn, ... }`
* `AZS_ZONE`: `{ zone, zname, zsub, diff, len, class, cname, race, rname, hero, ... }`
* `AZS_BUFFS`: `{ spell, left }`
* `AZS_SPELLS`: `{ key, spell, rank, cd, cdmax }`
* `AZS_UNITS`: `{ kind, id, name, hp, hpm, state }`
* `AZS_TARGET`: `{ kind, id, name, hp, hpm, state }`
* `AZS_CHESTS`, `AZS_LAIRS`: Locations für Radar-Pins

---

## Modul-Architektur
* `Core.lua`: Core-Namespace `B`, Datenbank `B.db`, Modul-Registrierung (`B:RegisterModule`), Mover & Alignment-Grid (`BUI_AlignmentGrid`), HUD & Combat-Text Sync (`B:SyncHud`, `B:RestoreStockCombatText`, `B:SyncCombatText`), Ticker (`Core:Tick` ruft `mod:Update(state)` defensiv auf).
* `Locale.lua`: Spracherkennung über die CVar `azsLanguage` (14 Spielsprachen; `GetLocale()` ist in benilla immer `enUS` und nur Fallback), Tabelle `B.L` (`L["English"]`, englischer Fallback), Override `B.db.language`, Font-Fallback auf Fira Sans für ru/uk (Barlow hat kein Kyrillisch). Übersetzungen in `Locales\<code>.lua` (`B:RegisterLocale`). UI-Texte nur zur Anzeigezeit mit `L[...]` übersetzen, nie in Tabellen auf Dateiebene.
* `AbilityNames.lua` / `GameStrings.lua` / `SpellIcons.lua`: generiert aus den Spieldaten (Spiel-JSON in der Exe via `tools/gen_abilitynames.py` / `tools/gen_gamestrings.py`, bzw. `Spell.dbc` via `tools/gen_spellicons.py`), nicht von Hand ändern.
* Stil: `B.db.uiStyle` = `"round"` (Standard) oder `"sharp"` (alter kantiger Stil), Umschalten erst nach `/reload`. Alle Hintergründe laufen über `B:Panel(f)` bzw. `B:Backdrop` (stilabhängig); `B:IsRound()` beim Bauen abfragen. Eckenradius `B.db.cornerRadius`, Panelfarbe `B.db.panelColor` (`false` = Stilfarbe), Schriftkontur `B.db.fontOutline`.
* Moduloptionen: Jedes Modul deklariert `mod.hint` und `mod.options` (Typen `section`, `note`, `toggle`, `range`, `choice`, `color`; Felder `key`/`db`, `default`, `depends`, `reload`, `format`) und setzt sie in `mod:ApplyOptions()` um. Werte in `B.db.mod[<modul>][<key>]`, lesen mit `B:ModOpt(key, opt, default)`. Skalierung/Deckkraft/Sichtbarkeit (immer, Kampf, außerhalb Kampf, Mouse-over) kommen automatisch aus Core für `mod.frame` bzw. `mod.lookFrames`; `mod.noLook` schaltet das ab. `Options.lua` erzeugt daraus pro Modul eine scrollbare Seite.
* Runde Optik (Konzept C): `B:RoundPanel`, `B:RoundBar`, `B:DotRing`, `B:RoundButton` in `Core.lua`, alle auf `media/textures/round.tga` (eigene Textur, erzeugt von `tools/gen_textures.py`). Die Engine kennt keinen Eckenradius; Ecken sind Kreisviertel. Meter, Timer und RareTimers nutzen sie.
* `GetWidth()`/`GetHeight()` liefern bei Frames mit zwei Ankerpunkten (`SetAllPoints`, TOPLEFT+TOPRIGHT) in benilla teils veraltete Werte (gemessen 220 statt 244). Für Layout-Berechnungen `B:FrameSize(f)` nutzen (aus `GetLeft/GetRight/GetTop/GetBottom`).
* Texturen im Layer `"HIGHLIGHT"` zeichnet benilla **dauerhaft**, nicht nur bei Mouse-over. Hover-Effekte deshalb als normale Textur bauen und in `OnEnter`/`OnLeave` zeigen/verstecken.
* Spell-Tooltips schreibt die Engine in der **Spielsprache** (`B.GAME_LANG`), nicht in der Addon-Sprache (`B.LANG`, ggf. Override). `Build.lua` erkennt Tooltip-Marker deshalb über `B:GameMatch`/`B:GameString` in Spielsprache plus Englisch (`B:TooltipLanguages()`), nie über fest verdrahtetes Englisch.
* `Pins.lua`: Radar-Pins auf der Minimap (Bosse, Guardians, Truhen). Strata `HIGH`.
* `CombatText.lua`: Scrolling Combat Text mit Toggle (`B.db.sctAlerts` / Blizzard-Zahlen-Wiederherstellung).
* `Build.lua`: Spells, Ränge, Cooldowns, Buff-Bars (schaltbar mit `showBuffBars`), Level-Up Button.
* `Meter.lua`: Damage/DPS-Meter mit Breakdown, Proc-Merging, Taken-Anzeige.
* `UnitFrames.lua`: Hero, Target, Boss, Guardian Frames mit Klassenfarben und Schildbalken.
* `Minimap.lua`: Runder/quadratischer Minimap-Rahmen, Koordinaten.
* `Options.lua`: Einstellungs-UI (`/bw`, `/bw options`), Themes, Toggles (`showBuffBars`, `showGrid`, `sctAlerts`).

---

## Entwickler-Workflows & Befehle

### 1. Entwicklung und Live-Stand im Client
Entwickelt wird in `F:\aktiv\blackwellui` (Branch `main`, Arbeit auf Feature-Branches oder Worktrees). Der Spielclient lädt den Worktree `F:\aktiv\blackwellui-live` (Branch `live`) über die Junction; halbe Zwischenstände landen so nicht im Spiel. Übernahme nach bestandenem Test-Gate (Abschnitt 4):
```powershell
git -C F:\aktiv\blackwellui-live merge --ff-only main
```
Danach im Spiel `/reload`. Kein `robocopy` (`/MIR` über eine Junction spiegelt ins Ziel).
* Prüfen: `(Get-Item "$env:USERPROFILE\Documents\AzerothSurvivors\benilla-config\AddOns\BlackwellUI").LinkType` liefert `Junction`, `.Target` zeigt auf `F:\aktiv\blackwellui-live`.
* Junction entfernen, ohne das Ziel anzufassen: `cmd /c rmdir "%USERPROFILE%\Documents\AzerothSurvivors\benilla-config\AddOns\BlackwellUI"` (nie `Remove-Item -Recurse`).
* Neu anlegen: `New-Item -ItemType Junction -Path "$env:USERPROFILE\Documents\AzerothSurvivors\benilla-config\AddOns\BlackwellUI" -Target 'F:\aktiv\blackwellui-live'`

### 2. Release & Tagging
```powershell
git add -A
git commit -m "feat/fix: Beschreibung"
git tag v2.X.X-azs
git push origin main
git push origin v2.X.X-azs
```

### 3. Release-Archiv erstellen (GitHub Release)
`tools/build_zip.py` packt nur, was das Spiel lädt (Ordner `BlackwellUI/`, ohne `.git`, `tools`, `CLAUDE.md`, `_`-Ordner wie `_work` und `*.zip`):
```powershell
python -I tools/build_zip.py . BlackwellUI.zip
gh release create v2.X.X-azs BlackwellUI.zip --title "BlackwellUI v2.X.X-azs" --notes "Release Notes"
```

### 4. Test-Gate (vor jedem Merge nach `main` und vor der Übernahme nach `live`)
```bash
bash tools/check.sh
```
Schritte: `luac -p` aller Lua-Dateien, `tools/lua50scan.py` (Lua-5.0-/1.12-Verstöße, Exit 1 bei Treffern; geprüfte Ausnahmen mit Kommentar `-- lua50scan: ok`), `toc_check.py` (Skill domain-wow-dev), `tools/l10n_tool.py catalog/check`, `tools/harness.lua` (Core) und `tools/harness_modules.lua` (alle TOC-Dateien gegen einen simulierten Client). Abschluss nur bei `GATE: OK`. Laufzeit im Client (CPU, Speicher) misst das Gate nicht.

---

## Leitprinzipien
1. **Zero Hallucination:** Niemals APIs, Parameter oder Dateipfade erfinden. Bei Unsicherheit Code oder Binary-Strings prüfen.
2. **Defensive Programmierung:** Alle Methodenaufrufe auf Drittobjekten oder Modulen mit `if type(...) == "function"` absichern.
3. **Keine Silent Failures:** Fehler niemals mit `except: pass` oder leeren Blöcken verschlucken.
4. **Vollständige Patches:** Keine Platzhalter wie `// TODO` oder `# ... rest`.
