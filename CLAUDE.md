# BlackwellUI - Azeroth Survivors (WoW 1.12.1 / Benilla Engine)

## Projektübersicht
BlackwellUI ist eine modulare Cyberpunk/Sci-Fi HUD- und Analytics-Engine für **Azeroth Survivors** (Roguelite auf Basis des Vanilla WoW 1.12.1 Clients, Engine „benilla“). Das Addon läuft sowohl im nativen Windows-Client (`AzerothSurvivors.exe`) als auch im WebGPU/WebAssembly (WASM) Browser-Client.

* **Repository:** `c:\Git\wenilla\benilla-config\AddOns\BlackwellUI`
* **Sync-Pfad Client:** `C:\Users\Pierre\Documents\AzerothSurvivors\benilla-config\AddOns\BlackwellUI`
* **Aktuelle Version:** 2.7.0-azs
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
   * **KEIN `C_Timer`:** Updates laufen über den 0.1s OnUpdate-Ticker von `Core.lua` (`Core:Tick()`).
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
* `Pins.lua`: Radar-Pins auf der Minimap (Bosse, Guardians, Truhen). Strata `HIGH`.
* `CombatText.lua`: Scrolling Combat Text mit Toggle (`B.db.sctAlerts` / Blizzard-Zahlen-Wiederherstellung).
* `Build.lua`: Spells, Ränge, Cooldowns, Buff-Bars (schaltbar mit `showBuffBars`), Level-Up Button.
* `Meter.lua`: Damage/DPS-Meter mit Breakdown, Proc-Merging, Taken-Anzeige.
* `UnitFrames.lua`: Hero, Target, Boss, Guardian Frames mit Klassenfarben und Schildbalken.
* `Minimap.lua`: Runder/quadratischer Minimap-Rahmen, Koordinaten.
* `Options.lua`: Einstellungs-UI (`/bw`, `/bw options`), Themes, Toggles (`showBuffBars`, `showGrid`, `sctAlerts`).

---

## Entwickler-Workflows & Befehle

### 1. Synchronisation mit lokalem Client
Nach Code-Änderungen in das Spielverzeichnis syncen:
```powershell
robocopy "c:\Git\wenilla\benilla-config\AddOns\BlackwellUI" "C:\Users\Pierre\Documents\AzerothSurvivors\benilla-config\AddOns\BlackwellUI" /MIR /XD .git .github media\screenshots /XF .gitignore
```

### 2. Release & Tagging
```powershell
git add -A
git commit -m "feat/fix: Beschreibung"
git tag v2.X.X-azs
git push origin main
git push origin v2.X.X-azs
```

### 3. Release-Archiv erstellen (GitHub Release)
```powershell
$target = "BlackwellUI"
Compress-Archive -Path "c:\Git\wenilla\benilla-config\AddOns\BlackwellUI" -DestinationPath "BlackwellUI.zip" -Force
gh release create v2.X.X-azs BlackwellUI.zip --title "BlackwellUI v2.X.X-azs" --notes "Release Notes"
```

---

## Pierre's Leitprinzipien
1. **Zero Hallucination:** Niemals APIs, Parameter oder Dateipfade erfinden. Bei Unsicherheit Code oder Binary-Strings prüfen.
2. **Defensive Programmierung:** Alle Methodenaufrufe auf Drittobjekten oder Modulen mit `if type(...) == "function"` absichern.
3. **Keine Silent Failures:** Fehler niemals mit `except: pass` oder leeren Blöcken verschlucken.
4. **Vollständige Patches:** Keine Platzhalter wie `// TODO` oder `# ... rest`.
