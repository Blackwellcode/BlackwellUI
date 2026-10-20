# BlackwellUI (BUI) // CYBERPUNK TACTICAL HUD FOR AZEROTH SURVIVORS

[![WoW Version](https://img.shields.io/badge/WoW-1.12.1%20Vanilla-blue.svg?style=flat-square)](https://github.com/Seele2024/BlackwellUI)
[![Game Mode](https://img.shields.io/badge/Mode-Azeroth%20Survivors-red.svg?style=flat-square)](https://github.com/Seele2024/BlackwellUI)
[![Release](https://img.shields.io/badge/Release-v2.1.0--azs-00e5ff.svg?style=flat-square)](https://github.com/Seele2024/BlackwellUI/releases)
[![Lua Engine](https://img.shields.io/badge/Engine-Strict%20Lua%205.0-brightgreen.svg?style=flat-square)](https://github.com/Seele2024/BlackwellUI)
[![License](https://img.shields.io/badge/License-MIT-orange.svg?style=flat-square)](https://github.com/Seele2024/BlackwellUI/blob/main/LICENSE)

> **BlackwellUI** is a lightweight, high-performance tactical HUD overhaul engineered from scratch specifically for the **Azeroth Survivors** game mode on World of Warcraft (Vanilla 1.12.1).

---

## ⚡ What is Azeroth Survivors & BlackwellUI?

**Azeroth Survivors** transforms World of Warcraft 1.12.1 into an adrenaline-fueled reverse bullet-hell / survival roguelite (*Vampire Survivors* style). Abilities trigger automatically, hordes of thousands of enemies swarm the arena, and millisecond build optimization decides victory or death.

Stock World of Warcraft UI (action bars, bag slots, micro menus, standard unitframes) is cluttered and counter-productive for this game mode. **BlackwellUI** completely purges all Blizzard UI overhead and replaces it with a razor-sharp tactical Cyberpunk HUD featuring 1px borders, dark translucent backdrops, Expressway typography, and real-time combat telemetry.

---

## 📸 In-Game Screenshots

### 1. Tactical Combat HUD (Naxxramas: The Scourge Invasion)
![BlackwellUI Combat HUD](media/screenshots/hud-overview.png)
*Full in-game combat HUD during a Naxxramas run. Centered Hero & Target frames with ability cooldown matrix, streamlined chat panel, economy telemetry DataBar, encounter radar and damage meter on the right, and the overhauled character sheet on the left.*

<br/>

### 2. Character Matrix & Run Stats Panel ('C' Key)
![Character Info & Run Stats](media/screenshots/character-runstats.png)
*Redesigned Character Info window: Crisp 3D model frame, item quality border highlights, zero redundant bottom tabs, and the Azeroth Survivors Run Stats panel cleanly docked to the right edge.*

<br/>

### 3. Run Clock, Boss Schedule & Live Damage Meter
![Run Timer & Damage Meter](media/screenshots/timer-meter.png)
*Live 20-minute run clock with boss spawn countdowns (Gates of Ahn'Qiraj: Kurinnaxx, General Rajaxx, Princess Huhuran, C'Thun) stacked directly above the Damage Meter featuring ability icons, dynamic equipped weapon textures, DPS rates, and the interactive `[R]` session reset button.*

---

## 🩸 Key Features

* **Zero-Clutter Philosophy:** Blizzard action bars, bags, and micro buttons are permanently hidden and suppressed. 100% of your screen is dedicated to combat visibility and threat tracking.
* **Centered Cooldown Manager:** 36×36px spell tiles with dark cooldown overlays, active rank badges, and full spell tooltips on hover. Includes dynamic weapon icon detection for melee swings and ranged auto-shots.
* **Target Debuff Aura Bars:** Stacks debuff bars directly above your target frame with square spell icons, spell names, remaining durations, and centered ticking damage values.
* **Cyberpunk Nameplates:** 120×10px statusbars, 1px contrast borders, neon reaction coloring (Hostile Red, Neutral Gold, Friendly Green), and dynamic accent borders for your active target.
* **Elites & Bosses Radar:** Tracks bosses, guardians, and elites in real-time with remaining HP and percentages. Supports **click-targeting** directly from the tracker row.
* **Authentic Damage Meter:** Toggle between Damage Done and Taken. Features the **`[R]` Reset Button** (Left-Click: resets session damage & DPS to 0 / Right-Click: restores total run data).
* **Live Stat Multipliers:** Displays active player multipliers (Damage, Cooldown Reduction, Crit, Area, Echo, Speed) parsed directly from `AZS_STATS`. Automatically hides when the Character Frame is opened to avoid screen overlap.
* **Telemetry DataBar:** Bottom telemetry strip displaying XP progress, Level, Kills, Gold, **Next Chest Cost**, Lives, Rerolls, and real-time FPS.

---

## 🎛 Quick Controls & Commands

| Command | Action |
|---|---|
| `/bui` or `/blackwell` | Toggle the BlackwellUI Control Center (Themes, Accent Colors, Font Scale) |
| `/bui unlock` or `/bui move` | Unlock all HUD frames for drag-and-drop repositioning |
| `/bui lock` | Lock all HUD frames in place |
| `/bui reset` | Reset all frames to default screen layout |
| `/bui demo` | Toggle demo/preview mode with simulated combat data |
| `/bui hud` | Toggle replacement of the stock Azeroth Survivors run HUD |

---

## 🔗 Links & Resources

* **GitHub Repository:** [github.com/Seele2024/BlackwellUI](https://github.com/Seele2024/BlackwellUI)
* **Releases & Downloads (`BlackwellUI.zip`):** [github.com/Seele2024/BlackwellUI/releases](https://github.com/Seele2024/BlackwellUI/releases)
* **Game Mode:** Azeroth Survivors (Custom Vanilla 1.12.1 Client)
* **Issue Tracker & Feature Requests:** [github.com/Seele2024/BlackwellUI/issues](https://github.com/Seele2024/BlackwellUI/issues)

---

## 🛠 Engineering Standard

* **100% Strict Lua 5.0:** Engineered specifically for the WoW 1.12.1 client core (no `#` length operators, no `%` modulo operators, no string method calls).
* **Zero Texture Leaks:** Idempotent border and backdrop management (`buiEdges` caching), eliminating texture duplication and memory bloat.
* **Zero Hallucination Defensive Architecture:** Safe function-type checks across all Azeroth Survivors globals (`AZS_*`), guarded spellbook scanners, and plain-string substring matching to prevent regex pattern crashes.
